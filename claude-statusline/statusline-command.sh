#!/bin/bash
# Claude Code Custom Statusline for Anthropic (Claude)
# Displays: folder | branch | context_bar | model · effort | 5h / 7d usage | cost
# Uses native Claude Code statusline fields (rate_limits, effort). Only dependency: jq.
# Segments are omitted gracefully when their data isn't present (e.g. rate_limits
# only populate on a Pro/Max subscription login, not on API-key billing).

CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
MAGENTA=$'\033[0;35m'
GREEN=$'\033[0;32m'
AMBER=$'\033[0;33m'
RED=$'\033[0;31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
folder=$(basename "$cwd" 2>/dev/null)
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Color a 0-100 percentage: green <50, amber 50-79, red >=80
pct_color() {
  local p=$1
  if [ "$p" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 50 ]; then printf '%s' "$AMBER"
  else printf '%s' "$GREEN"; fi
}

# Repeat a character N times (safe for N=0; avoids BSD `seq 1 0` quirk on macOS)
repeat_char() {
  local n=$1 ch=$2 s=""
  while [ "$n" -gt 0 ]; do s="${s}${ch}"; n=$((n - 1)); done
  printf '%s' "$s"
}

# Humanize a seconds-remaining value into Xd / Xh / Xm
fmt_reset() {
  local secs=$1
  [ "$secs" -le 0 ] && { printf ''; return; }
  local mins=$((secs / 60)) hours=$((secs / 3600)) days=$((secs / 86400))
  if   [ "$days"  -ge 1 ]; then printf '%sd' "$days"
  elif [ "$hours" -ge 1 ]; then printf '%sh' "$hours"
  else printf '%sm' "$mins"; fi
}

# Build one rate-limit segment: label + colored pct + reset countdown
rl_segment() {
  local label=$1 pct_path=$2 reset_path=$3
  local pct reset col secs r
  pct=$(echo "$input" | jq -r "$pct_path // empty")
  [ -z "$pct" ] || [ "$pct" = "null" ] && return
  pct=${pct%.*}
  col=$(pct_color "$pct")
  local seg="${col}${label}:${pct}%"
  reset=$(echo "$input" | jq -r "$reset_path // empty")
  if [ -n "$reset" ] && [ "$reset" != "null" ]; then
    secs=$((reset - $(date +%s)))
    r=$(fmt_reset "$secs")
    [ -n "$r" ] && seg="${seg} ↺${r}"
  fi
  printf '%s%s' "$seg" "$RESET"
}

# ---- context window bar ----
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_bar=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  upi=${used_pct%.*}
  cc=$(pct_color "$upi")
  [ "$upi" -gt 100 ] && upi=100
  filled=$((upi / 10)); empty=$((10 - filled))
  bar="$(repeat_char "$filled" █)$(repeat_char "$empty" ░)"
  ctx_bar="${cc}[${bar}]${RESET} ${cc}${upi}%${RESET}"
fi

# ---- rate limits (subscription usage: 5-hour + 7-day) ----
five=$(rl_segment "5h" ".rate_limits.five_hour.used_percentage" ".rate_limits.five_hour.resets_at")
seven=$(rl_segment "7d" ".rate_limits.seven_day.used_percentage" ".rate_limits.seven_day.resets_at")
rl_parts=""
[ -n "$five" ]  && rl_parts="$five"
[ -n "$seven" ] && { [ -n "$rl_parts" ] && rl_parts="${rl_parts} · ${seven}" || rl_parts="$seven"; }

# ---- model (+ effort level) ----
model_seg=""
if [ -n "$model" ]; then
  model_seg="${MAGENTA}${model}${RESET}"
  [ -n "$effort" ] && [ "$effort" != "null" ] && \
    model_seg="${model_seg} ${DIM}·${RESET} ${MAGENTA}${effort}${RESET}"
fi

# ---- cost ----
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_bar=""
[ -n "$cost" ] && [ "$cost" != "null" ] && cost_bar="${GREEN}\$$(printf '%.2f' "$cost")${RESET}"

# ---- assemble ----
parts=""
[ -n "$folder" ]    && parts="${CYAN}${folder}${RESET}"
[ -n "$branch" ]    && parts="${parts} | ${YELLOW}${branch}${RESET}"
[ -n "$ctx_bar" ]   && parts="${parts} | ${ctx_bar}"
[ -n "$model_seg" ] && parts="${parts} | ${model_seg}"
[ -n "$rl_parts" ]  && parts="${parts} | ${rl_parts}"
[ -n "$cost_bar" ]  && parts="${parts} | ${cost_bar}"
printf "%s\n" "${parts# | }"
