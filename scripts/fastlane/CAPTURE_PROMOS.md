# Capture current localized Premium originals

This opt-in runner builds an external copy of the current app and captures five
native screens in each of the 14 pending locales. It never captures Spanish,
uploads, changes
production Swift, rewrites previous references, or uses historical screenshots.

## Quick path

```sh
python3 -B -m unittest discover -s scripts/fastlane -p 'test_capture_repbuzz_promos.py'
python3 -B scripts/fastlane/capture_repbuzz_promos.py --execute
# Inspect all five raw/en/*.png files and their native UI proof first.
python3 -B scripts/fastlane/capture_repbuzz_promos.py --continue-from-pilot references/repbuzz-remaining-20261114T145150Z/pilot-en.json --confirm-pilot-reviewed
python3 -B scripts/fastlane/capture_repbuzz_promos.py --validate references/repbuzz-remaining-20261114T145150Z/capture-manifest.json
```

`--execute` (or `--execute --pilot-only`) builds and captures English, writes five
originals plus `pilot-en.json`, and pauses. Only after visual inspection may
`--continue-from-pilot ... --confirm-pilot-reviewed` reuse those five originals
and the same build to capture the other 13 locales. It checks unchanged source,
capture code and pilot hashes first. Originals are never overwritten.

The five approved Spanish final images are parent/renderer-owned reuse inputs.
This runner neither captures nor renders them. The combined final set is 75
images; this capture manifest deliberately contains only 70 fresh originals.

## Capture contract

| Item | Requirement |
|---|---|
| App | Current production bytes; built Info.plist must be 1.3.1 (4), `alejandroestevemaza.GymTimerPro` |
| Simulator | Retained iPhone 17 Pro Max / iOS 26.2; light; 09:41; full battery |
| Premium | Local `SKTestSession`, `premium_yearly`; uncached launch and actual Pro badge assertion |
| Store lookup | After launch/reset, select exactly one current container by the target bundle's simulator metadata; require an existing store |
| Fixture | 14 translated simulator user routines; unchanged production models and `RoutinesStore.create` |
| Progress | Six past sessions November 2, 4, 6, 9, 11, 13, 2026; four hypertrophy, two leg strength |
| Editor | Existing localized Full Body, 4 sets / 8 reps / 90 seconds / 35 kg; no keyboard |
| Completion | Real public action at set 4 of 4; immediate attachment before auto-reset |
| Timer notice | Require notice appearance after starting rest, dismiss, wait for disappearance, assert absence at capture |
| Pixels | Native 1320 × 2868 app screenshots; no framing, resizing or retouching |

The isolated test target receives byte-identical production model/store sources
and local fixture resources. `REPBUZZ_CAPTURE` enables the harness only for that
build. The production app sources are never patched, including in scratch.
Local simulator records are reset by existing DEBUG launch hooks before seeding.
No account credentials, real purchases, or `AppStore.sync` are involved.
The harness uses native XCTest attachments, not `setupSnapshot` or its shared
Fastlane cache; locale arguments are assigned exactly once per app launch.

## Outputs and failure handling

Originals: `references/<run_id>/raw/<locale>/<screen_id>.png`.
The fixed run ID is `repbuzz-remaining-20261114T145150Z`.

`capture-manifest.json` is emitted only after all 70 sources pass matrix,
locale, dimensions, timestamp and hash checks. Each record includes native UI
assertion evidence. Production fingerprints and capture-code fingerprints are
separate so parallel renderer edits cannot invalidate the app identity.

Any failure stops execution and emits `capture-partial-report.json`, listing
successful/pending locales, exact cause, count and scratch/log paths. A subsequent
report gets a unique suffix; previous evidence is preserved. Exit status is 1
for partial failures. A successful English-only pilot returns 0 but is not a
complete batch. Reports distinguish failed from not-attempted locales.
Do not upload a partial run.

Inspect every original for language, correct screen, clipped text and overlays.
Machine assertions are evidence, not a substitute for that visual review.
The runner leaves external scratch and the retained simulator for parent-owned
inspection and cleanup. It creates no worktree caches or build products.
