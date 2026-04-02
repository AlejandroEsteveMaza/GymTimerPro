#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT_DEFAULT="/Users/alejandroestevemaza/Code/GymTimerPro"
PROJECT_ROOT="${PROJECT_ROOT_DEFAULT}"
SCHEME="GymTimerPro"
DEVICE="iPhone 17 Pro Max"
LOCALE="en-US"
ASSETS_ROOT=""
SNAPSHOT_ROOT=""
MAP_FILE=""
REQUIRED_FILE=""
CLEAN_ASSETS="0"
RUN_SNAPSHOT="1"
RUN_DARK="0"
ALLOW_MISSING="0"

usage() {
  cat <<'EOF'
Usage:
  generate_assets_reference.sh [options]

This script executes snapshot and exports/renames captures into:
  android-port/design/assets-reference/

Options:
  --project-root PATH       Project root (default: /Users/alejandroestevemaza/Code/GymTimerPro)
  --scheme NAME             Xcode scheme for snapshot (default: GymTimerPro)
  --device NAME             Snapshot device name (default: iPhone 17 Pro Max)
  --locale CODE             Snapshot locale (default: en-US)
  --assets-root PATH        Target assets-reference folder (default: <project>/android-port/design/assets-reference)
  --snapshot-root PATH      Snapshot source root (default: <project>/fastlane/screenshots/<locale>)
  --map-file PATH           Mapping file (default: <project>/scripts/fastlane/assets_reference_map.txt)
  --required-file PATH      Required target list (default: <project>/scripts/fastlane/assets_reference_required.txt)
  --clean-assets            Remove existing PNGs in assets-reference before export
  --skip-snapshot           Skip fastlane snapshot run and only export from existing files
  --run-dark                Also run snapshot with SNAPSHOT_DARK_MODE=1
  --allow-missing           Do not fail when required captures are missing
  -h, --help                Show this help

Mapping format:
  <source_glob>=<target_filename>

Example source_glob:
  *01_Home.png
  iPhone 17 Pro Max-02_Timer.png
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --locale)
      LOCALE="$2"
      shift 2
      ;;
    --assets-root)
      ASSETS_ROOT="$2"
      shift 2
      ;;
    --snapshot-root)
      SNAPSHOT_ROOT="$2"
      shift 2
      ;;
    --map-file)
      MAP_FILE="$2"
      shift 2
      ;;
    --required-file)
      REQUIRED_FILE="$2"
      shift 2
      ;;
    --clean-assets)
      CLEAN_ASSETS="1"
      shift
      ;;
    --skip-snapshot)
      RUN_SNAPSHOT="0"
      shift
      ;;
    --run-dark)
      RUN_DARK="1"
      shift
      ;;
    --allow-missing)
      ALLOW_MISSING="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${ASSETS_ROOT}" ]]; then
  ASSETS_ROOT="${PROJECT_ROOT}/android-port/design/assets-reference"
fi
if [[ -z "${SNAPSHOT_ROOT}" ]]; then
  SNAPSHOT_ROOT="${PROJECT_ROOT}/fastlane/screenshots/${LOCALE}"
fi
if [[ -z "${MAP_FILE}" ]]; then
  MAP_FILE="${PROJECT_ROOT}/scripts/fastlane/assets_reference_map.txt"
fi
if [[ -z "${REQUIRED_FILE}" ]]; then
  REQUIRED_FILE="${PROJECT_ROOT}/scripts/fastlane/assets_reference_required.txt"
fi

if [[ ! -d "${PROJECT_ROOT}" ]]; then
  echo "ERROR: project root not found: ${PROJECT_ROOT}"
  exit 1
fi
if [[ ! -f "${MAP_FILE}" ]]; then
  echo "ERROR: map file not found: ${MAP_FILE}"
  exit 1
fi
if [[ ! -f "${REQUIRED_FILE}" ]]; then
  echo "ERROR: required file not found: ${REQUIRED_FILE}"
  exit 1
fi

mkdir -p "${ASSETS_ROOT}"

if [[ "${CLEAN_ASSETS}" == "1" ]]; then
  find "${ASSETS_ROOT}" -maxdepth 1 -type f -name "*.png" -delete
fi

