#!/bin/bash
# research.sh — Research agent: weekly competitive/field scan.
# Runs weekly (Sundays). Scans the field, files research-backed issues.
#
# Usage: ./research.sh [focus_topic]
# Env: REPO, GH_TOKEN, ANTHROPIC_API_KEY

source "$(dirname "$0")/setup-agent.sh"

TIMEOUT="${TIMEOUT:-1800}"  # 30 min

# ── Check if agent is enabled ──
ENABLED=$(parse_agent_enabled ".yoyo/yoyo.toml" "research" "false")
if [ "$ENABLED" = "false" ]; then
    echo "Research agent is disabled in .yoyo/yoyo.toml. Exiting."
    exit 0
fi

FOCUS="${1:-}"

# ── Build prompt ──
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<EOF
You are yoyo, running your weekly competitive R&D scan. Today is $DATE.

=== YOUR TASK: COMPETITIVE INTELLIGENCE ===

Read project docs (README.md, YOYO.md) to understand what this project is building.
Then scan the field for relevant intelligence.

Steps:

1. **Search for competitors and adjacent work:**
   - Similar products, alternative approaches
   - New tools, frameworks, or techniques relevant to this project
   - Community discussions, blog posts, launches
   ${FOCUS:+- PRIORITY FOCUS: $FOCUS}

2. **For each interesting find, note:**
   - What it is and who built it
   - What's clever (architecture, UX, failure modes)
   - What we should adopt, avoid, or learn from
   - How it would change our roadmap (if at all)

3. **Produce outputs:**
   a. File GitHub issues for concrete changes we should make:
      \`gh issue create --repo $REPO --title "Research: ..." --body "..." --label "agent-research" --label "triage"\`
      Max 3 issues. Each should be specific and actionable.
   b. Append a research entry to .yoyo/journal.md:
      \`\`\`
      ## $DATE (research scan)
      [Summary of what you found, what matters, what doesn't]
      \`\`\`

Rules:
- Focus on engineering intelligence: what works, what failed, what to adopt
- Be honest about what's better and what we do better
- This is bounded work — scan, distill, file issues, done
- Max 3 issues per session
- Do NOT implement anything
EOF

# ── Run research agent ──
echo "→ Running research agent..."
AGENT_LOG=$(mktemp)
RESEARCH_EXIT=0
run_agent "$TIMEOUT" "$PROMPT_FILE" "$AGENT_LOG" || RESEARCH_EXIT=$?
rm -f "$PROMPT_FILE"

if [ "$RESEARCH_EXIT" -eq 124 ]; then
    echo "  WARNING: Research agent timed out."
elif [ "$RESEARCH_EXIT" -ne 0 ]; then
    echo "  WARNING: Research agent exited with code $RESEARCH_EXIT."
fi
rm -f "$AGENT_LOG"

# ── Push journal updates ──
commit_and_push_journal "yoyo: weekly research scan ($DATE)"

echo "=== Research session complete ==="
