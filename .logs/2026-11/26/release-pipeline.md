# PR10 release pipeline

- User notes recorded in TODOS: Away sound picker, voice too quiet vs siren, onboarding backlog (face scan UI, top-right guided panel, closing video).
- Built: dev signing identity, BYAKU_VERSION stamp, SFace notice bundled, sha256 model pins, release.yml (tag → Release, PR → dry-run artifact), README download docs.
- Verified: swift test 16/16, check-ui, installed app Authority=byaku dev with cert-leaf DR, dry run green on macos-15 (parity 0.99994), artifact sha256 + codesign verify OK.
- Not verified yet (user): camera grant persists across rebuild, login item after re-sign, Open Anyway on the downloaded zip.
- Self-rating 8/10: advisor caught the workflow_dispatch-on-branch trap and the missing model pin before they cost a cycle.
