# Claude Usage Widget

A macOS **menu bar** widget (via [SwiftBar](https://swiftbar.app)) that shows your Claude
**Plan usage limits** — the same session/weekly numbers from `claude.ai/settings/usage` — at a glance:

```
🟢 S 10% · W 42%
   ├─ Session (5h): 10% used   · Resets in 2h 48m
   └─ Weekly (all models): 42% used · Resets Tue 11:00 AM
```

It exists because `/usage` no longer surfaces these plan limits.

## How it works

Every Claude API call returns your subscription usage in HTTP response headers
(`anthropic-ratelimit-unified-5h-utilization`, `…-7d-utilization`, plus `…-reset` timestamps).
The widget sends a tiny 1-token "ping" to `https://api.anthropic.com/v1/messages` using a long-lived
OAuth token and reads those headers — it never needs the response body.

## Setup

```bash
cd claude_usage_widget
./setup.sh
```

`setup.sh` will:
1. `brew install --cask swiftbar` (if not already installed),
2. ask you to run `claude setup-token` and paste the resulting `sk-ant-oat01-…` token,
   which it stores securely in the **macOS Keychain** (service `claude-usage-widget`, no plaintext on disk),
3. mark the plugin executable and symlink it into SwiftBar's plugin folder.

On SwiftBar's first launch you'll be asked to pick a **Plugin Folder** — the default
`~/Library/Application Support/SwiftBar/Plugins` is fine.

## Test it without SwiftBar

```bash
./claude-usage.5m.sh
```

You should see a title line plus a dropdown with two percentages. Cross-check them against
<https://claude.ai/settings/usage>.

## Notes

- **Refresh cadence**: the `.5m.` in the filename means "refresh every 5 minutes". Rename to
  `claude-usage.1m.sh` (1 min) or `.15m.sh` (15 min) to change it. Each refresh costs ~1 token — negligible.
- **Colors**: green `<60%`, amber `60–85%`, red `>85%`; the menu-bar emoji reflects whichever limit is closest.
- **Errors degrade gracefully**: missing token or API failure shows `⚠️ Claude` with details in the dropdown
  instead of breaking the menu bar.
- **Out of scope**: per-model (e.g. Sonnet) breakdown — that would require scraping the claude.ai session
  cookie rather than the OAuth header approach.
