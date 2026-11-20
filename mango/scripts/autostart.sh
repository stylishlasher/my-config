#!/bin/sh
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots 2>/dev/null
~/.config/mango/scripts/wallpaper &
mako &
waybar &
# История буфера обмена (Super+C)
if command -v cliphist >/dev/null 2>&1; then
  wl-paste --type text  --watch cliphist store &
  wl-paste --type image --watch cliphist store &
fi
