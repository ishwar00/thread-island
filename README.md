# ThreadIsland

A Dynamic Island for your coding agents. ThreadIsland sits in the MacBook notch and lists your recent
**Codex** and **Claude Code** threads in one place. Hover to see them, click one to jump straight to it.

If you switch between Codex and Claude Code all day, you know the problem: the thread you want is in
one of four apps or a dozen terminal tabs. ThreadIsland puts all of them in one list, ordered the way
Codex's own activity view orders them.

## What you see

- **Collapsed:** a black pill around the notch. The left side counts threads that need you (orange),
  the right side counts threads that are working (green).
- **Alerts:** when a thread starts to need you, or a working thread finishes, the pill widens for six
  seconds and shows which one. Click it to go there.
- **Expanded (hover):** a **Priority** section first (needs you, then working), then **Today**,
  **Yesterday** and one section per weekday for the last 7 days. Each row starts with the app icon,
  so you can scan for "the Codex one" by color, and the age is right under the title.
- **Health:** each source reads files that an app update can change. If a source breaks, a red line in
  the panel (and a triangle on the pill) says which one, so the list never silently shrinks.

## Where threads come from, and where a click takes you

| Source | Read from | Click |
|---|---|---|
| Codex app | `~/.codex/state_*.sqlite` + the thread's rollout file (status, last reply) | `codex://threads/<id>` |
| Codex CLI | same | focuses its Ghostty tab, else a new tab running `codex resume <id>` |
| Claude desktop (Code tab) | `~/Library/Application Support/Claude/claude-code-sessions` | `claude://code/continue?session=<id>` |
| Claude Code background jobs | `~/.claude/jobs/*/state.json` + live `~/.claude/sessions` | focuses the Ghostty tab it is attached in, else `claude attach <id>` in a new tab |
| Claude Code CLI sessions | `~/.claude/sessions` | focuses its Ghostty tab |

Ghostty tabs are found by TTY through Ghostty's AppleScript dictionary (Ghostty 1.3+).

## Install

Needs macOS 14+, Xcode Command Line Tools (`xcode-select --install`) and the system Python 3.

```sh
git clone https://github.com/ishwar00/thread-island.git ~/.local/share/thread-island
~/.local/share/thread-island/build.sh
open ~/Applications/ThreadIsland.app
```

On the first jump into Ghostty, macOS asks whether ThreadIsland may control Ghostty. Allow it.
To start it at login, add `~/Applications/ThreadIsland.app` in System Settings → General → Login Items.
Right-click the island to quit.

## How it works

`threads` (Python, standard library only) gathers every source into one JSON list, and `threads --jump`
opens one row. `main.swift` is only the UI: a borderless panel at the notch that runs `threads` every
12 s (every 4 s while open) and diffs states to raise alerts.

Run `threads` yourself to see the raw data.

## Limits

- Codex and Claude Code don't publish these file formats. An update can break a source; the health line
  tells you when.
- Codex records when a turn starts and ends, but not when it waits for your approval, so Codex threads
  show as working, never as "needs you". A turn with no writes for 10 minutes stops counting as working.
- Terminals other than Ghostty have no way to focus a given tab, so live sessions there can't be jumped to.
