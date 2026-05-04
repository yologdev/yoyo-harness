#!/bin/bash
# pm pre-hook: fetch existing issues, check build state.
# Exports: EXISTING_ISSUES, BUILD_STATUS, FOCUS

export FOCUS="${AGENT_ARGS:-}"
export FOCUS_LINE=""
[ -n "$FOCUS" ] && FOCUS_LINE="**Priority focus area:** $FOCUS"

echo "→ Fetching existing issues..."
export EXISTING_ISSUES=""
if command -v gh &>/dev/null; then
    EXISTING_ISSUES=$(gh issue list --repo "$REPO" --state open --limit 30 \
        --json number,title,labels \
        --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"' 2>/dev/null || true)
    echo "  $(echo "$EXISTING_ISSUES" | grep -c '^#' 2>/dev/null || echo 0) open issues."
fi

echo "→ Checking build state..."
export BUILD_STATUS="unknown"
if [ -f package.json ]; then
    set +o pipefail
    if eval "$BUILD_CMD" 2>&1 | tail -3 >/dev/null; then
        BUILD_STATUS="passing"
    else
        BUILD_STATUS="failing"
    fi
    set -o pipefail
else
    BUILD_STATUS="no build system detected"
fi
echo "  Build: $BUILD_STATUS"
