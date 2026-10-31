#!/bin/zsh
set -eu
GAME_DIR="${0:A:h}"
exec python3 "$GAME_DIR/tools/dev.py" run
