#!/usr/bin/env bash
#
# switch-to-claude.sh
# One-shot: switch Claude Code on this machine from the MiniMax API to a real
# Anthropic Claude model, and install the upgraded Claude statusline.
#
# Safe to run by a human OR an agent. Idempotent. Backs up first. Never prints
# or transmits your API token. The interactive `/login` is left to you at the end.
#
# Usage:
#   git clone https://github.com/immanwell/scripts.git
#   bash scripts/switch-to-claude.sh
#
# Rollback: see RESTORE.md (section B) or restore the backup printed below.

set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE="$CLAUDE_DIR/statusline-command.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW="https://raw.githubusercontent.com/immanwell/scripts/main/claude-statusline/statusline-command.sh"

c_green=$'\033[0;32m'; c_red=$'\033[0;31m'; c_amber=$'\033[0;33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
ok()   { printf '%s✅ %s%s\n' "$c_green" "$*" "$c_off"; }
warn() { printf '%s⚠️  %s%s\n' "$c_amber" "$*" "$c_off"; }
die()  { printf '%s❌ %s%s\n' "$c_red"   "$*" "$c_off" >&2; exit 1; }
step() { printf '\n%s── %s%s\n' "$c_dim" "$*" "$c_off"; }

# ---------------------------------------------------------------------------
step "Pre-flight checks"
[ -f "$SETTINGS" ] || die "No $SETTINGS found. Is Claude Code installed for this user?"

# Ensure jq is available (install via the machine's package manager if needed)
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found — attempting to install it…"
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y jq
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y jq
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm jq
  elif command -v brew    >/dev/null 2>&1; then brew install jq
  else die "Could not auto-install jq. Install it manually, then re-run."
  fi
fi
command -v jq >/dev/null 2>&1 || die "jq still not available after install attempt."
ok "jq present: $(jq --version)"

jq empty "$SETTINGS" 2>/dev/null || die "$SETTINGS is not valid JSON. Fix it before running."

