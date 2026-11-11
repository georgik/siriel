#!/usr/bin/env bash
# =====================================================================
# build_cdrv_shm.sh - macOS build of the TWO-PROCESS windowed Siriel.
#
# FPC-as-runtime cannot drive macOS AppKit without SIGILL (see
# C-DRIVES-PASCAL-RECIPE.md). So we split into two processes that share
# the framebuffer via POSIX shared memory:
#
#   cdrv_engine  (FPC + C)   drives Siriel, writes FrameRGB -> shm
#   cdrv_window  (C + Raylib) reads FrameRGB <- shm, DISPLAYS it (no FPC)
#   cdrv_run     (C)         launches both and exits when either stops
#
# Layout (this script lives in build/):
#   src/pascal  - ported Turbo-Pascal source (.PAS main, .pas aux units)
#   src/c       - C front-end + window + launcher
#   data        - game data (engine reads from its CWD)
#   third-party/raylib - Raylib submodule (window rendering)
#   out/        - all build OUTPUT (gitignored)
#
# Build steps:
#   ENGINE (FPC owns main; NO Raylib):
#     1. compile fb_shm.c, crash_handler.c, host_engine.c  -> out/
#     2. fpc -b  (build SI35.PAS objects, no link)           -> out/
#     3. fpc -B  link -> out/cdrv_engine                     -> out/
#   WINDOW (pure C + Raylib; NO FPC):
#     4. compile host_window.c, activate_macos.m            -> out/
#     5. clang link -> out/cdrv_window                       -> out/
#   LAUNCHER (pure C; NO FPC, NO Raylib):
#     6. compile + link host_launch.c -> out/cdrv_run        -> out/
#
# The libsiriel_bgi stub (out/libsiriel_bgi.dylib) must exist first; build it
# with build/make_stub.sh. It is a link-time shim for the BGI symbols the
# Pascal code references (rendering is done by Raylib, not by it).
# =====================================================================
set -uo pipefail

BUILD="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BUILD/.." && pwd)"
SRC="$ROOT/src"
PASCAL="$SRC/pascal"
C="$SRC/c"
TP="$ROOT/third-party"
RAYLIB_SRC="$TP/raylib/src"
RAYLIB_A="$RAYLIB_SRC/libraylib.a"
OUT="$ROOT/out"
NORM="$BUILD/fpc_normalize.py"
mkdir -p "$OUT"
# Work from out/ so fpc_normalize.py's errors.json (and any stray relative
# output) lands in the gitignored build dir, not the caller's CWD.
cd "$OUT"

[ -f "$RAYLIB_A" ] || { echo "ERROR: $RAYLIB_A missing (build raylib first)"; exit 1; }
[ -f "$OUT/libsiriel_bgi.dylib" ] || { echo "ERROR: $OUT/libsiriel_bgi.dylib missing (run build/make_stub.sh first)"; exit 1; }

command -v gcc >/dev/null 2>&1 && CC=gcc || CC=clang
command -v clang >/dev/null 2>&1 || { echo "ERROR: clang needed"; exit 1; }

# ---------------------------------------------------------------- ENGINE ---
echo "===== ENGINE: cdrv_engine (FPC) ====="

$CC -O2 -I"$C" -c "$C/fb_shm.c" -o "$OUT/fb_shm.o"
echo "fb_shm.o -> $(du -h "$OUT/fb_shm.o" | cut -f1)"
$CC -O2 -I"$C" -c "$C/crash_handler.c" -o "$OUT/crash_handler.o"
echo "crash_handler.o -> $(du -h "$OUT/crash_handler.o" | cut -f1)"
$CC -O2 -I"$C" -c "$C/host_engine.c" -o "$OUT/host_engine.o"
echo "host_engine.o -> $(du -h "$OUT/host_engine.o" | cut -f1)"

# FPC: build all objects, NO link (-b). -Sa puts every generated file
# (.o, .ppu) into OUT/ so nothing lands next to the sources.
echo "=== fpc build objects (-b, no link) ==="
fpc -O- -b -Mtp -dVID_HEADLESS -Sa \
    -o"$OUT/SI35.o" "$PASCAL/SI35.PAS" 2>&1 | python3 "$NORM"
[ -f "$OUT/SI35.o" ] || { echo "ERROR: SI35.o not produced"; exit 1; }

echo "=== fpc link -> out/cdrv_engine ==="
fpc -Mtp -B -O- -WM27.0 -dVID_HEADLESS \
    -k-undefined -kdynamic_lookup -k-lsiriel_bgi \
    -k-framework -kCocoa -k-framework -kFoundation \
    -k-framework -kIOKit -k-framework -kCoreVideo -k-framework -kCarbon \
    -Fl"$OUT" -o"$OUT/cdrv_engine" "$PASCAL/SI35.PAS" \
    -k"$OUT/host_engine.o" -k"$OUT/crash_handler.o" -k"$OUT/fb_shm.o" \
    2>&1 | python3 "$NORM"
echo "link_exit=${PIPESTATUS[0]}"
[ -x "$OUT/cdrv_engine" ] || { echo "ERROR: cdrv_engine not produced"; exit 1; }

# ---------------------------------------------------------------- WINDOW ---
echo "===== WINDOW: cdrv_window (C + Raylib, no FPC) ====="

$CC -O2 -I"$RAYLIB_SRC" -I"$RAYLIB_SRC/external/glfw/include" -I"$C" \
    -c "$C/host_window.c" -o "$OUT/host_window.o"
echo "host_window.o -> $(du -h "$OUT/host_window.o" | cut -f1)"

clang -O2 -I"$C" -c "$C/activate_macos.m" -o "$OUT/activate_macos.o"
echo "activate_macos.o -> $(du -h "$OUT/activate_macos.o" | cut -f1)"

# Pure-clang link: NO FPC objects. Validated raylib window pattern (same as
# examples/core/core_basic_window.c) so it cannot hit the FPC SIGILL.
echo "=== clang link -> out/cdrv_window ==="
clang -O2 -I"$RAYLIB_SRC" \
    "$OUT/host_window.o" "$OUT/activate_macos.o" "$OUT/fb_shm.o" \
    "$RAYLIB_A" \
    -framework OpenGL -framework Cocoa -framework IOKit \
    -framework CoreAudio -framework CoreVideo -framework QuartzCore \
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
file "$OUT/cdrv_engine" | cut -d, -f1-2
file "$OUT/cdrv_window" | cut -d, -f1-2
file "$OUT/cdrv_run" | cut -d, -f1-2
