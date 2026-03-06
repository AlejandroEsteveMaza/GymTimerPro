Frameit structure (organized)

- `logic/`: configuration/templates used to generate screenshots.
- `resources/`: reusable assets (backgrounds, fonts).
- `work/screenshots/`: frameit working input (localized screenshots + `Framefile.json`).
- `results/screenshots/`: final framed outputs ready to review/upload.

Typical flow:

1. Prepare structure, assets, localized titles, and copy raw screenshots:
   - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/setup_frameit_assets.sh --clean --overwrite-framefile --overwrite-titles`
2. Render with frameit and collect final outputs:
   - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/run_frameit_pipeline.sh --clean-results`

Notes:

- The render script normalizes input captures to `1290x2796` by default to avoid `Unsupported screen size` errors in `frameit`.
- Disable normalization only if your source screenshots already match a frameit-supported size:
  - `/Users/alejandroestevemaza/Code/GymTimerPro/scripts/fastlane/run_frameit_pipeline.sh --no-normalize`
