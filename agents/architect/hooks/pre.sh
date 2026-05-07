#!/bin/bash
# architect pre-hook: find help-wanted issues, gather context on failures.
# Exports: ISSUE_NUMBER, ISSUE_TITLE, ISSUE_BODY, FAILURE_HISTORY, FAILED_DIFFS

# ── Find an issue that needs help ──
export ISSUE_NUMBER="${AGENT_ARGS:-}"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "→ Finding issues that need architect help..."
    ISSUE_NUMBER=$(gh issue list --repo "$REPO" --state open \
        --label "agent-help-wanted" --limit 1 \
        --json number --jq '.[0].number' 2>/dev/null || true)
fi

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    echo "No issues need architect help. Done."
    exit 0
fi

echo "→ Analyzing issue #$ISSUE_NUMBER..."

# ── Fetch issue details ──
export ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title' 2>/dev/null || echo "Issue $ISSUE_NUMBER")
export ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body' 2>/dev/null | head -c 5000 || echo "")

echo "  Issue: #$ISSUE_NUMBER — $ISSUE_TITLE"

# ── Gather failure history (comments from failed build attempts) ──
export FAILURE_HISTORY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments \
    --jq '[.comments[] | select(.body | test("failed|Re-queued|rejected|no changes")) | .body] | join("\n---\n")' 2>/dev/null | head -c 5000 || echo "")

FAILURE_COUNT=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments \
    --jq '[.comments[] | select(.body | test("Re-queued as ready"))] | length' 2>/dev/null || echo 0)
echo "  Failed attempts: $FAILURE_COUNT"

# ── Find failed PRs for this issue ──
export FAILED_DIFFS=""
FAILED_PRS=$(gh pr list --repo "$REPO" --state all --search "issue $ISSUE_NUMBER" --limit 3 \
    --json number,title,state --jq '.[] | select(.state != "MERGED") | .number' 2>/dev/null || true)

for PR in $FAILED_PRS; do
    DIFF=$(gh pr diff "$PR" --repo "$REPO" 2>/dev/null | head -c 3000 || true)
    if [ -n "$DIFF" ]; then
        FAILED_DIFFS="${FAILED_DIFFS}
--- PR #${PR} (failed/closed) ---
${DIFF}
---"
    fi
done

if [ -n "$FAILED_DIFFS" ]; then
    echo "  Found diffs from failed PRs."
fi
