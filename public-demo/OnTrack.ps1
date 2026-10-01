#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Start', 'Quick', 'Connect', 'Status', 'Stop', 'Reset')]
    [string]$Action = 'Menu',
    [string]$Hostname = 'ontrack.maplefox.au',
    [switch]$LibraryOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:DemoRoot = $PSScriptRoot
$script:RepositoryRoot = Split-Path $PSScriptRoot -Parent
$script:EnvPath = Join-Path $PSScriptRoot '.env'
$script:ProjectName = 'ontrack-public-demo'

function Write-Utf8File([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
}

function New-RandomSecret {
    $bytes = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

function Protect-LocalFile([string]$Path) {
    if ($env:OS -eq 'Windows_NT') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        & icacls.exe $Path /inheritance:r /grant:r "${identity}:(F)" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not make $Path private to your Windows account." }
    } else {
        & chmod 600 $Path
        if ($LASTEXITCODE -ne 0) { throw "Could not protect $Path." }
    }
}

function Initialize-Settings {
    if (Test-Path $script:EnvPath) { return }
    if ($Hostname -notmatch '^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$') {
        throw 'Enter a hostname such as ontrack.maplefox.au, without https:// or a path.'
    }
    $settings = Get-Content (Join-Path $script:DemoRoot '.env.example') -Raw
    $settings = [regex]::Replace($settings, '(?m)^PUBLIC_HOST=.*$', "PUBLIC_HOST=$($Hostname.ToLowerInvariant())")
    $keys = @('MARIADB_PASSWORD', 'MARIADB_ROOT_PASSWORD', 'DF_SECRET_KEY_BASE', 'DF_SECRET_KEY_ATTR',
        'DF_SECRET_KEY_DEVISE', 'DF_ENCRYPTION_PRIMARY_KEY', 'DF_ENCRYPTION_DETERMINISTIC_KEY',
        'DF_ENCRYPTION_KEY_DERIVATION_SALT')
    foreach ($key in $keys) {
        if ($settings -notmatch "(?m)^$key=") { throw "Missing setting $key in .env.example." }
        $settings = [regex]::Replace($settings, "(?m)^$key=.*$", "$key=$(New-RandomSecret)")
    }
    # Compose needs nonempty placeholders while the API image is built. They are
    # replaced with a fresh real key pair before any application service starts.
    foreach ($key in @('DOUBTFIRE_VAPID_PUBLIC_KEY', 'DOUBTFIRE_VAPID_PRIVATE_KEY')) {
        $settings = [regex]::Replace($settings, "(?m)^$key=.*$", "$key=GENERATE_ON_FIRST_START")
    }
    Write-Utf8File $script:EnvPath $settings
    Protect-LocalFile $script:EnvPath
}

function Invoke-Docker([string[]]$DockerArguments) {
    & docker @DockerArguments
    if ($LASTEXITCODE -ne 0) { throw "Docker could not complete the requested step (exit $LASTEXITCODE). See the message above." }
}

function Invoke-DemoCompose([string[]]$ComposeArguments) {
    $arguments = @('compose', '--project-name', $script:ProjectName, '--env-file', $script:EnvPath,
        '-f', (Join-Path $script:DemoRoot 'compose.yml')) + $ComposeArguments
    Invoke-Docker $arguments
}

function Assert-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if ($env:OS -eq 'Windows_NT') {
            foreach ($directory in @("$env:ProgramFiles\Docker\Docker\resources\bin", "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin")) {
                if (Test-Path (Join-Path $directory 'docker.exe')) { $env:PATH = "$directory;$env:PATH"; break }
            }
        }
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            if ($env:OS -eq 'Windows_NT') { Start-Process 'https://docs.docker.com/desktop/setup/install/windows-install/' }
            throw 'Install Docker Desktop for Windows using its WSL 2 option, open Docker Desktop, then run Start OnTrack.cmd again. Docker may ask you to enable WSL or restart Windows.'
        }
    }
    $engine = & docker info --format '{{.OSType}}' 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Open Docker Desktop and wait until its engine is running, then try again.' }
    if ($engine -ne 'linux') { throw 'In Docker Desktop, switch to Linux containers, then try again.' }
    $versionText = & docker compose version --short 2>$null
    if ($LASTEXITCODE -ne 0 -or $versionText -notmatch '^v?(\d+\.\d+\.\d+)') { throw 'Update Docker Desktop: Docker Compose is missing.' }
    if ([version]$Matches[1] -lt [version]'2.33.1') { throw 'Update Docker Desktop: this setup needs Docker Compose 2.33.1 or newer.' }
}

