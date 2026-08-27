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
| API | `closure/api-ontrack-mvp-20260827` | `6c74dbbc07e219d60ca49e1b5ea42f737e5ef225` |
| Web | `closure/web-ontrack-mvp-20260827` | `16c22c992c821e16981c8f8cb2601f0a61f73007` |

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
- The protected anonymous push-settings contract passed 7 runs / 42 assertions,
  and the time-frozen portfolio-receipt lookup regression passed 1 run / 16
  assertions. Both tests now assert the current API and exact-user contracts.
- A local unsharded run completed 1,145 runs / 16,245 assertions / 0 skips in
  2,785.068 seconds. It is not reported as a pass: all 26 failing tests were
  classified as 22 Docker-helper/socket-dependent PDF, portfolio, JPlag and TII
  cases, two standalone-image workflow-mount cases, and the two stale test
  expectations fixed above. No outcome remains unclassified. Hosted CI, where
  the checkout and supported services are mounted, remains authoritative.

### Web

- Type-check and lint passed.
- CPD: 98 passed / 1 existing todo; PPI: 109 passed; notifications/push: 177
  passed.
- The complete suite passed 607 tests across 104 files, with 1 existing todo
  and no failures. The two extra tests and the extra file are the page-container
  spec that the 11.0.x merge brought onto the branch; on `5255c27` the same run
  was 605 across 103.
- The Node 22 production build passed in 99.911 seconds on `5255c27`. It has not
  been re-measured locally on `16c22c9`, so hosted `build (22)` on that head is
  the authority for the merged tree.

### Exact-image security scan

- Web image `ontrack-mvp-closure-web:5255c271` has immutable digest
  `sha256:ae5a90c845bbfec38e2dc1f84c5447fe4b301c189ea9c7f19d910c6b2c7bf23c`.
  Trivy 0.74.0 reported 33 Critical, 395 High, 1,592 Medium, 1,197 Low, and
  163 Unknown instances. The project npm layer contributed no findings and
  `npm audit` reported zero; the 16 fixable language-package findings are in
  the bundled npm from the Node 22 base image.
  This image was built from `5255c27`, the revision immediately before the
  11.0.x merge that produced the locked `16c22c9`. The findings still describe
  the locked revision: that merge changed 18 files, 14 Angular templates, one
  scss file and three TypeScript files, and touched neither `package.json`,
  `package-lock.json` nor any Dockerfile, so the OS and language package
  inventory Trivy measures is byte identical. Confirm with
  `git diff --name-only 5255c271 16c22c99 -- package.json package-lock.json`,
  which is empty. A rebuild and rescan is still required before release, for
  the digest rather than for the counts.
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

Expected component prefixes are `6c74dbb` for API and `16c22c9` for Web.

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
