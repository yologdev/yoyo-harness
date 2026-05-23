#!/bin/bash
# research post-hook: push journal updates.

JOURNAL_DIRTY=false
JOURNAL_COMMITTED=false

if [ -f .yoyo/journal.md ] && ! git diff --quiet -- .yoyo/journal.md 2>/dev/null; then
    JOURNAL_DIRTY=true
fi

if [ -n "${RESEARCH_START_SHA:-}" ] && ! git diff --quiet "$RESEARCH_START_SHA"..HEAD -- .yoyo/journal.md 2>/dev/null; then
    JOURNAL_COMMITTED=true
fi

if [ "$JOURNAL_DIRTY" = "false" ] && [ "$JOURNAL_COMMITTED" = "false" ]; then
    echo "ERROR: Research completed without updating .yoyo/journal.md."
    echo "A research run must leave an advantage brief even when it files 0 issues."
    exit 1
fi

if [ "$JOURNAL_DIRTY" = "true" ]; then
    commit_and_push_journal "yoyo: weekly research scan ($DATE)"
fi
