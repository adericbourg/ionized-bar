# ionized-bar

A KDE Plasma–style taskbar for macOS that replaces the Dock.

- One bar per display, showing only the windows on that display
- One entry per open window, all with the same width
- Hides the Dock while running and restores it on quit
- Starts at login

> Status: design phase, nothing to install yet. See [docs/PRODUCT.md](docs/PRODUCT.md) for scope, design and roadmap, and [docs/STATUS.md](docs/STATUS.md) for implementation progress.

## Requirements

macOS 27.2 or later. The app needs the Accessibility permission to list, raise and move windows.

## Installation (planned)

```sh
brew install --cask adericbourg/tap/ionized-bar
```

Known issue: releases are not signed yet, so you have to grant the Accessibility permission again after each upgrade. See [Known issues](docs/PRODUCT.md#known-issues-to-fix-later).

## License

[GPLv3](LICENSE)
