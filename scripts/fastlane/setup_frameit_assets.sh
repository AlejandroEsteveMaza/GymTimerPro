#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Frameit bootstrap for GymTimerPro
# - Creates localized fastlane/frameit/work/screenshots folders from app locales
# - Copies screenshots from a source root (Desktop by default)
# - Generates a runtime Framefile.json in work/ and a template in logic/
# - Generates title.strings for each locale
# - Generates default backgrounds/fonts in resources/assets
#
# Optional locale mapping file format:
#   en=/absolute/path/to/en
#   es=/absolute/path/to/es
# -----------------------------------------------------------------------------

PROJECT_ROOT_DEFAULT="/Users/alejandroestevemaza/Code/GymTimerPro"
SOURCE_ROOT_DEFAULT="/Users/alejandroestevemaza/Desktop"

PROJECT_ROOT="${PROJECT_ROOT_DEFAULT}"
SOURCE_ROOT="${SOURCE_ROOT_DEFAULT}"
DEST_ROOT=""
FRAMEIT_ROOT=""
RESOURCES_ROOT=""
LOGIC_ROOT=""
RESULTS_ROOT=""
MAP_FILE=""
OVERWRITE_FRAMEFILE="0"
OVERWRITE_TITLES="0"
CLEAN_DEST_IMAGES="0"

usage() {
  cat <<'EOF'
Usage:
  setup_frameit_assets.sh [options]

Options:
  --project-root PATH       Project root (default: /Users/alejandroestevemaza/Code/GymTimerPro)
  --source-root PATH        Source screenshots root (default: /Users/alejandroestevemaza/Desktop)
  --dest-root PATH          Destination work screenshots root (default: <project>/fastlane/frameit/work/screenshots)
  --map-file PATH           Optional locale-to-folder map file
  --overwrite-framefile     Overwrite Framefile.json if it exists
  --overwrite-titles        Overwrite title.strings files if they exist
  --clean                   Remove existing images in destination locale folders before copying
  -h, --help                Show this help

Example:
  ./scripts/fastlane/setup_frameit_assets.sh \
    --source-root /Users/alejandroestevemaza/Desktop \
    --map-file /Users/alejandroestevemaza/Desktop/screenshot_map.txt \
    --overwrite-framefile \
    --overwrite-titles \
    --clean
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --source-root)
      SOURCE_ROOT="$2"
      shift 2
      ;;
    --dest-root)
      DEST_ROOT="$2"
      shift 2
      ;;
    --map-file)
      MAP_FILE="$2"
      shift 2
      ;;
    --overwrite-framefile)
      OVERWRITE_FRAMEFILE="1"
      shift
      ;;
    --overwrite-titles)
      OVERWRITE_TITLES="1"
      shift
      ;;
    --clean)
      CLEAN_DEST_IMAGES="1"
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

if [[ -z "${DEST_ROOT}" ]]; then
  DEST_ROOT="${PROJECT_ROOT}/fastlane/frameit/work/screenshots"
fi

FRAMEIT_ROOT="$(cd "${DEST_ROOT}/../.." && pwd)"
RESOURCES_ROOT="${FRAMEIT_ROOT}/resources"
LOGIC_ROOT="${FRAMEIT_ROOT}/logic"
RESULTS_ROOT="${FRAMEIT_ROOT}/results/screenshots"

if [[ ! -d "${PROJECT_ROOT}" ]]; then
  echo "ERROR: project root not found: ${PROJECT_ROOT}"
  exit 1
fi

if [[ ! -d "${SOURCE_ROOT}" ]]; then
  echo "ERROR: source root not found: ${SOURCE_ROOT}"
  exit 1
fi

if [[ -n "${MAP_FILE}" && ! -f "${MAP_FILE}" ]]; then
  echo "ERROR: map file not found: ${MAP_FILE}"
  exit 1
fi

