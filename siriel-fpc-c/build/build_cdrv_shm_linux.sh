#!/usr/bin/env bash
# =====================================================================
# build_cdrv_shm_linux.sh - Linux build of the TWO-PROCESS windowed
#                            Siriel (port of the macOS build_cdrv_shm.sh).
#
# Same two-process architecture as the macOS build (see
# build/make_stub.sh and the wiki/modules/two-process-arch.md):
#
#   cdrv_engine  (FPC + C)   drives Siriel, writes FrameRGB -> shm
#   cdrv_window  (C + Raylib) reads FrameRGB <- shm, DISPLAYS it (no FPC)
#   cdrv_run     (C)         launches both and exits when either stops
#
# Differences from build_cdrv_shm.sh (macOS):
#   * No Cocoa/Foundation/IOKit/CoreVideo/Carbon frameworks.
#   * No -WM27.0 (macOS min-OS linker flag) and no -k-undefined
#     -kdynamic_lookup (those are Darwin dynamic-link flags).
#   * No activate_macos.m (Objective-C + AppKit) -- host_window.c guards
#     the siel_activate_app() call behind #if defined(__APPLE__).
#   * Raylib is linked against the Linux system libs: -lGL -lm -lpthread
#     -ldl -lX11 -lXcursor -lXrandr -lXi -lXinerama.
#   * The BGI stub is libsiriel_bgi.so (not .dylib), built by make_stub.sh.
#   * The engine records an RPATH of $ORIGIN so it finds libsiriel_bgi.so
#     next to the binary (relocatable, like the macOS @executable_path).
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
#     4. compile host_window.c -> out/
#     5. clang/gcc link -> out/cdrv_window                   -> out/
#   LAUNCHER (pure C; NO FPC, NO Raylib):
#     6. compile + link host_launch.c -> out/cdrv_run        -> out/
#
# The libsiriel_bgi stub (out/libsiriel_bgi.so) must exist first; build it
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

[ -f "$RAYLIB_A" ] || { echo "ERROR: $RAYLIB_A missing (build raylib first, see build/make_stub.sh notes)"; exit 1; }
[ -f "$OUT/libsiriel_bgi.so" ] || { echo "ERROR: $OUT/libsiriel_bgi.so missing (run build/make_stub.sh first)"; exit 1; }

# Linux has gcc and clang; either links fine. Prefer gcc (matches the stub).
command -v gcc >/dev/null 2>&1 && CC=gcc || CC=clang
command -v clang >/dev/null 2>&1 || true   # clang optional on Linux

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
#
# Linux link flags vs macOS:
#   * no -WM27.0, no -k-undefined / -kdynamic_lookup (Darwin-only)
#   * no -k-framework ... (Cocoa/Foundation/IOKit/CoreVideo/Carbon)
#   * -k-lsiriel_bgi + -Fl$OUT resolve the BGI stub next to the binary
#   * -Wl,-rpath,$ORIGIN so ld.so finds libsiriel_bgi.so at runtime
echo "=== fpc build objects (-b, no link) ==="
fpc -O- -b -Mtp -dVID_HEADLESS -Sa \
    -o"$OUT/SI35.o" "$PASCAL/SI35.PAS" 2>&1 | python3 "$NORM"
[ -f "$OUT/SI35.o" ] || { echo "ERROR: SI35.o not produced"; exit 1; }

echo "=== fpc link -> out/cdrv_engine ==="
fpc -Mtp -B -O- -dVID_HEADLESS \
    -k-lsiriel_bgi \
    -Fl"$OUT" -o"$OUT/cdrv_engine" "$PASCAL/SI35.PAS" \
    -k"$OUT/host_engine.o" -k"$OUT/crash_handler.o" -k"$OUT/fb_shm.o" \
    -k'-rpath $ORIGIN' \
    2>&1 | python3 "$NORM"
echo "link_exit=${PIPESTATUS[0]}"
[ -x "$OUT/cdrv_engine" ] || { echo "ERROR: cdrv_engine not produced"; exit 1; }

# ---------------------------------------------------------------- WINDOW ---
echo "===== WINDOW: cdrv_window (C + Raylib, no FPC) ====="

$CC -O2 -I"$RAYLIB_SRC" -I"$RAYLIB_SRC/external/glfw/include" -I"$C" \
    -c "$C/host_window.c" -o "$OUT/host_window.o"
echo "host_window.o -> $(du -h "$OUT/host_window.o" | cut -f1)"

# Pure-clang/gcc link: NO FPC objects. Validated raylib window pattern (same
# as examples/core/core_basic_window.c). On Linux Raylib links against the
# system GL/X11 stack (no -framework flags).
echo "=== clang/gcc link -> out/cdrv_window ==="
$CC -O2 -I"$RAYLIB_SRC" \
    "$OUT/host_window.o" "$OUT/fb_shm.o" \
    "$RAYLIB_A" \
    -lGL -lm -lpthread -ldl \
    -lX11 -lXcursor -lXrandr -lXi -lXinerama \
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
