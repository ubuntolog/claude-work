# Claude Code in a Container

Run [Claude Code](https://claude.com/claude-code) inside a container so it only sees the project folder you choose. Your login, settings and history are kept on the host between runs.

![Base image](https://img.shields.io/badge/base-debian%3Atrixie--slim-A81D33?logo=debian)
![Runtime](https://img.shields.io/badge/runtime-podman%20%7C%20docker-892CA0?logo=podman)
![Host](https://img.shields.io/badge/tested%20on-Fedora-51A2DA?logo=fedora)

---

## Table of contents

- [Why](#why)
- [What's in the image](#whats-in-the-image)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [How the run command works](#how-the-run-command-works)
- [Everyday usage](#everyday-usage)
- [Updating Claude Code](#updating-claude-code)
- [Using Docker instead of Podman](#using-docker-instead-of-podman)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [Repository layout](#repository-layout)

---

## Why

Claude Code can read files, edit code and run shell commands. Running it in a container gives you:

- **Isolation:** Claude Code only sees the one project folder you mount at `/workspace`, not your whole home directory.
- **Persistence:** your login, `settings.json`, conversation history and git config live in a folder on the host, so you sign in only once.
- **Reproducibility:** the same small Debian toolset on every machine, no matter what is installed on the host.
- **Correct file ownership:** files Claude Code creates belong to your host user, not to `root`.

## What's in the image

| Component | Purpose |
|-----------|---------|
| `debian:trixie-slim` | Minimal base image |
| `git`, `openssh-client` | Version control and pushing over SSH |
| `curl`, `ca-certificates` | HTTPS downloads |
| `ripgrep` | Fast code search, used by Claude Code |
| `bash`, `less`, `procps` | Shell basics |
| `claude` | Claude Code, installed with the official native installer and copied to `/usr/local/bin` |

The automatic updater is turned off (`DISABLE_AUTOUPDATER=1`). To update, rebuild the image; see [Updating Claude Code](#updating-claude-code).

## Requirements

- [Podman](https://podman.io/) 4.x or newer (rootless works). Docker also works with small changes.
- A Claude account (Pro, Max, Team or Enterprise) or an Anthropic API key.

## Quick start

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/claude-work.git
cd claude-work
```

### 2. Build the image

```bash
podman build -t safer-claudecode .
```

### 3. Create the host folders

Bind-mount sources must exist before the container starts:

```bash
mkdir -p "$HOME/github/claude-code/project"   # the code Claude Code works on
mkdir -p "$HOME/.claude-container"            # login, settings and history
```

### 4. Run it

```bash
podman run -it --rm \
  --name safer-claudecode \
  --userns=keep-id \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp/claude-home \
  -e CLAUDE_CONFIG_DIR=/tmp/claude-home \
  --mount type=bind,source="$HOME/github/claude-code/project",target=/workspace \
  --mount type=bind,source="$HOME/.claude-container",target=/tmp/claude-home \
  -w /workspace \
  safer-claudecode
```

The first time, Claude Code asks you to sign in. Open the link it prints in a browser on the host and complete the login. The credentials are saved to `~/.claude-container` on the host, so later runs start straight away.

## How the run command works

| Option | What it does |
|--------|--------------|
| `-it` | Interactive terminal, needed for the Claude Code interface |
| `--rm` | Deletes the container when you exit (your data is on the host, so nothing is lost) |
| `--name safer-claudecode` | Gives the container a fixed name so you can find it with `podman ps` |
| `--userns=keep-id` | Rootless Podman: maps your host user ID into the container |
| `--user "$(id -u):$(id -g)"` | Runs as your user, so new files are owned by you on the host |
| `-e HOME=/tmp/claude-home` | Points the home directory at the persistent mount |
| `-e CLAUDE_CONFIG_DIR=/tmp/claude-home` | Tells Claude Code where to store its configuration |
| `--mount ...target=/workspace` | The project folder Claude Code can see and edit |
| `--mount ...target=/tmp/claude-home` | Persistent folder for login, settings and history |
| `-w /workspace` | Starts Claude Code in the project folder |

> **Note:** the `Dockerfile` sets a default of `HOME=/workspace/.claude-home`. That default is used only if you run the image without the `-e HOME=...` option. In that case the configuration is stored inside the project folder, which is why `.claude-home/` is listed in `.gitignore`.

## Everyday usage

### Shell alias

Add this to `~/.bashrc` or `~/.zshrc` to start Claude Code with one word:

```bash
alias claude-box='podman run -it --rm \
  --userns=keep-id --user "$(id -u):$(id -g)" \
  -e HOME=/tmp/claude-home -e CLAUDE_CONFIG_DIR=/tmp/claude-home \
  --mount type=bind,source="$PWD",target=/workspace \
  --mount type=bind,source="$HOME/.claude-container",target=/tmp/claude-home \
  -w /workspace safer-claudecode'
```

The alias mounts the **current directory** (`$PWD`), so you can `cd` into any project and run `claude-box`. It leaves out `--name` so that several projects can run at the same time.

### Passing arguments to Claude Code

Anything after the image name is passed to `claude`:

```bash
claude-box --continue                    # resume the most recent conversation
claude-box -p "explain this repository"  # one-off prompt, non-interactive
claude-box --version
```

### Opening a shell in the container

```bash
podman run -it --rm --entrypoint bash \
  --userns=keep-id --user "$(id -u):$(id -g)" \
  --mount type=bind,source="$PWD",target=/workspace \
  -w /workspace safer-claudecode
```

### Using an API key instead of logging in

Export the key on the host, then add `-e ANTHROPIC_API_KEY` (with no value) to the `podman run` command, **before** the image name. Podman copies the value from your host environment, so the key never appears in your shell history or alias:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
podman run -it --rm -e ANTHROPIC_API_KEY ... safer-claudecode
```

## Updating Claude Code

Because the automatic updater is off, update by rebuilding without the cache:

```bash
podman build --no-cache -t safer-claudecode .
```

Your login and settings in `~/.claude-container` are not affected.

## Using Docker instead of Podman

`--userns=keep-id` is Podman-specific. With Docker, leave it out:

```bash
docker build -t safer-claudecode .
docker run -it --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp/claude-home \
  -e CLAUDE_CONFIG_DIR=/tmp/claude-home \
  --mount type=bind,source="$HOME/github/claude-code/project",target=/workspace \
  --mount type=bind,source="$HOME/.claude-container",target=/tmp/claude-home \
  -w /workspace \
  safer-claudecode
```

## Troubleshooting

<details>
<summary><b>"Permission denied" on mounted folders (Fedora / SELinux)</b></summary>

On SELinux systems such as Fedora, the container may be blocked from reading the bind mounts. Add `relabel=private` to each mount:

```bash
--mount type=bind,source="$PWD",target=/workspace,relabel=private
```

Only relabel folders that belong to you. Never relabel system folders such as `/home` or `/usr`.
</details>

<details>
<summary><b>"no such file or directory" when starting</b></summary>

The source folder of a `--mount` does not exist. Create it with `mkdir -p` (see [step 3](#3-create-the-host-folders)).
</details>

<details>
<summary><b>Claude Code asks me to log in every time</b></summary>

Check that `~/.claude-container` is mounted and that `HOME` and `CLAUDE_CONFIG_DIR` both point to `/tmp/claude-home`. After the first login, the folder should contain a credentials file.
</details>

<details>
<summary><b>Files created in the project are owned by another user</b></summary>

Make sure both `--userns=keep-id` (Podman) and `--user "$(id -u):$(id -g)"` are in the run command.
</details>

<details>
<summary><b>git asks "Please tell me who you are"</b></summary>

The container has its own git config, stored in the persistent home folder. Set it once:

```bash
podman run -it --rm --entrypoint git \
  --userns=keep-id --user "$(id -u):$(id -g)" \
  -e HOME=/tmp/claude-home \
  --mount type=bind,source="$HOME/.claude-container",target=/tmp/claude-home \
  safer-claudecode config --global user.name "Your Name"
```

Repeat with `user.email`.
</details>

## Security notes

- The container limits what Claude Code can **see** on disk, but it still has full **network** access.
- Anything in the mounted project folder can be read and changed. Commit or back up your work before giving Claude Code broad permissions.
- `~/.claude-container` holds your login credentials. Do not commit it, share it or mount it into untrusted containers.
- SSH keys are not in the image. If you want to push from inside the container, mount only the key you need, read-only.

## Repository layout

```
.
├── Dockerfile     # Image definition: Debian + tools + Claude Code
├── ReadMe.md      # This file
├── .gitignore     # Keeps .claude-home/ and projects/ out of git
└── projects/      # Other git repositories (ignored by this repository)
```

> **Note:** `projects/` is meant for other, independent git repositories: clone or create them there. Each keeps its own history and remote, and because the whole folder is listed in `.gitignore`, nothing inside it is ever committed to this repository.