if [[ ! -d "${PROJECT_ROOT}/Shared" ]]; then
  echo "ERROR: expected locales folder missing: ${PROJECT_ROOT}/Shared"
  exit 1
fi

mkdir -p "${DEST_ROOT}" "${RESOURCES_ROOT}" "${LOGIC_ROOT}" "${RESULTS_ROOT}"

find_map_path() {
  local locale="$1"
  local line=""
  if [[ -z "${MAP_FILE}" ]]; then
    return 1
  fi

  line="$(grep -E "^${locale}=" "${MAP_FILE}" | head -n 1 || true)"
  if [[ -z "${line}" ]]; then
    return 1
  fi
  echo "${line#*=}"
}

source_candidates_for_locale() {
  local locale="$1"
  case "${locale}" in
    en) echo "en-US en english" ;;
    es) echo "es-ES es spanish" ;;
    de) echo "de-DE de german" ;;
    fr) echo "fr-FR fr french" ;;
    it) echo "it it-IT italian" ;;
    pt-BR) echo "pt-BR ptbr brazil portuguese-br" ;;
    pt-PT) echo "pt-PT pt portuguese-pt" ;;
    nl) echo "nl-NL nl dutch" ;;
    sv) echo "sv sv-SE swedish" ;;
    da) echo "da da-DK danish" ;;
    nb) echo "nb nb-NO no norwegian" ;;
    ja) echo "ja ja-JP japanese" ;;
    ko) echo "ko ko-KR korean" ;;
    zh-Hans) echo "zh-Hans zh-CN zh chinese" ;;
    hi) echo "hi hi-IN hindi" ;;
    *) echo "${locale}" ;;
  esac
}

find_source_dir_for_locale() {
  local locale="$1"
  local mapped=""
  local candidate=""

  mapped="$(find_map_path "${locale}" || true)"
  if [[ -n "${mapped}" ]]; then
    if [[ -d "${mapped}" ]]; then
      echo "${mapped}"
      return 0
    fi
    if [[ -d "${SOURCE_ROOT}/${mapped}" ]]; then
      echo "${SOURCE_ROOT}/${mapped}"
      return 0
    fi
  fi

  for candidate in $(source_candidates_for_locale "${locale}"); do
    if [[ -d "${SOURCE_ROOT}/${candidate}" ]]; then
      echo "${SOURCE_ROOT}/${candidate}"
      return 0
    fi
  done

  if [[ -d "${SOURCE_ROOT}/common" ]]; then
    echo "${SOURCE_ROOT}/common"
    return 0
  fi

  return 1
}

