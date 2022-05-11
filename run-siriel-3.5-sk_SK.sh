#!/usr/bin/env bash

dosbox \
    -machine vesa_oldvbe \
    -fullscreen \
    -userconf \
    -conf siriel-3.5-dos/dosbox.conf \
    -c 'mount d siriel-3.5-dos' \
    -c 'd:' \
    -c 'cd d:\BIN' \
    -c 'COPY L10NSK.CFG SIRIEL3.CFG' \
    -c 'SI35.EXE' \
    -c 'exit'

