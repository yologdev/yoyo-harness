#!/bin/bash
# research pre-hook: set focus line from args.
# Exports: FOCUS_LINE

export FOCUS_LINE=""
if [ -n "${AGENT_ARGS:-}" ]; then
    FOCUS_LINE="**Priority focus:** $AGENT_ARGS"
fi