copy_images() {
  local src="$1"
  local dst="$2"
  local copied=0
  local file=""

  shopt -s nullglob
  for file in "${src}"/*.png "${src}"/*.PNG "${src}"/*.jpg "${src}"/*.JPG "${src}"/*.jpeg "${src}"/*.JPEG; do
    cp "${file}" "${dst}/"
    copied=$((copied + 1))
  done
  shopt -u nullglob
  echo "${copied}"
}

write_title_strings() {
  local locale="$1"
  local output="$2"
  local t1=""
  local t2=""
  local t3=""

  case "${locale}" in
    en) t1="Rest Timer for Strength"; t2="Organize Your Routines"; t3="Track Real Progress" ;;
    es) t1="Controla tus descansos"; t2="Organiza tus rutinas"; t3="Sigue tu progreso real" ;;
    de) t1="Pausen im Griff behalten"; t2="Routinen organisieren"; t3="Echten Fortschritt sehen" ;;
    fr) t1="Maîtrisez vos temps de repos"; t2="Organisez vos routines"; t3="Suivez vos vrais progrès" ;;
    it) t1="Gestisci i tempi di recupero"; t2="Organizza le tue routine"; t3="Segui progressi reali" ;;
    pt-BR) t1="Controle seus descansos"; t2="Organize suas rotinas"; t3="Acompanhe seu progresso" ;;
    pt-PT) t1="Controla os teus descansos"; t2="Organiza as tuas rotinas"; t3="Acompanha o teu progresso" ;;
    nl) t1="Beheer je rust tussen sets"; t2="Organiseer je routines"; t3="Volg echte vooruitgang" ;;
    sv) t1="Kontrollera vilan mellan set"; t2="Organisera dina rutiner"; t3="Följ verklig utveckling" ;;
    da) t1="Styr pauser mellem sæt"; t2="Organiser dine rutiner"; t3="Følg reel fremgang" ;;
    nb) t1="Kontroller pauser mellom sett"; t2="Organiser rutinene dine"; t3="Følg reell fremgang" ;;
    ja) t1="セット間休憩を最適化"; t2="ルーティンを整理"; t3="進捗を見える化" ;;
    ko) t1="세트 간 휴식 정밀 관리"; t2="루틴을 체계적으로 정리"; t3="실제 진행 상황 추적" ;;
    zh-Hans) t1="精准管理组间休息"; t2="高效整理训练计划"; t3="清晰追踪训练进展" ;;
    hi) t1="सेट्स के बीच आराम नियंत्रण"; t2="अपनी रूटीन व्यवस्थित करें"; t3="वास्तविक प्रगति ट्रैक करें" ;;
    *) t1="Rest Timer for Strength"; t2="Organize Your Routines"; t3="Track Real Progress" ;;
  esac

  cat > "${output}" <<EOF
"01_TIMER" = "${t1}";
"02_CATEGORIES" = "${t2}";
"03_PROGRESS" = "${t3}";
"TIMER" = "${t1}";
"CATEGORIES" = "${t2}";
"PROGRESS" = "${t3}";
EOF
}

write_framefile() {
  local framefile_path="$1"
  cat > "${framefile_path}" <<'EOF'
{
  "default": {
    "use_platform": "IOS",
    "background": "../../resources/assets/background_timer.jpg",
    "padding": "10%x12%",
    "title_min_height": "18%",
    "show_complete_frame": true,
    "font_scale_factor": 0.07,
    "title": {
      "color": "#F3F8FF",
      "font_size": 78,
      "font_weight": "700",
      "fonts": [
        {
          "font": "../../resources/assets/Avenir Next.ttc",
          "supported": [
            "da",
            "de",
            "en",
            "en-US",
            "es",
            "fr",
            "it",
            "nb",
            "nl",
            "pt-BR",
            "pt-PT",
            "sv"
          ]
        },
        {
          "font": "../../resources/assets/ArialUnicode.ttf",
          "supported": [
            "hi",
            "ja",
            "ko",
            "zh-Hans"
          ]
        }
      ]
    }
  },
  "data": [
    {
      "filter": "01_",
      "background": "../../resources/assets/background_timer.jpg"
    },
    {
      "filter": "02_",
      "background": "../../resources/assets/background_categories.jpg"
    },
    {
      "filter": "03_",
      "background": "../../resources/assets/background_progress.jpg"
    }
  ]
}
EOF
}

ensure_fonts() {
  local assets_dir="$1"
  local src_avenir="/System/Library/Fonts/Avenir Next.ttc"
  local src_unicode="/System/Library/Fonts/Supplemental/Arial Unicode.ttf"

  mkdir -p "${assets_dir}"

  if [[ -f "${src_avenir}" && ! -f "${assets_dir}/Avenir Next.ttc" ]]; then
    cp "${src_avenir}" "${assets_dir}/Avenir Next.ttc"
    echo "OK: ${assets_dir}/Avenir Next.ttc"
  fi

  if [[ -f "${src_unicode}" && ! -f "${assets_dir}/ArialUnicode.ttf" ]]; then
    cp "${src_unicode}" "${assets_dir}/ArialUnicode.ttf"
    echo "OK: ${assets_dir}/ArialUnicode.ttf"
  fi
}

generate_backgrounds() {
  local assets_dir="$1"
  local magick_cmd=""
  local file=""

  if command -v magick >/dev/null 2>&1; then
    magick_cmd="magick"
  elif command -v convert >/dev/null 2>&1; then
    magick_cmd="convert"
  else
    echo "WARN: ImageMagick not found in PATH; skipping background generation."
    return 0
  fi

  mkdir -p "${assets_dir}"

  # Rebuild backgrounds every run to keep the visual style deterministic.
  "${magick_cmd}" -size 2064x2752 gradient:"#0F2F57-#3B82F6" "${assets_dir}/background_timer.jpg"
  "${magick_cmd}" -size 2064x2752 gradient:"#122A4A-#2563EB" "${assets_dir}/background_categories.jpg"
  "${magick_cmd}" -size 2064x2752 gradient:"#1E3A8A-#F97316" "${assets_dir}/background_progress.jpg"

  for file in background_timer.jpg background_categories.jpg background_progress.jpg; do
    if [[ -f "${assets_dir}/${file}" ]]; then
      echo "OK: ${assets_dir}/${file}"
    fi
  done
}

echo "Project root : ${PROJECT_ROOT}"
echo "Source root  : ${SOURCE_ROOT}"
echo "Frameit root : ${FRAMEIT_ROOT}"
echo "Work root    : ${DEST_ROOT}"
echo "Logic root   : ${LOGIC_ROOT}"
echo "Assets root  : ${RESOURCES_ROOT}/assets"
echo "Results root : ${RESULTS_ROOT}"
if [[ -n "${MAP_FILE}" ]]; then
  echo "Map file     : ${MAP_FILE}"
fi
echo ""

LOCALES="$(find "${PROJECT_ROOT}/Shared" -maxdepth 1 -type d -name "*.lproj" -exec basename {} .lproj \; | sort)"

if [[ -z "${LOCALES}" ]]; then
  echo "ERROR: no locales found in ${PROJECT_ROOT}/Shared"
  exit 1
fi

for locale in ${LOCALES}; do
  locale_dir="${DEST_ROOT}/${locale}"
  mkdir -p "${locale_dir}"

  if [[ "${CLEAN_DEST_IMAGES}" == "1" ]]; then
    rm -f "${locale_dir}"/*.png "${locale_dir}"/*.PNG "${locale_dir}"/*.jpg "${locale_dir}"/*.JPG "${locale_dir}"/*.jpeg "${locale_dir}"/*.JPEG
  fi

  source_dir="$(find_source_dir_for_locale "${locale}" || true)"
  if [[ -n "${source_dir}" ]]; then
    copied="$(copy_images "${source_dir}" "${locale_dir}")"
    echo "OK: ${locale} <- ${source_dir} (${copied} files)"
  else
    echo "WARN: no screenshot source found for locale '${locale}'"
  fi

  title_file="${locale_dir}/title.strings"
  if [[ ! -f "${title_file}" || "${OVERWRITE_TITLES}" == "1" ]]; then
    write_title_strings "${locale}" "${title_file}"
    echo "OK: ${title_file}"
  fi
done

assets_dir="${RESOURCES_ROOT}/assets"
generate_backgrounds "${assets_dir}"
ensure_fonts "${assets_dir}"

framefile="${DEST_ROOT}/Framefile.json"
if [[ ! -f "${framefile}" || "${OVERWRITE_FRAMEFILE}" == "1" ]]; then
  write_framefile "${framefile}"
  echo "OK: ${framefile}"
fi

framefile_template="${LOGIC_ROOT}/Framefile.template.json"
if [[ ! -f "${framefile_template}" || "${OVERWRITE_FRAMEFILE}" == "1" ]]; then
  cp "${framefile}" "${framefile_template}"
  echo "OK: ${framefile_template}"
fi

echo ""
echo "Done."
echo "Run rendering pipeline with:"
echo "  ${PROJECT_ROOT}/scripts/fastlane/run_frameit_pipeline.sh"
