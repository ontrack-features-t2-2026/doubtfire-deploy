# OnTrack MVP validation lock — 2026-08-27

This branch records the **prior verified 26 August candidate** as a
reproducibility lock for the focused validation of
Cross-Project Dashboard, Peer Progress Indicator, Email Notifications and
Mobile/Web Push Notifications. It is **not** a release tag, deployment
approval, production acceptance result or claim that every current feature
head is included. API/Web final-candidate SHAs are expected to move; a successor
commit must update both gitlinks and rerun the required evidence before anyone
describes a Deploy ref as the final lock.

## Prior candidate revisions

The branch starts from Deploy `11.0.x` at
`5351009df475c4a3d4f788110b0197ce64b3d3f4`, the merge commit for Deploy
pull request #12. That base already contains the reviewed production Compose,
PPI configuration and workflow changes merged through Deploy pull requests
#11, #12, #18, #24 and #25.

| Component | Branch used for validation | Gitlink revision |
| --- | --- | --- |
| API | `integration/ontrack-mvp-validation-20260826` | `75d7337fd0dd04f9b3a985f287e40f3ec6a467a0` |
| Web | `integration/ontrack-mvp-validation-20260826` | `832d5e47eb26ff2e21ce25e576daa13b3054cc3e` |

Both component commits were published at the recorded branch names before this
lock was created. The configured `.gitmodules` URLs point to the matching
`ontrack-features-t2-2026` repositories.

## Evidence carried by this lock

The focused evidence was captured before this Deploy lock was assembled:

- API `75d7337f`: CPD 17 runs / 80 assertions; PPI 103 runs / 5,608
  assertions; email 77 runs / 428 assertions; push 72 runs / 295 assertions;
  Zeitwerk passed.
- Web `832d5e47`: lint passed; the parent candidate passed type-check; CPD
  passed 55 tests with one todo; PPI passed 93 tests; notification/push passed
  148 tests.
- Exact candidate development images were built and scanned with Trivy 0.74.0.
  The scan is not clean: the API image reported 35 Critical and 577 High
  instances; the Web image reported 33 Critical and 394 High instances.
- The Web production build is not green. Two attempts were killed during
  esbuild/minification; the constrained retry exited 137.
- Full API and Web suites were not run against these candidate revisions.
- No real background Web Push receipt, previous-unit CPD success, eligible live
  PPI browser result, current composed-stack acceptance or production approval
  was recorded for this lock.

The complete logs, layer-attributed image reports, screenshots, privacy
boundaries and exact rerun commands are in the published GitHub Guide evidence
branch `docs/ontrack-mvp-evidence-20260826` at
`c07f60f29c05364e1d643047456033c1bfae2b0d`.

## 27 August branch movement

The validation candidates are intentionally frozen. After they were built and
tested, feature and release branches moved and the previously open umbrella and
follow-up pull requests were merged. At the `2026-08-27T09:49:05Z` audit:

- API `11.0.x` was `cb03f80bdba5a19d12a821d3cb7e11f19b1b5c7f`;
- Web `11.0.x` was `9c618c3b04c272a34bceba62bba4c7a7627cf96d`;
- API `feature/notifications` was
  `ad708860d72f16dca0f4e7ab5aa6bf0310c08131`;
- API `feature/peer-progress-indicator` was
  `b0ac35f4083aaec66c10e1db4b3822655a66ae90`;
- Web `feature/cross-unit` was
  `9962e7ea171a2bf6d7a12be50874fa5c7ee77e21`;
- Web `feature/peer-progress-indicator` was
  `e12b5f8927830ab35f0243039a23bbf70e4a9cf3`; and
- Web `feature/notifications` remained
  `35ee9fa31c4b1c987e79c62cdfce93c270d30dc9`.

The newer branch heads are not substituted into this lock because the focused
results above do not attest that composition. Equivalent patches may already
exist in a candidate even when a later GitHub merge commit is not its ancestor;
ancestry alone must not be used to infer feature absence or acceptance.

## Reproduction and acceptance gates

After this branch is published, verify that a fresh recursive clone can fetch
both gitlinks:

```sh
git clone --recurse-submodules \
  --branch chore/ontrack-mvp-lock-20260827 \
  https://github.com/ontrack-features-t2-2026/doubtfire-deploy.git
cd doubtfire-deploy
git submodule status
```

Expected component prefixes are `75d7337f` for API and `832d5e47` for Web.
Then run the exact focused commands from the Guide evidence index and complete
all of the following before proposing any release:

1. refresh the integration candidate from the approved current bases and
   explicitly disposition the branch movement above;
2. run the complete API and Web suites plus a resource-sufficient Web
   production build;
3. validate every required Compose configuration and start the locked stack
   from a fresh clone;
4. reproduce active, previous and all-unit CPD with functional search;
5. reproduce eligible and suppressed live PPI through the authorised API and
   frontend adapter;
6. queue and process a current email through Sidekiq into Mailpit;
7. receive and open a privacy-safe background Web Push on every supported
   browser/device combination;
8. remediate, formally risk-accept and rescan the image findings; and
9. attach named review, go/no-go, rollback and immutable-image evidence.

Until a successor lock and those gates pass, use this branch only to reproduce
the prior focused candidate composition and its known limitations.
