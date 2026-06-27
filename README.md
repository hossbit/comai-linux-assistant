# ComAI - Local AI Linux Terminal Assistant

<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-hero.png" alt="ComAI local AI assistant for Linux" width="900">
</div>

<div align="center">

![Linux](https://img.shields.io/badge/Linux-supported-FCC624)
![Ubuntu](https://img.shields.io/badge/Ubuntu-supported-E95420)
![Fedora](https://img.shields.io/badge/Fedora-supported-51A2DA)
![Bash](https://img.shields.io/badge/Bash-shell-4EAA25)
![AI](https://img.shields.io/badge/AI-assisted-1565C0)
![Local AI](https://img.shields.io/badge/Local%20AI-supported-2E7D32)
![Ollama](https://img.shields.io/badge/Ollama-supported-black)
![ChatGPT](https://img.shields.io/badge/ChatGPT-supported-10A37F)
![Release](https://img.shields.io/badge/release-v2.1.2-green)
![License](https://img.shields.io/badge/license-MIT-green)
[![Wiki](https://img.shields.io/badge/Wiki-documentation-blueviolet)](https://github.com/hossbit/comai-linux-assistant-wiki)

![Local First](https://img.shields.io/badge/value-local%20first-2E7D32)
![Privacy Friendly](https://img.shields.io/badge/value-privacy%20friendly-00695C)
![Command Help](https://img.shields.io/badge/value-command%20help-6A1B9A)
![File Analysis](https://img.shields.io/badge/value-file%20analysis-1565C0)
![Log Checks](https://img.shields.io/badge/value-log%20checks-C62828)
![Multi Provider](https://img.shields.io/badge/value-multi%20provider-E65100)
![Bash Native](https://img.shields.io/badge/value-bash%20native-4EAA25)
![Configurable](https://img.shields.io/badge/value-configurable-455A64)
</div>

<div align="center">
  <a href="https://buymeacoffee.com/mirhh">
    <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/bmc-button.png" alt="Buy me a coffee" width="300">
  </a>
</div>

**ComAI** is an open-source AI-powered Linux terminal assistant written in Bash.

Ask Linux questions, explain shell commands, analyze configuration files,
inspect logs for errors, and interact with local LLMs, Ollama, or OpenAI directly
from your terminal.

ComAI supports:

- Local AI models through llama.cpp and OpenAI-compatible APIs
- Ollama models for local chat and file analysis
- OpenAI and ChatGPT API models
- Linux command explanations
- File and configuration analysis
- Log analysis and error detection
- Custom model selection
- Bash-friendly installation and configuration

## Documentation

Read the full wiki here:

https://github.com/hossbit/comai-linux-assistant-wiki

The wiki includes installation, quick start, provider setup, configuration,
file and log analysis, troubleshooting, and uninstall guides.

## Quick Example

```bash
comai explain chmod 755
comai how do I find files larger than 1GB?
comai do you see any error? -f application.log
comai ollama explain this script -f script.sh
comai gpt explain this nginx configuration -f nginx.conf
```

Local mode is the default. Ollama mode runs when the first word after `comai`
is `ollama`. ChatGPT mode runs when the first word is `gpt` or `chatgpt`.

## Install

For local mode, install [hossbit/localai](https://github.com/hossbit/localai) first. ComAI expects it at:

```bash
~/ai
```

If you only want Ollama or ChatGPT mode, you can skip localai and use
`comai ollama ...` or `comai gpt ...`.

```bash
git clone https://github.com/hossbit/comai-linux-assistant.git
cd comai-linux-assistant
chmod +x scripts/install.sh
./scripts/install.sh
```

Installed files go to `~/localcomai`.

The installer explains each section before it changes files. It asks where to
install ComAI, uses `~/localcomai` by default, shows when files already exist,
and preserves existing config values while adding new default config keys.

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

Use Ollama:

```bash
comai ollama hi
comai ollama explain chmod 755
```

Read a file:

```bash
comai explain this file -f script.sh
comai ollama summarize this file -f README.md
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
comai ollama --model=qwen2.5-coder:7b hi
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
provider: local
ai_dir: ~/ai
api_base_url: http://127.0.0.1
api_base_port: 11435
model: Qwen2.5-Coder-7B-Instruct-Q4_K_M
gpt_model: gpt-5.5
ollama_api_base: http://127.0.0.1:11434
ollama_model: qwen2.5-coder:7b
openai_api_base: https://api.openai.com
openai_api_key:
max_tokens: 420
timeout: 120
file_max_bytes: 24000
dir_context_max: 120
error_regex: error|errors|failed|failure|exception|fatal|panic|timeout|warn|warning|traceback
error_intent_regex: error|errors|failed|failure|warning|warnings|problem|problems|issue|issues|wrong|bad|broken|fail|crash|crashed|panic|timeout|traceback|healthy|health|(^|[[:space:]])ok([[:space:]]|$)|okay|check (this )?log|scan (this )?log
```

What the main keys mean:

- `provider`: default provider. Use `local`, `ollama`, or `openai`.
- `ai_dir`: where localai is installed. Default is `~/ai`.
- `api_base_url`: local OpenAI-compatible API URL without the port.
- `api_base_port`: local OpenAI-compatible API port.
- `model`: default local model for `comai hi`.
- `gpt_model`: default OpenAI model for `comai gpt hi`.
- `ollama_api_base`: Ollama API URL. Default is `http://127.0.0.1:11434`.
- `ollama_model`: default Ollama model for `comai ollama hi`.
- `openai_api_base`: OpenAI API URL. Keep this as `https://api.openai.com` unless you know you need another compatible server.
- `openai_api_key`: optional place to store your OpenAI key for ChatGPT mode. `OPENAI_API_KEY` is safer and overrides this.
- `max_tokens`: maximum answer length.
- `timeout`: request timeout in seconds.
- `file_max_bytes`: maximum bytes read from each `-f` file.
- `dir_context_max`: maximum current-directory entries sent as context.
- `error_regex`: words used by local log/error checks.
- `error_intent_regex`: words used to decide whether a question is asking for a log/error check.

Useful overrides:

```bash
COMAI_MODEL=Qwen2.5-7B-Instruct-Q4_K_M comai hi
COMAI_PROVIDER=ollama comai hi
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

## Ollama

Start Ollama, then run:

```bash
comai ollama hi
comai ollama summarize this file -f README.md
```

Check Ollama models:

```bash
curl -s http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
```

## Troubleshooting

`comai gpt ...` says `429`: OpenAI rejected the request for rate limit or quota. Check billing, credits, project, or rate limits.

`comai gpt ...` works without exporting a key: it is probably reading `openai_api_key` from `~/localcomai/config/comai.yaml`.

`comai ...` cannot reach local AI: start `comai-localai.service` or run `~/ai/start.sh`.

`comai ollama ...` cannot reach Ollama: start Ollama and check `ollama_api_base` in `config/comai.yaml`.

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
