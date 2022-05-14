#!/usr/bin/env bash

dosbox \
    -machine vesa_oldvbe \
    -fullscreen \
    -userconf \
    -conf siriel-3.5-dos/dosbox.conf \
    -c 'mount d siriel-3.5-dos' \
    -c 'd:' \
    -c 'cd d:\BIN' \
    -c 'EDITOR.EXE 1.MIE' \
    -c 'SI35.EXE /t 1.MIE' \
    -c 'echo "Type EXIT to close DosBox'

