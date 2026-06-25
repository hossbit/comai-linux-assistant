# ComAI - Local AI Linux Terminal Assistant

<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-hero.png" alt="ComAI local AI assistant for Linux" width="900">
</div>

![Linux](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Fedora-orange)
![Bash](https://img.shields.io/badge/Bash-shell-4EAA25)
![AI](https://img.shields.io/badge/AI-local%20%2B%20ChatGPT-blue)
![Release](https://img.shields.io/badge/release-v2.0-green)
![License](https://img.shields.io/badge/license-MIT-green)

<div align="center">
  <a href="https://buymeacoffee.com/mirhh">
    <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/bmc-button.png" alt="Buy me a coffee" width="300">
  </a>
</div>

**ComAI** is an open-source AI-powered Linux terminal assistant written in Bash.

Ask Linux questions, explain shell commands, analyze configuration files,
inspect logs for errors, and interact with local LLMs or OpenAI directly
from your terminal.

ComAI supports:

- Local AI models through llama.cpp and OpenAI-compatible APIs
- OpenAI and ChatGPT API models
- Linux command explanations
- File and configuration analysis
- Log analysis and error detection
- Custom model selection
- Bash-friendly installation and configuration

## Quick Example

```bash
comai explain chmod 755
comai how do I find files larger than 1GB?
comai do you see any error? -f application.log
comai gpt explain this nginx configuration -f nginx.conf
```

Local mode is the default. ChatGPT mode only runs when the first word after
`comai` is `gpt` or `chatgpt`.

## Install

For local mode, install [hossbit/localai](https://github.com/hossbit/localai) first. ComAI expects it at:

```bash
~/ai
```

If you only want ChatGPT mode, you can skip localai and use `comai gpt ...` with an OpenAI API key.

```bash
git clone https://github.com/hossbit/comai-linux-assistant.git
cd comai-linux-assistant
chmod +x scripts/install.sh
./scripts/install.sh
```

Installed files go to `~/localcomai`.

Commands:

```bash
comai
comi
```

## Common Usage

Ask a Linux question:

```bash
comai what is /etc in linux?
comai how this command work -command "find . -type f -size +100M"
```

Use ChatGPT:

```bash
comai gpt hi
comai gpt explain chmod 755
```

Read a file:

```bash
comai explain this file -f script.sh
comai gpt summarize this file -f llama-swap.log
```

Ask simple local file/log checks:

```bash
comai newest file
comai biggest file here
comai do you see any error? -f llama-swap.log
```

Choose a model for one request:

```bash
comai --model=Qwen2.5-7B-Instruct-Q4_K_M hi
comai gpt --model=gpt-5.5 hi
```

## ChatGPT Setup

Use an environment variable:

```bash
export OPENAI_API_KEY="your_api_key"
```

Or put the key in the installed config:

```yaml
openai_api_key: your_api_key
```

Installed config:

```bash
~/localcomai/config/comai.yaml
```

Do not commit a real API key to git.

## Config

Config files:

```bash
config/comai.yaml              # source default
~/localcomai/config/comai.yaml # installed config
```

Example:

```yaml
ai_dir: ~/ai
model: Qwen2.5-Coder-7B-Instruct-Q4_K_M
gpt_model: gpt-5.5
openai_api_base: https://api.openai.com
openai_api_key:
max_tokens: 420
timeout: 120
```

What the main keys mean:

- `ai_dir`: where localai is installed. Default is `~/ai`.
- `model`: default local model for `comai hi`.
- `gpt_model`: default OpenAI model for `comai gpt hi`.
- `openai_api_base`: OpenAI API URL. Keep this as `https://api.openai.com` unless you know you need another compatible server.
- `openai_api_key`: optional place to store your OpenAI key for ChatGPT mode. `OPENAI_API_KEY` is safer and overrides this.
- `max_tokens`: maximum answer length.
- `timeout`: request timeout in seconds.
- `file_max_bytes`: maximum bytes read from each `-f` file.
- `dir_context_max`: maximum current-directory entries sent as context.
- `error_regex`: words used by local log/error checks.

Useful overrides:

```bash
COMAI_MODEL=Qwen2.5-7B-Instruct-Q4_K_M comai hi
OPENAI_API_KEY=your_api_key comai gpt hi
COMAI_MAX_TOKENS=120 comai hi
```

## Local AI

ComAI expects a local OpenAI-compatible server in `~/ai`.

Start it:

```bash
systemctl --user start comai-localai.service
```

Or manually:

```bash
~/ai/start.sh
```

Check local models:

```bash
curl -s http://127.0.0.1:11435/v1/models | jq -r '.data[].id'
```

## Troubleshooting

`comai gpt ...` says `429`: OpenAI rejected the request for rate limit or quota. Check billing, credits, project, or rate limits.

`comai gpt ...` works without exporting a key: it is probably reading `openai_api_key` from `~/localcomai/config/comai.yaml`.

`comai ...` cannot reach local AI: start `comai-localai.service` or run `~/ai/start.sh`.

## Requirements

```text
bash curl jq find sort head sed awk grep wc tr readlink systemctl
```

Optional:

```text
file numfmt
```

## Uninstall

```bash
~/localcomai/scripts/uninstall.sh
```

This removes ComAI files and leaves `~/ai` alone.
