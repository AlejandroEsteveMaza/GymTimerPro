# RepBuzz promotional screenshots

The approved Spanish design uses the existing pipeline, Frameit device framing
and an ImageMagick composition stage. Production app code is unchanged.

```sh
bash scripts/fastlane/run_frameit_pipeline.sh \
  --design-config fastlane/frameit/logic/repbuzz-es.json --check-only
bash scripts/fastlane/run_frameit_pipeline.sh \
  --design-config fastlane/frameit/logic/repbuzz-es.json \
  --results-root fastlane/frameit/results/repbuzz-es
python3 -B -m unittest discover -s scripts/fastlane -p 'test_promo_frameit.py'
```

`--design-config` must be the first option. Other invocations retain the legacy
flow below. Each results directory must be new: a failed run exports nothing,
and previous outputs are never used as inputs. All five frames must exist.

Edit `logic/repbuzz-es.json` for explicit screen/source mappings, approved copy,
fonts, colors, light paths and layout. The source hashes and capture provenance
must match the current app; recapture and update them when the app changes.
Originals are never resized in place. Temporary copies are normalized to
1290×2796 for the cached black iPhone 14 Pro Max bezel; the real source captures
are from iPhone 17 Pro Max. Final RGB PNGs are 1290×2796.

Dependencies: macOS Arial/Arial Bold, ImageMagick, Python 3, Fastlane and its
existing frame cache (`~/.fastlane/frameit/latest`). Missing cache fails before
Frameit starts; this stage does not install tools, upload or download assets.
`manifest.json` records source and output hashes. This original entry point remains Spanish-only.
New editor/completion originals and reproducible isolated-test instructions are
in `references/repbuzz-1.3.1-build4-es-premium-additional/provenance.json`.

## Complete localized batch

The offline batch entry point generates **70 pending-language images only** and
copies the **five approved Spanish finals byte-for-byte**. Its capture manifest
must contain exactly fourteen ordered locales (all supported locales except
`es`), five screen IDs, 70 current Premium originals, UI assertions, current app
version/build/bundle and production fingerprints. Missing pending captures or
fresh Spanish captures fail before rendering. Originals are never resized in place.

```sh
python3 -B scripts/fastlane/run_repbuzz_promo_batch.py \
  --capture-manifest references/<run-id>/capture-manifest.json \
  --approved-es-root fastlane/frameit/results/repbuzz-es \
  --results-root fastlane/frameit/results/<run-id>
python3 -B scripts/fastlane/run_repbuzz_promo_batch.py \
  --results-root fastlane/frameit/results/<run-id> --validate-only
python3 -B -m unittest discover -s scripts/fastlane -p 'test_repbuzz_promo_batch.py'
```

`<run-id>` must match the capture manifest (`repbuzz-remaining-YYYYMMDDTHHMMSSZ`);
the authorized run is `repbuzz-remaining-20261114T145150Z`. The capture policy
is `pending_locales_only` (also the default when omitted).
An existing destination is refused, not cleaned. The renderer stages on the
destination filesystem, verifies everything, then publishes the complete
directory by rename. No batch manifest marked `validated` is exported on failure.
No network, credentials, uploader or App Store API is used here.

| Contract | Enforcement |
|---|---|
| Copy | `logic/repbuzz-locales.json`: ordered screen pairs; Spanish matches the approved strings exactly, including line breaks |
| Spanish approval | `logic/approved-es.json` pins the approved manifest, design, original capture provenance, five output hashes and five raw mappings |
| Spanish preservation | Verify before/after; only `copy2` into `es/`. No Spanish ImageMagick, Frameit, label rendering or validation recomposition |
| Design | Same approved palette, paths, brand Arial, icon, geometry and Frameit bezel for every locale |
| Latin text | Original ImageMagick Arial Bold/Arial raster path, bounded to 1150×280 / 1160×150 |
| Japanese / Korean | CoreText Hiragino Sans W6/W3 / Apple SD Gothic Neo Bold/Regular |
| Simplified Chinese / Hindi | CoreText STHeiti SC Medium/Light / Kohinoor Devanagari Semibold/Regular |
| Typography | 140 pending labels checked; actual fonts, missing-glyph count, positioned glyphs, ink metrics and pixel hashes; minimum 80px title / 36px subtitle. Spanish typography inherits the approved pixels, not new labels |
| Finals | Exactly 75 opaque 8-bit RGB/sRGB PNGs, 1290×2796, correct ASC locale and explicit screen order |
| Independent validation | Recheck 70 captures, regenerate pending labels and recompose only 70 fresh images; compare decoded pixels. Spanish copies must match approved hashes, PNG CRCs and decompressed scanlines |

