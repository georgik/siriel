#!/usr/bin/env bash
# =====================================================================
# build_engine_c.sh - build out/cdrv_engine_cc : the PURE C-C engine.
#
# This is the "C-C" engine: it re-implements the Siriel 3.5 engine core
# (the engine_* procedures that used to live in src/pascal/SI35.PAS) in
# C (src/c/engine.c). There is NO Pascal / FPC in this build at all.
#
# The C engine exports the EXACT FPC-mangled entry points that
# host_engine.c already calls (P$SIRIEL3_$$_ENGINE_* + U_$VIDBASE_$$_FRAMERGB
# via __asm__ labels), so host_engine.c and the two-process shm/window
# layout are UNCHANGED. This binary is the C-C replacement for
# cdrv_engine (the FPC build).
#
# Build:
#   1) compile fb_shm.c, crash_handler.c, host_engine.c, engine.c -> out/
#   2) link -> out/cdrv_engine_cc
#
# No Pascal objects, no raylib, no BGI stub -- the engine owns no window.
# The window (cdrv_window) and launcher (cdrv_run) are identical to the
# FPC build, so this script builds ONLY the engine.
#
# Cross-platform: platform-detects Darwin vs the rest and drops -ldl on macOS
# (dlfcn lives in libSystem there, so -ldl fails the link). build_engine_c.sh
# therefore supersedes the older standalone build_engine_macos.sh.
# =====================================================================
set -uo pipefail
BUILD="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BUILD/.." && pwd)"
SRC="$ROOT/src"
C="$SRC/c"
OUT="$ROOT/out"
mkdir -p "$OUT"

# -ldl is a no-op on modern macOS: dlfcn/dlsym lives in libSystem and Xcode
# has removed libdl, so passing -ldl fails the link ("ld: library not found
# for -ldl"). Detect the platform and only pass -ldl where it is needed, so
# this single script builds on both Linux and macOS (this is the one thing
# build_engine_macos.sh did separately).
PLATFORM="$(uname -s 2>/dev/null || echo unknown)"
case "$PLATFORM" in
    Darwin*) echo "platform: macOS ($PLATFORM)"; LDLIBS="" ;;
    *)       echo "platform: $PLATFORM";         LDLIBS="-ldl" ;;
esac

command -v gcc >/dev/null 2>&1 && CC=gcc || CC=clang

echo "===== ENGINE (pure C-C): cdrv_engine_cc ====="
$CC -O2 -I"$C" -c "$C/fb_shm.c"      -o "$OUT/fb_shm.o"
$CC -O2 -I"$C" -c "$C/crash_handler.c" -o "$OUT/crash_handler.o"
$CC -O2 -I"$C" -c "$C/host_engine.c"  -o "$OUT/host_engine.o"
$CC -O2 -I"$C" -c "$C/datx.c"        -o "$OUT/datx.o"      # DAT reader
$CC -O2 -I"$C" -c "$C/load235.c"     -o "$OUT/load235.o"   # load data disk
$CC -O2 -I"$C" -c "$C/menu.c"         -o "$OUT/menu.o"     # intro menu
$CC -O2 -I"$C" -c "$C/game_menu.c"    -o "$OUT/game_menu.o" # menu-driven run-loop states
$CC -O2 -I"$C" -c "$C/flic.c"         -o "$OUT/flic.o"    # FLI/FLC decoder (intro animation)
$CC -O2 -I"$C" -c "$C/engine.c"       -o "$OUT/engine.o" # engine core

echo "=== exported engine_* symbols in engine.o ==="
nm "$OUT/engine.o" | grep -E 'T P\$SIRIEL3_\$\_|B U\$VIDBASE_\$\_' || true

echo "=== link -> out/cdrv_engine_cc ==="
$CC -O2 -I"$C" \
    "$OUT/fb_shm.o" "$OUT/crash_handler.o" "$OUT/host_engine.o" \
    "$OUT/datx.o" "$OUT/load235.o" "$OUT/menu.o" "$OUT/game_menu.o" "$OUT/flic.o" "$OUT/engine.o" \
    -o "$OUT/cdrv_engine_cc" $LDLIBS
echo "link_exit=$?"
[ -x "$OUT/cdrv_engine_cc" ] || { echo "ERROR: cdrv_engine_cc not produced"; exit 1; }

echo "built $OUT/cdrv_engine_cc ($(du -h "$OUT/cdrv_engine_cc" | cut -f1))"
echo "done."
