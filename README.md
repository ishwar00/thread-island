# ThreadIsland

A Dynamic Island for your coding agents. ThreadIsland sits in the MacBook notch and lists your recent
**Codex** and **Claude Code** threads in one place. Hover to see them, click one to jump straight to it.

If you switch between Codex and Claude Code all day, you know the problem: the thread you want is in
one of four apps or a dozen terminal tabs. ThreadIsland puts all of them in one list, ordered the way
Codex's own activity view orders them.

## What you see

- **Collapsed:** a black pill around the notch. The left side counts threads that need you,
  the right side counts threads that are working.
- **Expanded (hover):** a **Priority** section first, then **Today**, **Yesterday** and one section per
  weekday for the last 7 days. Rows never swap places, so positions stay where you learned them:
  - **Priority** holds threads that are working, need you, or were active in the last 2 hours, oldest
    created on top. A new thread joins at the bottom; a thread idle for 2 hours drops into its day.
  - **Day sections** sort by when you last sent a message.

  Each row starts with the app icon, so you can scan for "the Codex one", and shows its age.
- **Design:** right-click the island to pick one of three designs: Instrument (state lamps in one
  column), Ink (serif titles, age in the margin) or Tide (rounded type, state ring around the icon).
  Nothing moves unless you hover.
- **Health:** each source reads files that an app update can change. If a source breaks, a red line in
  the panel (and a triangle on the pill) says which one, so the list never silently shrinks.

## Where threads come from, and where a click takes you

| Source | Read from | Click |
|---|---|---|
| Codex app | `~/.codex/state_*.sqlite` + the thread's rollout file (status, last reply) | `codex://threads/<id>` |
| Codex CLI | same | focuses its Ghostty window or Warp tab, else `codex resume <id>` in a new session (see below) |
| Claude desktop (Code tab) | `~/Library/Application Support/Claude/claude-code-sessions` | `claude://code/continue?session=<id>` |
| Claude Code background jobs | `~/.claude/jobs/*/state.json` + live `~/.claude/sessions` | focuses the Ghostty window or Warp tab it is attached in, else `claude attach <id>` in a new session (see below) |
| Claude Code CLI sessions | `~/.claude/sessions` | focuses its Ghostty window or Warp tab |

Ghostty terminals are found by TTY through Ghostty's AppleScript dictionary (Ghostty 1.3+). Warp tabs are
found by the `WARP_FOCUS_URL` (`warp://session/<id>`) Warp puts in every session's environment, read only
from sessions that Warp itself started.

A new session opens in the terminal you were just using: a Ghostty window, or a Warp tab (through a
Warp Tab Config, `~/.warp/tab_configs/threadisland.toml`, since Warp's URLs can't run a command). If you
were in neither, it uses whichever is running, Ghostty first.

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
32 s (every 4 s while open, and right away when you open it). It never pops up on its own: you look when you want to.

Run `threads` yourself to see the raw data.

## Limits

- Codex and Claude Code don't publish these file formats. An update can break a source; the health line
  tells you when.
- Codex records when a turn starts and ends, but not when it waits for your approval, so Codex threads
  show as working, never as "needs you". A turn with no writes for 10 minutes stops counting as working.
- Live sessions in terminals other than Ghostty and Warp show in the list but can't be jumped to.
