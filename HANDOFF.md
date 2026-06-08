# Handoff: switch this machine from MiniMax to a real Claude model

**Audience:** an AI coding agent (Claude Code, etc.) running on an Ubuntu/Linux
machine that currently has Claude Code configured to use the **MiniMax** API.

**Goal:** switch Claude Code to a real **Anthropic Claude** model (via Claude
Pro/Max subscription login) and install the upgraded Claude statusline — safely,
with a full rollback path.

---

## Ground rules for the agent (read first)

1. **Back up before changing anything.** Snapshot `settings.json` and the
   statusline so the machine can be restored exactly.
2. **Never print, commit, or transmit the MiniMax API token.** It lives in
   `~/.claude/settings.json` (`ANTHROPIC_AUTH_TOKEN`). It is *config*, not code —
   keep it on this machine only. Do **not** push the backup anywhere.
3. **The `/login` step is the human's job.** You cannot complete an interactive
   browser login. Do every automated step, then hand back with clear instructions.
4. **Be idempotent.** Every command below is safe to re-run.
5. If anything looks different from what's described (e.g. no `.env` block, custom
   env vars you didn't expect), **stop and report** rather than guessing.

---

## Step 0 — Confirm the starting state

```bash
# What's configured now? (token is redacted in this readout)
jq '.env // "NO ENV BLOCK"' ~/.claude/settings.json \
  | sed -E 's/(AUTH_TOKEN"[[:space:]]*:[[:space:]]*")[^"]*/\1***REDACTED***/'

# Is jq installed?
command -v jq || echo "jq MISSING — install in Step 2"
```

Expect to see an `env` block with `ANTHROPIC_BASE_URL` pointing at
`api.minimax.io` and the models set to `MiniMax-M2.7`. If there's no env block,
this machine may already be switched — verify with Step 6 and stop.

---

## Step 1 — Back up the working MiniMax config (local only)

```bash
BK="$HOME/.claude/backups/minimax-$(date +%Y-%m-%d)"
mkdir -p "$BK"
cp -p "$HOME/.claude/settings.json"          "$BK/settings.json.minimax.bak"
[ -f "$HOME/.claude/statusline-command.sh" ] && \
  cp -p "$HOME/.claude/statusline-command.sh" "$BK/statusline-command.minimax.sh"
jq '{env: .env}' "$HOME/.claude/settings.json" > "$BK/minimax-env-block.json"
echo "Backed up to: $BK"
ls -la "$BK"
```

> This backup contains the real token. Keep it on this machine. Do not commit it.

---

## Step 2 — Install jq if missing

```bash
command -v jq >/dev/null || { sudo apt-get update && sudo apt-get install -y jq; }
jq --version
```

---

## Step 3 — Remove the MiniMax env overrides from settings.json

This deletes only the MiniMax-related keys, preserves any other env vars, and
drops the `env` block entirely if it ends up empty. A `.tmp` file + validation
guards against corrupting the JSON.

```bash
cd "$HOME/.claude"
jq '
  (.env // {}) as $e
  | .env = ($e
      | del(.ANTHROPIC_BASE_URL, .ANTHROPIC_AUTH_TOKEN, .API_TIMEOUT_MS,
            .CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, .ANTHROPIC_MODEL,
            .ANTHROPIC_SMALL_FAST_MODEL, .ANTHROPIC_DEFAULT_SONNET_MODEL,
            .ANTHROPIC_DEFAULT_OPUS_MODEL, .ANTHROPIC_DEFAULT_HAIKU_MODEL))
  | if (.env | length) == 0 then del(.env) else . end
' settings.json > settings.json.tmp \
  && mv settings.json.tmp settings.json \
  && echo "✅ MiniMax env removed"

# Validate JSON is still well-formed
jq empty settings.json && echo "✅ settings.json is valid JSON"

# Confirm nothing MiniMax remains in the env (plugin names may still match — that's fine)
jq '.env // "ENV REMOVED"' settings.json
```

