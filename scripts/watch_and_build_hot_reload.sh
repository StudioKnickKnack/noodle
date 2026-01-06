#!/usr/bin/env bash

rm app_*.dylib
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$SCRIPTS/.." && pwd)"
find $PROJECT -name "*.odin"
find $PROJECT -name "*.odin" | entr $SCRIPTS/build_hot_reload.sh
