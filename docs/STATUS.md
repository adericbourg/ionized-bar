# Implementation status

_Last updated: 2026-11-02_

Scope, requirement numbers (R1–R9) and milestones come from [PRODUCT.md](PRODUCT.md).

Legend: ✅ done · 🚧 in progress · ⬜ not started · ⛔ blocked

## Overview

| Milestone | Status | Progress |
|---|---|---|
| M0 – Bootstrap | ✅ | 5/5 |
| M1 – Window model (headless) | ✅ | 5/5 |
| M2 – Bars | 🚧 | 4/6 |
| M3 – Dock replacement and launch at login | ⬜ | 0/4 |
| M4 – Push windows away | ⬜ | 0/3 |
| M5 – Release | ⬜ | 0/3 |
| M6 – Window preview | ⬜ | 0/6 |
| M7 – Settings | ✅ | 6/6 |

## Requirements

| # | Requirement | Milestone | Status |
|---|---|---|---|
| R1 | Taskbar | M2 | 🚧 |
| R2 | One bar per display | M2 | 🚧 |
| R3 | Per-display tasks | M1 | ✅ |
| R4 | Real windows only | M1 | ✅ |
| R5 | Equal width | M2 | 🚧 |
| R6 | Replaces the Dock | M3 | ⬜ |
| R7 | Launch at login | M3 | ⬜ |
| R8 | Current Space only | M1 | ✅ |
| R9 | Push windows away | M4 | ⬜ |

## Milestones

### M0 – Bootstrap
- [x] `LICENSE` (GPLv3)
- [x] `README.md`
- [x] `docs/PRODUCT.md`
- [x] Empty SwiftPM app (Swift 6, AppKit, `LSUIElement`, not sandboxed)
- [x] CI build (GitHub Actions)

### M1 – Window model (headless)
- [x] App launch and terminate tracking (`NSWorkspace`)
- [x] One `AXObserver` per app (created, destroyed, moved, resized, title, minimized, focused)
- [x] Standard-window filtering (R4) and current-Space filtering (R8)
- [x] Display assignment by largest intersection (R3)
- [x] Checks (`swift run IonizedBarChecks`): coordinate conversion, display assignment, equal-width layout math, `isRealWindow`, `isOnCurrentSpace`

### M1 manual pass
- [x] Space switch: the list updates and the CG list settles
- [x] A real window on another Space is filtered
- [x] Real mouse drag, with a terminal spinner running in another app
- [x] Close latency is about 1s
- [x] Click-driven `setFrontmost`
- [x] Screen-parameter change
- [x] Restore from minimized
- [x] Chromium or Electron subrole while minimized and hidden
- [x] An app whose AX frame might differ from CG bounds (Electron, Qt or Java)
- [x] Window moved between Spaces in Mission Control
- [x] First CI run of the checks step (fall back to macOS 27.0 per PRODUCT.md if it cannot load)

### M2 – Bars
- [x] One non-activating `NSPanel` per screen, following screen add, remove and resize (R2)
- [x] Entry view: icon, title, active, minimized and hover states (R1)
- [x] Equal-width layout with icon-only fallback (R5)
- [x] Interactions: click, click on active, middle-click, context menu
- [ ] Frosted glass vs Liquid Glass prototype, pick one
  - Compare: `open --env IONIZED_BAR_MATERIAL=liquid --stderr "$(tty)" build/IonizedBar.app` (Liquid Glass); without the env, frosted (default).
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

### M6 – Window preview
- [ ] Spike: can `SCScreenshotManager` capture a minimized window? Record the result and whether a cache is needed
- [ ] Opt-in setting and Screen Recording request (off by default, no prompt until enabled)
- [ ] Match the entry's window to an `SCWindow` and capture a thumbnail, with a header-only fallback when ambiguous
- [ ] Preview panel above the entry: hover delay, keyboard focus, Esc, stays open under the pointer
- [ ] Minimized windows: live capture or in-memory last capture, per the spike
- [ ] Reduce Motion, Reduce Transparency and contrast on the preview panel; manual pass