function Expand-SourceArchive([string]$Archive, [string]$Destination) {
    # Strip GitHub's long SHA directory while extracting, avoiding MAX_PATH
    # failures in Windows PowerShell 5.1. Reject any path escaping the target.
    # Windows PowerShell 5.1 uses separate .NET Framework assemblies for the
    # archive types and filesystem helpers; load both before using ZIP types.
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $root = [IO.Path]::GetFullPath($Destination) + [IO.Path]::DirectorySeparatorChar
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $slash = $entry.FullName.IndexOf('/')
            if ($slash -lt 0) { throw 'The source archive has an unexpected layout.' }
            $relative = $entry.FullName.Substring($slash + 1)
            if (-not $relative) { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $relative))
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'The source archive contains an unsafe path.' }
            if ($env:OS -eq 'Windows_NT' -and $target.Length -gt 245) {
                throw 'The folder name is too long for Windows. Extract the setup ZIP directly into C:\OnTrack and try again.'
            }
            if ($entry.FullName.EndsWith('/')) {
                [IO.Directory]::CreateDirectory($target) | Out-Null
            } else {
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
            }
        }
    } finally { $zip.Dispose() }
}

function Install-PinnedSources {
    $sourceLock = Get-Content (Join-Path $script:DemoRoot 'sources.lock.json') -Raw | ConvertFrom-Json
    foreach ($source in $sourceLock.sources) {
        if ($source.repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $source.revision -notmatch '^[a-f0-9]{40}$') {
            throw 'The source version file is invalid.'
        }
        # Only the reviewed component directories may be written by the installer.
        if ($source.path -notin @('doubtfire-api', 'doubtfire-web', 'doubtfire-web/JPlag-Report-Viewer')) { throw 'Unexpected source folder.' }
        $destination = Join-Path $script:RepositoryRoot $source.path
        $marker = Join-Path $destination '.ontrack-source-revision'
        if (Test-Path $marker) {
            if ((Get-Content $marker -Raw).Trim() -ne $source.revision) { throw "The $($source.path) version differs. Extract the new package into a fresh folder; existing files were preserved." }
            continue
        }
        if (Test-Path (Join-Path $destination '.git')) {
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "$destination is a Git checkout. Install Git or use the ZIP package in a fresh folder." }
            $revision = & git -C $destination rev-parse HEAD
            if ($LASTEXITCODE -ne 0 -or $revision -ne $source.revision) { throw "$($source.path) does not match the package's pinned version." }
            $changes = & git -C $destination status --porcelain --untracked-files=normal
            if ($LASTEXITCODE -ne 0 -or $changes) { throw "$($source.path) contains changes. Use a clean checkout or a fresh ZIP package." }
            continue
        }
        if ((Test-Path $destination) -and @(Get-ChildItem $destination -Force).Count -gt 0) { throw "$destination is not empty. Existing files were preserved. Extract the package to a fresh folder." }
        $archive = [IO.Path]::GetTempFileName()
        # Staging beside the final folder keeps Windows paths short and allows
        # an atomic move. A failed download never leaves a half-installed tree.
        $staging = Join-Path (Split-Path $destination -Parent) ('.ot-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $staging | Out-Null
        try {
            Write-Host "Downloading the tested $($source.path) version..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$($source.repository)/archive/$($source.revision).zip" -OutFile $archive
            Expand-SourceArchive $archive $staging
            if (Test-Path $destination) { Remove-Item -LiteralPath $destination }
            Move-Item -LiteralPath $staging -Destination $destination
            Write-Utf8File $marker ($source.revision + "`n")
        } finally {
            Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Initialize-PushKeys {
    $settings = Get-Content $script:EnvPath -Raw
    if ($settings -notmatch '(?m)^DOUBTFIRE_VAPID_(PUBLIC|PRIVATE)_KEY=GENERATE_ON_FIRST_START\r?$') { return }
    $ruby = 'k=WebPush.generate_key; puts({public_key:k.public_key,private_key:k.private_key}.to_json)'
    $output = Invoke-Docker @('run', '--rm', '--entrypoint', 'bundle', 'ontrack-public-demo-api:local',
        'exec', 'ruby', '-rweb-push', '-rjson', '-e', $ruby)
    $keys = ($output -join "`n") | ConvertFrom-Json
    if ($keys.public_key -notmatch '^B[A-Za-z0-9_-]{86}=?$' -or $keys.private_key -notmatch '^[A-Za-z0-9_-]{43}=?$') {
        throw 'Could not generate valid browser notification keys.'
    }
    $settings = [regex]::Replace($settings, '(?m)^DOUBTFIRE_VAPID_PUBLIC_KEY=.*$', "DOUBTFIRE_VAPID_PUBLIC_KEY=$($keys.public_key)")
    $settings = [regex]::Replace($settings, '(?m)^DOUBTFIRE_VAPID_PRIVATE_KEY=.*$', "DOUBTFIRE_VAPID_PRIVATE_KEY=$($keys.private_key)")
    Write-Utf8File $script:EnvPath $settings
    Protect-LocalFile $script:EnvPath
}

function Get-PublicHostname {
    $line = @(Get-Content $script:EnvPath | Where-Object { $_ -match '^PUBLIC_HOST=' })
    if ($line.Count -ne 1) { throw 'PUBLIC_HOST must appear once in .env.' }
    return $line[0].Substring('PUBLIC_HOST='.Length).Trim()
}

function Set-PublicHostname([string]$NewHostname) {
    if ($NewHostname -notmatch '^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$') {
        throw 'The website hostname is invalid.'
    }
    $settings = Get-Content $script:EnvPath -Raw
    $settings = [regex]::Replace($settings, '(?m)^PUBLIC_HOST=.*$', "PUBLIC_HOST=$($NewHostname.ToLowerInvariant())")
    Write-Utf8File $script:EnvPath $settings
    Protect-LocalFile $script:EnvPath
    # Recreate only the application services that consume PUBLIC_HOST. Keep the
    # quick tunnel alive: restarting it would assign a different hostname.
    Invoke-DemoCompose @('up', '-d', '--wait', '--wait-timeout', '300', 'apiserver', 'sidekiq', 'pdfgen', 'proxy')
}

function Open-QuickDemo {
    Assert-DockerReady
    if (-not (Test-Path $script:EnvPath)) { Start-OnTrack }
    if (Test-Path (Join-Path $script:DemoRoot 'secrets/tunnel-token.txt')) {
        Write-Host 'A permanent tunnel is configured. Use Connect to change it, or open the configured website.'
        return
    }
    Invoke-DemoCompose @('--profile', 'quick', 'up', '-d', '--force-recreate', 'quick-tunnel')
    $temporaryUrl = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $logs = Invoke-DemoCompose @('--profile', 'quick', 'logs', '--no-color', '--tail', '100', 'quick-tunnel')
        $found = [regex]::Match(($logs -join "`n"), 'https://([a-z0-9]+(?:-[a-z0-9]+)*\.trycloudflare\.com)')
        if ($found.Success) { $temporaryUrl = $found.Value; break }
        Start-Sleep -Seconds 2
    }
    if (-not $temporaryUrl) { throw 'Cloudflare has not supplied a temporary address. Check Docker internet access, then choose Open temporary website again.' }
    Set-PublicHostname ([uri]$temporaryUrl).Host
    Write-Host "`nTemporary public demo: $temporaryUrl"
    Write-Host 'Student: student_1 / password. Staff: staff_1 / password. Unit chair: chair_1 / password.'
    Write-Host 'This address changes when the temporary tunnel restarts. Keep Docker and your PC running.'
    Write-Host 'Use Connect website later for your permanent domain. Calendar subscriptions should use that permanent address.'
    if ($env:OS -eq 'Windows_NT') { Start-Process $temporaryUrl }
}

function Start-OnTrack {
    Assert-DockerReady
    Initialize-Settings
    Install-PinnedSources
    Write-Host 'Building OnTrack. The first build downloads several large components; later starts reuse them.'
    Invoke-DemoCompose @('build', 'apiserver', 'webserver', 'sidekiq', 'texlive-sidekiq', 'jplag', 'proxy')
    Initialize-PushKeys
    Invoke-DemoCompose @('up', '-d', '--wait', '--wait-timeout', '240', 'db', 'redis', 'mailpit')
    Invoke-DemoCompose @('--profile', 'setup', 'run', '--rm', 'bootstrap')
    Invoke-DemoCompose @('up', '-d', '--wait', '--wait-timeout', '300')
    $health = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/healthz' -TimeoutSec 20
    if ($health.StatusCode -ne 200) { throw 'The local OnTrack health check failed.' }
    if (Test-Path (Join-Path $script:DemoRoot 'secrets/tunnel-token.txt')) {
        Invoke-DemoCompose @('--profile', 'tunnel', 'up', '-d', 'cloudflared')
    }
    Write-Host "OnTrack is running locally. Public address after connecting the tunnel: https://$(Get-PublicHostname)"
    Write-Host 'Demo logins: student_1 / password, staff_1 / password, chair_1 / password.'
    Write-Host 'Captured demo email is private to this PC at http://localhost:8025.'
    Write-Host 'Use Connect to finish the website connection. Keep the PC awake and Docker Desktop running.'
}

function Connect-OnTrack {
    Assert-DockerReady
    if (-not (Test-Path $script:EnvPath)) { throw 'Choose Start first.' }
    Write-Host "In Cloudflare, create a Tunnel with a published route: $Hostname -> http://proxy:80."
    Write-Host 'Use the Docker connector option. Paste only its tunnel token here, not the whole command.'
    Write-Host 'The README explains the DNS move and how to preserve your existing website and mail.'
    $secureToken = Read-Host 'Tunnel token (hidden)' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim()
        if ($token.Length -lt 40 -or $token -notmatch '^[A-Za-z0-9_+/=-]+$') { throw 'That does not look like a tunnel token. Paste only the token from Cloudflare.' }
        $secretDirectory = Join-Path $script:DemoRoot 'secrets'
        New-Item -ItemType Directory -Force -Path $secretDirectory | Out-Null
        $tokenPath = Join-Path $secretDirectory 'tunnel-token.txt'
        Write-Utf8File $tokenPath $token
        Protect-LocalFile $tokenPath
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $token = $null
    }
    Set-PublicHostname $Hostname
    Invoke-DemoCompose @('--profile', 'quick', 'stop', 'quick-tunnel')
    Invoke-DemoCompose @('--profile', 'tunnel', 'up', '-d', '--force-recreate', 'cloudflared')
    Write-Host "Tunnel started. Cloudflare must show Healthy. Open https://$(Get-PublicHostname) and test both student and staff sign-in."
    if ($env:OS -eq 'Windows_NT') { Start-Process "https://$(Get-PublicHostname)" }
}

function Reset-OnTrack {
    Assert-DockerReady
    if (-not (Test-Path $script:EnvPath)) { throw 'No demo has been configured in this folder.' }
    Write-Host 'This permanently removes this demo database, uploads, messages, push subscriptions and progress.'
    $confirmation = Read-Host 'Type RESET DEMO to restore the made-up example data'
    if ($confirmation -cne 'RESET DEMO') { Write-Host 'Reset cancelled.'; return }
    Invoke-DemoCompose @('--profile', 'quick', '--profile', 'tunnel', '--profile', 'setup', 'down', '--volumes', '--remove-orphans')
    Start-OnTrack
}

function Invoke-OnTrackAction([string]$SelectedAction) {
    switch ($SelectedAction) {
        'Start' { Start-OnTrack }
        'Quick' { Start-OnTrack; Open-QuickDemo }
        'Connect' { Connect-OnTrack }
        'Reset' { Reset-OnTrack }
        'Status' { Assert-DockerReady; Invoke-DemoCompose @('--profile', 'quick', '--profile', 'tunnel', 'ps', '--all') }
        'Stop' { Assert-DockerReady; Invoke-DemoCompose @('--profile', 'quick', '--profile', 'tunnel', '--profile', 'setup', 'stop'); Write-Host 'OnTrack stopped. Demo data was kept.' }
    }
}

if ($LibraryOnly) { return }
try {
    if ($Action -eq 'Menu') {
        Write-Host "`nOnTrack public demo`n1. Set up / open temporary website`n2. Connect permanent website`n3. Check status`n4. Stop`n5. Reset demo data`n6. Exit`n"
        $choice = Read-Host 'Choose a number'
        $actions = @{ '1' = 'Quick'; '2' = 'Connect'; '3' = 'Status'; '4' = 'Stop'; '5' = 'Reset' }
        if ($actions.ContainsKey($choice)) { Invoke-OnTrackAction $actions[$choice] }
    } else { Invoke-OnTrackAction $Action }
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