For a text-only pilot (not delivery images), select a new proof directory:

```sh
python3 -B scripts/fastlane/run_repbuzz_promo_batch.py --typography-only \
  --results-root fastlane/frameit/work/repbuzz-remaining-tests/typography-new
```

This requires macOS CoreText/AppKit and `swiftc`, in addition to the original
dependencies. The helper draws only copy labels, never app UI. CoreText performs
Devanagari shaping; UTF-8 presence alone is not treated as glyph proof. Temporary
Swift module caches are confined to the rendering/test temporary directory.
Inspect the non-Latin labels before the final run; automated checks do not
establish native-speaker translation approval.

### Uploader boundary

Add `scripts/fastlane` to the Python import path, then call
`run_repbuzz_promo_batch.validate_batch(output_root: Path, project_root: Path)`.
It returns the loaded `batch-manifest.json` only after recomputing every check,
or raises. Do not trust a manifest's `status` without this call. Validation is
deliberately substantial: it runs the existing Frameit composition again for
the 70 pending images to verify actual source pixels and unchanged design.
Spanish is never recomposed. Its parent-decoded, approved PNGs are hash-locked;
the validator additionally checks their PNG structure and decompressed scanlines
without external image tools, then proves every copied byte matches.

The manifest records `schema_version`, `run_id`, `app`, ordered `locales` and
`screen_ids`, approved-design/capture/copy/icon hashes, `validated_at_utc` and
75 `images`, `generated_count: 70`, `reused_approved_count: 5` and
`approved_spanish` provenance with the original authority and asset hashes.
Each image has its ASC locale, explicit relative path (for example
`es/01_02_Timer.png`), decoded dimensions, output/source hashes, exact localized
`copy` and per-role `typography`. Only Spanish may have `origin: approved_reuse`;
its `source` points to the approved final PNG rather than a new raw capture.
All other images require `origin: fresh_capture` and the current capture run.
The public validation API needs no new flags. Only after this gate may a separate uploader
perform its own preflight. A failed locale means no complete deliverable and
no authorization to upload a partial set.

### Tests and local delivery evidence

```sh
python3 -B -m unittest discover -s scripts/fastlane -p 'test_promo_frameit.py'
python3 -B -m unittest discover -s scripts/fastlane -p 'test_repbuzz_promo_batch.py'
```

The batch tests use isolated synthetic assets and do not require ignored Spanish
exports, completed capture runs or App Store credentials. Typography tests still
require the macOS fonts, CoreText, `swiftc` and ImageMagick described above.

Actual generation requires the five hash-locked Spanish exports and matching
capture provenance locally. It also requires the project version/build to match
the approval (1.3.1, build 4); release version changes are separate from this
promotional workflow. Generated run screenshots, temporary diagnostics and Apple
delivery journals remain local and are not source dependencies for unit tests.

## Legacy three-image flow

The legacy setup below still uses old aliases and all app locales. Do not run it
to prepare the new five-image Spanish delivery; its alphabetical aliases are
not the approved explicit mapping.

- `logic/`: configuration/templates used to generate screenshots.
- `resources/`: reusable assets (backgrounds, fonts).
- `work/screenshots/` and `work/screenshots-ipad/`: frameit working input (localized screenshots + `Framefile.json`).
- `results/screenshots/` and `results/screenshots-ipad/`: final framed outputs ready to review/upload.

Typical flow:

1. Prepare iPhone structure, assets, localized titles, and copy raw screenshots:
   - Put raw screenshots in `/Users/alejandroestevemaza/Code/GymTimerPro/fastlane/frameit/resources/screenshots`
   - Run `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/setup_frameit_assets.sh --device iphone --clean --overwrite-framefile --overwrite-titles`
2. Render iPhone outputs:
   - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/run_frameit_pipeline.sh --device iphone --clean-results`
3. Prepare iPad structure:
   - Put raw screenshots in `/Users/alejandroestevemaza/Code/GymTimerPro/fastlane/frameit/resources/screenshots-ipad`
   - Run `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/setup_frameit_assets.sh --device ipad --clean --overwrite-framefile --overwrite-titles`
4. Render iPad outputs:
   - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/run_frameit_pipeline.sh --device ipad --clean-results`

Screenshot names (for both iPhone and iPad):

- `01_TIMER.png`
- `02_CATEGORIES.png`
- `03_PROGRESS.png`

Notes:

- The render script normalizes input captures to `1290x2796` by default to avoid `Unsupported screen size` errors in `frameit`.
- Disable normalization only if your source screenshots already match a frameit-supported size:
  - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/run_frameit_pipeline.sh --device iphone --no-normalize`
- iPad defaults use `2048x2732`; override with `--target-width` / `--target-height` if needed.
