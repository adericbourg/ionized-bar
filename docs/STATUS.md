# Implementation status

_Last updated: 2026-11-02_

Scope, requirement numbers (R1–R9) and milestones come from [PRODUCT.md](PRODUCT.md).

Legend: ✅ done · 🚧 in progress · ⬜ not started · ⛔ blocked

## Overview

| Milestone | Status | Progress |
|---|---|---|
| M0 – Bootstrap | 🚧 | 4/5 |
| M1 – Window model (headless) | ⬜ | 0/5 |
| M2 – Bars | ⬜ | 0/6 |
| M3 – Dock replacement and launch at login | ⬜ | 0/4 |
| M4 – Push windows away | ⬜ | 0/3 |
| M5 – Release | ⬜ | 0/3 |

## Requirements

| # | Requirement | Milestone | Status |
|---|---|---|---|
| R1 | Taskbar | M2 | ⬜ |
| R2 | One bar per display | M2 | ⬜ |
| R3 | Per-display tasks | M1 | ⬜ |
| R4 | Real windows only | M1 | ⬜ |
| R5 | Equal width | M2 | ⬜ |
| R6 | Replaces the Dock | M3 | ⬜ |
| R7 | Launch at login | M3 | ⬜ |
| R8 | Current Space only | M1 | ⬜ |
| R9 | Push windows away | M4 | ⬜ |

## Milestones

### M0 – Bootstrap
- [x] `LICENSE` (GPLv3)
- [x] `README.md`
- [x] `docs/PRODUCT.md`
- [x] Empty SwiftPM app (Swift 6, AppKit, `LSUIElement`, not sandboxed)
- [ ] CI build (GitHub Actions)

### M1 – Window model (headless)
- [ ] App launch and terminate tracking (`NSWorkspace`)
- [ ] One `AXObserver` per app (created, destroyed, moved, resized, title, minimized, focused)
- [ ] Standard-window filtering (R4) and current-Space filtering (R8)
- [ ] Display assignment by largest intersection (R3)
- [ ] Unit tests: coordinate conversion, display assignment, equal-width layout math

### M2 – Bars
- [ ] One non-activating `NSPanel` per screen, following screen add, remove and resize (R2)
- [ ] Entry view: icon, title, active, minimized and hover states (R1)
- [ ] Equal-width layout with icon-only fallback (R5)
- [ ] Interactions: click, click on active, middle-click, context menu
- [ ] Frosted glass vs Liquid Glass prototype, pick one
- [ ] VoiceOver labels, keyboard access, Reduce Transparency and Reduce Motion

### M3 – Dock replacement and launch at login
- [ ] Save the Dock prefs, then autohide with a huge delay (R6)
- [ ] Restore on quit, and recover after a crash on the next launch (R6)
- [ ] Launch at login via `SMAppService` (R7)
- [ ] Accessibility permission onboarding

### M4 – Push windows away
- [ ] Detect windows that overlap the bar (R9)
- [ ] Resize or move them through AX, with debounce
- [ ] Skip fullscreen windows

### M5 – Release
- [ ] Archive and zip the build
- [ ] Cask in `adericbourg/homebrew-tap`
- [ ] Clean-account install check (`brew install --cask adericbourg/tap/ionized-bar`)

## Known issues (tracked)

| Issue | Status |
|---|---|
| Accessibility grant lost on every `brew upgrade` (unsigned build) | ⬜ open, accepted for v1 |
| Gatekeeper quarantine on install | ⬜ open, accepted for v1 |

## Log

- 2026-11-02 — Product framing done, license, README and product brief committed.
- 2026-11-02 — Added this status document and the project `CLAUDE.md` rule to keep it updated after every task.
- 2026-11-02 — Empty SwiftPM app (`Package.swift`, `Info.plist`, `scripts/bundle.sh`) builds into a signed `.app` that runs as an agent app. M0 at 4/5.
