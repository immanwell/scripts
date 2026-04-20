# MiniMax + Claude Code Setup

Configure Claude Code to use MiniMax's Anthropic-compatible API.

## Overview

This setup routes Claude Code requests through MiniMax's API endpoint instead of Anthropic's, enabling use of MiniMax models (MiniMax-M2.7, etc.) with Claude Code's interface.

**API Endpoint:** `https://api.minimax.io/anthropic`

## Prerequisites

- MiniMax API key ([Get one here](https://platform.minimax.io/))
- Claude Code installed

## Setup

### 1. Clear Existing Environment Variables

Before configuring, unset any existing Anthropic environment variables to avoid conflicts:

```bash
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_BASE_URL
```

### 2. Configure Claude Code Settings

Edit `~/.claude/settings.json` (create if it doesn't exist):

**macOS / Linux:**
```bash
nano ~/.claude/settings.json
```

**Windows (PowerShell):**
```powershell
notepad $HOME\.claude\settings.json
```

Add this configuration:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.minimax.io/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "YOUR_MINIMAX_API_KEY",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
    "ANTHROPIC_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_SMALL_FAST_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7"
  }
}
```

### 3. Platform-Specific Notes

#### China Users
Use this endpoint instead:
```
https://api.minimaxi.com/anthropic
```

#### Windows (WSL)
If using WSL, add to your `~/.bashrc` or `~/.zshrc`:
```bash
export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
export ANTHROPIC_AUTH_TOKEN="YOUR_MINIMAX_API_KEY"
```

### 4. Post-Configuration

1. Navigate to your working directory
2. Run `claude` in terminal
3. Select **Trust This Folder** when prompted

## VS Code Extension Setup

1. Install [Claude Code Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
2. Set `claudeCode.selectedModel` to `minimax-m2.7` (or enter `MiniMax-M2.7` in Settings → Claude Code: Selected Model)
3. Configure the same environment variables in `claudeCode.environmentVariables`

## Environment Variables Priority

Environment variables take priority over `settings.json` configuration:

```bash
export ANTHROPIC_AUTH_TOKEN="YOUR_MINIMAX_API_KEY"
export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
```

## Troubleshooting

### "API key not valid" error
- Verify your API key is correct
- Ensure no leading/trailing spaces in the token
- Check the API key is active on [platform.minimax.io](https://platform.minimax.io/)

### Requests still going to Anthropic
- Confirm `settings.json` is properly formatted (valid JSON)
- Check for conflicting environment variables: `env | grep ANTHROPIC`

### Timeout errors
- Increase `API_TIMEOUT_MS` if on slow connection
- Check your API key has sufficient quota

## Models Available

| Model | Description |
|-------|-------------|
| MiniMax-M2.7 | Latest MiniMax model |
| MiniMax-M2 | Previous version |

## More Info

Official documentation: https://platform.minimax.io/docs/token-plan/claude-code

## Related

- [MiniMax Statusline](../minimax-statusline/) - Custom statusline with quota tracking