### M7 – Settings
- [x] Grouping decision with checks (`appsToGroup`, `barItems`)
- [x] Saved settings, re-applied to the bars without waiting for a window event
- [x] Task display modes: Icon only, App name, Content
- [x] Group entries and their window list
- [x] Settings window, and "Settings…" on entries and the empty bar
- [x] Manual pass

## Known issues (tracked)

| Issue | Status |
|---|---|
| Accessibility grant lost on every `brew upgrade` (unsigned build) | ⬜ open, accepted for v1 |
| Gatekeeper quarantine on install | ⬜ open, accepted for v1 |
| A minimized window on another Space cannot be told apart, so it is listed (public APIs cannot map an AX element to a `CGWindowID`) | ⬜ open, accepted for v1 |
| Native tabs are listed as duplicates while minimized (one entry per tab, seen on TextEdit; not seen while hidden) | ⬜ open, accepted for v1 |
| A hidden app's dialogs, and minimized dialogs, can be listed: real windows read as `AXDialog` in those states on macOS 27.2, so they cannot be told apart. An app reporting another subrole in those states is not listed | ⬜ open, accepted for v1 |
| Two same-app windows with the same frame on different Spaces cannot be told apart (both are listed if AX lists both), and a hidden app's other-Space windows are listed too | ⬜ open, accepted for v1 |
| A hung or retrying app's windows skip the Space check, so they stay listed across a Space switch while it hangs (an `.apiDisabled` state turns off Space filtering for every app) | ⬜ open, accepted for v1 |
| The minimized flag can show more than 1s late, because the first read during the animation fails and waits for the retry | ⬜ open, accepted for v1 |
| An app whose attach fails with an error other than `.cannotComplete` is lost until it is relaunched | ⬜ open, accepted for v1 |

## Log

