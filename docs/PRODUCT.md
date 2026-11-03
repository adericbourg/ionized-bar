# ionized-bar — Product brief

## Context
uBar and boringBar don't fit the need: a **KDE Plasma–style taskbar** for macOS. It should list one entry per open window, have one bar per display that shows only that display's windows, use equal-width entries, and take the Dock's place. The repo is empty (`main`, no commits). License: **GPLv3**. Target: **macOS 27.2+ only**. Distribution: **Homebrew cask** in `github.com/adericbourg/homebrew-tap`.


## Product vision
> A taskbar that shows the windows you have open, on the screen where they are. Nothing more.

## MVP scope (must-have)
| # | Requirement | Acceptance criteria |
|---|---|---|
| 1 | Taskbar | Horizontal bar at the bottom of the screen. Each entry shows the app icon and the window title. The active window is highlighted. |
| 2 | One bar per display | Connecting or disconnecting a display adds or removes its bar within about 1s. The bar follows changes to resolution and arrangement. |
| 3 | Per-display tasks | A window shows on the bar of the display that holds most of its area. Moving a window to another screen moves its entry within about 1s. |
| 4 | Real windows only | Tasks are windows: no windowless apps (for example, Finder with no windows shows no task). Pinned icons (M9) are not tasks. Minimized windows **are** shown, dimmed, as in KDE. Panels, sheets and utility windows are excluded (`AXStandardWindow` only). |
| 5 | Equal width | All entries share the bar's width equally, up to a max width. Titles get truncated. Below a minimum width only the icon shows (no wrapping). |
| 6 | Replaces the Dock | On launch, the app saves your Dock prefs, then sets `autohide=true` and a very large `autohide-delay`. On a normal quit or crash, it restores them. |
| 7 | Launch at login | `SMAppService.mainApp` toggle, on by default after onboarding. |
| 8 | Current Space only | Only windows on the active Space are listed. The list updates when you switch Spaces. |
| 9 | Push windows away | Any window that overlaps the bar gets resized or moved by AX so it stays above the bar. Maximize and zoom must not cover the bar. |

**Interactions (KDE parity, MVP):** clicking an entry raises and focuses that window. Clicking the active entry minimizes it. Clicking a minimized entry restores it. Middle-click closes the window. Right-click opens a menu: Close, Minimize, Quit app. The right-click menu of an entry or of the empty bar also has "Quit IonizedBar", under "Settings…".

**Accessibility (app UI):** every entry is a VoiceOver element with the window title, the app name and its state (active or minimized). The bar can be reached from the keyboard with ⌃⌥B. This follows the spirit of WCAG 2.2 AA (contrast, focus visible).

## Look & feel
- **Material:** frosted glass, using `NSVisualEffectView` with `blendingMode = .behindWindow`, `state = .active` and the `.hudWindow` material. The bar and the launcher panel are always dark, even in Light mode (the user prefers darker); the preview panel follows the system light or dark appearance.
  - Alternative: the native Liquid Glass (`NSGlassEffectView`) was prototyped in M2 and not kept.
- **Bar:** 36pt high with no rounded corners, flush with the bottom edge of each display. A 1px hairline separates it from the content above.
- **Entry:** 16pt icon plus the window title in the system font (13pt), padded 8pt, with a 4pt corner radius on hover and active states.
  - **Active:** tinted background in the system accent color.
  - **Hover:** subtle highlight.
  - **Minimized:** title and icon shown at about 50% opacity, title in italics.
  - **Icon-only mode:** the icon is centered and the title moves to a tooltip.
- **Max entry width:** about 220pt, so a few windows don't stretch across the whole screen. The shrink threshold below which only the icon shows is about 48pt.
- **Accessibility:** honor *Reduce Transparency* (switch to an opaque background; `NSVisualEffectView` does this for you) and *Increase Contrast*. Text over the glass must keep a contrast ratio of at least 4.5:1 (WCAG AA), so it uses label colors that adapt to vibrancy, never hard-coded grey.
- **Motion:** entries animate in, out and when resized in under 150ms. Animations are off when *Reduce Motion* is on.

## Non-goals (v1)
Widgets (tray, clock), windows from all Spaces, a top or side bar position, theming, multiple rows. Each one is a candidate for a later version. Window thumbnails on hover, grouping windows by app, an app launcher, pinned apps and re-ordering tasks are planned after v1, see below.

