#!/bin/bash
# review post-hook: return to main branch.

git checkout main 2>/dev/null || true
