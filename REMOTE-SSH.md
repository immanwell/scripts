# Switch a remote machine from MiniMax to Claude — over SSH

**Audience:** anyone (or an AI coding agent) sitting at one machine — say your
laptop — who wants to switch a **different** machine from the **MiniMax** API to a
real **Anthropic Claude** model, without sitting at that other machine's keyboard.

This is the same switch as [`HANDOFF.md`](./HANDOFF.md) / [`RESTORE.md`](./RESTORE.md),
but every command is wrapped in an SSH call so it runs on the **target** box. It
also documents the two gotchas you hit doing it remotely:

1. **Headless login** (no browser on the target) — the `c`-to-copy-URL trick.
2. **Update permission error** on a root-owned npm global install.

> ⚠️ **Know which machine you're on.** The whole point is you're driving a *remote*
> box. Wrap **every** mutating command in the SSH call below so you never edit your
> own workstation's `~/.claude` by mistake. Read-only probes first; back up before
> changing anything.

---

## Setup: define the target once

```bash
KEY=~/.ssh/your-key          # the private key for the target
TARGET=user@host             # e.g. em@192.168.100.10

# convenience wrapper — runs its argument ON the target box
on() { ssh -i "$KEY" "$TARGET" "$@"; }
```

Everything below uses `on '<command>'`. If you'd rather not define a function,
just spell out `ssh -i "$KEY" "$TARGET" '<command>'` each time.

---

## Step 0 — Confirm the target is on MiniMax (read-only)

```bash
on '
  jq ".env // \"NO ENV BLOCK\"" ~/.claude/settings.json \
    | sed -E "s/(AUTH_TOKEN\"[[:space:]]*:[[:space:]]*\")[^\"]*/\1***REDACTED***/"
  command -v jq || echo "jq MISSING"
'
```

Expect an `env` block with `ANTHROPIC_BASE_URL` → `api.minimax.io` and models set
to `MiniMax-M2.7` (the auth token is redacted in this readout). If you see
`NO ENV BLOCK`, the box may already be switched — stop and verify before changing
anything.

## Step 1 — Back up the working MiniMax config (stays on the target)

```bash
on '
  BK="$HOME/.claude/backups/minimax-$(date +%Y-%m-%d)"
  mkdir -p "$BK"
  cp -p "$HOME/.claude/settings.json" "$BK/settings.json.minimax.bak"
  [ -f "$HOME/.claude/statusline-command.sh" ] && \
    cp -p "$HOME/.claude/statusline-command.sh" "$BK/statusline-command.minimax.sh"
  jq "{env: .env}" "$HOME/.claude/settings.json" > "$BK/minimax-env-block.json"
  echo "Backed up to: $BK"; ls -la "$BK"
'
```

> This backup contains the real token. It stays on the target machine — do not
> copy it anywhere or commit it.

## Step 2 — Install `jq` on the target if missing

```bash
on 'command -v jq >/dev/null || { sudo apt-get update && sudo apt-get install -y jq; }; jq --version'
```

## Step 3 — Remove the MiniMax env overrides

```bash
on '
  cd "$HOME/.claude"
  jq "
    (.env // {}) as \$e
    | .env = (\$e
        | del(.ANTHROPIC_BASE_URL, .ANTHROPIC_AUTH_TOKEN, .API_TIMEOUT_MS,
              .CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, .ANTHROPIC_MODEL,
              .ANTHROPIC_SMALL_FAST_MODEL, .ANTHROPIC_DEFAULT_SONNET_MODEL,
              .ANTHROPIC_DEFAULT_OPUS_MODEL, .ANTHROPIC_DEFAULT_HAIKU_MODEL))
    | if (.env | length) == 0 then del(.env) else . end
  " settings.json > settings.json.tmp \
    && mv settings.json.tmp settings.json && echo "MiniMax env removed"
  jq empty settings.json && echo "settings.json is valid JSON"
  jq ".env // \"ENV REMOVED\"" settings.json
'
```

## Step 4 — Scan the target's shell startup files for stray exports

