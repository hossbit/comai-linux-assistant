# ComAI - Linux Terminal AI Assistant

<div align="center">
  <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/comai-hero.png" alt="ComAI local AI assistant for Linux" width="900">
</div>

<div align="center">

![Linux](https://img.shields.io/badge/Linux-supported-FCC624)
![Bash](https://img.shields.io/badge/Bash-shell-4EAA25)
![Local AI](https://img.shields.io/badge/Local%20AI-supported-2E7D32)
![Ollama](https://img.shields.io/badge/Ollama-supported-black)
![OpenAI](https://img.shields.io/badge/OpenAI-supported-10A37F)
![License](https://img.shields.io/badge/license-MIT-green)
[![Wiki](https://img.shields.io/badge/Wiki-documentation-blueviolet)](https://github.com/hossbit/comai-linux-assistant-wiki)

</div>

**ComAI** is a Bash-powered AI assistant for your Linux terminal.

Use it to ask Linux questions, explain commands before you run them, inspect
files, scan logs, and talk to local AI, Ollama, or OpenAI without leaving your
shell.

## Why Use It

- Works from any terminal with the simple `comai` command.
- Supports local OpenAI-compatible servers, Ollama, and OpenAI.
- Understands files and logs with `-f`.
- Keeps setup and provider checks visible with `comai status`.
- Installs as a user-space tool under `~/localcomai`.

## Install

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
comai gpt hi
```

Local mode is the default. Use `comai ollama ...` for Ollama and
`comai gpt ...` for OpenAI.

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
comai config      # View or edit settings
comai history     # Show previous conversations
comai start       # Start the bundled LocalAI helper service
comai stop        # Stop the bundled LocalAI helper service
comai restart     # Restart the bundled LocalAI helper service
```

## Providers

ComAI supports:

- `local`: any OpenAI-compatible local server, default `http://127.0.0.1:11435`
- `ollama`: local Ollama API, default `http://127.0.0.1:11434`
- `openai`: OpenAI API with `OPENAI_API_KEY` or `openai_api_key`

Check everything:

```bash
comai status
comai models
comai provider
```

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
- [Local AI Service](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Local-AI-Service.md)
- [File and Log Analysis](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/File-and-Log-Analysis.md)
- [Troubleshooting](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Troubleshooting.md)
- [Uninstall](https://github.com/hossbit/comai-linux-assistant-wiki/blob/main/Uninstall.md)

## Requirements

```text
bash curl jq find sort head sed awk grep wc tr readlink date systemctl
```

Optional:

```text
file numfmt git
```

## Support

<div align="center">
  <a href="https://buymeacoffee.com/mirhh">
    <img src="https://raw.githubusercontent.com/hossbit/mirassets/main/images/bmc-button.png" alt="Buy me a coffee" width="300">
  </a>
</div>
