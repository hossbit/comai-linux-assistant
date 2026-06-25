# ComAI

`comai` is a Bash assistant for Linux commands, files, and logs.

It has two modes:

```bash
comai hi      # local model
comai gpt hi  # ChatGPT/OpenAI
```

Local mode is the default. ChatGPT mode only runs when the first word after `comai` is `gpt` or `chatgpt`.

## Install

```bash
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

Main config keys:

```yaml
ai_dir: ~/ai
model: Qwen2.5-Coder-7B-Instruct-Q4_K_M
gpt_model: gpt-5.5
openai_api_base: https://api.openai.com
openai_api_key:
max_tokens: 420
timeout: 120
```

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
