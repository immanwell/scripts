#!/bin/bash
# Claude Code Custom Statusline for Anthropic
# Displays: folder | branch | context_bar | model | cost
# Standard version without MiniMax-specific quota/peak tracking

CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
MAGENTA=$'\033[0;35m'
GREEN=$'\033[0;32m'
AMBER=$'\033[0;33m'
RED=$'\033[0;31m'
RESET=$'\033[0m'

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
folder=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name')
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Get context usage percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage')
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ] && [ "$used_pct" != "empty" ]; then
  used_pct_int=${used_pct%.*}
  if [ "$used_pct_int" -ge 80 ]; then
    ctx_color=$RED
  elif [ "$used_pct_int" -ge 50 ]; then
    ctx_color=$AMBER
  else
    ctx_color=$GREEN
  fi
  filled=$((used_pct_int / 10))
  empty=$((10 - filled))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  ctx_bar="${ctx_color}[${bar}]${RESET} ${ctx_color}${used_pct_int}%${RESET}"
else
  ctx_bar=""
fi

# Get cost so far
cost=$(echo "$input" | jq -r '.cost.total_cost_usd')
if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "empty" ]; then
  cost_formatted=$(printf "%.2f" "$cost")
  cost_bar="${GREEN}\$${cost_formatted}${RESET}"
else
  cost_bar=""
fi

# Build output string dynamically
parts=""
[ -n "$folder" ] && parts="${CYAN}${folder}${RESET}"
[ -n "$branch" ] && parts="${parts} | ${YELLOW}${branch}${RESET}"
[ -n "$ctx_bar" ] && parts="${parts} | ${ctx_bar}"
[ -n "$model" ] && parts="${parts} | ${MAGENTA}${model}${RESET}"
[ -n "$cost_bar" ] && parts="${parts} | ${cost_bar}"
printf "%s\n" "$parts"
