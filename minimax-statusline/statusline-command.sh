#!/bin/bash
# Claude Code Custom Statusline for MiniMax
# Displays: folder | branch | context_bar | model · peak | quota | cost
# Works with MiniMax API (requires mmx CLI for quota data)

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

# Check if current China time (UTC+8) is on-peak (weekdays 15:00-17:30)
china_hour=$(TZ='Asia/Shanghai' date +'%H')
china_min=$(TZ='Asia/Shanghai' date +'%M')
china_dow=$(TZ='Asia/Shanghai' date +'%u')

on_peak=false
if [ "$china_dow" -le 5 ]; then
  if [ "$china_hour" -gt 15 ] && [ "$china_hour" -lt 17 ]; then
    on_peak=true
  elif [ "$china_hour" -eq 15 ] && [ "$china_min" -ge 0 ]; then
    on_peak=true
  elif [ "$china_hour" -eq 17 ] && [ "$china_min" -le 30 ]; then
    on_peak=true
  fi
fi

if [ "$on_peak" = true ]; then
  peak_indicator="${RED}⚡on-peak${RESET}"
else
  peak_indicator="${GREEN}🌙off-peak${RESET}"
fi

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

# Get rate limits from mmx quota (MiniMax-specific)
quota_json=$(mmx quota 2>/dev/null)
if [ -n "$quota_json" ]; then
  daily=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .current_interval_usage_count')
  daily_total=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .current_interval_total_count')
  weekly=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .current_weekly_usage_count')
  weekly_total=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .current_weekly_total_count')
  daily_reset_ms=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .remains_time')
  weekly_reset_ms=$(echo "$quota_json" | jq -r '.model_remains[] | select(.model_name == "MiniMax-M*") | .weekly_remains_time')

  if [ -n "$daily" ] && [ -n "$daily_total" ] && [ "$daily_total" -gt 0 ]; then
    daily_pct=$((daily * 100 / daily_total))
  else
    daily_pct=0
  fi

  if [ -n "$weekly" ] && [ -n "$weekly_total" ] && [ "$weekly_total" -gt 0 ]; then
    weekly_pct=$((weekly * 100 / weekly_total))
  else
    weekly_pct=0
  fi

  quota_daily="${AMBER}D:${daily_pct}%"
  if [ -n "$daily_reset_ms" ] && [ "$daily_reset_ms" -gt 0 ]; then
    daily_reset_min=$((daily_reset_ms / 60000))
    daily_reset_hours=$((daily_reset_ms / 3600000))
    if [ "$daily_reset_min" -ge 60 ]; then
      quota_daily="${quota_daily} ↺${daily_reset_hours}h"
    else
      quota_daily="${quota_daily} ↺${daily_reset_min}m"
    fi
  fi

  quota_weekly="${AMBER}W:${weekly_pct}%"
  if [ -n "$weekly_reset_ms" ] && [ "$weekly_reset_ms" -gt 0 ]; then
    weekly_reset_hours=$((weekly_reset_ms / 1000 / 60 / 60))
    if [ "$weekly_reset_hours" -ge 24 ]; then
      weekly_reset_days=$((weekly_reset_hours / 24))
      quota_weekly="${quota_weekly} ↺${weekly_reset_days}d"
    else
      [ "$weekly_reset_hours" -lt 1 ] && weekly_reset_hours=1
      quota_weekly="${quota_weekly} ↺${weekly_reset_hours}h"
    fi
  fi

  quota_bar="${quota_daily} · ${quota_weekly}${RESET}"
else
  quota_bar=""
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
parts="${parts} | ${MAGENTA}${model}${RESET} · ${peak_indicator}"
[ -n "$quota_bar" ] && parts="${parts} | ${quota_bar}"
[ -n "$cost_bar" ] && parts="${parts} | ${cost_bar}"
printf "%s\n" "$parts"
