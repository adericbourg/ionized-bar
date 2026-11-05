# ionized-bar: product brief

This brief describes what IonizedBar does and why. To install or use it, see the [README](../README.md). To build or release it, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Vision

> A taskbar that shows the windows you have open, on the screen where they are, and the Plasma window behaviours macOS lacks.

uBar and boringBar don't fit the need: a KDE Plasma–style taskbar for macOS, with one entry per open window and one bar per display that shows only that display's windows.

- **Platform:** macOS 27.2 or later, Apple silicon. One OS version keeps the test surface small.
- **License:** GPLv3.
- **Distribution:** a Homebrew cask in `adericbourg/homebrew-tap`.

## Taskbar

| Behaviour | What it does | Why |
|---|---|---|
| Taskbar | A horizontal bar at the bottom of the screen. Each entry shows the app icon and the window title, and the active window is highlighted. | The window is the unit of work, as in KDE. |
| One bar per display | Connecting or disconnecting a display adds or removes its bar within about 1 s. The bar follows resolution and arrangement changes. | Each screen shows what is on it. |
| Per-display tasks | A window shows on the bar of the display that holds most of its area. Moving it to another screen moves its entry within about 1 s. | A window straddling two displays still needs one answer. |
| Real windows only | Tasks are standard windows (`AXStandardWindow`). Panels, sheets, utility windows and windowless apps have no task. Minimized windows do, dimmed. | Finder with no windows is not a task, and a minimized window is still open. |
| Equal width | Entries share the bar's width equally, up to about 220 pt. Titles truncate. Below about 48 pt only the icon shows. | Positions stay predictable, and a few windows don't stretch across the screen. |
| Current Space only | Only windows on the active Space are listed, and the list updates on a Space switch. | The bar shows what you can see. |

**Interactions**, as in KDE:

- A click raises and focuses the window.
- A click on the active entry minimizes it.
- A click on a minimized entry restores it.
- A middle-click closes the window.
- A right-click opens a menu: Settings… and Quit IonizedBar, a separator, then Close, Minimize and Quit the app. The empty bar offers the first two.

## Replacing the Dock

The Dock can't be removed, because it hosts Cmd-Tab, Mission Control and Spaces. Autohide with a very long delay is the usual workaround, so the Dock can still be glimpsed at the screen edge.

- **Hiding:** the app saves the Dock prefs, then sets `autohide` to true and `autohide-delay` to 1000 s through `CFPreferences`, and runs `killall Dock`. It waits for the Accessibility permission, since the bar shows no tasks until then.
- **Restoring:** a normal quit, `SIGTERM` or `SIGINT` restores the saved values. A key that wasn't set is deleted, not given a default.
- **Several copies:** a dev build and the installed app share the saved values, and each holds a file lock while it runs. Only the last copy to quit restores the Dock, so the Dock doesn't show under a bar that is still running.
- **After a crash:** the saved values live in the app's own prefs, so the next launch recovers them instead of saving the hidden values as the originals.
- **Leftovers:** an `autohide-delay` of 60 s or more means another taskbar or a lost state left the Dock hidden. The app doesn't treat it as a preference, so a quit leaves the Dock visible.

## Pushing windows off the bar

A window that overlaps the bar is resized or moved through the Accessibility API (AX), so maximizing and zooming don't cover the bar.

- **Target:** the screen's frame minus the bar, and never above the top of `NSScreen.visibleFrame`, so a push doesn't go under the menu bar.
- **Timing:** no push while a mouse button is held or before the frame has settled, so the app doesn't fight a drag.
- **Fullscreen:** fullscreen windows are left alone.
- **Windows that resist:** a window left over the bar, by its minimum size or its app, is not pushed again until its frame changes. This avoids jitter with apps that reposition themselves.
- **Two displays:** a window is only checked against the bar of its assigned display.

## Resizing tiled windows together

With "Resize tiled windows together" on, dragging the edge shared by two windows that fill a screen resizes both, as with Plasma's tiles. It is off by default.

