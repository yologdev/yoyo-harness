#!/bin/bash
# entrypoint.sh — Docker entrypoint for yoyo agents.
# Usage: entrypoint.sh <agent> [args...]
# Agents: pm, build, review, office-hour, research

set -euo pipefail

AGENT="${1:?Usage: entrypoint.sh <agent> [args...]}"
shift

exec /opt/yoyo/scripts/run-agent.sh "$AGENT" "$@"