# Detect whether this machine is actually on MiniMax
on_minimax=$(jq -r '((.env.ANTHROPIC_BASE_URL // "") | contains("minimax"))
                    or ((.env.ANTHROPIC_MODEL // "") | startswith("MiniMax"))' "$SETTINGS")
if [ "$on_minimax" != "true" ]; then
  warn "This machine does not appear to be on MiniMax (no MiniMax env block found)."
  warn "Will still (re)install the Claude statusline, but skip env removal."
fi

# ---------------------------------------------------------------------------
step "Step 1/5 — Back up current config (local only; contains your token)"
BK="$CLAUDE_DIR/backups/minimax-$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$BK"
cp -p "$SETTINGS" "$BK/settings.json.minimax.bak"
[ -f "$STATUSLINE" ] && cp -p "$STATUSLINE" "$BK/statusline-command.minimax.sh"
jq '{env: (.env // {})}' "$SETTINGS" > "$BK/minimax-env-block.json"
ok "Backed up to: $BK"

# ---------------------------------------------------------------------------
step "Step 2/5 — Remove MiniMax env overrides from settings.json"
if [ "$on_minimax" = "true" ]; then
  tmp="$(mktemp)"
  jq '
    (.env // {}) as $e
    | .env = ($e | del(
        .ANTHROPIC_BASE_URL, .ANTHROPIC_AUTH_TOKEN, .API_TIMEOUT_MS,
        .CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, .ANTHROPIC_MODEL,
        .ANTHROPIC_SMALL_FAST_MODEL, .ANTHROPIC_DEFAULT_SONNET_MODEL,
        .ANTHROPIC_DEFAULT_OPUS_MODEL, .ANTHROPIC_DEFAULT_HAIKU_MODEL))
    | if (.env | length) == 0 then del(.env) else . end
  ' "$SETTINGS" > "$tmp" || die "jq failed editing settings.json (original untouched)."
  jq empty "$tmp" 2>/dev/null || die "Edited settings.json was invalid (original untouched)."
  mv "$tmp" "$SETTINGS"
  ok "MiniMax env keys removed."
else
  ok "Skipped (not on MiniMax)."
fi

# ---------------------------------------------------------------------------
step "Step 3/5 — Check shell startup files for stray MiniMax exports"
found_exports=0
for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
  [ -f "$f" ] || continue
  hits=$(grep -nE 'ANTHROPIC_(BASE_URL|AUTH_TOKEN|MODEL)|api\.minimax' "$f" 2>/dev/null)
  if [ -n "$hits" ]; then
    found_exports=1
    warn "Found MiniMax exports in $f (these override settings.json — remove them):"
    printf '%s\n' "$hits"
    echo "    To remove: cp \"$f\" \"$f.bak\" && sed -i.bak '/api\\.minimax\\|ANTHROPIC_AUTH_TOKEN\\|ANTHROPIC_BASE_URL\\|ANTHROPIC_.*MODEL/d' \"$f\""
  fi
done
[ "$found_exports" -eq 0 ] && ok "No MiniMax exports in shell startup files."

# ---------------------------------------------------------------------------
step "Step 4/5 — Install the Claude statusline"
SRC="$SCRIPT_DIR/claude-statusline/statusline-command.sh"
if [ -f "$SRC" ]; then
  cp "$SRC" "$STATUSLINE"
  ok "Installed from repo: $SRC"
else
  warn "Sibling claude-statusline not found; downloading from GitHub…"
  if   command -v curl >/dev/null 2>&1; then curl -fsSL "$REPO_RAW" -o "$STATUSLINE" || die "Download failed."
  elif command -v wget >/dev/null 2>&1; then wget -qO "$STATUSLINE" "$REPO_RAW" || die "Download failed."
  else die "Need curl or wget to download the statusline, or run this from inside the cloned repo."
  fi
  ok "Downloaded statusline from GitHub."
fi
chmod +x "$STATUSLINE"

# Point settings.json at it (idempotent, uses this machine's $HOME)
tmp="$(mktemp)"
jq --arg cmd "bash $STATUSLINE" '.statusLine = {type:"command", command:$cmd}' \
   "$SETTINGS" > "$tmp" && jq empty "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS" \
   || die "Failed to wire statusLine into settings.json."
ok "settings.json statusLine -> bash $STATUSLINE"

# ---------------------------------------------------------------------------
step "Step 5/5 — Verify"
jq -e '(.env.ANTHROPIC_BASE_URL // "") | contains("minimax") | not' "$SETTINGS" >/dev/null \
  && ok "No MiniMax base URL left in settings env." \
  || die "MiniMax base URL still present — investigate."

echo "Sample render:"
NOW=$(date +%s)
cat <<EOF | bash "$STATUSLINE"
{"workspace":{"current_dir":"$HOME"},"model":{"display_name":"Sonnet 4.6"},
 "effort":{"level":"high"},"cost":{"total_cost_usd":0.14},
 "context_window":{"used_percentage":17},
 "rate_limits":{"five_hour":{"used_percentage":60,"resets_at":$((NOW+3600))},
                "seven_day":{"used_percentage":8,"resets_at":$((NOW+432000))}}}
EOF

# ---------------------------------------------------------------------------
printf '\n%s========================================%s\n' "$c_green" "$c_off"
ok "Automated switch complete."
cat <<'NEXT'

Two manual steps remain (an agent/script can't do these):

  1. Fully RESTART Claude Code  (quit & reopen, or start a fresh `claude`).
  2. Run  /login  and sign in with your Anthropic (Claude Pro/Max) account.
       - The "Not logged in" warning disappears.
       - The 5h / 7d usage segments appear (subscription only, not API billing).

Verify after restart:
     env | grep ANTHROPIC      # should NOT show api.minimax.io or MiniMax-M2.7

Rollback: see RESTORE.md (section B), or restore the backup printed in Step 1.
NEXT
