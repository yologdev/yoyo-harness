#!/bin/bash
# research post-hook: push journal updates.

if [ -f .yoyo/journal.md ] && git diff --quiet -- .yoyo/journal.md 2>/dev/null; then
    echo "ERROR: Research completed without updating .yoyo/journal.md."
    echo "A research run must leave an advantage brief even when it files 0 issues."
    exit 1
fi

commit_and_push_journal "yoyo: weekly research scan ($DATE)"
