#requires -Version 5.1
# Run with: pwsh -NoProfile -File public-demo/tests/launcher_test.ps1
# No Docker, network, registry, real credentials or existing demo data are used.
# This checks launcher logic; Windows ACLs, Docker Desktop and ZIP extraction
# still need a real Windows acceptance test.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$launcher = Join-Path (Split-Path $PSScriptRoot -Parent) 'OnTrack.ps1'
$template = Join-Path (Split-Path $PSScriptRoot -Parent) '.env.example'
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
. $launcher -LibraryOnly

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ontrack-launcher-test-' + [guid]::NewGuid().ToString('N'))
$script:Checks = 0
$script:Calls = New-Object Collections.Generic.List[object]
$script:ProtectedPaths = New-Object Collections.Generic.List[string]
$script:Reply = ''
$script:Started = 0
$script:DockerExitCode = 0
$script:CapturedDockerArguments = @()

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAILED: $Message" }
    $script:Checks++
}

function Assert-Throws([scriptblock]$Operation, [string]$ExpectedMessage) {
    $caught = $null
    try { & $Operation } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught.Contains($ExpectedMessage)) "Expected refusal containing '$ExpectedMessage'; got '$caught'."
}

function Read-Settings {
    $result = @{}
    Get-Content $script:EnvPath | ForEach-Object {
        if ($_ -match '^([A-Z_]+)=(.*)$') { $result[$Matches[1]] = $Matches[2] }
    }
    return $result
}