```bash
on '
  for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
    [ -f "$f" ] && grep -nE "ANTHROPIC_(BASE_URL|AUTH_TOKEN|MODEL)|api\.minimax" "$f" \
      && echo ">> Found MiniMax exports in $f — remove those lines (back up first)."
  done
  echo "Scan complete."
'
```

## Step 5 — Install the Claude statusline on the target

```bash
on '
  TMP="$(mktemp -d)"
  git clone --depth 1 https://github.com/immanwell/scripts.git "$TMP/scripts"
  cp "$TMP/scripts/claude-statusline/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
  chmod +x "$HOME/.claude/statusline-command.sh"; rm -rf "$TMP"
  cd "$HOME/.claude"
  jq --arg cmd "bash $HOME/.claude/statusline-command.sh" \
     ".statusLine = {type:\"command\", command:\$cmd}" \
     settings.json > settings.json.tmp && mv settings.json.tmp settings.json
  jq ".statusLine" settings.json
'
```

## Step 6 — Verify (automated)

```bash
on '
  cd "$HOME/.claude"
  jq -e "(.env.ANTHROPIC_BASE_URL // \"\") | contains(\"minimax\") | not" settings.json \
    >/dev/null && echo "no MiniMax base URL left"
  NOW=$(date +%s)
  cat <<EOF | bash "$HOME/.claude/statusline-command.sh"
{"workspace":{"current_dir":"$HOME"},"model":{"display_name":"Sonnet 4.6"},
 "effort":{"level":"high"},"cost":{"total_cost_usd":0.14},
 "context_window":{"used_percentage":17},
 "rate_limits":{"five_hour":{"used_percentage":60,"resets_at":$((NOW+3600))},
                "seven_day":{"used_percentage":8,"resets_at":$((NOW+432000))}}}
EOF
'
```

---

## Step 7 — Log in (headless / over SSH) — the `c`-copy trick

You **cannot** be logged in for you from another machine: the login is an OAuth
handshake bound to the `claude` session you start **on the target**, and tokens
don't transfer cleanly between machines (macOS keeps them in the Keychain, not a
file). So this step is interactive and yours — but you don't need a browser *on
the target*:

1. In your SSH session, start Claude Code on the target: `claude`
2. Run `/login` and pick your **Anthropic (Claude Pro/Max) account** — not an API
   key, so you get the native 5h/7d usage tracking.
3. It tries to open a browser locally and can't (headless box). It prints:
   **"Browser didn't open? Use the url below to sign in (c to copy)"**.
   Press **`c`** to copy that URL.
4. Paste the URL into a browser on **any machine already signed into your
   Anthropic account** (e.g. your laptop). Approve. The page shows an
   **authorization code**.
5. **Copy that code and paste it back** into the waiting SSH prompt. Done — Claude
   Code writes the credentials on the target.

**Verify:**
```bash
on 'env | grep ANTHROPIC || echo "clean — no MiniMax routing"'
```
It should no longer show `api.minimax.io` or `MiniMax-M2.7`, and the status bar
should stop saying "Not logged in".

---

## Gotcha: `claude update` fails with "Insufficient permissions"

If Claude Code on the target was installed as a **root-owned npm global**
(`/usr/local/bin/claude` → `node_modules/@anthropic-ai/claude-code`), the built-in
`claude update` self-updater can't write to it and errors out. Update it with the
package manager instead:

```bash
on 'sudo npm install -g @anthropic-ai/claude-code@latest; claude --version'
```

(Works without prompting if the account has passwordless sudo.) Switching to a
native install via `claude install` also fixes auto-updates, but only if
`~/.local/bin` is on the target's `PATH` — otherwise it needs PATH changes, so the
`sudo npm` route above is usually the least-disruptive fix.

---

## Rollback

To return the target to MiniMax, restore the Step 1 backup:

```bash
on '
  BK="$HOME/.claude/backups/minimax-<DATE>"   # the folder from Step 1
  cp "$BK/settings.json.minimax.bak"     "$HOME/.claude/settings.json"
  cp "$BK/statusline-command.minimax.sh" "$HOME/.claude/statusline-command.sh"
'
# then fully restart Claude Code on the target
```

Or follow [`RESTORE.md`](./RESTORE.md) §B.