- 2026-11-02 — Product framing done, license, README and product brief committed.
- 2026-11-02 — Added this status document and the project `CLAUDE.md` rule to keep it updated after every task.
- 2026-11-02 — Empty SwiftPM app (`Package.swift`, `Info.plist`, `scripts/bundle.sh`) builds into a signed `.app` that runs as an agent app. M0 at 4/5.
- 2026-11-02 — Added the `Build` GitHub Actions workflow (`.github/workflows/build.yml`, runs `scripts/bundle.sh` on `xcode-27`). First run pending, so the CI box stays unticked. M0 at 4/5.
- 2026-11-02 — First CI run failed: the runner's default Xcode 27.1 ships only the macOS 27.0 SDK. The workflow now selects Xcode 27.2; its first run is pending.
- 2026-11-02 — CI build is green on `main` with Xcode 27.2 (result reported by the user). M0 done, 5/5.
- 2026-11-02 — Testing approach decided: a `swift run` check executable, because Command Line Tools have no working test framework. Minimum drops to macOS 27.0 only if CI needs it.
- 2026-11-02 — M1 task 1: added `IonizedBarCore` (`flipRect`, `assignDisplay`, `entryWidth`) and the `IonizedBarChecks` executable, run in CI. M1 at 1/5.
- 2026-11-02 — M1 task 2: `AppTracker` (KVO on `runningApplications`) logs launch/terminate to stderr; `main.swift` prompts for Accessibility once and polls until trusted. M1 at 2/5.
- 2026-11-02 — M1 task 3: `WindowTracker` hosts one `AXObserver` per app on a dedicated thread and publishes debounced window snapshots, logged to stderr. `kAXUIElementDestroyed` is registered on the app element and filtered to known windows, because it never fires on window elements on macOS 27.2. `setFrontmost` on activation is still to check by hand. M1 at 3/5.
- 2026-11-02 — M1 task 3 fix: a failed window read keeps the cached windows and retries about once a second, so a busy app no longer loses an update and a hung app costs at most one 0.25s timeout per retry. Only `noValue`, `attributeUnsupported` and `invalidUIElement` count as no windows. M1 stays at 3/5.
- 2026-11-02 — M1 task 4: only `AXStandardWindow` windows are listed, and only those on the active Space (AX frame matched to the CG on-screen list by pid and bounds within 2pt). Minimized and hidden windows skip both checks, because AppKit reports them as `AXDialog` on macOS 27.2. Windows that just moved, and apps whose read failed, skip the Space check, since their frames can be stale. Real mouse drags and Space switches are still to check by hand. M1 at 4/5.
- 2026-11-02 — M1 task 4 fix: the state exception now admits only `AXDialog`, through `isRealWindow` in `IonizedBarCore` with checks, so hiding an app no longer lists its desktop or system windows. Measured on TextEdit: no window reads as `AXDialog` once it is neither minimized nor hidden. M1 stays at 4/5.
- 2026-11-02 — M1 task 5: `WindowModel` (main actor) flips each AX frame with the primary screen height, assigns it to a display by largest intersection and logs windows per display; windows with no intersection are logged as unassigned. A screen parameter change marks every app dirty. Checked by hand on 3 displays: every window got a display, and a TextEdit window moved across displays changed entry within about 1s. M1 done, 5/5; R3 done.
- 2026-11-02 — M1 final review fix: every refresh schedules one trailing publish about 0.5s later, with no AX read, so a window filtered or kept by an unsettled CG list is corrected without waiting for another event. An unchanged trailing snapshot is logged again.
- 2026-11-02 — M1 final review fix: an attach that gets `.cannotComplete` now retries while the process lives, at 5s after the first 10 fast retries, logged once per pid, instead of losing the app until relaunch. Apps still attaching are skipped by `markAllDirty`. Measured on 12 helpers that never answer: each failed attempt returns in under 1ms, so about 5ms of AX thread time per 5s. A failed read now logs once when the app starts retrying.
- 2026-11-02 — M1 final review docs: M1 and R8 go back to 🚧 until the M1 manual pass checklist is done, and the R8 limits are open pending the user's decision. README status and `open --stderr` command, and the KVO note in PRODUCT.md, are corrected.
- 2026-11-02 — M1 manual pass: the user ran the checklist and reported "seems ok", with no per-item results recorded. R8 is ✅. M1 stays 🚧 until the checks step has a first CI run, which needs a push. The R8 limits under Known issues are still pending the user's decision.
- 2026-11-02 — The user accepted the three R8 limits for v1. Recorded the lost-app case under Known issues.
- 2026-11-02 — CI is green with the checks step on `main` (result reported by the user), so the macOS 27.0 fallback is not needed. M1 done, 5/5.
- 2026-11-02 — M2 task 1: `BarManager` keeps one non-activating `NSPanel` (`BarPanel`, 36pt, `.statusBar`, frosted `NSVisualEffectView` with a one-pixel hairline) per `NSScreen`, synced at launch and on screen parameter changes; `barFrame` in `IonizedBarCore` has checks (non-zero origin). Build, checks and bundle pass; the app was not launched, so the panels, their placement and the screen add, remove and resize behaviour are unverified until the M2 manual pass. M2 at 1/6; R2 🚧.
- 2026-11-02 — M2 task 2: `EntryView` (icon, title, active, hover and minimized states) and `BarContentView` (entries keyed by AX element and reused, laid out with `entryWidth` on backing-aligned frames) now show each display's windows in its panel. `TrackedWindow` carries its element and a stable `order`, assigned at first read and kept across re-reads, so focus changes do not move entries and a new window goes last. Build, checks and bundle pass. An offscreen scratch render of the views, in light and dark, showed the states and the hairline, and confirmed reuse, removal, order and aligned frames. The app was not launched, so live windows, stable order with real AX data, real hover and appearance switching are unverified until the M2 manual pass. M2 at 2/6; R1 and R5 🚧.
- 2026-11-02 — Added M6 – Window preview, after M5 and out of v1 scope: an opt-in thumbnail panel on hover. PRODUCT.md no longer lists thumbnails as a non-goal, and Screen Recording is now allowed for opt-in previews only. Whether a minimized window can be captured is still open, so M6 starts with a spike that decides if a cache is needed. M6 at 0/6.
- 2026-11-02 — M2 task 5: `IONIZED_BAR_MATERIAL=liquid` hosts the bar (hairline included) in an `NSGlassEffectView` instead of the frosted `NSVisualEffectView`; frosted stays default. The compare command is under the material box, which stays unticked until the user picks. Build, checks and bundle pass; the app was not launched, so neither material's look is verified.
- 2026-11-02 — M2 task 2 fix: each app now keeps its windows' order in a map that outlives the window cache, so a window missing from a read keeps its place when it returns, released when the window is destroyed or the app quits. First reads go through apps in pid order, so the order across apps no longer varies between launches. Build, checks and bundle pass; the app was not launched, so this is unverified with real AX data until the M2 manual pass.
- 2026-11-02 — M2 task 3: entries below 48pt hide the title, center the icon and show the title as tooltip (kept current on title changes); entries fade in and out and animate frame changes through `NSAnimationContext` (0.12s), applied immediately with Reduce Motion. A window returning during its fade reuses the fading view. `entryWidth` checks already cover the 48pt boundary and the 220pt cap, so none added. Build, checks and bundle pass; an offscreen scratch run of `BarContentView` confirmed icon-only switch with tooltips, no duplicate on return during a fade, and removal after the fade. The app was not launched, so the animation's look and timing, Reduce Motion and real-window behaviour are unverified until the M2 manual pass. M2 at 3/6.
- 2026-11-02 — M2 task 4: entries act on windows. A left click on mouse-up raises, minimizes an active window or restores a minimized one (`clickAction` in `IonizedBarCore`, with checks); a middle click closes; the context menu has Close, Minimize and Quit. `WindowTracker` gains `raise`, `minimize`, `restore` and `close`, on its thread, logging AX failures. Build, checks and bundle pass. A scratch run sent synthetic mouse events through a real off-screen `BarPanel`, with recording closures in place of the tracker: click decisions, mouse-up outside, middle and other buttons, menu items and their disabled state, right-click and control-click menus, and the panel staying non-key with the app inactive. The app was not launched and the scratch run made no AX calls, so the AX actions on real windows, focus staying with the raised app and real mouse input are unverified until the M2 manual pass. M2 at 4/6.
- 2026-11-02 — Added M7 – Settings, after v1: window grouping (Never, When full, Always) and task display (Icon only, App name, Content), set in a settings window. PRODUCT.md no longer lists grouping as a non-goal, and a group entry has no M6 preview. M7 at 0/6.
- 2026-11-02 — M7 task 1: `appsToGroup` and `barItems` in `IonizedBarCore` decide which apps merge and where a group sits, with checks. Nothing calls them yet, so the bar is unchanged. Checks pass. M7 at 1/6.
- 2026-11-02 — M7 tasks 2 and 3: `Settings` is saved in `UserDefaults`, and `BarManager` can re-apply it to the latest snapshot. Entries show Icon only (compact 48pt, packed left), App name or Content, with the title in a tooltip when it isn't shown. Nothing changes the settings until the settings window exists. Build and checks pass, and an offscreen render of the views showed all three modes. The app was not launched. M7 at 3/6.
- 2026-11-02 — M7 task 4: the bar groups windows through `barItems`, and regroups when its width changes. A group shows the icon, app name and count (icon and count when icon-only); a click opens a native menu listing its windows, middle-click does nothing, and right-click offers Close All Windows and Quit. Entries are now VoiceOver buttons with a label for the window or group. Build and checks pass. An offscreen render showed grouping in every mode, including When full merging the largest apps first and stopping, and printed menus and labels were right. The app was not launched, so the menu's position above the entry, picking a window and VoiceOver are unverified until the manual pass. M7 at 4/6.
- 2026-11-02 — M7 task 5: `SettingsWindow` (AppKit, two labelled pop-ups) opens with "Settings…" from an entry's or the empty bar's right-click menu; changes apply at once and are saved. Build and checks pass. The app was not launched, so the window itself, activation and Cmd-W are unverified until the manual pass. M7 at 5/6.
- 2026-11-02 — M7 task 5 check: the real `SettingsWindow`, driven from a scratch harness, shows the saved selection, reports each change through `onChange`, closes on Cmd-W but not on a plain W, and reopens. Its layout frames are centered and unambiguous. An offscreen capture came out blank, so its look, activation and real pop-up use are still unverified until the manual pass. M7 stays at 5/6.
- 2026-11-02 — M7 manual pass: the user reported "all good", with no per-item results recorded. M7 done, 6/6.
