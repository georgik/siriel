#!/usr/bin/env bash
# =====================================================================
# build_raylib.sh - build the Raylib static library that the C window
#                   (build_window_c.sh) links against.
#
# Raylib is a git submodule (third-party/raylib). GLFW is bundled and
# merged into libraylib.a as an object library, so building just the
# `raylib` target is enough. The resulting archive is copied next to the
# Raylib source where build_window_c.sh expects it:
#
#     third-party/raylib/src/libraylib.a
#
# This is step 1 of wiki/build-linux.md. It is platform-specific: the
# archive produced here is a *Linux* build. (The Windows port cross-builds
# its own raylib -- see wiki/build-windows.md.)
# =====================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAYLIB="$ROOT/third-party/raylib"
RAYLIB_SRC="$RAYLIB/src"
RAYLIB_A="$RAYLIB_SRC/libraylib.a"
BUILD_DIR="$RAYLIB/_cmbuild"

command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found"; exit 1; }
[ -f "$RAYLIB/src/raylib.h" ] || { echo "ERROR: raylib submodule missing ($RAYLIB_SRC/raylib.h)"; exit 1; }

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== cmake configure ($BUILD_DIR) ==="
cmake "$RAYLIB" -DCMAKE_BUILD_TYPE=Release

echo "=== cmake build --target raylib ==="
cmake --build "$BUILD_DIR" --target raylib -j"$(nproc 2>/dev/null || echo 4)"

echo "=== install libraylib.a -> $RAYLIB_A ==="
cp "$BUILD_DIR/raylib/libraylib.a" "$RAYLIB_A"
echo "built $RAYLIB_A ($(du -h "$RAYLIB_A" | cut -f1))"
