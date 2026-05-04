#!/bin/bash
# build pre-hook: claim issue, create branch, fetch details.
# Exports: ISSUE_NUMBER, ISSUE_TITLE, ISSUE_LABELS, SAFE_BODY, BRANCH, SESSION_START_SHA

MAX_FIX_ATTEMPTS=5
export MAX_FIX_ATTEMPTS

# ── Claim an issue ──
export ISSUE_NUMBER="${AGENT_ARGS:-}"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "→ Finding highest-priority ready issue..."
    for PRIORITY in p0-critical p1-high p2-medium p3-low; do
        ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
            --label "ready" --label "$PRIORITY" --limit 1 \
            --json number --jq '.[0].number' 2>/dev/null || true)
        [ -n "$ISSUE_NUMBER" ] && [ "$ISSUE_NUMBER" != "null" ] && break
        ISSUE_NUMBER=""
    done
    # Fallback: any ready issue
    if [ -z "$ISSUE_NUMBER" ]; then
        ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
            --label "ready" --limit 1 \
            --json number --jq '.[0].number' 2>/dev/null || true)
    fi
fi

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    echo "No ready issues to work on. Done."
    exit 0
fi

echo "→ Claiming issue #$ISSUE_NUMBER..."

# Atomic claim: swap ready → in-progress
gh issue edit "$ISSUE_NUMBER" --repo "$REPO" \
    --remove-label "ready" --add-label "in-progress" 2>/dev/null || true

# Fetch issue details
export ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title' 2>/dev/null || echo "Issue $ISSUE_NUMBER")
ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body' 2>/dev/null | head -c 3000 || echo "")
export ISSUE_LABELS=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels --jq '.labels | map(.name) | join(", ")' 2>/dev/null || echo "")

echo "  Issue: #$ISSUE_NUMBER — $ISSUE_TITLE"
echo "  Labels: $ISSUE_LABELS"

# ── Create branch ──
export BRANCH="yoyo/issue-${ISSUE_NUMBER}"
git checkout -b "$BRANCH" origin/main 2>/dev/null || git checkout -b "$BRANCH"
echo "  Branch: $BRANCH"

export SESSION_START_SHA=$(git rev-parse HEAD)

# ── Sanitize issue body ──
export SAFE_BODY=$(echo "$ISSUE_BODY" | sanitize_issue_content)
