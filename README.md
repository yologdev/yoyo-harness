# yoyo-harness

Open-source agent harness for [yoyo](https://github.com/yologdev) coding agents.

Contains the scripts, identity, and Dockerfile that power yoyo's 5-agent pipeline:

| Agent | Purpose | Default |
|-------|---------|---------|
| **PM** | Suggest implementation issues | Enabled |
| **Build** | Implement issues on branches | Enabled |
| **Review** | Review PRs, fix loop, merge | Enabled |
| **Office Hour** | Auto-triage issues | Opt-in |
| **Research** | Weekly competitive scan | Opt-in |

## Usage

This image is used by [`yologdev/yoyo-action`](https://github.com/yologdev/yoyo-action). You don't need to interact with it directly.

```bash
# Pull the image
docker pull ghcr.io/yologdev/yoyo-harness:latest

# Run an agent directly (for debugging)
docker run --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e GH_TOKEN="$GH_TOKEN" \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ghcr.io/yologdev/yoyo-harness:latest pm
```

## Configuration

Projects configure yoyo via `.yoyo/yoyo.toml`:

```toml
[commands]
build = "pnpm build"
test = "pnpm test"
lint = "pnpm lint"

[protected]
paths = [".github/", ".yoyo/yoyo.toml"]

[agents.pm]
enabled = true

[agents.build]
enabled = true

[agents.review]
enabled = true

[agents.office-hour]
enabled = false

[agents.research]
enabled = false

# Optional: enable bounded Office Hour-led decision discussions.
# Defaults are false and 3, so the basic PM + Build setup is unchanged.
[collaboration]
decision_discussions = false
max_rounds = 3
```

When decision discussions are enabled, Office Hour may ask enabled specialist
agents for judgment in issue comments using `Ask-PM:`, `Ask-Architect:`, and
`Ask-Research:` markers. Those agents reply with `Decision-Input:` comments, and
Office Hour makes the final readiness verdict after at most `max_rounds`.

## PR Repair Loop

The Build and Review agents form a generic repair loop for yoyo-authored PRs:

1. Build claims a `ready` issue, opens or updates `yoyo/issue-N`, and creates a
   PR with `Closes #N`.
2. Review checks the PR against the linked issue, build result, and protected
   paths.
3. If Review requests changes, it re-queues the linked issue and comments with a
   machine-readable retry block:

```md
<!-- yoyo-review-retry
pr: 123
issue: 45
verdict: changes_requested
-->
Review requested changes on PR #123. Re-queued for Build retry.

Required changes:
- Update src/example.ts to preserve the existing error format.
- Update tests to assert the existing format.
```

4. The next Build run injects the latest `yoyo-review-retry` comment into its
   prompt and treats it as required correction context.
5. Build pushes back to the existing `yoyo/issue-N` branch when a PR already
   exists, causing Review to run again on the updated PR.
6. If Review passes and checks are mergeable, Review merges the PR.

This loop is intentionally issue/PR based rather than project-specific. Any
repository using yoyo-harness can reuse it as long as Build PRs include
`Closes #N` and Review can comment on the linked issue.

## License

MIT
