# Implementation status

_Last updated: 2026-11-02_

Scope, requirement numbers (R1–R9) and milestones come from [PRODUCT.md](PRODUCT.md).

Legend: ✅ done · 🚧 in progress · ⬜ not started · ⛔ blocked

## Overview

| Milestone | Status | Progress |
|---|---|---|
| M0 – Bootstrap | ✅ | 5/5 |
| M1 – Window model (headless) | ✅ | 5/5 |
| M2 – Bars | 🚧 | 5/6 |
| M3 – Dock replacement and launch at login | 🚧 | 4/4 |
| M4 – Push windows away | 🚧 | 3/3 |
| M5 – Release | 🚧 | 1/3 |
| M6 – Window preview | 🚧 | 1/6 |
| M7 – Settings | ✅ | 6/6 |

## Requirements

| # | Requirement | Milestone | Status |
|---|---|---|---|
| R1 | Taskbar | M2 | 🚧 |
| R2 | One bar per display | M2 | 🚧 |
| R3 | Per-display tasks | M1 | ✅ |
| R4 | Real windows only | M1 | ✅ |
| R5 | Equal width | M2 | 🚧 |
| R6 | Replaces the Dock | M3 | 🚧 |
| R7 | Launch at login | M3 | 🚧 |
| R8 | Current Space only | M1 | ✅ |
| R9 | Push windows away | M4 | 🚧 |

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
- [x] VoiceOver labels, keyboard access, Reduce Transparency and Reduce Motion

### M2 manual pass
- [ ] On 2 displays: open, close, move and minimize windows and check each bar; a window dragged across displays moves its entry within about 1s (R3)
- [ ] Switch Spaces: entries update (R8), and the bar stays visible on every normal Space
- [ ] Default motion: entries animate in, out and on resize with no visible glitch
- [ ] Long titles truncate at the tail; the 220pt cap holds with few windows
- [ ] Bar geometry: flush with the bottom, 36pt, hairline visible, no Cmd-Tab entry
- [ ] Unplug a display while in keyboard mode
- [ ] After closing Settings, the active highlight returns and keys reach an app
- [ ] Click an entry, then ⌃⌥B: the outline shows
- [ ] Tooltips on icon-only entries while a terminal spinner is running in another app
- [ ] Add and remove a display
- [ ] Resolution change
- [ ] Display arrangement change
- [ ] Each entry state in light and dark: normal, hover, active, minimized
- [ ] Equal width and icon-only with many windows
- [ ] Click an entry
- [ ] Click the active entry
- [ ] Click a minimized entry: it restores, stays in place and does not blink
- [ ] Middle-click
- [ ] Each menu item: Close, Minimize, Quit, Quit IonizedBar
- [ ] No focus steal on click
- [ ] VoiceOver reads an entry
- [ ] VoiceOver and keyboard on a group entry: its label, press and Return open the window list, and the list works with the keyboard
- [ ] ⌃⌥B, Left, Right, Tab, Shift-Tab and wrap, Return, Space, Shift-F10 (keyboard context menu) and Escape; focus is visible, also on the active entry, and focus returns to the frontmost app
- [ ] Hotkey on an empty bar: nothing happens
- [ ] Hotkey, then a click on an entry: keyboard mode ends and typing reaches the app
- [ ] Hotkey on a fullscreen Space: nothing happens and the fullscreen app keeps keys
- [ ] Key handback with two displays
- [ ] Key handback with the Settings window open
- [ ] Reduce Transparency
- [ ] Increase Contrast
- [ ] Reduce Motion
- [ ] Minimized title contrast: PRODUCT.md asks for both about 50% opacity and 4.5:1
- [ ] Entry order across a Space round trip: a window AX stops listing while on another Space goes last when it returns
- [ ] Adjacent highlights touching: entries fill the bar height with no inset
- [ ] Active-entry text contrast on the accent color, across accent colors: `alternateSelectedControlTextColor` on `controlAccentColor` may be under 4.5:1
- [ ] Hover highlight after entries reflow under a still cursor
- [ ] First click on the never-key panel, over the title and under `IONIZED_BAR_MATERIAL=liquid`
- [ ] Focus lands on the raised window
- [ ] A quick second click on an entry
- [ ] Middle press on one entry and release on another
- [ ] Tooltips while the app is inactive
- [ ] Accent color change redraws live
- [ ] Material pick