## After v1: window preview (M6)
Hovering an entry shows a panel above it with the app icon and name, the window title and a thumbnail of that window. A preview always shows one window, so a group entry (M7) has no preview: its window list takes that place.

- **Opt-in:** off by default, toggled by a "Show window previews" item in the entry's right-click menu. The bar works fully without Screen Recording, and macOS only prompts when previews are turned on. With previews off, nothing appears and the icon-only tooltip stays as it is. If the permission is denied, no preview appears.
- **Showing and dismissing:** the panel appears after about 300ms of hover, and also on keyboard focus. Esc dismisses it, and it stays open while the pointer is over it (WCAG 1.4.13). Esc works whichever app is frontmost, and that app gets the key too: a global key monitor can only observe. With previews on and the permission granted, a window entry has no tooltip, since the panel shows its title.
- **Display-only:** clicking the panel does nothing. Clicks stay on the entry.
- **Minimized windows:** never captured live: macOS lists them but fails the capture (verified on macOS 27.2), so the panel shows the last captured image. With no captured image, the panel shows the header only.
- **Cache:** in memory only, never written to disk. It's filled on hover and drops an image when its window closes, so a window minimized with its yellow button and never hovered shows the header only.
- **Ambiguous match:** if the window can't be identified with certainty, the panel shows the header only. Showing another window's content is worse than showing none.
- **Accessibility:** the panel honors *Reduce Motion*, *Reduce Transparency* and *Increase Contrast*, like the bar.

## After v1: settings (M7)
A settings window, opened with "Settings…" from the right-click menu of an entry or of the empty bar. Settings are global, apply immediately and are saved in `UserDefaults`. The defaults keep the behavior of v1.

- **Group windows:** Never (default), When full or Always. Each bar decides for itself, because bars differ in width.
  - **When full:** apps merge when entries would drop below about 120pt (48pt in Icon only mode). The app with the most windows merges first, and merging stops once entries fit. On a tie, the later app on the bar merges first. If merging every app isn't enough, entries shrink as usual.
- **Show tasks as:** Icon only, App name or Content (default, the window title). When the title isn't shown, it moves to a tooltip. VoiceOver reads it in every mode.
  - **Icon only:** compact entries of about 48pt, packed from the left. This is the one exception to R5's equal share of the bar's width.
- **Start at login:** the R7 toggle. It shows the real `SMAppService` status and applies at once; it is not saved in `UserDefaults`. The app registers itself once when Accessibility is first granted, and never again after that.
- **Group entry:** all of an app's windows on that bar (2 or more), placed where the app's first window was. It shows the icon, app name and window count, or the icon and count in Icon only mode. It's highlighted if any of its windows has focus, and dimmed only if all of them are minimized.
- **Group interactions:** a click opens a native menu above the entry that lists the windows. The focused window has a checkmark, and minimized windows say so. Picking a window raises or restores it. Middle-click does nothing, so a stray click can't close several windows. Right-click offers Close all windows, Quit, Settings… and Quit IonizedBar.

## After v1: app launcher (M8)
A button always at the left of the bar, on every bar. It opens a panel above it that lists applications, with a search field. Nothing else: no categories and no recent apps.

- **Button:** a fixed-width, icon-only entry, about 48pt like Icon only tasks, on every bar and in every display mode, with a system icon. Tasks share the width left of the bar (see M9 for the order). R5's equal share then means the width left for tasks; When full decides on that width and Icon only tasks pack from just after the button. Hovering it shows no preview, and right-click offers Settings… and Quit IonizedBar.
- **Applications:** the `.app` bundles in `/Applications`, `/System/Applications` and `~/Applications`, and in their `Utilities` folder, sorted by name, each with its icon and name.
- **Search:** fuzzy matching over application names only (see Description). The search field has focus when the panel opens, and an empty search lists everything.
- **Description:** macOS bundles have no standard description field. The M8 spike (2026-11-03) read 125 bundles from the three folders: Spotlight `kMDItemDescription` was empty on all 125, and Info.plist `CFBundleGetInfoString` was empty on 109, a copyright or version line on 12 and a real description on 3 (all third-party, none among the 65 system apps). Not usable, so search covers names only.
- **Opening an app:** a click, or Return on the selected row, opens it with `NSWorkspace.openApplication` and closes the panel. Esc or a click outside closes the panel too, and keys go back to the frontmost app.
- **Keyboard:** the launcher is the first stop of ⌃⌥B keyboard mode. A bar is never empty anymore, so ⌃⌥B with no tasks now focuses the launcher button instead of doing nothing.
- **Accessibility:** the button is a VoiceOver button whose label says what it does, the rows are VoiceOver elements labelled with the app name, and the panel honors *Reduce Motion*, *Reduce Transparency* and *Increase Contrast*, like the bar.

