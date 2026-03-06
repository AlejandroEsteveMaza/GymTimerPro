#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT_DEFAULT="/Users/alejandroestevemaza/Code/GymTimerPro"
PROJECT_ROOT="${PROJECT_ROOT_DEFAULT}"
DEVICE="iphone"
WORK_ROOT=""
RESULTS_ROOT=""
CLEAN_RESULTS="0"
NORMALIZE_SIZE="1"
TARGET_WIDTH=""
TARGET_HEIGHT=""
TARGET_WIDTH_SET="0"
TARGET_HEIGHT_SET="0"

usage() {
  cat <<'EOF'
Usage:
  run_frameit_pipeline.sh [options]

Options:
  --project-root PATH    Project root (default: /Users/alejandroestevemaza/Code/GymTimerPro)
  --device NAME          Target device: iphone | ipad (default: iphone)
  --work-root PATH       Frameit work screenshots root (default depends on --device)
  --results-root PATH    Final framed screenshots root (default depends on --device)
  --clean-results        Remove previous framed output from results root before copying
  --no-normalize         Do not normalize input screenshot size before frameit
  --target-width PX      Normalize width (default: 1290 for iPhone, 2048 for iPad)
  --target-height PX     Normalize height (default: 2796 for iPhone, 2732 for iPad)
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --device)
      DEVICE="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
      shift 2
      ;;
    --work-root)
      WORK_ROOT="$2"
      shift 2
      ;;
    --results-root)
      RESULTS_ROOT="$2"
      shift 2
      ;;
    --clean-results)
      CLEAN_RESULTS="1"
      shift
      ;;
    --no-normalize)
      NORMALIZE_SIZE="0"
      shift
      ;;
    --target-width)
      TARGET_WIDTH="$2"
      TARGET_WIDTH_SET="1"
      shift 2
      ;;
    --target-height)
      TARGET_HEIGHT="$2"
      TARGET_HEIGHT_SET="1"
      shift 2
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

if [[ "${DEVICE}" != "iphone" && "${DEVICE}" != "ipad" ]]; then
  echo "ERROR: --device must be 'iphone' or 'ipad' (got: ${DEVICE})"
  exit 1
fi

if [[ "${TARGET_WIDTH_SET}" == "0" ]]; then
  if [[ "${DEVICE}" == "ipad" ]]; then
    TARGET_WIDTH="2048"
  else
    TARGET_WIDTH="1290"
  fi
fi

if [[ "${TARGET_HEIGHT_SET}" == "0" ]]; then
  if [[ "${DEVICE}" == "ipad" ]]; then
    TARGET_HEIGHT="2732"
  else
    TARGET_HEIGHT="2796"
  fi
fi

if [[ -z "${WORK_ROOT}" ]]; then
  if [[ "${DEVICE}" == "ipad" ]]; then
    WORK_ROOT="${PROJECT_ROOT}/fastlane/frameit/work/screenshots-ipad"
  else
    WORK_ROOT="${PROJECT_ROOT}/fastlane/frameit/work/screenshots"
  fi
fi
if [[ -z "${RESULTS_ROOT}" ]]; then
  if [[ "${DEVICE}" == "ipad" ]]; then
    RESULTS_ROOT="${PROJECT_ROOT}/fastlane/frameit/results/screenshots-ipad"
  else
    RESULTS_ROOT="${PROJECT_ROOT}/fastlane/frameit/results/screenshots"
  fi
fi

if [[ ! -d "${WORK_ROOT}" ]]; then
  echo "ERROR: work root not found: ${WORK_ROOT}"
  exit 1
fi

if [[ ! -f "${WORK_ROOT}/Framefile.json" ]]; then
  echo "ERROR: Framefile not found: ${WORK_ROOT}/Framefile.json"
  exit 1
fi

if [[ "${CLEAN_RESULTS}" == "1" && -d "${RESULTS_ROOT}" ]]; then
  find "${RESULTS_ROOT}" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -delete
fi

mkdir -p "${RESULTS_ROOT}"

sync_framed_outputs() {
  local copied=0
  while IFS= read -r -d '' framed_file; do
    rel_path="${framed_file#${WORK_ROOT}/}"
    locale_dir="$(dirname "${rel_path}")"
    filename="$(basename "${rel_path}")"

    mkdir -p "${RESULTS_ROOT}/${locale_dir}"
    cp "${framed_file}" "${RESULTS_ROOT}/${locale_dir}/${filename}"
    copied=$((copied + 1))
  done < <(find "${WORK_ROOT}" -type f -name "*_framed.png" -print0)
  echo "${copied}"
}

# Ensure partial outputs are preserved even if frameit is interrupted.
trap 'sync_framed_outputs >/dev/null || true' EXIT

echo "Work root    : ${WORK_ROOT}"
echo "Results root : ${RESULTS_ROOT}"
echo "Device       : ${DEVICE}"
echo ""

if [[ "${NORMALIZE_SIZE}" == "1" ]]; then
  while IFS= read -r -d '' img; do
    # Do not touch already framed outputs.
    if [[ "${img}" == *_framed.png ]]; then
      continue
    fi
    sips -z "${TARGET_HEIGHT}" "${TARGET_WIDTH}" "${img}" >/dev/null
  done < <(find "${WORK_ROOT}" -type f \( -name "*.png" -o -name "*.PNG" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.JPG" -o -name "*.JPEG" \) -print0)
fi

(
  cd "${WORK_ROOT}"
  fastlane frameit ios
)

copied="$(sync_framed_outputs)"

echo "Done. Copied ${copied} framed screenshots to:"
echo "  ${RESULTS_ROOT}"
