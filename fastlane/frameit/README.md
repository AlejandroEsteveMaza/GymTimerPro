Frameit structure (organized)

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
