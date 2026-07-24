# ComAI - Linux Terminal AI Assistant

<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-hero.png" alt="ComAI local AI assistant for Linux" width="900">
</div>

<div align="center">

![Linux](https://img.shields.io/badge/Linux-supported-FCC624)
![Bash](https://img.shields.io/badge/Bash-shell-4EAA25)
![Local AI](https://img.shields.io/badge/Local%20AI-supported-2E7D32)
![Ollama](https://img.shields.io/badge/Ollama-supported-black)
![LM Studio](https://img.shields.io/badge/LM%20Studio-supported-1F6FEB)
![OpenAI](https://img.shields.io/badge/OpenAI-supported-10A37F)
![Gemini](https://img.shields.io/badge/Gemini-supported-4285F4)
![OpenRouter](https://img.shields.io/badge/OpenRouter-supported-6467F2)
![License](https://img.shields.io/badge/license-MIT-green)
[![Wiki](https://img.shields.io/badge/Wiki-documentation-blueviolet)](https://github.com/hossbit/comai-linux-assistant-wiki)

</div>

<div align="center">

<a href="https://github.com/hossbit/comai-linux-assistant/releases/latest"><img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-badge-release.svg" alt="Latest Release" height="68"></a>
<a href="https://github.com/hossbit/comai-linux-assistant/pulse"><img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-badge-download.svg" alt="Downloads" height="68"></a>
<a href="https://github.com/hossbit/comai-linux-assistant/stargazers"><img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-badge-stars.svg" alt="GitHub Stars" height="68"></a>
</div>

**ComAI** is a Bash-powered AI assistant for your Linux terminal.

Use it to ask Linux questions, explain commands before you run them, inspect
files, scan logs, and talk to local AI, Ollama, OpenAI, Gemini, or OpenRouter
without leaving your shell. ComAI is the client; LocalAI is only one optional
backend.

## Why Use It

- Works from any terminal with the simple `comai` command.
- Supports LocalAI, Ollama, LM Studio, llama.cpp server, OpenAI, Gemini, OpenRouter, and other OpenAI-compatible APIs.
- Understands files and logs with `-f`.
- Keeps setup and provider checks visible with `comai status`.
- Installs as a user-space tool under `~/localcomai`.

## Demo

<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-demo.gif" alt="ComAI terminal demo" width="640">
</div>

## Install

One-line install:

```bash
curl -fsSL https://hossbit.github.io/comai/install.sh | bash
```

Custom install directory:

```bash
curl -fsSL https://hossbit.github.io/comai/install.sh | COMAI_INSTALL_DIR="$HOME/apps/comai" bash
```

Manual install:

```bash
git clone https://github.com/hossbit/comai-linux-assistant.git
cd comai-linux-assistant
chmod +x scripts/install.sh
./scripts/install.sh
```

Then run:

```bash
comai status
```

## First Commands

```bash
comai explain chmod 755
comai how do I find files larger than 1GB?
comai do you see any error? -f application.log
comai ollama hi
comai lmstudio hi
comai gpt hi
comai gemini hi
comai opr hi
```

Local mode is the default. Use `comai ollama ...` for Ollama,
`comai lmstudio ...` for LM Studio, `comai gpt ...` for OpenAI,
`comai gemini ...` for Gemini, and `comai opr ...` for OpenRouter.
Short aliases also work: `olm`, `lms`, `gem`, `opr`.

Use `--` when the first word of your question is also a provider name:

```bash
comai -- ollama is the first word of this question
```

## Main Commands

```bash
comai setup       # Configure provider, API, and model
comai ask         # Ask one question
comai chat        # Start an interactive conversation
comai explain     # Explain a command, error, or output
comai analyze     # Analyze logs, files, or piped output
comai status      # Show provider status and connections
comai provider    # Show active and available providers
comai models      # List models from all providers
comai config      # View, get, or edit settings
comai history     # Show previous conversations
comai start       # Start the optional LocalAI helper service
comai stop        # Stop the optional LocalAI helper service
comai restart     # Restart the optional LocalAI helper service
```

Common options:

```bash
comai --provider gemini --model gemini-2.5-flash hi
comai --max-tokens 900 "summarize this"
```

`--max-tokens` must be a positive integer.

## Providers

ComAI supports:

- `local`: any OpenAI-compatible local server, default `http://127.0.0.1:11435`; optional `LOCALAI_API_KEY` or `providers.local.api_key` if the server has active keys (e.g. via `localai key create`) -- unauthenticated by default
- `ollama`: local Ollama API, default `http://127.0.0.1:11434` (alias: `olm`)
- `lmstudio`: LM Studio local server, default `http://127.0.0.1:1234` (alias: `lms`)
- `openai`: OpenAI API with `OPENAI_API_KEY` or `providers.openai.api_key` (alias: `gpt`, `chatgpt`)
- `gemini`: Gemini API with `GEMINI_API_KEY` or `providers.gemini.api_key` (alias: `gem`)
- `openrouter`: OpenRouter API with `OPENROUTER_API_KEY` or `providers.openrouter.api_key` (alias: `opr`)

<div align="center">
  <a href="https://github.com/hossbit/local-ai-server">
    <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/local-ai-server.png" alt="Local AI Server" width="300">
    <br>
    <strong>hossbit/local-ai-server</strong>
  </a>
  <br>
  OpenAI-compatible Linux local AI backend for the <code>local</code> provider.
</div>

Check providers:

```bash
comai status
comai models
comai provider
```

`status`, `provider`, and `models` colorize connection results (green/yellow/red) when
output is a real terminal. Force or disable it with `COMAI_COLOR=1`, `COMAI_COLOR=0`,
or the standard `NO_COLOR=1`.

## Models

ComAI can list models from every configured provider, so you can use local
models, Ollama models, LM Studio models, OpenAI models, Gemini models, and
OpenRouter models from the same command line.

```bash
comai models
```

Example output:

```text
local (active):
  Qwen2.5-Coder-7B-Instruct-Q4_K_M
  Qwen3.5-9B-UD-IQ2_XXS
  bge-m3-q8_0

ollama:
  qwen2.5-coder:7b

lmstudio:
  qwen/qwen3.5-9b

openai:
  gpt-4o-mini
  gpt-4.1
  gpt-4o

gemini:
  gemini-2.5-flash
  gemini-2.5-pro
  gemini-flash-latest

openrouter:
  openrouter/auto
  anthropic/claude-sonnet-4.5
  openai/gpt-5
  ... (hundreds more)
```

OpenRouter's catalog alone can list hundreds of models. Narrow any provider's list with `--filter`:

```bash
comai models openrouter --filter claude
comai models all --filter gemini
```

Use any listed model for one request:

```bash
comai --provider gemini --model gemini-2.5-flash "explain journalctl -u nginx"
comai --gpt --model gpt-4o-mini "write a safe backup command"
comai --ollama --model qwen2.5-coder:7b "explain this shell error"
comai opr --model anthropic/claude-sonnet-4.5 "explain this shell error"
```

Or save a provider's default model:

```bash
comai config set providers.gemini.model gemini-2.5-flash
comai config set providers.openai.model gpt-4o-mini
comai config set providers.openrouter.model anthropic/claude-sonnet-4.5
```

Provider code lives under `lib/comai/providers/`. To add another API provider,
add a provider module with the standard `model`, `api_base`, `status`, `models`,
and `ask` functions, then register it in `lib/comai/providers/registry.sh`.

## Files And Logs

```bash
comai explain this script -f install.sh
comai summarize this config -f nginx.conf
comai is this service healthy? -f service.log
```

ComAI service/status logs are written under:

```bash
~/localcomai/logs/comai.log
```

## Documentation

Full documentation lives in the wiki:

- [Quick Start](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Quick-Start.md)
- [Installation](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Installation.md)
- [Providers](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Providers.md)
- [Configuration](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Configuration.md)
- [ComAI + LocalAI](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/ComAI-and-LocalAI.md)
- [Local AI Service](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Local-AI-Service.md)
- [File and Log Analysis](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/File-and-Log-Analysis.md)
- [Troubleshooting](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Troubleshooting.md)
- [Uninstall](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Uninstall.md)

## Requirements

```text
Bash 4.2+ curl jq awk grep sed sort head wc tr readlink date
GNU coreutils, including stat -c
GNU findutils, including find -printf
```

Optional:

```text
file numfmt git systemctl shellcheck
```

Standard Debian, Ubuntu, RHEL, Fedora, Rocky, AlmaLinux, and CentOS-style
systems provide GNU coreutils/findutils, so `find -printf` and `stat -c` are
expected to work there. Minimal BusyBox/toybox-based containers, Alpine images,
and some UBI-minimal images may not provide those GNU extensions; install GNU
findutils/coreutils or run ComAI from a fuller Debian/RHEL userland.

For local portability checks, run:

```bash
scripts/test-local.sh
```

The test script uses the current `awk`, plus `mawk` and `gawk` when installed.
To fully exercise the RHEL/Fedora awk path, run it on a host with `gawk`
installed.

## Support

<div align="center">
  <a href="https://buymeacoffee.com/mirhh">
    <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/bmc-button.png" alt="Buy me a coffee" width="300">
  </a>
</div>
<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/give-it-a-star.png" alt="If this repo helped you, give it a star" width="100%">
</div>