- **Which windows:** two windows, side by side or one above the other, at any ratio, that together fill the screen minus the bar and the menu bar. They can be up to 32 pt short of an edge or apart, because some apps size in text rows, and can go past an edge, because a window can sit under the bar until it is pushed. Only their geometry when the drag starts counts, so nothing links them. Minimized and fullscreen windows don't count, nor do windows on another Space.
- **Trigger:** a mouse drag only. A shortcut from a window manager, an app resizing itself or a push off the bar moves no other window.
- **Following:** live during the drag. The other window's far edge stays where it is.
- **Separating:** a drag that moves any other edge of the window, such as a corner drag, stops following until the next drag. Moving a window by its title bar moves only that window.
- **Stacked windows:** every window that completes the dragged one follows, including those behind. A window stacked behind the dragged one, on the same side, stays.
- **Minimum size:** macOS doesn't let another app stop a drag, so the windows overlap once the follower can't shrink further. On release, the dragged window goes back to the follower's edge.
- **More than two windows:** quarter tiling isn't covered, because a quarter window never fills the screen with one other window.

## Start at login

The app registers itself with `SMAppService.mainApp` once, when Accessibility is first granted. "Start at login" in Settings shows the real status and applies at once. It is not saved separately, and a relaunch doesn't turn it back on.

## Settings

A settings window opens with "Settings…" from a right-click menu. Settings are global, apply at once and are saved in `UserDefaults`. The window has four tabs in its toolbar, General, Widgets, Windows and About, the macOS convention for a few panes.

The General tab holds:

