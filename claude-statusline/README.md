# Claude Statusline

Custom statusline for Claude Code when using the standard Anthropic API (without MiniMax).

## Elements

| Element | Color | Description |
|---------|-------|-------------|
| folder | cyan | Current working directory basename |
| branch | yellow | Current git branch |
| [███░░] 41% | green/amber/red | Context window usage percentage |
| model | magenta | Model name |
| $1.00 | green | Total cost for session |

## Sample Output

```
muhoozi | main | [████░░░░░░] 41% | Claude Opus | $1.00
```

## Features

- **Simple & clean**: No external dependencies like `mmx` CLI
- **Cross-platform**: Works on macOS, Linux, WSL

## Prerequisites

- [jq](https://stedolan.github.io/jq/) - JSON processor

## Installation

1. Copy `statusline-command.sh` to your desired location:
   ```bash
   cp statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Install `jq`:

   **macOS:**
   ```bash
   brew install jq
   ```

   **Ubuntu/Debian:**
   ```bash
   sudo apt install jq
   ```

   **Fedora/RHEL:**
   ```bash
   sudo dnf install jq
   ```

   **Arch:**
   ```bash
   sudo pacman -S jq
   ```

4. Update Claude Code settings (`~/.claude/settings.json`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash /path/to/statusline-command.sh"
     }
   }
   ```

## What This Does NOT Include

Unlike the MiniMax version, this does NOT have:
- **Quota tracking** - Anthropic doesn't expose `mmx quota` equivalent in the JSON
- **Peak/off-peak hours** - MiniMax-specific rate limiting indicator
- **Lines changed** - Not always relevant for Anthropic usage

## Adapting for MiniMax

This statusline is for standard Anthropic. For MiniMax features (quota tracking, China peak hours), see the `minimax-statusline` folder in this repo.

## Context Bar Colors

| Usage | Color | Meaning |
|-------|-------|---------|
| <50% | Green | Plenty of context remaining |
| 50-79% | Amber | Getting mid-range |
| ≥80% | Red | Near capacity, consider compacting |

## Troubleshooting

If the statusline doesn't appear:
1. Ensure `jq` is installed: `jq --version`
2. Check the script is executable: `chmod +x ~/.claude/statusline-command.sh`
3. Debug: Run `bash -x ~/.claude/statusline-command.sh` to see errors
