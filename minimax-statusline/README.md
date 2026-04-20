# MiniMax Statusline

Custom statusline for Claude Code when using the MiniMax API.

## Elements

| Element | Color | Description |
|---------|-------|-------------|
| folder | cyan | Current working directory basename |
| branch | yellow | Current git branch |
| [███░░] 41% | green/amber/red | Context window usage percentage |
| model · peak | magenta/green/red | Model name + China on/off-peak status |
| D:4% ↺2h · W:7% ↺6d | amber | Daily/weekly quota usage + reset countdown |
| $1.00 | green | Total cost for session |

## Sample Output

```
muhoozi | main | [████░░░░░░] 41% | MiniMax-M2.7 · 🌙off-peak | D:4% ↺2h · W:7% ↺6d | $1.00
```

## MiniMax-Specific Features

- **Quota tracking**: Uses `mmx quota` CLI to show daily/weekly usage and reset countdown
- **China peak hours**: Shows ⚡on-peak (red) when China is 15:00-17:30 UTC+8 on weekdays, 🌙off-peak (green) otherwise

## Prerequisites

- [jq](https://stedolan.github.io/jq/) - JSON processor
- [mmx](https://github.com/minimaxdev/mmx) CLI - for MiniMax quota data

## Installation

1. Copy `statusline-command.sh` to your desired location:
   ```bash
   cp statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Install dependencies:

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

3. Ensure `mmx` CLI is installed and configured with your MiniMax API credentials.

4. Update Claude Code settings (`~/.claude/settings.json`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash /path/to/statusline-command.sh"
     }
   }
   ```

## Peak Hours

MiniMax rate limiting is stronger during peak hours in China:

- **⚡on-peak** (red): Weekdays 15:00-17:30 China time (UTC+8)
- **🌙off-peak** (green): All other times

## Context Bar Colors

| Usage | Color | Meaning |
|-------|-------|---------|
| <50% | Green | Plenty of context remaining |
| 50-79% | Amber | Getting mid-range |
| ≥80% | Red | Near capacity, consider compacting |

## Adapting for Anthropic (Standard Claude Code)

This statusline is tailored for MiniMax. To adapt for standard Anthropic models:

1. **Remove the peak indicator** - it's MiniMax-specific
2. **Remove quota tracking** - Anthropic doesn't have an `mmx` equivalent (or use `claude api quotas` if available)
3. **Keep**:
   - folder
   - branch
   - model
   - context bar
   - cost
   - lines changed (optional)

See the `claude-statusline` folder in this repo for an Anthropic version.

## Troubleshooting

If the statusline doesn't appear:
1. Ensure `jq` is installed: `jq --version`
2. Check the script is executable: `chmod +x ~/.claude/statusline-command.sh`
3. Verify mmx is working: `mmx quota`
4. Check Claude Code is using the correct settings path
5. Debug: Run `bash -x ~/.claude/statusline-command.sh` to see errors
