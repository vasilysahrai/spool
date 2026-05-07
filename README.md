# SPOOL

```
 ▄▄▄▄  ▄▄▄▄▄  ▄▄▄▄▄ ▄▄▄▄▄ ▄
█▀ ▀▄ █   █  █   █ █   █ █
▀▄▄▄  █▄▄▄█  █▄▄▄█ █▄▄▄█ █▄▄▄
   ▀█ █      █     █     █
```

A native macOS macro recorder with a hacker-style minimal UI. Record any keys (W/A/S/D/E/Z, modifiers, mouse clicks) and replay them — including key holds and multi-key chords. Built for games like Roblox.

Open source · MIT · zero dependencies · single Swift Package.

## What it does

- Records left/right mouse clicks (with screen position) and any key press/release.
- Captures **key holding** and **multi-key holding** — if you hold W+A for 3 seconds, playback holds W+A for 3 seconds.
- Records modifier keys (Shift, Ctrl, Option, Cmd, Fn) including standalone presses.
- Big monospace **stopwatch** while recording (mm:ss.cs).
- Configurable **global hotkeys** for Record / Pause / Stop / Play.
- Saves macros locally as JSON (`~/Library/Application Support/Spool/macros.json`). Rename, replay, delete.
- Posts events at the HID level (`.cghidEventTap`, `.hidSystemState`) for maximum compatibility with games.

## Default hotkeys

| Action | Key |
|---|---|
| Record / Stop | `F6` |
| Pause / Resume | `F7` |
| Stop | `F8` |
| Play (selected) | `F9` |

All four are remappable in the **HOTKEYS** panel.

## Build

Requires macOS 13+ and the Apple Swift toolchain (Xcode or Command Line Tools).

```bash
git clone https://github.com/vasilysahrai/spool.git
cd spool
./build_app.sh
open Spool.app
```

The build script runs `swift build -c release`, wraps the binary in a proper `.app` bundle with `Info.plist`, and ad-hoc signs it.

## First run — Accessibility permission

macOS requires **Accessibility** permission to monitor and post system input events. On first record attempt, Spool will prompt you. You can also open it directly:

```
System Settings → Privacy & Security → Accessibility → enable Spool
```

You may need to quit and relaunch Spool once after granting.

## How to use

1. Launch `Spool.app`.
2. Press your **Record** hotkey (default `F6`).
3. A 300 ms grace period gives you time to alt-tab into your game.
4. Do whatever sequence you want recorded — clicks, key holds, chords.
5. Press **Stop** (default `F8`) — Spool prompts you to name the macro.
6. Select a macro in the list, press **Play** (default `F9`) to replay.

The right pane shows a live stopwatch and event count while recording. The left pane lists saved macros with duration, event count, and timestamp. Right-click a macro for play / rename / delete.

## How accurate is playback?

Spool replays events with their original relative timestamps, accurate to the millisecond. Multi-key holds are preserved by recording each `keyDown` / `keyUp` independently — the player schedules them on a high-resolution timer and posts them as low-level HID events.

If a game uses anti-automation that fingerprints synthetic events, Spool can't bypass that — and shouldn't try to. Use it for personal automation in games and apps that allow it.

## Storage

```
~/Library/Application Support/Spool/
  macros.json     # all your macros
  hotkeys.json    # your custom hotkey bindings
```

JSON, plain-text, version-controllable.

## File structure

```
spool/
├── Package.swift
├── build_app.sh
└── Sources/Spool/
    ├── App.swift            # @main entry, NSApplicationDelegateAdaptor
    ├── AppController.swift  # central state + hotkey wiring
    ├── ContentView.swift    # main UI (split-pane, stopwatch, controls)
    ├── Sheets.swift         # save prompt + hotkey settings
    ├── Recorder.swift       # CGEventTap (.listenOnly, .cgSessionEventTap)
    ├── Player.swift         # CGEvent.post (.cghidEventTap, .hidSystemState)
    ├── Store.swift          # JSON persistence
    ├── Hotkeys.swift        # Carbon RegisterEventHotKey wrapper
    ├── KeyMap.swift         # keycode → label
    ├── Models.swift         # Macro, MacroEvent, HotkeyDef
    └── Theme.swift          # colors / fonts (phosphor green on black)
```

Roughly 800 lines of Swift, no third-party dependencies.

## License

MIT — see [LICENSE](LICENSE).