function New-TestArchive([string]$Path, [hashtable]$Entries) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $Entries.Keys) {
            $entry = $zip.CreateEntry($name)
            if ($name.EndsWith('/')) { continue }
            $writer = New-Object IO.StreamWriter($entry.Open())
            try { $writer.Write($Entries[$name]) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
}

# Every external action is replaced before a tested function can reach it.
function Protect-LocalFile([string]$Path) { $script:ProtectedPaths.Add($Path) }
function Invoke-WebRequest { throw 'Unexpected network request in launcher test.' }
function Start-Process { throw 'Unexpected browser launch in launcher test.' }
function docker {
    $script:CapturedDockerArguments = @($args)
    $global:LASTEXITCODE = $script:DockerExitCode
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $script:RepositoryRoot = Join-Path $testRoot 'package with spaces'
    $script:DemoRoot = Join-Path $script:RepositoryRoot 'public-demo'
    New-Item -ItemType Directory -Path $script:DemoRoot -Force | Out-Null
    Copy-Item -LiteralPath $template -Destination (Join-Path $script:DemoRoot '.env.example')
    $script:EnvPath = Join-Path $script:DemoRoot '.env'

    $Hostname = 'https://invalid.example/path'
    Assert-Throws { Initialize-Settings } 'Enter a hostname'
    Assert-True (-not (Test-Path $script:EnvPath)) 'Invalid hostname must not write settings.'
    $Hostname = 'OnTrack.Example.Com'
    Initialize-Settings
    $settings = Read-Settings
    Assert-True ($settings.PUBLIC_HOST -ceq 'ontrack.example.com') 'Hostname is normalized.'
    $secretNames = @('MARIADB_PASSWORD', 'MARIADB_ROOT_PASSWORD', 'DF_SECRET_KEY_BASE', 'DF_SECRET_KEY_ATTR',
        'DF_SECRET_KEY_DEVISE', 'DF_ENCRYPTION_PRIMARY_KEY', 'DF_ENCRYPTION_DETERMINISTIC_KEY', 'DF_ENCRYPTION_KEY_DERIVATION_SALT')
    $secrets = @($secretNames | ForEach-Object { $settings[$_] })
    foreach ($secret in $secrets) { Assert-True ($secret -cmatch '^[a-f0-9]{64}$') 'Each generated secret has 32 random bytes.' }
    Assert-True (@($secrets | Select-Object -Unique).Count -eq $secretNames.Count) 'Different settings receive different secrets.'
    Assert-True ($script:ProtectedPaths.Contains($script:EnvPath)) 'New settings request private file permissions.'
    $initialBytes = [IO.File]::ReadAllBytes($script:EnvPath)
    Assert-True (-not ($initialBytes[0] -eq 239 -and $initialBytes[1] -eq 187 -and $initialBytes[2] -eq 191)) 'Settings have no UTF-8 BOM.'
    Assert-True (-not ([IO.File]::ReadAllText($script:EnvPath).Contains("`r"))) 'Settings use LF line endings.'
    Initialize-Settings
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:EnvPath)) -ceq [Convert]::ToBase64String($initialBytes)) 'Restart preserves settings and secrets byte-for-byte.'

    # Verify arguments containing spaces and shell-looking text stay individual
    # arguments all the way through both real launcher wrappers.
    $payload = 'literal $HOME; $(do-not-run) and spaces'
    Invoke-DemoCompose @('exec', 'apiserver', 'printf', '%s', $payload)
    $expected = @('compose', '--project-name', 'ontrack-public-demo', '--env-file', $script:EnvPath,
        '-f', (Join-Path $script:DemoRoot 'compose.yml'), 'exec', 'apiserver', 'printf', '%s', $payload)
    Assert-True ($script:CapturedDockerArguments.Count -eq $expected.Count) 'Compose argument count is preserved.'
    for ($index = 0; $index -lt $expected.Count; $index++) {
        Assert-True ($script:CapturedDockerArguments[$index] -ceq $expected[$index]) "Compose argument $index is preserved."
    }
    $script:DockerExitCode = 17
    Assert-Throws { Invoke-Docker @('ignored') } 'exit 17'
    $script:DockerExitCode = 0

    # Refusal paths must keep user files and must not fetch a different revision.
    $sourceDirectory = Join-Path $script:RepositoryRoot 'doubtfire-api'
    New-Item -ItemType Directory -Path $sourceDirectory | Out-Null
    $lockPath = Join-Path $script:DemoRoot 'sources.lock.json'
    $revision = 'a' * 40
    $lock = @{ sources = @(@{ path = 'doubtfire-api'; repository = 'example/api'; revision = $revision }) }
    Write-Utf8File $lockPath ($lock | ConvertTo-Json -Depth 4)
    $marker = Join-Path $sourceDirectory '.ontrack-source-revision'
    Write-Utf8File $marker (('b' * 40) + "`n")
    Assert-Throws { Install-PinnedSources } 'version differs'
    Assert-True ((Get-Content $marker -Raw).Trim() -ceq ('b' * 40)) 'Wrong-version marker is preserved.'
    Remove-Item -LiteralPath $marker -Force
    $userFile = Join-Path $sourceDirectory 'keep.txt'
    Write-Utf8File $userFile 'local work'
    Assert-Throws { Install-PinnedSources } 'not empty'
    Assert-True ((Get-Content $userFile -Raw) -ceq 'local work') 'Existing source files are preserved.'
    $lock.sources[0].path = '../outside-package'
    Write-Utf8File $lockPath ($lock | ConvertTo-Json -Depth 4)
    Assert-Throws { Install-PinnedSources } 'Unexpected source folder'
    $lock.sources[0].path = 'doubtfire-api'
    $lock.sources[0].revision = 'main'
    Write-Utf8File $lockPath ($lock | ConvertTo-Json -Depth 4)
    Assert-Throws { Install-PinnedSources } 'source version file is invalid'
    $lock.sources[0].revision = $revision
    Write-Utf8File $lockPath ($lock | ConvertTo-Json -Depth 4)
    Write-Utf8File $marker ($revision + "`n")
    Install-PinnedSources
    Assert-True ((Get-Content $userFile -Raw) -ceq 'local work') 'Pinned source reuse performs no download or deletion.'

    # Use real ZIP IO, including the long SHA folder returned by GitHub. These
    # tests exercise traversal rejection without ever writing outside testRoot.
    $archive = Join-Path $testRoot 'sources.zip'
    $extracted = Join-Path $testRoot 'extracted'
    New-Item -ItemType Directory -Path $extracted | Out-Null
    $archiveRoot = 'doubtfire-web-' + ('a' * 40)
    $entries = @{}
    $entries["$archiveRoot/"] = ''
    $entries["$archiveRoot/src/"] = ''
    $entries["$archiveRoot/src/path with spaces/main.ts"] = 'export const demo = true;'
    $entries["$archiveRoot/.dockerignore"] = 'node_modules'
    New-TestArchive $archive $entries
    Expand-SourceArchive $archive $extracted
    Assert-True ((Get-Content (Join-Path $extracted 'src/path with spaces/main.ts') -Raw) -ceq 'export const demo = true;') 'Source ZIP files extract with their relative directories and contents.'
    Assert-True ((Get-Content (Join-Path $extracted '.dockerignore') -Raw) -ceq 'node_modules') 'Source ZIP dotfiles are included.'
    Assert-True (-not (Test-Path (Join-Path $extracted $archiveRoot))) 'Extraction strips the long GitHub SHA root.'
    $existingSource = Join-Path $extracted 'src/path with spaces/main.ts'
    Write-Utf8File $existingSource 'preserved local content'
    Assert-Throws { Expand-SourceArchive $archive $extracted } 'already exists'
    Assert-True ((Get-Content $existingSource -Raw) -ceq 'preserved local content') 'Extraction never overwrites existing files.'

    $unsafeZip = Join-Path $testRoot 'unsafe.zip'
    New-TestArchive $unsafeZip @{ 'repo/../escape.txt' = 'must not escape' }
    Assert-Throws { Expand-SourceArchive $unsafeZip $extracted } 'unsafe path'
    Assert-True (-not (Test-Path (Join-Path $testRoot 'escape.txt'))) 'Traversal cannot write beside the extraction folder.'
    $prefixZip = Join-Path $testRoot 'prefix.zip'
    New-TestArchive $prefixZip @{ 'repo/../extracted-sibling/escape.txt' = 'must not escape' }
    Assert-Throws { Expand-SourceArchive $prefixZip $extracted } 'unsafe path'
    Assert-True (-not (Test-Path (Join-Path $testRoot 'extracted-sibling'))) 'A sibling sharing the target prefix is still outside the extraction folder.'
    $flatZip = Join-Path $testRoot 'flat.zip'
    New-TestArchive $flatZip @{ 'no-github-root.txt' = 'invalid layout' }
    Assert-Throws { Expand-SourceArchive $flatZip $extracted } 'unexpected layout'

    # Generate keys once, using a fake image response; do not print key material.
    $script:KeyGenerationCalls = 0
    function Invoke-Docker([string[]]$DockerArguments) {
        $script:KeyGenerationCalls++
        return (@{ public_key = 'B' + ('a' * 86); private_key = 'b' * 43 } | ConvertTo-Json -Compress)
    }
    Initialize-PushKeys
    $withKeys = [IO.File]::ReadAllText($script:EnvPath)
    Initialize-PushKeys
    Assert-True ($script:KeyGenerationCalls -eq 1) 'Push keys are generated only once.'
    Assert-True ([IO.File]::ReadAllText($script:EnvPath) -ceq $withKeys) 'Restart preserves push keys.'
    $updatedSettings = Read-Settings
    foreach ($key in $secretNames) { Assert-True ($updatedSettings[$key] -ceq $settings[$key]) 'Push key creation preserves other credentials.' }

    function Invoke-DemoCompose([string[]]$ComposeArguments) { $script:Calls.Add(@($ComposeArguments)) }
    function Assert-DockerReady {}
    function Read-Host { return $script:Reply }
    function Start-OnTrack { $script:Started++ }

    foreach ($reply in @('', 'reset demo', 'RESET', 'RESET DEMO ')) {
        $script:Reply = $reply
        Reset-OnTrack
        Assert-True ($script:Calls.Count -eq 0 -and $script:Started -eq 0) 'Reset requires the exact confirmation phrase.'
    }
    $script:Reply = 'RESET DEMO'
    Reset-OnTrack
    Assert-True ($script:Calls.Count -eq 1) 'Confirmed reset invokes Compose once before restart.'
    Assert-True ($script:Calls[0] -contains 'down' -and $script:Calls[0] -contains '--volumes') 'Confirmed reset explicitly removes demo volumes.'
    Assert-True ($script:Started -eq 1) 'Confirmed reset starts a new demo.'
    Assert-True ($script:Calls[0] -contains 'quick' -and $script:Calls[0] -contains 'tunnel') 'Reset includes both public tunnel profiles.'

    $script:Calls.Clear()
    Invoke-OnTrackAction 'Stop'
    Assert-True ($script:Calls.Count -eq 1 -and $script:Calls[0] -contains 'stop') 'Stop invokes a service stop.'
    Assert-True ($script:Calls[0] -notcontains '--volumes' -and $script:Calls[0] -notcontains 'down') 'Stop keeps existing data.'
    Assert-True ($script:Calls[0] -contains 'quick' -and $script:Calls[0] -contains 'tunnel') 'Stop includes both public tunnel profiles.'

    $script:Calls.Clear()
    Assert-Throws { Set-PublicHostname 'https://invalid.example/path' } 'hostname is invalid'
    Assert-True ($script:Calls.Count -eq 0) 'Invalid hostname does not restart services.'
    Set-PublicHostname 'New.Example.Com'
    Assert-True ((Get-PublicHostname) -ceq 'new.example.com') 'Switching hostname updates saved public URLs.'
    Assert-True ($script:Calls.Count -eq 1 -and $script:Calls[0] -notcontains 'quick-tunnel') 'Hostname switch preserves the temporary tunnel address.'

    Write-Host "PASS: $script:Checks launcher assertions (external actions mocked; real Windows acceptance not run)."
} finally {
    if (Test-Path $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
