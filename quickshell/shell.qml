//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma UseQApplication
//@ pragma IconTheme kora

import Quickshell
import Quickshell.Wayland

ShellRoot {
    Bar {}
    Notifications {}
    SoundOSD {}
    MediaOSD {}
    BrightnessOSD {}
}
