#!/bin/bash
# entrypoint.sh — Docker entrypoint for yoyo agents.
# Usage: entrypoint.sh <agent> [args...]
# Agents: pm, build, review, office-hour, research

set -euo pipefail

AGENT="${1:?Usage: entrypoint.sh <agent> [args...]}"
shift

SCRIPT="/opt/yoyo/scripts/${AGENT}.sh"

if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: Unknown agent '$AGENT'. Available: pm, build, review, office-hour, research"
    exit 1
fi

exec "$SCRIPT" "$@"
