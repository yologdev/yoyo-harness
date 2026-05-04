#!/bin/bash
# setup-agent.sh — Shared setup for all yoyo agent scripts.
# Source this at the top of each agent script:
#   source "$(dirname "$0")/setup-agent.sh"
#
# Provides:
#   $REPO, $MODEL, $DATE, $SESSION_TIME, $BOT_LOGIN, $BOT_SLUG
#   $SYSTEM_FILE, $SHARED_SKILLS, $TIMEOUT_CMD
#   $BUILD_CMD, $TEST_CMD, $LINT_CMD, $PROTECTED_PATHS
#   run_agent()              — run yoyo with identity + skills
#   check_protected_files()  — detect modifications to protected files
#   sanitize_issue_content() — strip HTML comments + boundary markers
#   commit_and_push_journal() — commit and push journal changes

set -euo pipefail

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ── Auto-detect repo from git remote ──
if [ -z "${REPO:-}" ]; then
    REPO=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]||;s|\.git$||' || echo "")
    if [ -z "$REPO" ]; then
        echo "ERROR: Could not detect REPO. Set REPO env var."
        exit 1
    fi
fi

MODEL="${MODEL:-claude-opus-4-6}"
BOT_LOGIN="${BOT_LOGIN:-yoyo[bot]}"
BOT_SLUG="${BOT_SLUG:-yoyo}"
DATE=$(date -u +%Y-%m-%d)
SESSION_TIME=$(date -u +%H:%M)

# Security nonce for content boundary markers
BOUNDARY_NONCE=$(python3 -c "import os; print(os.urandom(16).hex())") || {
    echo "ERROR: python3 required for security nonce generation."
    exit 1
}
BOUNDARY_BEGIN="[BOUNDARY-${BOUNDARY_NONCE}-BEGIN]"
BOUNDARY_END="[BOUNDARY-${BOUNDARY_NONCE}-END]"

# ── Read project config ──
read_config

# ── Preflight: check yoyo binary ──
if ! command -v yoyo &>/dev/null; then
    echo "ERROR: yoyo binary not found on PATH."
    exit 1
fi

# ── Load identity ──
# Identity is baked into the Docker image at /opt/yoyo/identity/
# Also check for project-local identity override
SYSTEM_FILE=""
if [ -f ".yoyo/identity/SOUL.md" ]; then
    SYSTEM_FILE=".yoyo/identity/SOUL.md"
elif [ -f "/opt/yoyo/identity/SOUL.md" ]; then
    SYSTEM_FILE="/opt/yoyo/identity/SOUL.md"
fi

# If no pre-built identity, try downloading from yoyo-evolve
if [ -z "$SYSTEM_FILE" ]; then
    echo "→ Downloading yoyo identity from yoyo-evolve..."
    YOYO_EVOLVE_DIR="/tmp/yoyo-evolve"
    mkdir -p "$YOYO_EVOLVE_DIR" ".yoyo/identity"

    if gh api "repos/yologdev/yoyo-evolve/tarball/main" > /tmp/yoyo-evolve.tar.gz 2>/dev/null; then
        tar xzf /tmp/yoyo-evolve.tar.gz -C "$YOYO_EVOLVE_DIR" --strip-components=1
        rm -f /tmp/yoyo-evolve.tar.gz

        if [ -f "$YOYO_EVOLVE_DIR/scripts/yoyo_context.sh" ]; then
            YOYO_REPO="$YOYO_EVOLVE_DIR" source "$YOYO_EVOLVE_DIR/scripts/yoyo_context.sh"
            echo "$YOYO_CONTEXT" > ".yoyo/identity/SOUL.md"
            SYSTEM_FILE=".yoyo/identity/SOUL.md"
            echo "  Identity loaded ($(wc -l < "$SYSTEM_FILE" | tr -d ' ') lines)"
        fi
        rm -rf "$YOYO_EVOLVE_DIR"
    else
        echo "  WARNING: Failed to download identity. Running without system prompt."
        rm -f /tmp/yoyo-evolve.tar.gz
    fi
fi

# ── Legacy: shared skills from Docker image (unused with run-agent.sh) ──
SHARED_SKILLS=""
if [ -d "/opt/yoyo/skills" ]; then
    SHARED_SKILLS="/opt/yoyo/skills"
fi

# ── Timeout command (cross-platform) ──
TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null; then
    if command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
        echo "WARNING: No timeout command found. Agent calls will have no time limit."
    fi
fi

# ── Helper: run agent ──
run_agent() {
    local timeout_val="$1"
    local prompt_file="$2"
    local log_file="$3"
    local extra_flags="${4:-}"

    local exit_code=0
    # shellcheck disable=SC2086
    ${TIMEOUT_CMD:+$TIMEOUT_CMD "$timeout_val"} yoyo \
        --model "$MODEL" \
        ${SYSTEM_FILE:+--system-file "$SYSTEM_FILE"} \
        --skills .yoyo/skills \
        ${SHARED_SKILLS:+--skills "$SHARED_SKILLS"} \
        $extra_flags \
        < "$prompt_file" 2>&1 | tee "$log_file" || exit_code=$?

    return "$exit_code"
}

# ── Helper: check protected files ──
check_protected_files() {
    local base_sha="$1"
    local protected=""
    # shellcheck disable=SC2086
    protected=$(git diff --name-only "$base_sha"..HEAD -- $PROTECTED_PATHS 2>/dev/null || true)
    local staged
    # shellcheck disable=SC2086
    staged=$(git diff --cached --name-only -- $PROTECTED_PATHS 2>/dev/null || true)
    [ -n "$staged" ] && protected="${protected}${protected:+
}${staged}"
    local unstaged
    # shellcheck disable=SC2086
    unstaged=$(git diff --name-only -- $PROTECTED_PATHS 2>/dev/null || true)
    [ -n "$unstaged" ] && protected="${protected}${protected:+
}${unstaged}"
    echo "$protected"
}

# ── Helper: sanitize issue content ──
sanitize_issue_content() {
    python3 -c "
import sys, re
bb, be = sys.argv[1], sys.argv[2]
text = sys.stdin.read()
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
text = text.replace(bb, '[marker-stripped]').replace(be, '[marker-stripped]')
print(text)
" "$BOUNDARY_BEGIN" "$BOUNDARY_END"
}

# ── Helper: commit and push journal changes ──
commit_and_push_journal() {
    local message="$1"
    git add .yoyo/journal.md 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "$message"
        git pull --rebase origin main 2>/dev/null || true
        git push || echo "WARNING: Failed to push journal update"
    fi
}

echo "=== Agent Session ($DATE $SESSION_TIME) ==="
echo "Repo: $REPO | Model: $MODEL"