## After v1: pinned apps (M9)
Pinning keeps an app's icon on the bar while it's closed, and clicking the icon opens the app. The bar reads, from the left: launcher (M8), pinned icons, tasks.

- **Pinning:** "Pin" in the right-click menu of a task or of a group entry, since a pin belongs to the app and not to a window. "Unpin" replaces it when the app is pinned, and is also in the right-click menu of a pinned icon. A task whose app has no bundle identifier has no Pin item.
- **Pinned icon:** a fixed-width, icon-only entry, about 48pt, with the app name as tooltip. A click opens the app with `NSWorkspace.openApplication`: a running app comes to the front and decides whether to reopen a window, no new window is forced.
- **Saved as:** an ordered list of bundle identifiers in `UserDefaults`, global to all bars, in pinning order. Reordering is not planned. A pin whose app is no longer installed isn't shown, and stays saved.
- **Setting "Keep pinned app icons visible":** a checkbox in the settings window, off by default.
  - **On:** the pinned icon is always visible, even when the app is open.
  - **Off:** the pinned icon disappears as the app opens, then only the task is visible.
- **Hiding is per bar:** with the setting off, an icon hides on a bar only if that bar shows a task for the app. It stays on other displays, on Spaces without the app's windows, and for a running app with no windows, so an app can always be reached from any bar.
- **Keyboard:** pinned icons are in ⌃⌥B keyboard mode, between the launcher and the tasks. Shift-F10 opens their menu.
- **Accessibility:** a pinned icon is a VoiceOver button labelled with the app name and "pinned".

## After v1: re-order tasks (M10)
Dragging a task along its bar changes its place on that bar. Only the entry moves: the window itself is neither raised nor moved.

- **Scope:** an entry moves within its own bar. It can't be dragged to another bar, because R3 ties an entry to its window's display. A drag past the end of the task area stops at the end.
- **Click or drag:** a drag starts once the pointer has moved about 4pt, and its mouse-up is not a click. Dropping an entry back where it started changes nothing. Esc doesn't cancel a drag, because the panel is never key. In keyboard mode, where it is, keys are ignored during a drag and the drop ends keyboard mode, as a click does. A right or middle click during a drag does nothing. A window opening or closing during a drag doesn't end it, unless the dragged entry itself goes, as when its window closes or grouping changes it: the drag then ends with no move and no click.
- **Order:** kept in memory only, so it's lost on quit: AX window elements don't survive a restart, and public APIs have no stable window id. A new window still goes last. A window that leaves and returns (Space switch, another display) keeps its place. A window moved to another display lands there by that same place, not last, since it isn't new.
- **Group entry (M7):** drags as one, and its windows stay next to each other if the bar later ungroups. The order inside a group's window list can't be dragged.
- **Launcher and pinned icons (M8, M9):** can't be dragged, and a task can't be dropped before them.
- **Without dragging:** "Move Left" and "Move Right" in the right-click menu of a task or group entry, disabled at the ends. WCAG 2.2 AA 2.5.7 asks for an alternative to dragging. The menu also covers keyboard mode (Shift-F10) and VoiceOver, so there's no new shortcut.
- **Motion:** the other entries slide apart in under 150ms, and jump with *Reduce Motion* on. A drag dismisses the M6 preview and shows no new one until the drop.

