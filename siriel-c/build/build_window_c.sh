#!/usr/bin/env bash
# =====================================================================
# build_window_c.sh - build the PURE-C window + launcher for the C-C
#                     engine (no Pascal / FPC at all).
#
#   cdrv_window  (C + Raylib) reads FrameRGB <- shm, DISPLAYS it
#   cdrv_run     (C)          launches the engine + window and exits
#                               when either stops
#
# This is the window half of the two-process layout. It is the SAME
# window as build_cdrv_shm_linux.sh produces, but it only compiles the
# C sources (host_window.c, host_launch.c, fb_shm.c) + Raylib -- there
# is no FPC engine stage here, because the engine is built separately
# by build_engine_c.sh into out/cdrv_engine_cc.
#
# Prerequisites:
#   * out/cdrv_engine_cc  must exist (run build/build_engine_c.sh first)
#   * third-party/raylib/src/libraylib.a must be built (see raylib README)
#
# Layout (this script lives in build/):
#   src/c       - C front-end + window + launcher
#   out/        - all build OUTPUT (gitignored)
#   data        - game data (engine reads from its CWD)
#   third-party/raylib - Raylib submodule (window rendering)
# =====================================================================
set -uo pipefail

BUILD="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BUILD/.." && pwd)"
C="$ROOT/src/c"
RAYLIB_SRC="$ROOT/third-party/raylib/src"
RAYLIB_A="$RAYLIB_SRC/libraylib.a"
OUT="$ROOT/out"
mkdir -p "$OUT"

[ -f "$RAYLIB_A" ] || { echo "ERROR: $RAYLIB_A missing (build raylib first, see third-party/raylib/README)"; exit 1; }
[ -x "$OUT/cdrv_engine_cc" ] || { echo "NOTE: $OUT/cdrv_engine_cc not found -- run build/build_engine_c.sh first"; }

# Linux has gcc and clang; either links fine.
command -v gcc >/dev/null 2>&1 && CC=gcc || CC=clang

# ---------------------------------------------------------------- WINDOW ---
echo "===== WINDOW: cdrv_window (C + Raylib) ====="

$CC -O2 -I"$RAYLIB_SRC" -I"$RAYLIB_SRC/external/glfw/include" -I"$C" \
    -c "$C/host_window.c" -o "$OUT/host_window.o"
echo "host_window.o -> $(du -h "$OUT/host_window.o" | cut -f1)"

# Platform-specific link flags. Linux links the system GL/X11 stack
# (-lGL, -lX11, ...); macOS links the equivalent Apple frameworks that
# Raylib/GLFW need, and drops -ldl (dlfcn lives in libSystem there, so
# -ldl fails the link — same reasoning as build_engine_c.sh).
PLATFORM="$(uname -s 2>/dev/null || echo unknown)"
case "$PLATFORM" in
    Darwin*) echo "platform: macOS ($PLATFORM)";
             WIN_LINK="-framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo -framework QuartzCore -lm -lpthread" ;;
    *)       echo "platform: $PLATFORM";
             WIN_LINK="-lGL -lm -lpthread -ldl -lX11 -lXcursor -lXrandr -lXi -lXinerama" ;;
esac

# Pure-clang/gcc link: NO FPC objects.
$CC -O2 -I"$RAYLIB_SRC" \
    "$OUT/host_window.o" "$OUT/fb_shm.o" \
    "$RAYLIB_A" \
    $WIN_LINK \
    -o "$OUT/cdrv_window"
echo "link_exit=$?"
[ -x "$OUT/cdrv_window" ] || { echo "ERROR: cdrv_window not produced"; exit 1; }

# ---------------------------------------------------------------- LAUNCHER ---
echo "===== LAUNCHER: cdrv_run ====="
$CC -O2 -I"$C" -c "$C/host_launch.c" -o "$OUT/host_launch.o"
echo "host_launch.o -> $(du -h "$OUT/host_launch.o" | cut -f1)"
$CC -O2 -o "$OUT/cdrv_run" "$OUT/host_launch.o"
echo "link_exit=$?"
[ -x "$OUT/cdrv_run" ] || { echo "ERROR: cdrv_run not produced"; exit 1; }

echo ""
echo "=== done (outputs in $OUT) ==="
file "$OUT/cdrv_window" | cut -d, -f1-2
file "$OUT/cdrv_run" | cut -d, -f1-2
