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
`manifest.json` records source and output hashes. Only Spanish is enabled.
New editor/completion originals and reproducible isolated-test instructions are
in `references/repbuzz-1.3.1-build4-es-premium-additional/provenance.json`.

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
