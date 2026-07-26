#!/usr/bin/env bash
#
# End-to-end WiBesk branding pipeline:
#   1. Auto-detect the WiBesk icon/logo PNGs in a source folder you point it at.
#   2. Convert the square icon into a proper multi-resolution Windows .ico.
#   3. Copy everything into the Flutter asset dirs via inject_branding_assets.sh.
#   4. Run `flutter build linux --release` (unless --skip-build is passed).
#
# Usage:
#   scripts/apply_wibesk_branding.sh <source_dir> [--skip-build]
#
# Expected files in <source_dir> (case-insensitive match, spaces ok):
#   favicon.png         - square app icon (used as-is, and converted to .ico)
#   logo.png            - wide logo, colored/light variant (default + light theme)
#   white.png           - wide logo, white variant (dark theme)
#   favicon white.png   - optional circular/white icon badge; copied to
#                         assets/icon_dark.png for future use, not yet wired
#                         into any widget (loadIcon() has no dark variant today)
#
# Any file not found is skipped with a warning; the script does not fail
# unless the square icon (favicon*.png) is missing, since the Windows .ico
# conversion depends on it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$REPO_ROOT/flutter"
ASSETS_DIR="$FLUTTER_DIR/assets"

usage() {
    sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

SRC_DIR=""
SKIP_BUILD=0
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-build) SKIP_BUILD=1; shift ;;
        -h|--help)    usage 0 ;;
        *)
            if [ -z "$SRC_DIR" ]; then SRC_DIR="$1"; shift
            else echo "Unknown argument: $1" >&2; usage 1; fi
            ;;
    esac
done

if [ -z "$SRC_DIR" ]; then
    echo "ERROR: source directory required." >&2
    usage 1
fi
if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: not a directory: $SRC_DIR" >&2
    exit 1
fi

# find_one <dir> <pattern...>
# Case-insensitive match against find -iname; returns first hit.
find_one() {
    local dir="$1"; shift
    for pat in "$@"; do
        local hit
        hit="$(find "$dir" -maxdepth 1 -iname "$pat" -print -quit)"
        if [ -n "$hit" ]; then
            echo "$hit"
            return 0
        fi
    done
    return 1
}

ICON_SRC="$(find_one "$SRC_DIR" "favicon.png" || true)"
# Exclude anything with "white" in the name from the plain logo match.
LOGO_SRC="$(find_one "$SRC_DIR" "logo.png" "logo.jpg" || true)"
LOGO_DARK_SRC="$(find_one "$SRC_DIR" "white.png" || true)"
ICON_BADGE_SRC="$(find_one "$SRC_DIR" "favicon white.png" "favicon_white.png" "faviconwhite.png" || true)"

echo "Detected in $SRC_DIR:"
echo "  icon (favicon.png)        -> ${ICON_SRC:-NOT FOUND}"
echo "  logo (Logo.png)           -> ${LOGO_SRC:-NOT FOUND}"
echo "  logo_dark (White.png)     -> ${LOGO_DARK_SRC:-NOT FOUND}"
echo "  icon badge (Favicon White.png, optional) -> ${ICON_BADGE_SRC:-not found, skipping}"
echo

if [ -z "$ICON_SRC" ]; then
    echo "ERROR: no favicon.png (square app icon) found in $SRC_DIR - required to build app_icon.ico." >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ICO_OUT="$WORKDIR/app_icon.ico"
echo "Converting square icon to multi-resolution .ico ..."
(cd "$FLUTTER_DIR" && dart run tool/png_to_ico.dart "$ICON_SRC" "$ICO_OUT")
echo

INJECT_ARGS=(--icon-png "$ICON_SRC" --windows-ico "$ICO_OUT")
[ -n "$LOGO_SRC" ] && INJECT_ARGS+=(--logo "$LOGO_SRC" --logo-light "$LOGO_SRC")
[ -n "$LOGO_DARK_SRC" ] && INJECT_ARGS+=(--logo-dark "$LOGO_DARK_SRC")

"$SCRIPT_DIR/inject_branding_assets.sh" "${INJECT_ARGS[@]}"

if [ -n "$ICON_BADGE_SRC" ]; then
    mkdir -p "$ASSETS_DIR"
    cp "$ICON_BADGE_SRC" "$ASSETS_DIR/icon_dark.png"
    echo "  OK  $ICON_BADGE_SRC -> ${ASSETS_DIR#"$REPO_ROOT"/}/icon_dark.png (reserved, not yet referenced by any widget)"
fi

if [ "$SKIP_BUILD" -eq 1 ]; then
    echo
    echo "Skipping build (--skip-build passed). Assets are in place."
    exit 0
fi

echo
echo "Building: flutter build linux --release ..."
(cd "$FLUTTER_DIR" && flutter build linux --release)
echo
echo "Done. Release build output: flutter/build/linux/x64/release/bundle/"
