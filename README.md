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

## License

MIT
