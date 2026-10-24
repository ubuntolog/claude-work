FROM debian:trixie-slim

# Basic tools Claude Code likes to have around
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git ripgrep less procps bash openssh-client \
 && rm -rf /var/lib/apt/lists/*

# Install Claude Code with the official native installer, then copy the real
# binary to a system path so it works for whatever user/HOME runs the container.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && cp -L /root/.local/bin/claude /usr/local/bin/claude \
 && chmod 755 /usr/local/bin/claude \
 && rm -rf /root/.local /root/.claude /root/.claude.json

# HOME lives inside the mounted folder, so login (~/.claude/.credentials.json),
# settings (~/.claude/settings.json), ~/.claude.json, history, git config etc.
# all persist on the host between runs.
ENV HOME=/workspace/.claude-home \
    DISABLE_AUTOUPDATER=1 \
    USE_BUILTIN_RIPGREP=0

WORKDIR /workspace

# Create HOME on first start (the volume is empty then), then launch Claude.
# Any extra args after the image name are passed through to `claude`.
ENTRYPOINT ["/bin/bash", "-c", "mkdir -p \"$HOME\" && exec claude \"$@\"", "claude"]