---

## Step 4 — Check shell startup files for stray MiniMax exports

The MiniMax setup guide tells WSL/bash users to add exports to `~/.bashrc`. Those
**override `settings.json`**, so they must go too.

```bash
for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
  [ -f "$f" ] && grep -nE 'ANTHROPIC_(BASE_URL|AUTH_TOKEN|MODEL)|api\.minimax' "$f" \
    && echo ">> Found MiniMax exports in $f — remove those lines (back up the file first)."
done
echo "Scan complete. If nothing printed above, shell files are clean."
```

If any lines are found, back up the file (`cp "$f" "$f.bak"`) and delete only the
matching `export ANTHROPIC_* ` / MiniMax lines. Report which lines you removed.

---

## Step 5 — Install the upgraded Claude statusline

Pull it straight from this repo so every machine gets the identical, tested
version (includes native 5h/7d usage tracking, effort level, and the macOS/BSD
`seq` bar-length fix — harmless on Linux but kept for portability).

```bash
TMP="$(mktemp -d)"
git clone --depth 1 https://github.com/immanwell/scripts.git "$TMP/scripts"
cp "$TMP/scripts/claude-statusline/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline-command.sh"
rm -rf "$TMP"

# Point settings.json at it (idempotent; uses this machine's $HOME)
cd "$HOME/.claude"
jq --arg cmd "bash $HOME/.claude/statusline-command.sh" \
   '.statusLine = {type:"command", command:$cmd}' \
   settings.json > settings.json.tmp && mv settings.json.tmp settings.json
jq '.statusLine' settings.json
```

---

## Step 6 — Verify (automated)

```bash
# 1. No MiniMax routing left in env
jq -e '(.env.ANTHROPIC_BASE_URL // "") | contains("minimax") | not' settings.json \
  >/dev/null && echo "✅ no MiniMax base URL in settings env"

# 2. Statusline renders with a Claude-style payload
NOW=$(date +%s)
cat <<EOF | bash "$HOME/.claude/statusline-command.sh"
{"workspace":{"current_dir":"$HOME"},"model":{"display_name":"Sonnet 4.6"},
 "effort":{"level":"high"},"cost":{"total_cost_usd":0.14},
 "context_window":{"used_percentage":17},
 "rate_limits":{"five_hour":{"used_percentage":60,"resets_at":$((NOW+3600))},
                "seven_day":{"used_percentage":8,"resets_at":$((NOW+432000))}}}
EOF
echo "(expect: folder | [bar] 17% | Sonnet 4.6 · high | 5h:60% ... · 7d:8% ... | \$0.14)"
```

---

## Step 7 — Hand back to the human (REQUIRED)

Tell the user, verbatim:

> ✅ Automated switch complete. Two manual steps remain:
> 1. **Fully restart Claude Code** (quit and reopen, or start a fresh `claude`).
> 2. Run **`/login`** and sign in with your **Anthropic (Claude Pro/Max) account**.
>    The status bar will stop showing "Not logged in", and the `5h`/`7d` usage
>    segments will populate (they only appear on a subscription login, not on
>    API-key billing).
>
> Verify with: `env | grep ANTHROPIC` — it should no longer show `api.minimax.io`
> or `MiniMax-M2.7`.

Note: the reset countdown uses the `↺` glyph; if the terminal font can't draw it,
the time (e.g. `1h`, `5d`) still shows correctly next to it.

---

## Rollback

To return this machine to MiniMax, follow [`RESTORE.md`](./RESTORE.md) → section B,
or restore the backup from Step 1:

```bash
BK="$HOME/.claude/backups/minimax-<DATE>"   # the folder created in Step 1
cp "$BK/settings.json.minimax.bak"        "$HOME/.claude/settings.json"
cp "$BK/statusline-command.minimax.sh"    "$HOME/.claude/statusline-command.sh"
# then restart Claude Code
```