### M3 – Dock replacement and launch at login
- [x] Save the Dock prefs, then autohide with a huge delay (R6)
- [x] Restore on quit, and recover after a crash on the next launch (R6)
- [x] Launch at login via `SMAppService` (R7)
- [x] Accessibility permission onboarding

### M3 manual pass
- [ ] Onboarding window: shows only when untrusted, button opens the Accessibility pane, grant closes it and starts tracking, Cmd-W closes it without quitting and polling goes on, Tab/Return and VoiceOver reach the button
- [ ] IonizedBar appears in the Accessibility list without pressing +, and the system prompt and the opened pane don't get in each other's way
- [ ] Dock, starting visible (autohide off, no other taskbar running): it stays until the permission is granted, then hides; the app's log shows no `defaults` or `killall` failure; a delay of 1000 keeps it from showing at the screen edge
- [ ] Dock comes back with the original values, read with `defaults read com.apple.dock`, after Quit IonizedBar, `kill -TERM` and `kill -INT`, including with a key that was absent before
- [ ] Starting from a Dock left hidden by another taskbar (delay of 60s or more): the log says it's a leftover, and quitting IonizedBar deletes both keys and leaves the Dock visible
- [ ] `kill -9`, relaunch: the Dock stays hidden, then Quit restores the original values and not the hidden ones
- [ ] `kill -9`, Accessibility permission removed, relaunch: the Dock comes back while the onboarding window shows
- [ ] Log out with the app running: the Dock is restored
- [ ] Log in again: IonizedBar starts by itself, and with the permission already granted the Dock is hidden and the bar fills
- [ ] First run after granting the permission: "Start at login" is on in Settings and IonizedBar is in System Settings > General > Login Items
- [ ] Toggling "Start at login" off then on in Settings follows Login Items in System Settings, and the checkbox shows the real status when Settings reopens; once off, a relaunch doesn't turn it back on
- [ ] Deny then grant onboarding: the login item is only registered after the grant
- [ ] A failed register or unregister (e.g. login item disabled in System Settings) is logged and the checkbox falls back to the real status

### M4 – Push windows away
- [x] Detect windows that overlap the bar (R9)
- [x] Resize or move them through AX, with debounce
- [x] Skip fullscreen windows

### M4 manual pass
- [ ] Maximize and zoom: the window ends above the bar, below the menu bar; zooming a pushed window back and forth doesn't jitter
- [ ] Drag a window down over the bar: nothing moves until the mouse button is released, then it is pushed; holding it still over the bar doesn't push either
- [ ] Min-size app shrunk over the bar on a short display: one push, one "still over the bar" log line, no jitter; moving it pushes again
- [ ] Electron app (repositions itself, may animate AX writes): it lands in place with no fight loop
- [ ] Fullscreen: entering and leaving moves nothing while fullscreen, and the window's frame after leaving is pushed if it overlaps
- [ ] Two displays: a window is pushed on its own display, including one with a non-zero origin or above the primary, and only against its assigned display's bar
- [ ] Shrink-and-move lands exactly: a too-tall window ends at the bar's top and `visibleFrame`'s top, with size set before position
- [ ] An app rejecting the AX write: the failure is logged once per frame, not on every snapshot
- [ ] An app that moves its window without posting a notification, right before a push: the stale skip re-reads the frame, then the window is pushed from the new frame, with no repeated push log lines

