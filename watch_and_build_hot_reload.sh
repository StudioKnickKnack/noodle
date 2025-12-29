#!/usr/bin/env bash

rm app_*.dylib
find . -name '*.odin' | entr ./build_hot_reload.sh
