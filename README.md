# ComAI

`comai` is a local Linux command assistant written in Bash. It talks to an OpenAI-compatible local AI server, can read files you pass to it, and answers some simple filesystem/log questions directly without asking the model.

## Features

- Ask Linux and command-line questions from the terminal.
- Include file content with `-f` / `--file`.
- Automatically uses an existing file mentioned in the current directory.
- Direct checks for common local facts, such as newest/largest file, number lookup in a file, and log error scans.
- Per-request model selection with `--model=...`.
- User install into `~/localcomai`.
- Small wrapper commands in `~/.local/bin`, not symlinks.

## Requirements

Required commands:

```text
bash curl jq find sort head sed awk grep wc tr readlink systemctl
```

Optional commands:

```text
file numfmt
```

The installer checks for required commands and can install missing packages on systems with `apt`, `dnf`, or `pacman`.

ComAI expects a local OpenAI-compatible AI service under `~/ai`. The included user service starts:

```bash
~/ai/start.sh
```

and stops:

```bash
~/ai/stop.sh
```

## Install

Clone the repo, then run:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

The installer copies ComAI into `~/localcomai`, creates wrapper commands, reloads systemd, and enables/starts `comai-localai.service`.

Default install location:

```bash
~/localcomai
```

Command wrappers:

```bash
~/.local/bin/comai
~/.local/bin/comi
```

If `comai` is not found after installing:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

The installer only prints this PATH hint when `~/.local/bin` is missing from your current `PATH`.

To install somewhere else:

```bash
COMAI_INSTALL_DIR="$HOME/tools/localcomai" ./scripts/install.sh
```

## Uninstall

From the source repo:

```bash
./scripts/uninstall.sh
```

Or from the installed copy:

```bash
~/localcomai/scripts/uninstall.sh
```

Uninstall removes ComAI user files and leaves `~/ai` untouched.

## Usage

Ask a normal question:

```bash
comai what is /etc in linux?
```

Use a specific model:

```bash
comai --model=Qwen2.5-7B-Instruct-Q4_K_M summarize this file -f README.md
```

Read and summarize a file:

```bash
comai summarize this file -f README.md
```

Ask about a file by name from the same directory:

```bash
comai can you see number 200 in this file llama-swap.log
```

Check a log for common error lines:

```bash
comai do you see any error? -f llama-swap.log
comai is this log ok llama-swap.log
```

Ask current-directory file facts:

```bash
comai newest file
comai biggest file here
comai oldest file
comai smallest file
```

Ask about a command:

```bash
comai how this command work -command "find . -type f -size +100M"
```

## Configuration

Defaults live in:

```bash
~/localcomai/config/comai.yaml
```

Source default config:

```bash
config/comai.yaml
```

Current config keys:

```yaml
ai_dir: ~/ai
model: Qwen2.5-Coder-7B-Instruct-Q4_K_M
max_tokens: 420
timeout: 120
file_max_bytes: 24000
dir_context_max: 120
error_regex: error|errors|failed|failure|exception|fatal|panic|timeout|warn|warning|traceback
```

Environment variables can override config values:

```bash
COMAI_MODEL=Qwen2.5-7B-Instruct-Q4_K_M comai hi
COMAI_MAX_TOKENS=120 comai summarize this file -f README.md
COMAI_FILE_MAX_BYTES=60000 comai summarize this log -f app.log
```

## Project Layout

```text
bin/comai                     main entrypoint
config/comai.yaml             default config
lib/comai/config.sh           config and shared helpers
lib/comai/args.sh             command-line parsing
lib/comai/context.sh          file and directory context
lib/comai/local-checks.sh     direct filesystem/log checks
lib/comai/model-conditions.sh model-specific behavior hooks
lib/comai/ai.sh               local AI API request and output cleanup
scripts/install.sh            user installer
scripts/uninstall.sh          user uninstaller
scripts/comai-localai-service.sh
```

## Troubleshooting

If the local API is not responding:

```bash
systemctl --user start comai-localai.service
```

Check available models:

```bash
curl -s http://127.0.0.1:11435/v1/models | jq -r '.data[].id'
```

If model output is poor, try another model for that request:

```bash
comai --model=Qwen2.5-7B-Instruct-Q4_K_M summarize this file -f README.md
```

For direct factual checks, ComAI avoids the model when it can. For example, log error checks and simple file facts are computed with local Linux tools.
