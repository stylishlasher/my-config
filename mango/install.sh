#!/usr/bin/env bash
# Установка MangoWC dotfiles из этого репозитория.
# Безопасно запускать повторно: пользовательские настройки (settings.env) сохраняются.
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Определяем корень с конфигами: mango/install.sh -> родитель; или запуск из корня.
if [ -d "$SCRIPT_PATH/../mango" ] && [ -d "$SCRIPT_PATH/../waybar" ]; then
  ROOT="$(cd "$SCRIPT_PATH/.." && pwd)"
elif [ -d "$SCRIPT_PATH/mango" ] && [ -d "$SCRIPT_PATH/waybar" ]; then
  ROOT="$SCRIPT_PATH"
elif [ -d "$SCRIPT_PATH/scripts" ] && [ -f "$SCRIPT_PATH/config.conf" ]; then
  # запущено из каталога mango/, но конфиги лежат на уровень выше? маловероятно
  ROOT="$(cd "$SCRIPT_PATH/.." && pwd)"
else
  echo "Не найдены конфиги (ожидаются каталоги mango/, waybar/, foot/, fuzzel/, mako/, matugen/ рядом с репозиторием)." >&2
  exit 1
fi

DIRS=(mango waybar foot fuzzel mako matugen)
for d in "${DIRS[@]}"; do
  if [ ! -d "$ROOT/$d" ]; then
    echo "Предупреждение: каталог $ROOT/$d не найден, пропускаю." >&2
  fi
done

BK="$HOME/.config-backup-mango-$(date +%Y%m%d_%H%M%S)"
BACKED_UP=0
backup_if_exists() {
  local target="$1" name="$2"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BK"
    mv "$target" "$BK/$name"
    BACKED_UP=1
    echo "бэкап: $target -> $BK/$name"
  fi
}

restore_backup() {
  echo "Ошибка установки, восстанавливаю бэкап..." >&2
  for d in "${DIRS[@]}"; do
    if [ -e "$BK/$d" ] || [ -L "$BK/$d" ]; then
      rm -rf "$HOME/.config/$d"
      mv "$BK/$d" "$HOME/.config/$d"
    fi
  done
  if [ -e "$BK/mango-settings" ]; then
    mkdir -p "$HOME/.local/bin"
    mv "$BK/mango-settings" "$HOME/.local/bin/mango-settings"
  fi
}

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

OLD_ENV=""
if [ -f "$HOME/.config/mango/settings.env" ]; then
  OLD_ENV="$HOME/.config/mango/settings.env"
fi

# Копируем во временную область, затем атомарно подменяем, чтобы не остаться без конфига при сбое.
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/mango-install.XXXXXX")"
cleanup_tmp() { rm -rf "$TMPROOT"; }
trap cleanup_tmp EXIT

for d in "${DIRS[@]}"; do
  if [ -d "$ROOT/$d" ]; then
    cp -a "$ROOT/$d" "$TMPROOT/$d"
  fi
done
if [ -f "$ROOT/bin/mango-settings" ]; then
  cp -a "$ROOT/bin/mango-settings" "$TMPROOT/mango-settings"
fi

# Применяем с откатом при ошибке
on_error() {
  trap - ERR
  restore_backup 2>/dev/null || true
  echo "Установка прервана." >&2
  exit 1
}
trap on_error ERR

for d in "${DIRS[@]}"; do
  [ -d "$TMPROOT/$d" ] || continue
  backup_if_exists "$HOME/.config/$d" "$d"
  cp -a "$TMPROOT/$d" "$HOME/.config/$d"
done

if [ -f "$TMPROOT/mango-settings" ]; then
  if [ -f "$HOME/.local/bin/mango-settings" ]; then
    mkdir -p "$BK"; cp -a "$HOME/.local/bin/mango-settings" "$BK/mango-settings"; BACKED_UP=1
  fi
  install -m755 "$TMPROOT/mango-settings" "$HOME/.local/bin/mango-settings"
fi

if [ -d "$HOME/.config/mango/scripts" ]; then
  chmod +x "$HOME/.config/mango/scripts/"* 2>/dev/null || true
fi

# Слить settings.env: новые ключи добавить, пользовательские значения сохранить.
NEW_ENV="$HOME/.config/mango/settings.env"
if [ -n "$OLD_ENV" ] && [ -f "$BK/mango/settings.env" ] && [ -f "$NEW_ENV" ]; then
  MERGED="$(mktemp "$HOME/.config/mango/.settings.env.XXXXXX")"
  cp "$BK/mango/settings.env" "$MERGED"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    key="${line%%=*}"
    case "$key" in
      *[!A-Za-z0-9_]*|'') continue ;;
    esac
    if ! grep -q "^${key}=" "$MERGED" 2>/dev/null; then
      printf '%s\n' "$line" >> "$MERGED"
    fi
  done < "$NEW_ENV"
  mv "$MERGED" "$NEW_ENV"
  echo "настройки и обои сохранены (settings.env объединён)"
fi

trap - ERR

if [ "$BACKED_UP" = 0 ] && [ -d "$BK" ]; then
  rmdir "$BK" 2>/dev/null || true
fi

# Применить сразу, если мы уже в сессии Wayland
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  { mmsg dispatch reload_config || mmsg -d reload_config; } >/dev/null 2>&1 || true
  pkill -x waybar 2>/dev/null || true
  pkill -x mako 2>/dev/null || true
  sleep 0.2
  command -v waybar >/dev/null 2>&1 && setsid waybar >/dev/null 2>&1 &
  command -v mako >/dev/null 2>&1 && setsid mako >/dev/null 2>&1 &
  if [ -x "$HOME/.config/mango/scripts/wallpaper" ]; then
    "$HOME/.config/mango/scripts/wallpaper" >/dev/null 2>&1 &
  fi
fi

echo ""
echo "✓ Готово."
echo "  Настройки: Super+S   Обои: Super+W   Случайные: Super+Shift+W   Блокировка: Super+L"
echo "  Нужны пакеты: fuzzel fzf mako libnotify swaybg waybar grim slurp wl-clipboard cliphist brightnessctl playerctl pavucontrol foot swaylock python3"
echo "  Опционально: matugen-bin (AUR, цвета из обоев), satty (редактор скриншотов), swayidle, wlsunset/gammastep, polkit-агент"