## Technical direction
- **Stack:** Swift 6 and AppKit. SwiftUI is allowed only inside the entry view. SwiftPM package, bundled by a script (development happens on a machine with Command Line Tools only, no Xcode). Not sandboxed (the AX APIs require it).
- **Bar window:** borderless, non-activating `NSPanel`, one per `NSScreen`, placed at `.statusBar` level. It joins all Spaces (`canJoinAllSpaces`, `stationary`) and does not show in Cmd-Tab (`LSUIElement`).
- **Window model:** KVO on `NSWorkspace.runningApplications` for app launch and terminate (the launch and terminate notifications skip `LSUIElement` apps), plus one `AXObserver` per app for created, destroyed, moved, resized, title changed, minimized and focused. `CGWindowListCopyWindowInfo` is used only to cross-check what's on screen. No Screen Recording permission, except for opt-in previews (M6): titles come from AX.
- **Preview capture (M6):** ScreenCaptureKit (`SCScreenshotManager` with `SCContentFilter(desktopIndependentWindow:)`), since `CGWindowListCreateImage` is unavailable in the macOS 15+ SDK. An entry's window is matched to an `SCWindow` by pid and bounds within 2pt, the same rule as the Space check, because public APIs cannot map an AX element to a `CGWindowID`.
- **Display assignment:** the largest intersection between the window frame and `NSScreen.frame` (after converting AX top-left coordinates to Cocoa bottom-left).
- **Push windows away:** when a window moves or resizes and its frame overlaps the bar's strip, set `kAXSize` and `kAXPosition` so it fits the screen's frame minus the bar. The top limit is `NSScreen.visibleFrame`'s top, so a push never goes under the menu bar. A window straddling two displays is only checked against the bar of its assigned display. No push while a mouse button is held or before the frame has settled, and none for fullscreen windows. A window a push leaves over the bar is not pushed again until its frame changes.
- **Dock handling:** `defaults` domain `com.apple.dock`, then `killall Dock` to apply. The original values are saved in the app's own prefs so a crash can be recovered on the next launch.
- **Permissions onboarding:** check `AXIsProcessTrusted()`. If it's false, show a single-window guide and poll until the grant is given.
- **Re-ordering (M10):** mouse tracking in the existing entry views rather than `NSDraggingSource`, since nothing leaves the bar and no pasteboard is needed. The order decision is pure logic in `IonizedBarCore`, with checks. It is one relative order of all windows that each bar projects onto its own: a move changes the place of the moved windows only, plus the other windows of a group it passes, which close up behind that group's first window, so other bars and windows on another Space or display are undisturbed, and a window coming back finds its place whatever closed meanwhile. An entry goes when the tracker's `kAXUIElementDestroyedNotification` or the app's exit drops the window, not when a snapshot leaves it out. Windows of a moved group that are elsewhere at that moment (another Space or display) stay where they were.

## Risks
| Risk | Impact | Mitigation |
|---|---|---|
| The Dock can't truly be removed (it hosts Cmd-Tab, Mission Control, Spaces) | The Dock can still be glimpsed at the edge | Autohide plus a huge delay is the industry-standard hack. Document it. |
| Unsigned cask: Gatekeeper quarantine, and the AX grant resets on every rebuild or upgrade | Bad experience on every update | Accepted for v1, see *Known issues*. Until fixed, document `xattr -d com.apple.quarantine` and re-granting Accessibility |
| Push-away fights apps that enforce a minimum size or reposition themselves (Electron apps, games, fullscreen) | Windows jitter, or the bar gets covered | Debounce. Skip fullscreen windows. Keep a per-app opt-out list (post-MVP) |
| AX latency or hangs with unresponsive apps | Bar freezes | Run AX calls off the main thread with `AXUIElementSetMessagingTimeout` |
| macOS 27 changes behavior | Breakage | Use public APIs only. Pinning one OS version keeps the test surface small |
| Preview (M6): same-app windows with the same frame can't be told apart | A thumbnail could show the wrong window | Show the header only when the match is ambiguous |
| Preview (M6): `SCScreenshotManager` capture is async and can lag | The panel feels slow, or the bar stutters | Capture once per hover, not on every mouse move |
| Preview (M6): the Screen Recording grant is probably lost on upgrade, like Accessibility (unverified) | Previews stop working after an update | Check during M6. Same fix as the Accessibility grant, see *Known issues* |
| Launcher and pins (M8, M9) take bar width | Tasks shrink sooner, and many pins can leave little room for them | The entry width and the When full grouping both use the width left for tasks. Tasks shrink as usual; pins never do |
| Launcher (M8): apps provide no usable description | Search can't match on what an app does | Checked in the M8 spike: 3 of 125 bundles have one, so search covers names only |
| Re-order (M10): a drag can fire a click or raise a window | Dropping an entry minimizes or raises a window by accident | The 4pt threshold, and a manual check |