run_snapshot() {
  local dark="$1"
  local cmd=(
    fastlane snapshot
    --scheme "${SCHEME}"
    --languages "${LOCALE}"
    --devices "${DEVICE}"
    --clear_previous_screenshots true
    --only_testing "GymTimerProUITests/GymTimerProUITests/testSnapshots"
  )
  if [[ "${dark}" == "1" ]]; then
    echo "Running snapshot (dark mode) for ${DEVICE} ${LOCALE}"
    SNAPSHOT_DARK_MODE=1 "${cmd[@]}"
  else
    echo "Running snapshot (light mode) for ${DEVICE} ${LOCALE}"
    "${cmd[@]}"
  fi
}

cleanup_snapshot_report() {
  local report="${PROJECT_ROOT}/fastlane/screenshots/screenshots.html"
  if [[ -f "${report}" ]]; then
    rm -f "${report}"
    echo "Removed snapshot HTML report: ${report}"
  fi
}

if [[ "${RUN_SNAPSHOT}" == "1" ]]; then
  (
    cd "${PROJECT_ROOT}"
    run_snapshot "0"
    if [[ "${RUN_DARK}" == "1" ]]; then
      run_snapshot "1"
    fi
  )
  cleanup_snapshot_report
fi

resolve_snapshot_root() {
  if [[ -d "${SNAPSHOT_ROOT}" ]]; then
    return 0
  fi

  local fallback_locale="${LOCALE%%-*}"
  local fallback_path="${PROJECT_ROOT}/fastlane/screenshots/${fallback_locale}"
  if [[ -n "${fallback_locale}" && -d "${fallback_path}" ]]; then
    SNAPSHOT_ROOT="${fallback_path}"
    return 0
  fi

  local screenshots_base="${PROJECT_ROOT}/fastlane/screenshots"
  if [[ -d "${screenshots_base}" ]]; then
    local detected=""
    detected="$(find "${screenshots_base}" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
    if [[ -n "${detected}" ]]; then
      SNAPSHOT_ROOT="${detected}"
      return 0
    fi
  fi

  return 1
}

if ! resolve_snapshot_root; then
  echo "ERROR: snapshot root not found: ${SNAPSHOT_ROOT}"
  exit 1
fi

copy_from_mapping() {
  local copied=0
  local missing=0
  local line=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Ignore comments and empty lines.
    if [[ -z "${line}" || "${line}" == \#* ]]; then
      continue
    fi
    if [[ "${line}" != *=* ]]; then
      echo "WARN: invalid mapping line (expected source_glob=target.png): ${line}"
      continue
    fi

    local source_glob="${line%%=*}"
    local target_name="${line#*=}"
    local match=""

    # Pick most recent match for this glob.
    match="$(find "${SNAPSHOT_ROOT}" -maxdepth 1 -type f -name "${source_glob}" -print0 | xargs -0 ls -t 2>/dev/null | head -n 1 || true)"
    if [[ -z "${match}" ]]; then
      echo "WARN: no snapshot match for pattern '${source_glob}'"
      missing=$((missing + 1))
      continue
    fi

    cp "${match}" "${ASSETS_ROOT}/${target_name}"
    echo "OK: ${target_name} <- $(basename "${match}")"
    copied=$((copied + 1))
  done < "${MAP_FILE}"

  echo "Copied ${copied} captures from mapping."
  echo "Missing mapping matches: ${missing}"
}

check_required() {
  local missing_required=0
  local line=""
  local target=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "${line}" || "${line}" == \#* ]]; then
      continue
    fi
    target="${ASSETS_ROOT}/${line}"
    if [[ ! -f "${target}" ]]; then
      echo "MISSING REQUIRED: ${line}"
      missing_required=$((missing_required + 1))
    fi
  done < "${REQUIRED_FILE}"

  if [[ "${missing_required}" -gt 0 ]]; then
    if [[ "${ALLOW_MISSING}" == "1" ]]; then
      echo "Required capture check: ${missing_required} missing (allowed)."
    else
      echo "ERROR: required capture check failed with ${missing_required} missing files."
      exit 2
    fi
  else
    echo "Required capture check: OK"
  fi
}

copy_from_mapping
check_required

echo ""
echo "Done. Assets exported to:"
echo "  ${ASSETS_ROOT}"
