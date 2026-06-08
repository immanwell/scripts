# Scripts

Collection of utility scripts for development workflows.

## Switching Claude Code between Claude and MiniMax

See **[RESTORE.md](./RESTORE.md)** for a step-by-step guide to switching your
Claude Code setup between a real Anthropic Claude model and MiniMax (and back),
including which statusline to install for each.

### Automated handoff for other machines

**[HANDOFF.md](./HANDOFF.md)** is an agent-executable runbook: point a coding
agent (Claude Code, etc.) on another Ubuntu/Linux machine at it to switch that
machine from MiniMax to a real Claude model + install the Claude statusline, with
backup and rollback built in.

## Subfolders

### [claude-statusline](./claude-statusline/)
Custom statusline for Claude Code on a standard Anthropic / Claude subscription
setup. Shows folder, branch, context bar, model + effort level, native 5-hour and
7-day usage limits, and session cost. No external CLI required (just `jq`).

### [minimax-statusline](./minimax-statusline/)
Custom statusline for Claude Code when using the MiniMax API. Includes quota
tracking (via the `mmx` CLI), a China peak/off-peak hours indicator, and session cost.

### [minimax-claude-code](./minimax-claude-code/)
Setup guide for routing Claude Code through MiniMax's Anthropic-compatible API.
