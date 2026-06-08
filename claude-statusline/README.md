# Claude Statusline

Custom statusline for Claude Code when using the standard Anthropic API / a Claude
subscription (Pro/Max). Mirrors the richness of the MiniMax statusline, but swaps
the MiniMax-only bits for native Claude Code data.

## Elements

| Element | Color | Description |
|---------|-------|-------------|
| folder | cyan | Current working directory basename |
| branch | yellow | Current git branch (omitted outside a repo) |
| `[███░░] 41%` | green/amber/red | Context window usage percentage + bar |
| model · effort | magenta | Model name and current effort level (e.g. `Opus 4.8 · high`) |
| `5h:23% ↺2h` | green/amber/red | 5-hour rate-limit usage + reset countdown |
| `7d:88% ↺3d` | green/amber/red | 7-day rate-limit usage + reset countdown |
| `$1.23` | green | Total cost for the session |

Each segment is **omitted gracefully** when its data isn't present.

## Sample Output

```
Research | [████░░░░░░] 41% | Opus 4.8 · high | 5h:23% ↺2h · 7d:88% ↺3d | $1.23
```

On a fresh session outside a git repo (less data available):

```
.claude | [░░░░░░░░░░] 0% | Opus 4.8 (1M context) · high | $0.00
```

## Features vs. the MiniMax version

This version replaces MiniMax-specific features with native Claude equivalents:

| MiniMax statusline | Claude statusline |
|--------------------|-------------------|
| `mmx quota` daily/weekly (needs `mmx` CLI) | Native `rate_limits.five_hour` / `seven_day` from the statusline JSON — no extra CLI |
| China peak / off-peak hours indicator | Effort level (`high` / `xhigh`, etc.) |
| Cost, context bar, folder, branch | Same |

> **Note on rate limits:** the `5h` / `7d` segments only appear when you're signed
> in with a **Claude Pro/Max subscription** (`/login`). On pay-as-you-go API-key
> billing those fields aren't provided, so the segments are simply omitted.

## Color Thresholds

Both the context bar and the rate-limit segments use the same scale:

| Usage | Color | Meaning |
|-------|-------|---------|
| <50% | Green | Plenty remaining |
| 50–79% | Amber | Mid-range |
| ≥80% | Red | Near capacity |

## Prerequisites

- [jq](https://stedolan.github.io/jq/) — JSON processor
- Claude Code **v2.1.x or later** for the `rate_limits` and `effort` fields
  (older versions still work; those segments just won't appear)

## Installation

1. Copy the script and make it executable:
   ```bash
   cp statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Install `jq`:
   ```bash
   brew install jq          # macOS
   sudo apt install jq      # Ubuntu/Debian
   sudo dnf install jq      # Fedora/RHEL
   sudo pacman -S jq        # Arch
   ```

3. Point Claude Code at it in `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash /Users/YOU/.claude/statusline-command.sh"
     }
   }
   ```

4. Restart Claude Code.

## Switching between Claude and MiniMax

See [`../RESTORE.md`](../RESTORE.md) for a step-by-step guide to switching your
Claude Code setup between a real Claude model and MiniMax (and back).

## Troubleshooting

1. Statusline blank? Ensure `jq` is installed: `jq --version`
2. Script executable? `chmod +x ~/.claude/statusline-command.sh`
3. Debug: pipe a sample payload through it:
   ```bash
   echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":41},"cost":{"total_cost_usd":1.2}}' \
     | bash ~/.claude/statusline-command.sh
   ```
4. No `5h`/`7d` segments? You're likely on API-key billing, not a subscription —
   that's expected (see the note above).
