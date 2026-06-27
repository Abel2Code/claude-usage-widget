#!/bin/bash
#
# <bitbar.title>Claude Usage</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>claude_usage_widget</bitbar.author>
# <bitbar.desc>Shows Claude Max plan session + weekly usage limits in the menu bar.</bitbar.desc>
# <bitbar.dependencies>curl,python3</bitbar.dependencies>
# <swiftbar.hideAbout>false</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>false</swiftbar.hideRunInTerminal>
#
# SwiftBar plugin: filename suffix ".5m." => refresh every 5 minutes.
# Reads an OAuth token from the macOS Keychain, pings the Anthropic API, and
# renders the rate-limit headers Anthropic returns (session + weekly usage).

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/anaconda3/bin:$PATH"
USAGE_URL="https://claude.ai/settings/usage"

# Absolute path to this script (used by the in-menu toggle buttons).
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# What the menu-bar title shows: session | weekly | both. Stored in a tiny config
# file so the dropdown toggle can change it. Defaults to session-only.
CONFIG_DIR="$HOME/.config/claude-usage-widget"
MODE_FILE="$CONFIG_DIR/menubar_mode"

# Toggle handler: invoked as `script --set-mode <mode>` by the dropdown buttons.
if [ "${1:-}" = "--set-mode" ] && [ -n "${2:-}" ]; then
  mkdir -p "$CONFIG_DIR"
  printf '%s' "$2" > "$MODE_FILE"
  exit 0
fi

MODE="$(cat "$MODE_FILE" 2>/dev/null || echo session)"
case "$MODE" in session|weekly|both) ;; *) MODE="session" ;; esac

TOKEN="$(security find-generic-password -s claude-usage-widget -a oauth -w 2>/dev/null)"

if [ -z "$TOKEN" ]; then
  echo "⚠️ Claude"
  echo "---"
  echo "No OAuth token in Keychain"
  echo "Run setup.sh to configure it | color=#888888"
  echo "---"
  echo "Open usage page | href=$USAGE_URL"
  exit 0
fi

# Capture response headers only; body is discarded (1-token ping).
HEADERS="$(curl -sS --max-time 15 -o /dev/null -D - https://api.anthropic.com/v1/messages \
  -H "authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "content-type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"."}]}' 2>&1)"

HEADERS_RAW="$HEADERS" MODE="$MODE" SELF="$SELF" python3 <<'PY'
import os, sys, re, time, datetime

USAGE_URL = "https://claude.ai/settings/usage"
MODE = os.environ.get("MODE", "session")
SELF = os.environ.get("SELF", "")
raw = os.environ.get("HEADERS_RAW", "")

# Parse "Header: value" lines (case-insensitive keys).
h, status_line = {}, ""
for line in raw.splitlines():
    if line.upper().startswith("HTTP/"):
        status_line = line.strip()
        continue
    m = re.match(r'^([A-Za-z0-9\-]+):\s*(.*)$', line)
    if m:
        h[m.group(1).lower()] = m.group(2).strip()

def num(name):
    try:
        return float(h[name])
    except (KeyError, ValueError, TypeError):
        return None

s_util  = num('anthropic-ratelimit-unified-5h-utilization')
s_reset = num('anthropic-ratelimit-unified-5h-reset')
w_util  = num('anthropic-ratelimit-unified-7d-utilization')
w_reset = num('anthropic-ratelimit-unified-7d-reset')
status  = h.get('anthropic-ratelimit-unified-status')

# Error path: no usable headers came back.
if s_util is None and w_util is None:
    print("⚠️ Claude")
    print("---")
    if status_line:
        print(f"{status_line} | color=#e53935")
    else:
        print("Could not reach Anthropic API | color=#e53935")
    snippet = raw.strip().splitlines()[:6]
    if snippet:
        print("---")
        for s in snippet:
            print(s.replace("|", "/")[:120] + " | font=Menlo size=10 color=#888888")
    print("---")
    print(f"Open usage page | href={USAGE_URL}")
    print("Refresh | refresh=true")
    sys.exit(0)

def pct(util):
    if util is None:
        return None
    return round(util * 100 if util <= 1 else util)

def color(p):
    if p is None:   return "#888888"
    if p < 60:      return "#4caf50"
    if p < 85:      return "#ffb300"
    return "#e53935"

def emoji(p):
    if p is None:   return "⚪️"
    if p < 60:      return "🟢"
    if p < 85:      return "🟡"
    return "🔴"

now = time.time()

def countdown(reset):
    if not reset:
        return ""
    secs = int(reset - now)
    if secs <= 0:
        return "now"
    hrs, mins = secs // 3600, (secs % 3600) // 60
    return f"{hrs}h {mins}m" if hrs else f"{mins}m"

def absfmt(reset):
    if not reset:
        return ""
    return datetime.datetime.fromtimestamp(reset).strftime("%a %-I:%M %p")

sp, wp = pct(s_util), pct(w_util)
worst = max([p for p in (sp, wp) if p is not None], default=None)

# --- Menu bar title (depends on MODE) ---
if MODE == "weekly":
    title_emoji, title_txt = emoji(wp), (f"W {wp}%" if wp is not None else "W —")
elif MODE == "both":
    bits = []
    if sp is not None: bits.append(f"S {sp}%")
    if wp is not None: bits.append(f"W {wp}%")
    title_emoji, title_txt = emoji(worst), " · ".join(bits)
else:  # session (default)
    title_emoji, title_txt = emoji(sp), (f"S {sp}%" if sp is not None else "S —")
print(f"{title_emoji} {title_txt}")

# --- Dropdown ---
print("---")
print("Claude — Plan usage | size=12 color=#aaaaaa")
print("---")
if sp is not None:
    print(f"Session (5h): {sp}% used | color={color(sp)}")
    cd = countdown(s_reset)
    if cd:
        print(f"Resets in {cd} | color=#888888 size=11")
print("---")
if wp is not None:
    print(f"Weekly (all models): {wp}% used | color={color(wp)}")
    af = absfmt(w_reset)
    if af:
        print(f"Resets {af} | color=#888888 size=11")
if status and status not in ("allowed",):
    print("---")
    print(f"Status: {status} | color=#e53935 size=11")
print("---")
print("Menu bar shows | size=11 color=#888888")
for key, label in (("session", "Session %"), ("weekly", "Weekly %"), ("both", "Both")):
    mark = "✓ " if MODE == key else "    "
    print(f"{mark}{label} | bash=\"{SELF}\" param1=--set-mode param2={key} terminal=false refresh=true")
print("---")
print("Refresh now | refresh=true")
print(f"Open usage page | href={USAGE_URL}")
PY
