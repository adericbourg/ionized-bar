# ionized-bar

A KDE Plasma–style taskbar for macOS that replaces the Dock.

- One bar per display, showing only the windows on that display
- One entry per open window, or per app if you group them, all with the same width
- Hides the Dock while running and restores it on quit
- Moves or resizes windows that overlap the bar, so maximizing doesn't cover it
- Starts at login

> Status: the bars exist, the Dock is hidden while the app runs, and windows are pushed off the bar. Nothing to install yet. See [docs/PRODUCT.md](docs/PRODUCT.md) for scope, design and roadmap, and [docs/STATUS.md](docs/STATUS.md) for implementation progress.

## Requirements

macOS 27.2 or later. The app needs the Accessibility permission to list, raise and move windows; a small window explains it and opens the right System Settings pane.

## Start at login

The first time it has the Accessibility permission, the app adds itself to the login items (`SMAppService`). Turn it off with "Start at login" in Settings; it is not turned back on.

## App launcher

The button at the left of the bar opens a list of your applications, with a search field that tolerates typos. Up, Down and Return, or a click, open an app; Escape or a click outside closes the list. VoiceOver announces the number of results and the selected app. The list follows Reduce Motion, Reduce Transparency and Increase Contrast.

## Pinned apps

"Pin" in the right-click menu of a task or a group keeps the app's icon on the bar, between the launcher button and the tasks, on every display. A click on the icon opens the app. In keyboard mode (see Keyboard) Return or Space does the same and Shift-F10 opens its menu; VoiceOver reads it as a button labelled with the app name and "pinned". "Unpin" is in the same menus and in the icon's own. By default, an icon hides on a bar that shows a task for its app.

## Window previews

Off by default. Turn on "Show window previews" in a window entry's right-click menu; macOS then asks for the Screen Recording permission, used only to capture the hovered window. Hovering an entry (or focusing it with the keyboard) shows its app, title and a thumbnail; Esc dismisses it. A minimized window shows its last captured image, or the header only if it was never hovered. Nothing is written to disk. The panel follows Reduce Motion, Reduce Transparency and Increase Contrast.

## Windows over the bar

A window that ends up over the bar is moved up, and shrunk if it doesn't fit below the menu bar. This waits until the mouse button is released and the frame has held for a moment. Fullscreen windows are left alone. If a push leaves a window over the bar, because of its minimum size or because the app puts it back, it stays there until its frame changes.

## Dock

The Dock can't be removed, so the app hides it the usual way: it sets `autohide` to true and `autohide-delay` to 1000 seconds in `com.apple.dock`, then runs `killall Dock`. It does this only once it has the Accessibility permission, since the bar shows no tasks until then. The Dock can still be glimpsed at the screen edge.

Your original values are saved in the app's own prefs first, and a key that wasn't set is deleted again on restore rather than given a default. They come back on a normal quit, and on `SIGTERM` or `SIGINT`.

`kill -9` or a crash can't restore anything, so the Dock stays hidden until the next launch. That launch treats the saved values as the truth and keeps them: it hides the Dock again and the next quit restores them. Without the permission, it restores them right away.

An `autohide-delay` of 60 seconds or more is not taken for a preference: it means another taskbar or a lost saved state left the Dock hidden. In that case both keys are saved as not set, so quitting IonizedBar leaves the Dock visible. Running alongside another taskbar (boringBar, uBar) still fights over the Dock, and quitting IonizedBar shows it even if that other taskbar is still running.

To get the Dock back by hand, for example after a crash followed by uninstalling the app:

```sh
defaults delete com.apple.dock autohide-delay
defaults write com.apple.dock autohide -bool false
killall Dock
```

## Installation (planned)

```sh
brew install --cask adericbourg/tap/ionized-bar
```

Known issue: releases are not signed yet, so you have to grant the Accessibility permission again after each upgrade. See [Known issues](docs/PRODUCT.md#known-issues-to-fix-later).

## Keyboard

⌃⌥B focuses the bar under the mouse: the active window's entry, or the launcher button if no window is active. Tab, Shift-Tab, Left and Right move between the launcher button, the pinned icons and the entries; Return or Space clicks; Shift-F10 opens the menu; Escape leaves.

## Build

Command Line Tools are enough, Xcode is not needed.

```sh
./scripts/bundle.sh
open --stderr "$(tty)" build/IonizedBar.app
```

Checks: `swift run IonizedBarChecks` runs the pure-logic checks (no XCTest on Command Line Tools) and exits non-zero on failure.

## Releasing

Apple silicon only. `./scripts/archive.sh` builds the bundle and zips it into `build/IonizedBar-<version>.zip`, printing the path and its sha256 (for the cask). To release: bump `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, commit, then push a tag `v<version>`, for example `v0.1.0`. The Release workflow fails if the tag doesn't match the plist, runs the checks and attaches the zip to a GitHub release. A second job then sets `version` and `sha256` in `Casks/ionized-bar.rb` of `adericbourg/homebrew-tap` and pushes it to that repository's `main`. It needs the `HOMEBREW_TAP_TOKEN` secret: a fine-grained token limited to the tap, with `Contents: Read and write`. The cask must already be on the tap's `main`.

After the first release, add the cask to the tap README's table, then on a clean macOS account run `brew install --cask adericbourg/tap/ionized-bar`, open the app, grant Accessibility, uninstall and check the Dock is back.

## License

[GPLv3](LICENSE)
