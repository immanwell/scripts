# Switching Claude Code between Claude and MiniMax

This repo holds two statusline variants and the config needed to run Claude Code
either on a real **Anthropic Claude** model or on the **MiniMax** API. This guide
is the canonical way to switch between them (and back).

> ⚠️ **Never commit your real API token.** The MiniMax setup needs your MiniMax
> key in `~/.claude/settings.json`. Keep that key only in your local settings file
> — it is *config*, not code, and must stay out of this repo.

---

## A. Switch to a real Claude model (Anthropic)

Use this when you want Claude Code to run on Claude (Opus/Sonnet/Haiku) via your
Anthropic Pro/Max subscription or an Anthropic API key.

1. **Remove the MiniMax `env` block** from `~/.claude/settings.json`. That block
   is what reroutes Claude Code to MiniMax — delete the whole `"env": { ... }`
   object that contains `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and the
   `MiniMax-M2.7` model overrides. Leave everything else (`permissions`, `hooks`,
   `statusLine`, `enabledPlugins`) untouched.

2. **Install the Claude statusline:**
   ```bash
   cp claude-statusline/statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

3. **Restart Claude Code, then authenticate:**
   - Subscription: run `claude`, then `/login` and sign in with your Anthropic
     account. The bottom bar should stop showing "Not logged in".
   - API key: instead, set `ANTHROPIC_API_KEY` (env var or a fresh `env` block).

4. **Verify:**
   ```bash
   env | grep ANTHROPIC      # should NOT show api.minimax.io or MiniMax-M2.7
   ```
   The statusline model field should read a Claude model (e.g. `Opus 4.8`).

See [`claude-statusline/`](./claude-statusline/) for what the Claude statusline shows.

---

## B. Switch to MiniMax

Use this to route Claude Code through MiniMax's Anthropic-compatible API.

1. **Add the MiniMax `env` block** to `~/.claude/settings.json` (full instructions
   and the exact JSON are in [`minimax-claude-code/`](./minimax-claude-code/)).
   Put your real MiniMax key in `ANTHROPIC_AUTH_TOKEN`.

2. **Install the MiniMax statusline:**
   ```bash
   cp minimax-statusline/statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```
   (Requires the `mmx` CLI for the quota display; without it the quota segment is
   just omitted.)

3. **Restart Claude Code** and verify:
   ```bash
   env | grep ANTHROPIC      # should show api.minimax.io + MiniMax-M2.7
   ```

See [`minimax-statusline/`](./minimax-statusline/) and
[`minimax-claude-code/`](./minimax-claude-code/) for details.

---

## What differs between the two statuslines

| | Claude | MiniMax |
|---|--------|---------|
| Usage tracking | Native `rate_limits` (5h / 7d), no extra CLI | `mmx quota` (daily / weekly), needs `mmx` CLI |
| Extra indicator | Effort level (`high` / `xhigh`) | China peak / off-peak hours |
| Shared | folder · branch · context bar · model · cost | same |

## Tip: keep a local backup of your working config

Before switching, snapshot your live files so you can roll back exactly:

```bash
BK=~/.claude/backups/$(date +%Y-%m-%d)
mkdir -p "$BK"
cp ~/.claude/settings.json "$BK/settings.json.bak"
cp ~/.claude/statusline-command.sh "$BK/statusline-command.bak.sh"
```

Keep that backup folder **local** — `settings.json` contains your API token.
