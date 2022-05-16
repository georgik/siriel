#!/usr/bin/env bash

which dosbox >/dev/null || {
    echo "dosbox command not found. Please install dosbox"
    exit 1
}

dosbox \
    -machine vesa_oldvbe \
    -fullscreen \
    -userconf \
    -conf siriel-3.5-dos/dosbox.conf \
    -c 'mount d siriel-3.5-dos' \
    -c 'd:' \
    -c 'cd d:\BIN' \
    -c 'SI35.EXE' \
    -c 'exit'