## Milestones
1. **M0 – Bootstrap:** `LICENSE` (GPLv3), README, `docs/PRODUCT.md`, an empty SwiftPM app, CI build on GitHub Actions.
2. **M1 – Window model (headless):** AX observers plus display assignment, with the output logged. Checks for display assignment, coordinate conversion and the equal-width layout math.
3. **M2 – Bars:** one panel per screen, entries, click interactions.
4. **M3 – Dock replacement and launch at login:** save and restore the Dock, `SMAppService`, onboarding.
5. **M4 – Push windows away.**
6. **M5 – Release:** archive, zip, and a cask in `adericbourg/homebrew-tap`.
7. **M6 – Window preview:** opt-in thumbnail panel on hover, after v1. Depends on the M2 entries and their hover state.
8. **M7 – Settings:** window grouping and task display, after v1. Depends on the M2 interactions.
9. **M8 – App launcher:** a button at the left of the bar and an application list with fuzzy search, after v1. Depends on the M2 bars and keyboard mode.
10. **M9 – Pin applications:** pinned icons on the bar and the "Keep pinned app icons visible" setting, after v1. Depends on the M7 settings window, and on M8 for the bar's order and task width.
11. **M10 – Re-order tasks:** drag and drop a task on its bar, with "Move Left" and "Move Right" as the alternative, after v1. Depends on the M2 entries and interactions and on the M7 group entries.

## Verification (per milestone, once implemented)
- A check executable (`swift run IonizedBarChecks`) for the pure logic, because Command Line Tools have no working test framework (no `TestingMacros` plugin, no XCTest): screen assignment, flipping coordinates between top-left and bottom-left origins, the entry width formula (shrink, then icon-only threshold), and the overlap and fit computation. CI runs it too. If it can't load on the runner's older macOS, lower the minimum from 27.2 to 27.0.
- Manual checklist on 2 displays: open, close, move and minimize windows, then check each bar. Plug and unplug a display. Switch Spaces. Quit the app and check the Dock comes back. Kill it with `kill -9`, relaunch, and check the Dock comes back. Log out and in to check launch at login. Maximize a window to check it doesn't cover the bar.
- `brew install --cask adericbourg/tap/ionized-bar` on a clean user account.
- Manual checklist for M6: previews on and off, a minimized window, two same-app windows with the same frame, keyboard focus and Esc (also with another app frontmost), and the Screen Recording grant being denied.
- Manual checklist for M7: every display mode with every grouping mode, and settings surviving a relaunch. Going past and back under the When full threshold, with each bar deciding on its own. Picking and restoring from a group's list, by mouse and keyboard. Opening settings with no windows open, closing with Cmd-W, and using them with VoiceOver.
- Manual checklist for M8: the button on every bar, in every display mode and with no tasks. Fuzzy search with typos and partial names, opening an app by mouse and keyboard, Esc and a click outside, keys going back to the frontmost app, and VoiceOver.
- Manual checklist for M9: pin and unpin from a task, a group entry and a pinned icon. The icon opening a closed app and raising a running one. The setting on and off, with the app open on one display only, on another Space, and running with no windows. Pins surviving a relaunch, an uninstalled pinned app, and VoiceOver and keyboard on a pinned icon.
- Manual checklist for M10: drag a task and a group entry in every display mode, with and without grouping. A plain click and a small pointer slip still act as a click, and a drop neither raises nor minimizes a window. A drag past either end, and a window opening or closing during a drag. The order across a Space switch, a window moved to another display and back, and ungrouping. "Move Left" and "Move Right" by mouse, keyboard and VoiceOver, disabled at the ends. Reduce Motion, and a drag with a preview showing.

## Known issues (to fix later)
- **The Accessibility grant is lost on every `brew upgrade`.** TCC ties the grant to the code signature, and an ad-hoc or unsigned build gets a new identity on each release. Accepted for v1. Candidate fixes to evaluate later: a Developer ID with a stable Team ID and notarization, or a stable self-signed certificate used for every release. Once M6 ships, the Screen Recording grant is probably affected too (unverified).
- **Gatekeeper quarantine on install.** Same root cause, same fix. Until then, the cask `caveats` and the README document the workaround.
