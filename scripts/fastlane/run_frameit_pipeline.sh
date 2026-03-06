#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT_DEFAULT="/Users/alejandroestevemaza/Code/GymTimerPro"
PROJECT_ROOT="${PROJECT_ROOT_DEFAULT}"
WORK_ROOT=""
RESULTS_ROOT=""
CLEAN_RESULTS="0"
NORMALIZE_SIZE="1"
TARGET_WIDTH="1290"
TARGET_HEIGHT="2796"

usage() {
  cat <<'EOF'
Usage:
  run_frameit_pipeline.sh [options]

Options:
  --project-root PATH    Project root (default: /Users/alejandroestevemaza/Code/GymTimerPro)
  --work-root PATH       Frameit work screenshots root (default: <project>/fastlane/frameit/work/screenshots)
  --results-root PATH    Final framed screenshots root (default: <project>/fastlane/frameit/results/screenshots)
  --clean-results        Remove previous framed output from results root before copying
  --no-normalize         Do not normalize input screenshot size before frameit
  --target-width PX      Normalize width (default: 1290)
  --target-height PX     Normalize height (default: 2796)
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
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
      shift 2
      ;;
    --target-height)
      TARGET_HEIGHT="$2"
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

if [[ -z "${WORK_ROOT}" ]]; then
  WORK_ROOT="${PROJECT_ROOT}/fastlane/frameit/work/screenshots"
fi
if [[ -z "${RESULTS_ROOT}" ]]; then
  RESULTS_ROOT="${PROJECT_ROOT}/fastlane/frameit/results/screenshots"
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