### M5 – Release
- [x] Archive and zip the build
- [ ] Cask in `adericbourg/homebrew-tap` (draft on the tap's local `feature/ionized-bar-cask` branch, `sha256` still `TODO`; ticks once published)
- [ ] Clean-account install check (`brew install --cask adericbourg/tap/ionized-bar`)

### M6 – Window preview
- [ ] Spike: can `SCScreenshotManager` capture a minimized window? Record the result and whether a cache is needed (ran 2026-11-02, unknown: the control capture failed, so the cache is assumed needed)
- [x] Opt-in setting and Screen Recording request (off by default, no prompt until enabled)
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
- 2026-11-02 — Added "Quit IonizedBar" under "Settings…" in the right-click menu of entries and of the empty bar, through `NSApplication.terminate`. No milestone change.
- 2026-11-02 — M2 task 6: entries are VoiceOver buttons labelled by `entryAccessibilityLabel` (in `IonizedBarCore`, with checks), with press and show-menu actions, in a "Taskbar" group. ⌃⌥B (Carbon `RegisterEventHotKey`, `BarHotKey`) makes the panel under the mouse key and focuses the active entry, else the first; Tab, Shift-Tab, Left and Right wrap, Return and Space click and end keyboard mode, Shift-F10 opens the menu, Escape ends it. A focused entry that goes away passes focus to its neighbour, and an emptied bar ends keyboard mode. `EntryView` sets `needsPanelToBecomeKey` to false: it follows `acceptsFirstResponder` by default, and a scratch run showed clicks then making the panel key. No code added for Reduce Transparency or Increase Contrast, which are expected to adapt on their own. Build, checks and bundle pass. A scratch run with a recording panel covered focus, wrap, visual order, fading entries, removal, each key, the accessibility values and actions, and a synthetic click on an off-screen panel staying non-key. The app was not launched, and the hotkey, real key status, handing key back to the frontmost app, the focus ring's look, the context menu popping up from the keyboard, VoiceOver itself and the accessibility settings are unverified until the M2 manual pass. Rebased onto M7: a group entry reads "<app>, <n> windows" plus its state (`groupAccessibilityLabel`, with checks), keyboard mode moves through groups, Return and Space open its native window list, and every display mode keeps the full label. VoiceOver presses are deferred so a menu does not hold the accessibility reply. A scratch run covered these too, with the menus replaced by counters, so the list's keyboard handling while the panel is key is unverified until the manual pass. M2 at 5/6, the material box stays open until the user picks.
- 2026-11-02 — M2 task 6 fix: the active entry draws an outline in `alternateSelectedControlTextColor` while focused, because the system ring does not show on the accent fill; a panel losing key clears its first responder so the outline goes away. Every click action now ends keyboard mode, whether from the mouse, the keyboard or VoiceOver, so key no longer stays on the panel when no other app takes it. ⌃⌥B does nothing when the panel is not on the active Space, such as a fullscreen Space. README drops the material line. Build, checks and bundle pass. A scratch run with a recording panel covered each case, with the outline checked in rendered pixels, but with faked key and Space state. The app was not launched, so these are unverified with real input until the M2 manual pass.
- 2026-11-02 — M2 final-review fixes: `BarPanel.becomeKey` redraws the first responder so the focus outline shows after a click then ⌃⌥B; `kAXWindowDeminiaturizedNotification` is treated like moved and resized so a restored window is not filtered by the lagging CG list (no blink); `EntryView` only assigns a tooltip when it changes; README says entries are per app when grouped and lists login as not yet there; the M2 manual pass gains the missing checks. M7's tick predates keyboard access, whose group-list check is on the M2 manual pass. Build, checks and bundle pass; the app was not launched, so the fixes are unverified until the manual pass. M2 stays 5/6.
- 2026-11-02 — Window titles are no longer logged, per the user: the per-snapshot window listing in `WindowModel` is gone, since the bars show it, and failed-action logs name the app and pid instead. M2 stays 5/6.
- 2026-11-02 — M3 task 1: `OnboardingWindow` (AppKit, explanation plus a default "Open Accessibility Settings" button, Cmd-W closes) replaces the stopgap prompt; `main.swift` shows it only when `AXIsProcessTrusted()` is false, keeps the 1s poll, and on grant closes it and runs `onAccessibilityTrusted()`, the main-thread path later M3 and M4 steps hook into (also called directly when already trusted). The button also calls `AXIsProcessTrustedWithOptions` with the prompt option, since that call is believed to be what adds the app to the Accessibility list; it is not called at launch, so no system dialog covers the guide (that registration is an assumption, unverified on macOS 27). Build, checks and bundle pass. A scratch run of the real window showed its size, the button as initial first responder and Cmd-W handled. The app was not launched, so the window's look, the Settings pane opening, the grant closing it and tracking starting, and VoiceOver are unverified until the M3 manual pass. M3 at 1/4.
- 2026-11-02 — M3 task 2: the app saves `autohide` and `autohide-delay` in its own prefs (absent keys stay absent, flushed to disk before any write; if that fails the Dock is left alone), then hides the Dock from the trusted path with a delay of 1000 and `killall Dock`. Quit, `SIGTERM` and `SIGINT` restore it; saved values found at launch mean a crash and are kept. The decisions (`hideDock`, `restoreDock`, `parseDockPrefs`) are in `IonizedBarCore`, with checks. Reads use `defaults export`, because `defaults` error messages can't reliably tell an absent key from a failure. Not in the brief: without the permission, a launch that finds saved values restores them right away, since the bar is empty and each upgrade loses the permission. Build, checks and bundle pass. A scratch app with the real `defaults` code on a scratch domain and a fake Dock relaunch went through `SIGTERM`, `SIGINT`, terminate and `kill -9` then relaunch, with set and absent keys: values and saved state were right each time, and the real `com.apple.dock` and Dock pid did not change. The app was not launched and the Dock was never written, so the real hide and restore, the Dock's reaction, the untrusted restore and logout are unverified until the M3 manual pass. boringBar was running here with the same values (autohide on, delay 1000): it must be quit before testing, or those are the originals saved. If the saved state is lost while the Dock is hidden, the hidden values become the originals; the README has the manual recovery. M3 at 3/4, R6 🚧.
- 2026-11-02 — M3 task 2 fix: when saving originals, an `autohide-delay` of 60s or more (`leftoverDelayThreshold`) means another taskbar or a lost saved state left the Dock hidden, so both keys are saved as absent, logged once, and the restore leaves the Dock visible. This replaces the two limits noted in the previous line: boringBar's values are no longer saved as originals, and a lost saved state no longer keeps the Dock hidden. A real `autohide` on with such a delay is lost, on purpose. Saved state found at launch is still kept as it is. Running alongside another taskbar still fights over the Dock. Build, checks and bundle pass, and the scratch app on a scratch domain restored to absent keys from a leftover delay, with the real `com.apple.dock` and Dock pid unchanged. The app was not launched, so this is unverified on the real Dock until the M3 manual pass. M3 stays 3/4.
- 2026-11-02 — M3 task 3: `LoginItem` wraps `SMAppService.mainApp`. A "Start at login" checkbox in the settings window applies at once, is refreshed from the real status each time the window opens, and falls back to it if register or unregister throws (logged). `onAccessibilityTrusted()` registers once, tracked by the saved flag `loginItemRegisteredOnce` (set before the attempt, so a failure is not retried and a user who turns it off is never overridden). README no longer says there is no login item. Build, checks and bundle pass. The login item was never registered and the app was not launched, so registration, the checkbox, the Login Items entry and the flag are unverified until the M3 manual pass (5 checks added). M3 at 4/4; R6 and R7 stay 🚧 until that pass.
- 2026-11-02 — M4 task 1: `overlapsBar` and `pushedFrame` in `IonizedBarCore` (Cocoa coordinates, like `barFrame`): a window that fits moves up and keeps its size, a taller one shrinks to the room between the bar's top and `visibleFrame`'s top (so never under the menu bar), x and width never change. `WindowModel` logs, per snapshot, the non-minimized windows overlapping the bar of their assigned display (app and pid, no title); a window straddling two displays is only checked against that bar (noted in PRODUCT.md). Nothing is written through AX yet. 7 checks added (overlap, move, shrink, non-zero origin, hanging below the screen); build, checks and bundle pass. The log line was not seen in a running app since it can't be launched here. M4 at 1/3, R9 🚧. M3 now reads 🚧 4/4 like M1, as its manual pass is open.
- 2026-11-02 — M4 task 2: `WindowPusher` (main thread) steps a `PushMemory` per window on each snapshot and on a 0.1s tick while anything is pending, since a mouse release posts nothing; the tracker writes on its AX thread under the existing messaging timeout. `pushTarget` in `IonizedBarCore` is the one way to `pushedFrame`: nil unless the window overlaps its bar, isn't minimized or fullscreen, and there is room above the bar. `PushMemory` waits for no mouse button held and a frame held 0.3s, then awaits the result for 1s after the push; the frame it settles on is remembered and not pushed again until the frame changes, whether it overlaps or not. The write re-reads position, size and `AXFullScreen` first and skips if the frame moved on from the snapshot, so a stale frame is never pushed; size goes before position, and only what changes is set. The per-snapshot overlap log is gone: one line per push, one when a push leaves the window over the bar. Own windows never get here: `AppTracker` excludes this process. Entries go 60s after the last snapshot showing the window, not on the first absent one, because the Space filter can drop a window for one snapshot. README and PRODUCT.md updated. Checks added (`pushTarget`, including no room and a tall window clear of the bar, and the `PushMemory` sequences); build, checks and bundle pass. The app was not launched, so no window has been pushed: every AX path, the debounce with a real drag, the write order and `AXFullScreen` are unverified until the M4 manual pass (8 checks). An app repositioning itself more than 1s after a push would still fight at about that period (marked `ponytail:`). M4 at 3/3, R9 stays 🚧.
- 2026-11-02 — M4 task 2 fix: a stale skip now marks the window moving and its app dirty, like a successful push. Before, an app whose move posted no notification kept its old cached frame, so the same stale push repeated every 0.3s under a 10Hz tick and the window stayed over the bar until another event dirtied that app. This path is in the tracker, so it has no check; it joins the M4 manual pass (9 checks now). Build, checks and bundle pass; the app was not launched, so this is unverified. M4 stays at 3/3, R9 🚧.
- 2026-11-02 — M5 task 1: `Info.plist` has `CFBundleShortVersionString` and `CFBundleVersion` at 0.1.0. `scripts/archive.sh` runs `bundle.sh`, zips with `ditto -c -k --keepParent` into `build/IonizedBar-<version>.zip` (version read with PlistBuddy) and prints the path and sha256. `.github/workflows/release.yml` runs on tags `v*` on the same runner as `build.yml`, fails if the tag isn't `v<plist version>`, runs the checks and the archive, then `gh release create` with the zip (`GITHUB_TOKEN`, `contents: write`, no new action). README has a Releasing section. Build, checks and bundle pass, and a local archive unzipped in the scratch dir passed `codesign --verify` with the right plist version; the app was not launched. The workflow has never run (no tag pushed, YAML only linted for syntax), so the runner's `gh`, the tag check and the release step are unverified until the first tag. M5 at 1/3.
- 2026-11-02 — M5 task 2: cask draft `Casks/ionized-bar.rb` committed on the tap's local branch `feature/ionized-bar-cask` (not pushed, `main` untouched): version 0.1.0, release zip url, `sha256 "TODO"`, `depends_on arch: :arm64` and `macos: :golden_gate` (brew only knows major releases, so the caveats state 27.2), `app`, `uninstall quit` on the bundle id plus `login_item`, `zap` for the prefs, caveats on `xattr -d com.apple.quarantine` and the Accessibility re-grant. `brew style` passes and the cask loads (a scratch copy with a dummy sha256, through `Cask::CaskLoader::FromContentLoader` in `brew ruby`; brew refuses paths outside a tap): macos `>= 27`, arm64, release url. The first draft's `">= 27.2"` didn't load, which `brew style` can't catch. `brew audit` can't take a path and would need the tap installed, so it wasn't run (it would fail on the `TODO` sha256 anyway). README Releasing lists the publish steps. The cask is untested: no release exists, nothing was installed, and the `login_item` name and `zap` paths are unchecked against a real install. M5 stays at 1/3; the clean-account install check is still open.
- 2026-11-02 — M6 spike, result unknown. A scratch program (not in the repo) opened its own magenta window and captured it with `SCScreenshotManager` and `SCContentFilter(desktopIndependentWindow:)` before, while minimized and after restoring. Every capture, the on-screen control included, failed with `SCStreamErrorDomain -3811`, although `CGPreflightScreenCaptureAccess()` was true and no prompt appeared, so the minimized result can't be told from a harness limit. What did work: on macOS 27.2 `SCShareableContent` (with `onScreenWindowsOnly: false`) keeps listing the window while minimized, with the same frame and `isOnScreen == false`; its `isActive` is also false. Later M6 tasks assume the cache is needed. The box stays open, to retry from a normal GUI session. M6 stays at 0/6.
- 2026-11-02 — M6 task 9: `Settings.showsPreviews` (off by default, saved) and a checkable "Show window previews" item in a window entry's right-click menu (not on groups or the empty bar). Turning it on calls `CGRequestScreenCaptureAccess()`; at launch, only if it is on, `CGPreflightScreenCaptureAccess()` runs read-only and is logged. With it off no Screen Recording call is made. The settings window keeps the stored value when it reports its own changes. Build, checks and bundle pass. The app was not launched and the request was not called, so the menu item, the system prompt and the persisted value are unverified until the M6 manual pass. M6 at 1/6, the spike box stays open.
