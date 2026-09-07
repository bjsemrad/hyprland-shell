# Epoch Shell

Epoch Shell is a personal desktop shell built with [Quickshell](https://quickshell.org/) for a Wayland desktop. It provides the bar, popups, notifications, OSDs, launcher, and polkit prompt used by the session.

The project is intentionally pragmatic: it keeps only the pieces used by the current configuration and favors a small, understandable QML codebase over a generalized shell framework.

## Features

- Top bar with workspace indicators, launcher, media indicator, clock, weather, network, Bluetooth, volume, Tailscale, battery, notifications, system tray items, and system menu.
- Custom launcher backed by `elephant` for applications, files, clipboard, windows, and calculator results.
- Notification daemon UI with notification history and do-not-disturb support.
- Sound, media, and brightness OSDs.
- Network, Bluetooth, audio, battery, weather, calendar, media, notification, and system popups.
- Built-in polkit authentication agent with password and fingerprint-aware UI.
- Optional external config override file at `~/.config/epochshell/config.toml`.

## Layout

```text
quickshell/
  shell.qml                  # Shell root
  Bar.qml                    # Top bar
  Polkit.qml                 # Polkit authentication prompt
  Notifications.qml          # Notification windows
  SoundOSD.qml               # Volume OSD
  MediaOSD.qml               # Media OSD
  BrightnessOSD.qml          # Brightness OSD
  commonwidgets/             # Shared UI building blocks
  modules/                   # Bar modules and launcher
  popups/                    # Popup panels
  services/                  # QML singletons and backend integrations
  theme/Config.qml           # Defaults plus optional TOML overrides
```

## Running Locally

Run the repo version directly during development:

```bash
quickshell -p /home/brian/projects/EpochShell/quickshell -vv
```

If the installed system service is already running, stop it first to avoid duplicate notification and polkit registration:

```bash
systemctl --user stop epochshell.service
quickshell -p /home/brian/projects/EpochShell/quickshell -vv
```

When finished:

```bash
Ctrl-C
systemctl --user start epochshell.service
```

To reduce Qt font database noise during development:

```bash
quickshell -p /home/brian/projects/EpochShell/quickshell -vv --log-rules 'qt.text.font.db=false'
```

## Launcher

The launcher is implemented in `quickshell/modules/LauncherOverlay.qml` and uses `quickshell/services/LauncherService.qml` to query `elephant`.

Open/toggle is wired through the launcher icon on the bar and the launcher IPC target:

```bash
quickshell ipc call launcher toggle
```

Provider prefixes:

| Prefix | Provider |
|--------|----------|
| `/` | Files |
| `:` | Clipboard |
| `!` | Windows |
| `=` | Calculator |
| `*` | All configured default providers |
| `;` | Provider picker |

Typing a math expression can route to the calculator provider automatically when `calc` is available.

Bitwarden/rbw support is intentionally not included in the current config. Elephant currently panics on some zero-result responses, so Epoch Shell suppresses the known `panic: unexpected end of JSON input` stderr noise and treats it as an empty result set.

Launcher sizing:

- Normal mode: fixed launcher panel size from the QML defaults.
- Files mode (`/`): `60%` screen width by `60%` screen height.
- Clipboard mode (`:`): `40%` screen width by `40%` screen height.
- Preview pane width scales relative to the current panel width.

## Polkit

`quickshell/Polkit.qml` registers a Quickshell polkit agent at:

```text
/org/epochshell/PolkitAgent
```

Only one polkit agent can be active for a session. If local development does not show the prompt, another agent is probably already registered. Check the logs for:

```text
epochshell polkit agent registered
```

Test a prompt with:

```bash
pkexec ls /root
```

The prompt supports password auth and a fingerprint waiting state when `pam_fprintd.so` is present in `/etc/pam.d/polkit-1`. It also checks laptop lid state and falls back to password when the reader is physically unavailable.

## Configuration

Epoch Shell has built-in defaults in `quickshell/theme/Config.qml`. You can override any supported value with:

```text
~/.config/epochshell/config.toml
```

The file is optional. If it does not exist, defaults are used. If it exists, it is treated as a partial override: include only the keys you want to change.

The file is watched by Quickshell, so changes are reloaded at runtime.

Example:

```toml
accent = "#ff00aa"
background = "#0e1013"
fontFamily = "JetBrainsMono Nerd Font Propo"
fontSizeLarge = 22
barHeight = 44
workspaceStripMaxWidthRatio = 0.35
panelAnimationsEnabled = true
```

The parser supports flat TOML-style key/value lines:

```toml
key = "string"
key = 123
key = 0.45
key = true
```

Section headers are ignored, so grouped files like this are also accepted:

```toml
[theme]
accent = "#4fa6ed"
barHeight = 40
```

Unknown keys are ignored with a warning.

### Color Keys

```toml
accent = "#4fa6ed"
accentLightShade = "#1a4fa6ed"
inactive = "#bfa0a8b7"
active = "#a0a8b7"
activeSelection = "#282c34"
background = "#0e1013"
surface = "#1f2329"
surfaceVariant = "#323641"
surfaceContainer = "#1f2329"
surfaceContainerHigh = "#282c34"
surfaceContainerHighest = "#30363f"
surfaceText = "#a0a8b7"
outline = "#8c9199"
purple = "#bf68d9"
green = "#8ebd6b"
orange = "#cc9057"
blue = "#4fa6ed"
yellow = "#e2b86b"
cyan = "#48b0bd"
red = "#e55561"
bg_blue = "#61afef"
bg_yellow = "#e8c88c"
```

Derived colors such as `accentLightShade`, `inactive`, `active`, and `activeSelection` update automatically from their source colors unless explicitly overridden.

### Font Keys

```toml
fontFamily = "JetBrainsMono Nerd Font Propo"
fontSizeNormal = 14
fontSizeMedium = 16
fontSizeLarge = 18
fontSizeXLarge = 24
fontSizeSubtext = 11
```

### Bar Keys

```toml
barHeight = 40
barIconSize = 18
barClockSize = 11
barWeatherSize = 14
barModuleSpacing = 10
barGroupIconSpacing = 20
barIconTextSpacing = 5
barModuleHorizontalPadding = 14
barModuleVerticalPadding = 10
workspaceIcons = true
workspaceStripMaxWidthRatio = 0.45
```

Derived bar values such as `barClockSize`, `barWeatherSize`, `barGroupIconSpacing`, `barModuleHorizontalPadding`, and `barModuleVerticalPadding` update automatically unless explicitly overridden.

### Popup And Card Keys

```toml
popupPadding = 10
popupRadius = 10
popupLayoutSpacing = 8
cardRadius = 10
cardHeight = 50
cardMargin = 14
cardSpacing = 10
selectedBorderWidth = 1
networkPopupWidth = 400
tailscalePopupWidth = 600
bluetoothPopupWidth = 400
audioPopupWidth = 550
systemTrayPopupWidth = 300
systemPopupWidth = 300
batteryPopupWidth = 250
musicPlayerWidth = 600
controlCenterPopupWidth = 700
```

### Layout And Misc Keys

```toml
widthPaddingLarge = 20
widthPaddingSmall = 14
heightPaddingSmall = 5
layoutMarginSmall = 5
layoutSpacingLarge = 20
layoutSpacingSmall = 20
roundRadius = 20
cornerRadius = 18
connectedIconSize = 40
headerSize = 40
panelBottomMargin = 5
panelBottomMarginMedium = 15
statMargin = 12
tailscalePeersFontSize = 14
panelAnimationsEnabled = false
hideInactiveWorkspaces = true
```

### Switch Keys

```toml
switchHeight = 42
switchWidth = 24
switchKnobSize = 20
switchKnobRadius = 10
```

### System Action Keys

```toml
settingsHeaderHeight = 30
settingsHeaderSpacing = 10
systemActionSize = 40
systemActionRadius = 10
systemActionMargin = 30
systemActionSpacing = 10
```

### Volume Slider Keys

```toml
volumeSliderSize = 40
volumeSliderRadius = 20
volumeSliderMargin = 30
volumeSliderSpacing = 10
```

## Dependencies

Epoch Shell expects these tools/services to be available in the session:

- `quickshell`
- `elephant` for launcher results and activation
- `hyprlock` for the lock action
- `wpctl`/PipeWire stack for audio controls
- `networkmanager` stack for network controls
- `bluetoothctl`/BlueZ stack for Bluetooth controls
- `tailscale` for Tailscale status/actions
- `pkexec`/polkit for privileged auth prompts
- Optional `pam_fprintd.so` configuration for fingerprint auth

Some modules are compositor-aware. Hyprland and Niri support are represented by compositor services and workspace modules.

## Development Notes

- The active shell root is `quickshell/shell.qml`.
- Theme and sizing defaults live in `quickshell/theme/Config.qml`.
- QML services are registered in `quickshell/services/qmldir`.
- The current codebase intentionally omits older grouped bar, overview, Nix update, and Bitwarden/rbw paths.
- Live installed config may be generated or read-only depending on the system setup; for development, run directly with `quickshell -p` from this repo.
