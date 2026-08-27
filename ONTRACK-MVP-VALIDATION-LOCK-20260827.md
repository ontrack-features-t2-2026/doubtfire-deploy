# OnTrack MVP validation lock — 2026-08-27

This branch pins the final 27 August repository-side validation candidates for
the Cross-Project Dashboard (CPD), Peer Progress Indicator (PPI), Email
Notifications (EN), and Mobile/Web Push Notifications (MN). The gitlinks are
the single integration input for subsequent fresh-clone and hosted-CI checks.

This is a validation lock, not a release tag, production approval, security
risk acceptance, or claim that browser/device work which still needs a human
permission grant has already occurred.

## Locked component revisions

The branch starts from Deploy `11.0.x` at
`5351009df475c4a3d4f788110b0197ce64b3d3f4`, the merge commit for Deploy pull
request #12. The base contains the reviewed production Compose, PPI
configuration, and workflow changes merged through Deploy pull requests #11,
#12, #18, #24, and #25.

| Component | Branch | Gitlink revision |
| --- | --- | --- |
| API | `closure/api-ontrack-mvp-20260827` | `f25945d228c1a3b321412047dcfe304e43cb7658` |
| Web | `closure/web-ontrack-mvp-20260827` | `5255c271778643cd6f972e3bce1d83ecdb2e292d` |

The configured `.gitmodules` URLs point to the matching
`ontrack-features-t2-2026` repositories. The component branches must be
published before a recursive-clone verification can succeed.

## Evidence attached to the lock

### API

- The CPD Previous/All request regression passes with the same 200 response
  and 3-project/60-task/60-definition result as the prior candidate.
- Batching and association preloading reduced that request from 453 SQL
  statements to 38 (91.6% fewer) and from 4.218 seconds to 2.390 seconds
  (43.3% faster) in the controlled local reproduction.
- The focused regression passed 1 run / 6 assertions. Zeitwerk, changed-file
  RuboCop, Ruby syntax, workflow syntax, and whitespace checks passed.
- CI now uses eight deterministic process-isolated Rails test shards while
  retaining the stable `unit-tests` required check. The manifest verifier
  assigned all 129 discovered files exactly once, with no duplicates or
  omissions; shards contain 15–17 files and 4,278–4,284 lines. Splitter tests
  passed 5 runs / 29 assertions.
- A local unsharded run reached the repository's LaTeX/JPlag helper-service
  tests but could not access `/var/run/docker.sock` from the managed sandbox.
  Those environment-bound errors are not represented as product regressions
  or as a full-suite pass. Hosted CI, where the workflow provisions the
  required services, remains authoritative.

### Web

- Type-check and lint passed.
- CPD: 98 passed / 1 existing todo; PPI: 109 passed; notifications/push: 177
  passed.
- The complete suite passed 605 tests across 103 files, with 1 existing todo
  and no failures.
- The Node 22 production build passed in 99.911 seconds.

### Exact-image security scan

- Web image `ontrack-mvp-closure-web:5255c271` has immutable digest
  `sha256:ae5a90c845bbfec38e2dc1f84c5447fe4b301c189ea9c7f19d910c6b2c7bf23c`.
  Trivy 0.74.0 reported 33 Critical, 395 High, 1,592 Medium, 1,197 Low, and
  163 Unknown instances. The project npm layer contributed no findings and
  `npm audit` reported zero; the 16 fixable language-package findings are in
  the bundled npm from the Node 22 base image.
- The final API image scan is recorded in the companion Guide evidence report.

The Web result is not clean and the image is not approved for production.
Critical/High findings require remediation or an authorised, expiring risk
acceptance followed by a rebuild and rescan.

## Historical prior candidate

Deploy commit `c4c0d9a5` pinned the 26 August candidates API `75d7337f` and Web
`832d5e47`. Deploy commit `32c7abb` correctly relabelled that composition as a
prior-candidate reproducibility record. The gitlinks at this branch head
supersede that composition; prior evidence remains historical and must not be
used to imply that the final revisions were tested.

## Reproduction and remaining gates

After the three branches are published, verify a fresh recursive clone:

```sh
git clone --recurse-submodules \
  --branch chore/ontrack-mvp-lock-20260827 \
  https://github.com/ontrack-features-t2-2026/doubtfire-deploy.git
cd doubtfire-deploy
git submodule status
```

Expected component prefixes are `f25945d` for API and `5255c27` for Web.

Repository-side handover can proceed from this lock. Production release still
requires all applicable gates below:

1. hosted API CI passes at the locked SHA and supplies measured eight-shard
   timings;
2. a fresh-clone Compose run confirms the locked stack;
3. current browser evidence covers Active/Previous/All CPD, eligible and
   suppressed live PPI, and Sidekiq-to-Mailpit email delivery;
4. background Web Push is received and opened on each supported browser/device
   after the tester grants notification permission;
5. image Critical/High findings are remediated or formally risk-accepted and
   the immutable release images are rescanned; and
6. the release owner records go/no-go and rollback evidence.

Requester approval for repository closure was recorded on 27 August 2026;
named-leader confirmation was waived by the requester. This statement is not
attributed to an uncontacted individual and is not a production release
approval.