- **Group windows:** Never (default), When full or Always. Each bar decides for itself, because bars differ in width.
- **When full:** apps merge when entries would drop below about 120 pt, or 48 pt with Icon only. The app with the most windows merges first, and merging stops once entries fit. On a tie, the later app on the bar merges first.
- **Show tasks as:** Icon only, App name or Content (default, the window title). A title that isn't shown moves to a tooltip, and VoiceOver reads it in every mode.
- **Icon only:** compact entries of about 48 pt, packed from the left. This is the one exception to the equal width.
- **Keep pinned app icons visible:** see [Pinned apps](#pinned-apps).
- **Start at login:** see [Start at login](#start-at-login).

The Widgets tab holds the [clock](#clock) and [calendar](#calendar) settings. The Windows tab holds [Resize tiled windows together](#resizing-tiled-windows-together). The About tab shows the version and the commit it was built from, which `scripts/bundle.sh` writes into the bundle, because a local build has the same version as the last release. A release shows the last commit before its `chore: release` commit. Below them, a link opens the GitHub repository in the browser.

### Group entries

A group entry holds all of an app's windows on that bar (2 or more), placed where the app's first window was.

- It shows the icon, app name and window count, or the icon and count with Icon only.
- It is highlighted if any of its windows has focus, and dimmed only if all of them are minimized.
- A click opens a native menu that lists the windows. The focused window has a checkmark, and minimized windows say so.
- A middle-click does nothing, so a stray click can't close several windows.
- A right-click offers Settings… and Quit IonizedBar, a separator, then Close All Windows, the move and pin items and Quit the app.

## Window previews

Hovering an entry shows a panel above it with the app icon and name, the window title and a thumbnail. A group entry has no preview, because a preview shows one window and the window list takes that place.

- **Opt-in:** off by default, through "Show window previews" in a window entry's menu. The bar works fully without Screen Recording, and macOS only prompts when previews are turned on. If the permission is denied, no preview appears.
- **Showing and dismissing:** the panel appears after about 300 ms of hover, and on keyboard focus. Esc dismisses it, and it stays open under the pointer (WCAG 1.4.13). A global key monitor can only observe, so the frontmost app gets the Esc too.
- **Display-only:** a click on the panel does nothing.
- **Minimized windows:** macOS lists them but fails the capture, so the panel shows the last captured image, or the header only if there is none.
- **Cache:** in memory only, never on disk. It fills on hover and drops an image when its window closes.
- **Ambiguous match:** public APIs can't map an AX element to a `CGWindowID`, so a window is matched by process ID and bounds within 2 pt. If two windows match, the panel shows the header only, because showing another window's content is worse than showing none.
- **Capture rate:** one capture per hover, not per mouse move, so the bar doesn't stutter.

## App launcher

A button at the left of every bar opens a panel in the layout of Plasma's launcher: a search field on top, a sidebar on the left, apps on the right, and a footer with Restart and Shut Down. Places, the account picture, Sleep and Leave are left out.

- **Button:** fixed at about 48 pt, in every display mode. Tasks share the width left, and a bar is never empty.
- **Applications:** the `.app` bundles in `/Applications`, `/System/Applications` and `~/Applications`, and in their `Utilities` folder, sorted by name.
- **Search:** fuzzy matching over names only, because almost no bundle has a usable description. Typing searches all apps from any view.
- **Sidebar:** Favorites, All Applications, then the categories that have apps.
- **Favorites:** the pinned apps, in the same order, as an icon grid. It is the opening view, or All Applications when nothing is pinned.
- **Hover:** the pointer and the arrow keys share one highlight, as in Plasma. A sidebar item switches view after 150 ms, so crossing the sidebar on the way to an app doesn't replace the list.
- **Restart and Shut Down:** these ask `loginwindow` for the macOS confirmation dialog and never act directly.

**Categories** come from the optional `LSApplicationCategoryType` key in each bundle's `Info.plist`, the only category macOS has. Most of its values hold an app or two, so they merge:

| Group | `public.app-category.*` |
|---|---|
| Development | `developer-tools` |
| Education | `education`, `reference`, `books` |
| Games | `games`, `*-games` |
| Graphics | `graphics-design`, `photography` |
| Internet | `social-networking`, `news` |
| Multimedia | `music`, `video`, `entertainment` |
| Office | `productivity`, `business`, `finance` |
| Utilities | `utilities` |
| Other, always last | any other value, or none |

## Pinned apps

Pinning keeps an app's icon on the bar while the app is closed. The bar reads, from the left: launcher, pinned icons, tasks, then the [clock](#clock) when it is on.

- **Pinning:** "Pin" and "Unpin" are in the menu of a task or group, since a pin belongs to the app and not to a window. "Unpin" is also in the icon's menu. An app with no bundle identifier can't be pinned.
- **Icon:** about 36 pt wide with a 28 pt icon, and the app name as tooltip. A click opens the app. A running app comes to the front and decides whether to reopen a window.
- **Saved as:** an ordered list of bundle identifiers in `UserDefaults`, global to all bars. A pin whose app is no longer installed isn't shown, and stays saved.
- **"Keep pinned app icons visible":** off by default. On, the icon always shows. Off, it hides on a bar that shows a task for the app.
- **Hiding is per bar:** the icon stays on other displays, on Spaces without the app's windows, and for a running app with no windows, so an app can always be reached from any bar.
- **Width:** pins keep their width. Tasks shrink and group in the width left.

## Clock

A clock at the right end of every bar, off by default. It is the first widget, so the code has no widget abstraction until a second one shows what it should be. The layout follows Plasma's panel clock.

- **Layout:** the time alone is one vertically centred line. With the date, the time (13 pt) sits above the date (11 pt), which fits the 36 pt bar with no height change.
- **Width:** measured on a sample date with two digits everywhere, and with monospaced digits. It changes only with the settings or the locale, so tasks don't move as the time changes. Tasks shrink and group in the width left.
- **Updates:** on the second, or on the minute with seconds off. It also refreshes after waking from sleep and after a change of system clock, time zone or locale.
- **Interaction:** a click opens the [calendar](#calendar), and a right-click opens the bar's menu. It is the last keyboard stop. VoiceOver reads it with the date spelled out.

| Setting | Values |
|---|---|
| Display clock | Off (default), On |
| Display seconds | Off (default), On |
| Time format | System default (default), 12-hour, 24-hour |
| Display date | Off (default), On |
| Date format | System default (default), ISO (yyyy-mm-dd), dd/mm/yyyy |

A setting under one that is off stays visible, greyed out, and keeps its value. The ISO and dd/mm/yyyy formats always use the Gregorian calendar.

## Calendar

A click on the clock opens a month calendar above it, in a panel as dark as the launcher. Another click closes it, as do Esc, a click elsewhere and a display change.

- **Month:** it opens on the current month, and reopening returns to it. Arrows beside the title go to the previous or next month.
- **Month and year selectors:** a click on the title replaces the days with the 12 months of that year, under the year as title. A click on that year replaces them with 12 years, under their range as title. Picking a year shows its months, and picking a month shows its days. The panel keeps its size, and the arrows move by a year or by 12 years. Year pages start on multiples of 12, and the current month and year have the same outline as today.
- **Grid:** only the rows the month needs, 4 to 6. The panel always has room for 6, so the arrows don't move under the pointer. Days of the adjacent months are shaded.
- **Today and hover:** today has an outline in the system accent color. Hovering a day fills it with that color. A click on a day does nothing.
- **Week numbers:** week 1 is the first with at least 4 days in the new year, with the chosen first day of the week. With Monday first, these are ISO week numbers.
- **Calendar system:** always Gregorian, because ISO weeks are only defined there. Month and weekday names follow the system locale.
- **Keyboard and VoiceOver:** Tab reaches the title, the arrows and the months or years, and Return or Space presses them. VoiceOver reads each day as a full date, says which is today and announces the new title when it changes.

| Setting | Values |
|---|---|
| First day of week | System default (default), Monday to Sunday |
| Show week numbers | Off (default), On |

These settings are greyed out when the clock is off, because the calendar opens from the clock. A change applies the next time the calendar opens.

## Re-ordering

Dragging a task or a pinned icon along the bar changes its place. Only the entry moves: the window is neither raised nor moved.

- **Click or drag:** a drag starts once the pointer has moved about 4 pt, and its mouse-up is not a click. This keeps a drop from raising or minimizing a window.
- **Ends:** past the first or last place, the entry follows with growing resistance and lands on the nearest end on release.
- **Without dragging:** "Move Left" and "Move Right" in the right-click menu, disabled at the ends (WCAG 2.2 AA 2.5.7). The menu also covers keyboard mode and VoiceOver, so there is no new shortcut.
- **Motion:** the other entries slide apart in under 150 ms, and jump with Reduce Motion on.

**Tasks** stay on their own bar, because a task belongs to its window's display.

- The order is kept in memory only and is lost on quit. AX window elements don't survive a restart, and public APIs have no stable window ID.
- A new window goes last. A window that leaves and returns (Space switch, another display) keeps its place.
- A group drags as one, and its windows stay next to each other if the bar later ungroups.

**Pins** stay between the launcher and the tasks.

- The order is the saved pin list, so it is global to all bars, survives a relaunch and also orders Favorites.
- A pin hidden on this bar keeps its saved place.

## Look and feel

- **Material:** frosted glass (`NSVisualEffectView`, `.hudWindow`). The native Liquid Glass was prototyped and not kept.
- **Appearance:** the bar, the launcher and the calendar are always dark, with a dark tint over the material, which alone turns mid-grey over white. The preview panel follows the system appearance.
- **Bar:** 36 pt high, flush with the bottom edge, with a hairline along its top.
- **Entry:** a rounded tile with a 28 pt icon and the title in the 13 pt system font.
- **Entry states:** active uses a soft tint of the system accent color with an outline in that color, hover a subtle highlight, and minimized about 50% opacity.
- **Motion:** entries animate in, out and on resize in under 150 ms.

## Accessibility

The app follows the spirit of WCAG 2.2 AA.

- **VoiceOver:** every entry is an element with the window title, the app name and its state. Launcher rows and pinned icons have labels, and the launcher announces results and view changes.
- **Keyboard:** ⌃⌥B reaches the bar. It walks the launcher, the pinned icons, the tasks and the clock, and Shift-F10 opens the menus.
- **System settings:** the bar and its panels honor Reduce Motion, Reduce Transparency and Increase Contrast.
- **Contrast:** text keeps a ratio of at least 4.5:1, using label colors rather than hard-coded grey.

## Technical decisions

- **Swift 6 and AppKit, SwiftPM, bundled by a script:** development happens with Command Line Tools only, no Xcode.
- **No sandbox:** the AX APIs require it.
- **Bar window:** a borderless, non-activating `NSPanel` per `NSScreen` at `.statusBar` level, so the bar never takes focus. It joins all Spaces except fullscreen ones, so a fullscreen window covers the display.
- **App tracking:** KVO on `NSWorkspace.runningApplications`, because the launch and terminate notifications skip `LSUIElement` apps.
- **Window tracking:** one `AXObserver` per app. Titles come from AX, so the bar needs no Screen Recording. `CGWindowListCopyWindowInfo` only cross-checks what is on screen.
- **Unresponsive apps:** AX calls use a 0.25 s messaging timeout, so a hung app can't freeze the bar.
- **Preview capture:** `SCScreenshotManager`, since `CGWindowListCreateImage` is unavailable in the macOS 15+ SDK.
- **Re-ordering:** mouse tracking in the entry views rather than `NSDraggingSource`, since nothing leaves the bar. One relative order of all windows is projected onto each bar, so a move doesn't disturb other bars or windows on another Space.
- **Pure logic in `IonizedBarCore`:** a check executable tests it, because Command Line Tools have no working test framework.
- **Self-signed certificate:** the Transparency, Consent and Control (TCC) database then pins grants to the identifier and certificate, not to each build's hash, so they survive upgrades. Gatekeeper doesn't trust it, and a fix needs a paid Developer ID with notarization. Until then the cask removes the quarantine attribute, which a third-party tap may do. See [Signing certificate](DEVELOPMENT.md#signing-certificate).

## Out of scope

A tray widget, windows from all Spaces, a top or side bar position, theming, multiple rows, and recent apps in the launcher.
