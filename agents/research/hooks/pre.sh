#!/bin/bash
# research pre-hook: set focus line from args.
# Exports: FOCUS_LINE

export FOCUS_LINE=""
[ -n "${AGENT_ARGS:-}" ] && FOCUS_LINE="**Priority focus:** $AGENT_ARGS"
