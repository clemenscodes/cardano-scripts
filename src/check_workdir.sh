#!/bin/sh

PROJECT_DIR="$(locate cardano-scripts | head -n1)"
SHELLS_DIR="$PROJECT_DIR/src/"

# shellcheck disable=SC1091
. "$SHELLS_DIR/color.sh"

white "Hello there"