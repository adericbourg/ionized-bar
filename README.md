# ionized-bar

A KDE Plasma–style taskbar for macOS that replaces the Dock.

- One bar per display, showing only the windows on that display
- One entry per open window, or per app if you group them, all with the same width
- Hides the Dock while running and restores it on quit
- Starts at login

> Status: the bars exist and the Dock is hidden while the app runs. There is no login item and nothing to install yet. See [docs/PRODUCT.md](docs/PRODUCT.md) for scope, design and roadmap, and [docs/STATUS.md](docs/STATUS.md) for implementation progress.

## Requirements

macOS 27.2 or later. The app needs the Accessibility permission to list, raise and move windows; a small window explains it and opens the right System Settings pane.

## Dock

The Dock can't be removed, so the app hides it the usual way: it sets `autohide` to true and `autohide-delay` to 1000 seconds in `com.apple.dock`, then runs `killall Dock`. It does this only once it has the Accessibility permission, since the bar is empty until then. The Dock can still be glimpsed at the screen edge.

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

⌃⌥B focuses the bar under the mouse. Tab, Shift-Tab, Left and Right move between entries; Return or Space clicks; Shift-F10 opens the menu; Escape leaves.

## Build

Command Line Tools are enough, Xcode is not needed.

```sh
./scripts/bundle.sh
open --stderr "$(tty)" build/IonizedBar.app
```

Checks: `swift run IonizedBarChecks` runs the pure-logic checks (no XCTest on Command Line Tools) and exits non-zero on failure.

## License

[GPLv3](LICENSE)
