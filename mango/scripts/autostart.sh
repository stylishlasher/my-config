#!/bin/sh
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots 2>/dev/null

# Настройки пользователя
[ -f "$HOME/.config/mango/settings.env" ] && . "$HOME/.config/mango/settings.env"

~/.config/mango/scripts/wallpaper &
mako &
waybar &

# Док (настраиваемый Waybar-док)
if [ "${DOCK_ENABLED:-0}" = "1" ] && [ -x "$HOME/.config/mango/scripts/dock" ]; then
  "$HOME/.config/mango/scripts/dock" start >/dev/null 2>&1 &
fi

# История буфера обмена (Super+C)
if command -v cliphist >/dev/null 2>&1; then
  wl-paste --type text  --watch cliphist store &
  wl-paste --type image --watch cliphist store &
fi
