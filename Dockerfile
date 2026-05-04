FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9 --activate

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install yoyo binary (latest release)
RUN REPO="yologdev/yoyo-evolve" \
    && LATEST=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name') \
    && curl -fsSL "https://github.com/$REPO/releases/download/$LATEST/yoyo-$LATEST-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/yoyo.tar.gz \
    && tar xzf /tmp/yoyo.tar.gz -C /tmp \
    && cp /tmp/yoyo /usr/local/bin/yoyo || cp /tmp/yoyo-*/yoyo /usr/local/bin/yoyo \
    && chmod +x /usr/local/bin/yoyo \
    && rm -rf /tmp/yoyo*

# Copy harness scripts, agents, skills, and identity
COPY scripts/ /opt/yoyo/scripts/
COPY agents/ /opt/yoyo/agents/
COPY skills/ /opt/yoyo/skills/
COPY identity/ /opt/yoyo/identity/

RUN chmod +x /opt/yoyo/scripts/*.sh \
    && find /opt/yoyo/agents -name "*.sh" -exec chmod +x {} \;

COPY entrypoint.sh /opt/yoyo/entrypoint.sh
RUN chmod +x /opt/yoyo/entrypoint.sh

ENTRYPOINT ["/opt/yoyo/entrypoint.sh"]
