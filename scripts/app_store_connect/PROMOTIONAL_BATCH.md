# Deliver the complete RepBuzz promotional batch

Use `upload_promotional_batch.py` after capture, composition and visual inspection.
It reuses the existing uploader's discovery, locale normalization, Apple lookup,
screenshot reservation and processing primitives. The legacy uploader is unchanged.

## Authorized destination

This delivery is fixed to `alejandroestevemaza.GymTimerPro`, iOS **1.3.1**, linked
build **4**, and `APP_IPHONE_67`. It changes only screenshot resources and their
ordering, never metadata, builds, review submissions, releases or iPad assets.

Before network access, the renderer's validator must accept all 75 current PNGs.
`visual-validation.json` in the batch root must bind the batch-manifest SHA-256,
run ID, all 15 reviewed locales and six true checks: `correct_screens`,
`correct_ui_locales`, `text_not_clipped`, `no_overlap`, `contrast`,
`font_and_encoding`. Record actual inspection, not a template approval.

```sh
PY=.venv_asc/bin/python
ROOT=fastlane/frameit/results/<run-id>
PLAN=references/<run-id>/asc-preflight.json
JOURNAL=references/<run-id>/asc-upload-journal.json

# Offline: no credentials are loaded.
$PY -B scripts/app_store_connect/upload_promotional_batch.py \
  --batch-root "$ROOT" --preflight-plan "$PLAN" --scan-only

# GET only, using ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY_PATH.
$PY -B scripts/app_store_connect/upload_promotional_batch.py \
  --batch-root "$ROOT" --preflight-plan "$PLAN"

# Only after the complete batch and preflight pass.
$PY -B scripts/app_store_connect/upload_promotional_batch.py \
  --batch-root "$ROOT" --preflight-plan "$PLAN" --journal "$JOURNAL" --apply
```

The live plan is recomputed before apply. Missing locales, a different build,
non-editable state, changed files/plan, incomplete processing or insufficient
capacity block the batch. Safe capacity requires existing screenshots + 5 <= 10
in every set. There is no eager/delete-first fallback.

All 75 new screenshots must process successfully, and all 15 sets must retain
exactly their planned membership, before deletion of any old screenshot. The
final ordered IDs, filenames, MD5 checksums and COMPLETE states are read back.

## Failure and recovery

Apple does not provide a transaction across 15 screenshot sets. A network failure
can leave newly reserved/uploaded assets; a late deletion/order failure can leave
mixed old/new membership. The journal records pending operations **before** each
mutation and confirmed IDs afterward. Existing journals are never replayed.
Stop, inspect Apple and the journal, and obtain a new recovery plan if interrupted.
No automatic mutation retries or rollback deletions are performed.

The strict transport disables ambient `.netrc`/proxy credentials and redirects.
JWTs go only to App Store Connect; byte-transfer operations must target HTTPS
Apple-owned upload hosts and cover the exact file once. New upload hosts fail
closed instead of receiving bytes automatically.

## Offline tests

```sh
.venv_asc/bin/python -B -m unittest discover -s scripts/app_store_connect \
  -p 'test_upload_promotional_batch.py'
```
