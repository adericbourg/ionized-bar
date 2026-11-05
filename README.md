# ionized-bar

A KDE Plasma–style taskbar for macOS that replaces the Dock.

![The bar at the bottom of the screen, with the launcher button, pinned icons and one entry per open window](docs/images/bar.png)

- One bar per display, showing only the windows on that display
- One entry per open window, or per app if you group them, all with the same width
- An app launcher with fuzzy search, and pinned apps
- Optional window previews on hover
- Hides the Dock while running and restores it on quit
- Moves or resizes windows that overlap the bar, so maximizing doesn't cover it

## Install

You need macOS 27.2 or later on Apple silicon.

```sh
brew install --cask adericbourg/tap/ionized-bar
```

The app is self-signed and not notarized, so Gatekeeper would refuse to open it. The cask removes the quarantine attribute after installing, so installing from the tap means trusting it to bypass Gatekeeper for this app.

To install by hand instead:

1. Download the zip from the [releases page](https://github.com/adericbourg/ionized-bar/releases).
2. Move `IonizedBar.app` to `/Applications`.
3. Remove the quarantine attribute:

```sh
xattr -d com.apple.quarantine /Applications/IonizedBar.app
```

## First launch

1. Open IonizedBar.
2. Grant the Accessibility permission. A small window explains why and opens the right System Settings pane. The app needs it to list, raise and move windows.

Once the permission is granted:

- The bar fills with your windows.
- The Dock hides.
- The app adds itself to your login items. To stop this, turn off "Start at login" in Settings. It stays off.

To quit, right-click the bar and pick "Quit IonizedBar". The Dock comes back.

## Use

### Tasks

| Action | Result |
|---|---|
| Click | Raises the window |
| Click the active task | Minimizes it |
| Click a minimized task | Restores it |
| Middle-click | Closes the window |
| Right-click | Opens a menu: Settings…, Quit IonizedBar, then Close, Minimize, Move Left, Move Right, Pin and Quit the app |

A click on a group lists its windows. A middle-click on a group does nothing, so a stray click can't close several windows.

Windows that overlap the bar move up, and shrink if they don't fit. This waits until you release the mouse button. Fullscreen windows are left alone.

### Launcher

The button at the left of the bar lists your applications.

- Type to search all apps. The search tolerates typos.
- Pick Favorites (your pinned apps), All Applications or a category in the sidebar. Apps that declare no category are under Other.
- Press Return or click to open an app.
- Press Escape or click outside to close the panel.
- Restart and Shut Down in the footer show the macOS confirmation dialog. They never act without it.

### Pinned apps

- Pick "Pin" in the right-click menu of a task or a group. The app's icon stays on every bar, between the launcher and the tasks.
- Click the icon to open the app.
- Pick "Unpin" in the same menus or in the icon's own menu.

By default, an icon hides on a bar that shows a task for its app. To always show it, turn on "Keep pinned app icons visible" in Settings.

### Re-ordering

- Drag a task or a pinned icon along the bar. A group moves as one.
- Or pick "Move Left" or "Move Right" in its right-click menu.

The task order is lost on quit. The pin order is saved and applies to all bars.

### Window previews

Previews are off by default.

1. Right-click a task and pick "Show window previews".
2. Grant the Screen Recording permission when macOS asks. The app uses it only to capture the window you hover.

Hovering a task then shows its app, title and a thumbnail. Press Esc to dismiss it. A minimized window shows its last captured image, or no image if you never hovered it. Nothing is written to disk.

### Settings

Pick "Settings…" in a right-click menu of the bar.

| Setting | Values |
|---|---|
| Group windows | Never (default), When full, Always |
| Show tasks as | Icon only, App name, Content (default, the window title) |
| Keep pinned app icons visible | Off by default |
| Start at login | On after the first launch |
| Display clock | Off by default. Shows a clock at the right of the bar. A click on it opens a month calendar |
| Display seconds | Off by default |
| Time format | System default (default), 12-hour, 24-hour |
| Display date | Off by default. Shows the date under the time |
| Date format | System default (default), ISO (yyyy-mm-dd), dd/mm/yyyy |
| First day of week | System default (default), Monday to Sunday. For the calendar |
| Show week numbers | Off by default. For the calendar |
| Resize tiled windows together | Off by default. Dragging the edge between two windows that fill the screen resizes both |

The About tab shows the version and commit you are running. Include them when you report a bug. It also links to the GitHub repository.

### Keyboard

Press ⌃⌥B to focus the bar under the mouse.

| Key | Result |
|---|---|
| Tab, Shift-Tab, Left, Right | Moves between the launcher, the pinned icons, the tasks and the clock |
| Return, Space | Clicks |
| Shift-F10 | Opens the menu |
| Escape | Leaves the bar |

In the launcher, Tab reaches the sidebar and the footer. In the sidebar, Up and Down switch view, Right goes to its apps and Left comes back.

VoiceOver reads every item on the bar and in the launcher. The bar and its panels follow Reduce Motion, Reduce Transparency and Increase Contrast.

## Get the Dock back

The Dock comes back when you quit the app or uninstall the cask. After a crash it stays hidden until the next launch and quit.

If you removed the app after a crash, restore the Dock by hand. These commands reset its autohide settings, so set them again if you used them:

```sh
defaults delete com.apple.dock autohide-delay
defaults write com.apple.dock autohide -bool false
killall Dock
```

## Uninstall

```sh
brew uninstall --cask ionized-bar
```

This quits the app, which restores the Dock, and removes the login item.

## Known limitations

**Dock**

- The Dock can't be removed, only hidden, so it can still be glimpsed at the screen edge.
- Running alongside another taskbar (boringBar, uBar) fights over the Dock. Quitting IonizedBar shows the Dock even if the other taskbar is still running.

**Windows that show when they shouldn't**

- A minimized window on another Space is listed.
- Two windows of one app with the same frame on different Spaces can both be listed.
- A hidden app's windows on other Spaces are listed.
- A hidden app's dialogs, and minimized dialogs, can be listed.
- Native tabs show as one entry per tab while minimized (seen on TextEdit).
- The windows of an app that hangs stay listed across a Space switch while it hangs.

**Slow or stale updates**

- A window moved to another Space with no notification from its app keeps its entry until the app's windows are read again.
- A minimized task can take more than 1 s to dim.
- A minimized task can blink out and back, about 1 minimize in 10 (seen on Claude and IntelliJ).
- An app that fails to attach at launch can stay missing from the bar until you relaunch it.

**Fullscreen**

- The bar stays above fullscreen that isn't a native fullscreen Space: some games, or Firefox with `full-screen-api.macos-native-full-screen` turned off.

**Windows that stay over the bar**

- A window with a large minimum size, or whose app puts it back, stays over the bar until its frame changes.

## More

- [Product brief](docs/PRODUCT.md): what the app does and why
- [Development](docs/DEVELOPMENT.md): build from source and release

## License

[GPLv3](LICENSE)
