#!/bin/bash
# lib.sh — Shared library for yoyo agent scripts.
# Provides config parsing, helpers, and common setup.
#
# Provides:
#   parse_toml_value()    — extract a value from yoyo.toml
#   parse_toml_array()    — extract an array from yoyo.toml
#   read_config()         — load all config into env vars

# ── TOML parser (minimal, no external deps) ──

# Parse a simple key = "value" or key = true/false from a TOML file.
parse_toml_value() {
    local file="$1" key="$2" default="${3:-}"
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    local val
    val=$(python3 -c "
import sys, re
content = open(sys.argv[1]).read()
key = re.escape(sys.argv[2])
default = sys.argv[3]
m = re.search(rf'^{key}\s*=\s*[\"'\''](.*?)[\"'\'']|^{key}\s*=\s*(\S+)', content, re.MULTILINE)
if m:
    print(m.group(1) or m.group(2))
else:
    print(default)
" "$file" "$key" "$default" 2>/dev/null || echo "$default")
    echo "$val"
}

# Parse an array like paths = [".github/", ".yoyo/yoyo.toml"]
parse_toml_array() {
    local file="$1" key="$2"
    if [ ! -f "$file" ]; then
        echo ""
        return
    fi
    python3 -c "
import sys, re, ast
content = open(sys.argv[1]).read()
key = re.escape(sys.argv[2])
m = re.search(rf'^{key}\s*=\s*(\[.*?\])', content, re.MULTILINE | re.DOTALL)
if m:
    items = ast.literal_eval(m.group(1))
    print(' '.join(str(i) for i in items))
" "$file" "$key" 2>/dev/null || echo ""
}

# Parse agent enabled status: [agents.NAME] enabled = true/false
parse_agent_enabled() {
    local file="$1" agent="$2" default="${3:-true}"
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    python3 -c "
import sys, re
content = open(sys.argv[1]).read()
agent = sys.argv[2]
default = sys.argv[3]
# Find [agents.NAME] section and its enabled key
pattern = rf'\[agents\.{agent}\].*?enabled\s*=\s*(\w+)'
m = re.search(pattern, content, re.DOTALL)
if m:
    print(m.group(1))
else:
    print(default)
" "$file" "$agent" "$default" 2>/dev/null || echo "$default"
}

# ── Read project config ──
read_config() {
    local config_file=".yoyo/yoyo.toml"

    # Commands
    BUILD_CMD=$(parse_toml_value "$config_file" "build" "pnpm build")
    TEST_CMD=$(parse_toml_value "$config_file" "test" "pnpm test")
    LINT_CMD=$(parse_toml_value "$config_file" "lint" "pnpm lint")

    # Protected paths
    PROTECTED_PATHS=$(parse_toml_array "$config_file" "paths")
    [ -z "$PROTECTED_PATHS" ] && PROTECTED_PATHS=".github/ .yoyo/yoyo.toml"

    export BUILD_CMD TEST_CMD LINT_CMD PROTECTED_PATHS
}
