#!/bin/bash
# pm.sh — PM agent: assess codebase, file implementation issues.
# Runs daily. Reads project docs, identifies gaps, files structured issues.
#
# Usage: ./pm.sh [focus_topic]
# Env: REPO, GH_TOKEN, ANTHROPIC_API_KEY

source "$(dirname "$0")/setup-agent.sh"

TIMEOUT="${TIMEOUT:-900}"  # 15 min
FOCUS="${1:-}"

# ── Check if agent is enabled ──
ENABLED=$(parse_agent_enabled ".yoyo/yoyo.toml" "pm" "true")
if [ "$ENABLED" = "false" ]; then
    echo "PM agent is disabled in .yoyo/yoyo.toml. Exiting."
    exit 0
fi

# ── Fetch existing issues to avoid duplicates ──
echo "→ Fetching existing issues..."
EXISTING_ISSUES=""
if command -v gh &>/dev/null; then
    EXISTING_ISSUES=$(gh issue list --repo "$REPO" --state open --limit 30 \
        --json number,title,labels \
        --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"' 2>/dev/null || true)
    echo "  $(echo "$EXISTING_ISSUES" | grep -c '^#' 2>/dev/null || echo 0) open issues."
fi

# ── Check build state ──
echo "→ Checking build state..."
BUILD_STATUS="unknown"
if [ -f package.json ]; then
    set +o pipefail
    if eval "$BUILD_CMD" 2>&1 | tail -3; then
        BUILD_STATUS="passing"
    else
        BUILD_STATUS="failing"
    fi
    set -o pipefail
else
    BUILD_STATUS="no build system detected"
fi

# ── Build prompt (safe from shell injection) ──
PROMPT_FILE=$(mktemp)
{
    echo "You are yoyo, running your daily PM session. Today is $DATE $SESSION_TIME."
    echo ""
    echo "=== YOUR TASK: PROJECT MANAGEMENT ==="
    echo ""
    echo "You are the PM agent. Your job: assess the current state of the project, identify"
    echo "what to build next, and file implementation issues on GitHub."
    if [ -n "$FOCUS" ]; then
        echo ""
        echo "**Priority focus area:** $FOCUS"
    fi
    echo ""
    cat <<'STATIC'
Steps:

1. **Read project context:**
   - Look for project docs: README.md, YOYO.md, any vision/roadmap files
   - Understand the project goals, tech stack, current phase

2. **Read the codebase** — directory structure, key components.

3. **Read recent history:**
   - .yoyo/journal.md (last 3 entries) if it exists
   - git log --oneline -15 (recent commits)
   - .yoyo/learnings.md for project-specific insights (if exists)
STATIC
    echo ""
    echo "4. **Check build status:** Build is currently: $BUILD_STATUS"
    echo ""
    echo "5. **Review existing issues** (do NOT duplicate these):"
    echo "${EXISTING_ISSUES:-No existing issues.}"
    echo ""
    cat <<DYNAMIC
6. **Identify gaps** between the project roadmap and the current codebase.
   Focus on the CURRENT phase — don't skip ahead.

7. **File implementation issues** on GitHub. Max 3 issues per session.

For each issue, run:
\`\`\`
gh issue create --repo $REPO \\
  --title "<short descriptive title>" \\
  --label "agent-self" --label "triage" --label "<type>" \\
  --body "## Context
[Why this work matters — tie to roadmap phase and vision]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2

## Files Involved
- \\\`path/to/file1\\\` — what changes
- \\\`path/to/file2\\\` — what changes

## Acceptance Criteria
- [ ] Build passes (\`$BUILD_CMD && $LINT_CMD && $TEST_CMD\`)
- [ ] Criterion 1
- [ ] Criterion 2

## Size Estimate
[small/medium — each issue should be ≤20 min, ≤5 files]"
\`\`\`

Where <type> is one of: feature, bug, refactor, docs.

8. **Close stale issues** — if any open agent-self issues are now superseded
   by completed work, close them with a comment explaining why.

9. **Append a PM note** to .yoyo/journal.md:
   \`\`\`
   ## $DATE $SESSION_TIME (pm)
   [What you assessed, what issues you filed, what's next]
   \`\`\`

Rules:
- Each issue must be ATOMIC — completable in ≤20 minutes, touching ≤5 files
- Each issue must be independently verifiable (build passes after implementation)
- Prioritize: fix build failures > current roadmap phase > community issues > polish
- Do NOT implement anything. Filing issues is your only job.
- Do NOT duplicate existing open issues
- If build is failing, file a P0 bug issue for the fix
DYNAMIC
} > "$PROMPT_FILE"

# ── Run PM agent ──
echo "→ Running PM agent..."
AGENT_LOG=$(mktemp)
PM_EXIT=0
run_agent "$TIMEOUT" "$PROMPT_FILE" "$AGENT_LOG" || PM_EXIT=$?
rm -f "$PROMPT_FILE"

if [ "$PM_EXIT" -eq 124 ]; then
    echo "  WARNING: PM agent timed out."
elif [ "$PM_EXIT" -ne 0 ]; then
    echo "  WARNING: PM agent exited with code $PM_EXIT."
fi
rm -f "$AGENT_LOG"

# ── Push journal updates ──
commit_and_push_journal "yoyo: pm session ($DATE)"

echo "=== PM session complete ==="
