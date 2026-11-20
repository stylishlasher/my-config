#!/usr/bin/env bash
# Установка. Безопасно запускать повторно: обои и настройки (settings.env) сохраняются.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
BK="$HOME/.config-backup-$(date +%s)"
for d in mango waybar foot fuzzel mako matugen; do
  if [ -e "$HOME/.config/$d" ]; then mkdir -p "$BK"; mv "$HOME/.config/$d" "$BK/"; echo "бэкап: $d -> $BK"; fi
  mkdir -p "$HOME/.config"; cp -r "$SRC/$d" "$HOME/.config/$d"
done
chmod +x "$HOME"/.config/mango/scripts/*
mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"
install -m755 "$SRC/bin/mango-settings" "$HOME/.local/bin/mango-settings"

# Вернуть прежние настройки (обои, акцент, браузер…), новые ключи дописать
NEW="$HOME/.config/mango/settings.env"
OLD="$BK/mango/settings.env"
if [ -f "$OLD" ]; then
  cp "$OLD" "$NEW.merged"
  while IFS= read -r line; do
    k="${line%%=*}"; grep -q "^$k=" "$OLD" || echo "$line" >> "$NEW.merged"
  done < "$NEW"
  mv "$NEW.merged" "$NEW"
  echo "настройки и обои сохранены"
fi

# Прежний акцент поверх свежих конфигов
. "$NEW" 2>/dev/null || true
if [ -n "$ACCENT" ] && [ "$ACCENT" != cba6f7 ] && command -v gum >/dev/null; then
  "$HOME/.local/bin/mango-settings" accent "$ACCENT" >/dev/null 2>&1 || true
fi

# Применить сразу, если мы уже в сессии
if [ -n "$WAYLAND_DISPLAY" ]; then
  { mmsg dispatch reload_config || mmsg -d reload_config; } >/dev/null 2>&1 || true
  pkill -x waybar 2>/dev/null || true
  pkill -x mako 2>/dev/null || true
  sleep 0.3
  command -v waybar >/dev/null && setsid waybar >/dev/null 2>&1 &
  command -v mako   >/dev/null && setsid mako   >/dev/null 2>&1 &
  "$HOME/.config/mango/scripts/wallpaper" >/dev/null 2>&1 &
fi

echo ""
echo "✓ Готово."
echo "  Настройки: Super+S (ещё раз — закрыть)   Обои: Super+W   Случайные: Super+Shift+W"
echo "  Нужны пакеты: fuzzel gum mako libnotify swaybg waybar grim slurp wl-clipboard cliphist"
echo "  Опционально: matugen-bin (AUR, цвета из обоев), satty (редактор скриншотов)"
