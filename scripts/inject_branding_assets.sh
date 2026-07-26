#!/usr/bin/env bash
#
# Drops your own logo/icon files into the exact paths RustDesk's icon and
# app-logo assets used to occupy, now that they've been removed as part of
# the WiBesk rebrand. Run from anywhere; paths below are resolved relative
# to this script's location, not your current directory.
#
# Destinations populated (only for the flags you pass):
#   flutter/assets/icon.svg                       - small in-app icon (vector, checked if icon.png is absent)
#   flutter/assets/icon.png                        - small in-app icon (raster, preferred over icon.svg if present)
#   flutter/assets/logo.png                        - large logo shown on the connect/home screen
#   flutter/assets/logo_light.png                  - large logo, light theme variant (optional)
#   flutter/assets/logo_dark.png                   - large logo, dark theme variant (optional)
#   flutter/windows/runner/resources/app_icon.ico  - Windows .exe / taskbar icon
#
# Usage:
#   scripts/inject_branding_assets.sh \
#     --icon-svg   path/to/icon.svg \
#     --icon-png   path/to/icon.png \
#     --logo       path/to/logo.png \
#     --logo-light path/to/logo_light.png \
#     --logo-dark  path/to/logo_dark.png \
#     --windows-ico path/to/app_icon.ico
#
# Every flag is optional; pass only the ones you have source files for.
# Run with -h/--help for details.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ASSETS_DIR="$REPO_ROOT/flutter/assets"
WIN_RES_DIR="$REPO_ROOT/flutter/windows/runner/resources"

usage() {
    sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

ICON_SVG=""
ICON_PNG=""
LOGO=""
LOGO_LIGHT=""
LOGO_DARK=""
WINDOWS_ICO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --icon-svg)    ICON_SVG="$2"; shift 2 ;;
        --icon-png)    ICON_PNG="$2"; shift 2 ;;
        --logo)        LOGO="$2"; shift 2 ;;
        --logo-light)  LOGO_LIGHT="$2"; shift 2 ;;
        --logo-dark)   LOGO_DARK="$2"; shift 2 ;;
        --windows-ico) WINDOWS_ICO="$2"; shift 2 ;;
        -h|--help)     usage 0 ;;
        *) echo "Unknown argument: $1" >&2; usage 1 ;;
    esac
done

if [ -z "$ICON_SVG$ICON_PNG$LOGO$LOGO_LIGHT$LOGO_DARK$WINDOWS_ICO" ]; then
    echo "No source files given." >&2
    usage 1
fi

# copy_into <src> <dest_dir> <dest_filename> <expected_ext>
copy_into() {
    local src="$1" dest_dir="$2" dest_name="$3" expected_ext="$4"
    [ -z "$src" ] && return 0

    if [ ! -f "$src" ]; then
        echo "ERROR: source file not found: $src" >&2
        exit 1
    fi
    if [ ! -s "$src" ]; then
        echo "ERROR: source file is empty: $src" >&2
        exit 1
    fi
    local actual_ext="${src##*.}"
    if [ "${actual_ext,,}" != "$expected_ext" ]; then
        echo "ERROR: $src does not have a .$expected_ext extension (expected for $dest_name)" >&2
        exit 1
    fi

    mkdir -p "$dest_dir"
    cp "$src" "$dest_dir/$dest_name"
    echo "  OK  $src -> ${dest_dir#"$REPO_ROOT"/}/$dest_name"
}

echo "Injecting branding assets into $REPO_ROOT ..."
copy_into "$ICON_SVG"    "$ASSETS_DIR"  "icon.svg"     svg
copy_into "$ICON_PNG"    "$ASSETS_DIR"  "icon.png"     png
copy_into "$LOGO"        "$ASSETS_DIR"  "logo.png"     png
copy_into "$LOGO_LIGHT"  "$ASSETS_DIR"  "logo_light.png" png
copy_into "$LOGO_DARK"   "$ASSETS_DIR"  "logo_dark.png"  png
copy_into "$WINDOWS_ICO" "$WIN_RES_DIR" "app_icon.ico" ico

cat <<'EOF'

Done. Notes:
  - flutter/assets/ is wildcard-included in pubspec.yaml, so new files there
    are picked up automatically - no pubspec.yaml edit needed.
  - icon.png (if provided) takes priority over icon.svg at runtime; you only
    need one of the two.
  - logo.png is the fallback used when no logo_light.png/logo_dark.png is
    present; provide all three for full light/dark theming, or just logo.png
    for a single-image logo.
  - app_icon.ico must be a real multi-resolution Windows .ico (16x16 up to
    256x256) or the built .exe's icon will look wrong at some sizes.
  - This script does NOT touch res/ (the source images used by
    flutter_launcher_icons to (re)generate macOS/iOS/Android/Linux icons) or
    flutter/macos/Runner/AppIcon.icns - those still carry the original
    RustDesk artwork and are a separate follow-up if you need those platforms
    rebranded too.
EOF
