#!/usr/bin/env bash
# ==============================================================================
# ARCH MULTITOOL v3 — универсальный установщик и обслуживание Arch Linux
# ==============================================================================
# Что умеет:
#   1) Полная установка и настройка окружения одной командой
#   2) Инструменты обслуживания системы (аудит, обновление, очистка и т.д.)
#   3) Отдельная установка/настройка любого компонента из пункта 1
#
# Скрипт самодостаточен: личные конфиги (fish, neovim, neovide, темы Serpantinum)
# берутся из папки рядом со скриптом, а если её нет — скачиваются из GitHub.
#
# Запуск от обычного пользователя (sudo запрашивается по необходимости).
#   -h  справка   |   -a  только аудит   |   -f  полная установка без меню
# ==============================================================================

set -uo pipefail

# ------------------------------- Конфигурация --------------------------------
# Необязательный файл конфигурации (обычный bash-синтаксис).
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/arch_multitool.conf"

# --- Личные конфиги ---
# Репозиторий с конфигами: fish/, nvim/, neovide/, *.json (темы), install.txt
REPO_SLUG="stylishlasher/my-config"
REPO_BRANCH="main"
CONFIG_TARBALL="https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_BRANCH}"

# Команда установки dotfiles (используется, если нет локального install.txt)
DOTFILES_CMD="curl -fsSL install.serpantinum.dev | bash"

# Файлы-пресеты Serpantinum (archy), которые нужно применить
THEME_FILES=(glass.json archy-style.json)
# Каталог состояния Serpantinum и подкаталог для пресетов (archy)
SERPANTINUM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum"
THEME_DIR="$SERPANTINUM_STATE_DIR/presets"
# Плагины fish (для fisher)
FISH_PLUGINS=(jorgebucaran/fisher ilancosman/tide@v6)

# --- Прочее ---
DOTFILES=(hypr kitty fish nvim neovide serpantinum gpu-screen-recorder nwg-look)
ESSENTIALS=(discord telegram-desktop gpu-screen-recorder gpu-screen-recorder-ui spotify steam btop)
PACCACHE_KEEP=2
JOURNAL_MAX="100M"
BACKUP_DIR="$HOME"
BACKUP_KEEP=5
REPORT_DIR="$HOME"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/arch_multitool.log"

# Каталог, где лежит сам скрипт (для поиска локальных конфигов)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# --------------------------------- Цвета -------------------------------------
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# --------------------------------- Утилиты -----------------------------------
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log()  { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE" 2>/dev/null; }
info() { echo -e "${CYAN}$*${NC}"; log "INFO  $*"; }
warn() { echo -e "${YELLOW}$*${NC}"; log "WARN  $*"; }
ok()   { echo -e "${GREEN}[✓] $*${NC}"; log "OK    $*"; }
err()  { echo -e "${RED}[✗] $*${NC}" >&2; log "ERROR $*"; }

pause() { echo; read -rp "${YELLOW}Нажмите Enter для продолжения...${NC}" _; }

# confirm "вопрос" -> 0 если да (по умолчанию «нет»)
confirm() {
    local ans
    read -rp "${YELLOW}$1 [y/N]: ${NC}" ans
    [[ "$ans" =~ ^[YyДд]$ ]]
}

has() { command -v "$1" &>/dev/null; }

# Однократный запрос sudo + поддержание тикета на время сессии
SUDO_KEEPALIVE_PID=""
WORK_DIR=""
ensure_sudo() {
    if [[ $EUID -eq 0 ]]; then
        err "Не запускайте скрипт от root: makepkg и AUR-хелперы откажутся работать."
        return 1
    fi
    has sudo || { err "sudo не установлен."; return 1; }
    sudo -v || return 1
    if [[ -z "$SUDO_KEEPALIVE_PID" ]]; then
        ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
        SUDO_KEEPALIVE_PID=$!
    fi
}

ensure_work_dir() { [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] || WORK_DIR=$(mktemp -d); }

cleanup() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    return 0
}
trap cleanup EXIT
trap 'echo; warn "Прервано пользователем."; exit 130' INT TERM

require_arch() {
    if ! has pacman; then
        err "pacman не найден — скрипт предназначен для Arch Linux и производных."
        exit 1
    fi
}

aur_helper() {
    if has paru; then echo paru; elif has yay; then echo yay; fi
}

# Не мешаем уже запущенному pacman
pacman_busy() {
    if [[ -e /var/lib/pacman/db.lck ]]; then
        err "База pacman заблокирована (/var/lib/pacman/db.lck). Другой pacman запущен?"
        return 0
    fi
    return 1
}

# Установка пакета(ов) через pacman с запросом sudo
pac_install() {
    sudo pacman -S --needed --noconfirm "$@"
}

# Убедиться, что установлены нужные инструменты (curl/git/tar/...)
ensure_tools() {
    local -a missing=() t
    for t in "$@"; do has "$t" || missing+=("$t"); done
    (( ${#missing[@]} == 0 )) && return 0
    warn "Устанавливаю недостающие утилиты: ${missing[*]}"
    ensure_sudo || return 1
    pac_install "${missing[@]}"
}

# Количество непустых строк в переменной
count_lines() { [[ -n "$1" ]] && printf '%s\n' "$1" | wc -l || echo 0; }
# Склеить строки в "a, b, c"
join_lines() { printf '%s\n' "$1" | paste -sd ',' - | sed 's/,/, /g'; }

# Переместить существующий путь в резервную копию (path.bak.<дата>)
stash_dir() {
    local p="$1"
    [[ -e "$p" ]] || return 0
    local b="${p}.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$p" "$b" && info "Старое сохранено: $b"
}

# Заменить жёстко прописанный домашний путь старого пользователя на текущий $HOME
normalize_paths() {
    local dir="$1"
    [[ "$HOME" == "/home/lislash" ]] && return 0
    grep -rlI -- '/home/lislash' "$dir" 2>/dev/null | while IFS= read -r f; do
        sed -i "s|/home/lislash|$HOME|g" "$f"
    done
}

# ОГРОМНАЯ памятка: пресеты Serpantinum нужно включить вручную
serpantinum_notice() {
    local b="${BOLD}${YELLOW}" n="${NC}"
    local bar="████████████████████████████████████████████████████████████████████████████████████"
    echo
    echo -e "${b}${bar}${n}"
    echo -e "${b}  ⚠  ВАЖНО: ПРЕСЕТЫ ПРИМЕНЕНЫ, НО ИХ НУЖНО ВКЛЮЧИТЬ ВРУЧНУЮ!${n}"
    echo -e "${b}${bar}${n}"
    echo -e "${b}  Serpantinum  →  Настройки  →  Presets (Пресеты)  →  выбрать тему${n}"
    echo -e "${b}  Доступные темы:  glass  /  archy-style${n}"
    echo -e "${b}${bar}${n}"
    echo
}

# ------------------------------------------------------------------------------
# ИСТОЧНИК КОНФИГОВ (локально или из GitHub)
# ------------------------------------------------------------------------------
CONFIGS_DIR=""
CONFIGS_READY=0
resolve_configs() {
    (( CONFIGS_READY )) && return 0

    # 1. Ищем локальные конфиги рядом со скриптом или в текущем каталоге
    local d
    for d in "$SCRIPT_DIR" "$PWD"; do
        if [[ -d "$d/fish" || -d "$d/nvim" || -f "$d/glass.json" ]]; then
            CONFIGS_DIR="$d"; CONFIGS_READY=1
            info "Использую локальные конфиги: $CONFIGS_DIR"
            return 0
        fi
    done

    # 2. Скачиваем архив из GitHub
    ensure_tools curl tar || return 1
    ensure_work_dir
    local tarball="$WORK_DIR/configs.tar.gz"
    warn "Скачиваю конфиги из https://github.com/${REPO_SLUG} ..."
    if ! curl -fsSL --connect-timeout 20 --retry 2 "$CONFIG_TARBALL" -o "$tarball"; then
        err "Не удалось скачать конфиги (нет сети?)."
        return 1
    fi
    mkdir -p "$WORK_DIR/configs"
    if ! tar -xzf "$tarball" -C "$WORK_DIR/configs"; then
        err "Не удалось распаковать архив конфигов."
        return 1
    fi
    local root
    for root in "$WORK_DIR"/configs/*/; do
        [[ -d "$root" ]] || continue
        CONFIGS_DIR="${root%/}"
        break
    done
    [[ -n "$CONFIGS_DIR" ]] || { err "Архив конфигов пуст."; return 1; }
    CONFIGS_READY=1
    ok "Конфиги готовы: $CONFIGS_DIR"
    return 0
}

# ------------------------------------------------------------------------------
# 1. АУДИТ СИСТЕМЫ
# ------------------------------------------------------------------------------
run_audit() {
    [[ "${AUDIT_ONLY:-0}" == 1 ]] || clear
    info "Запуск аналитики системы..."
    echo

    local report_file now
    report_file="$REPORT_DIR/system_audit_report_$(date +%Y%m%d_%H%M%S).txt"
    now=$(date "+%Y-%m-%d %H:%M:%S")

    # --- Система ---
    local os_name kernel host cpu_name uptime_str
    os_name=$( (source /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$NAME}") || echo "Arch Linux")
    kernel=$(uname -r)
    host=$(hostnamectl hostname 2>/dev/null || hostname 2>/dev/null || echo "unknown")
    cpu_name=$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
    [[ -z "$cpu_name" ]] && cpu_name=$(awk -F: '/model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' /proc/cpuinfo)
    uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //')

    # --- Память ---
    local ram_total ram_used swap_total
    ram_total=$(free -h | awk '/^Mem:/  {print $2}')
    ram_used=$(free -h  | awk '/^Mem:/  {print $3}')
    swap_total=$(free -h | awk '/^Swap:/ {print $2}')

    # --- GPU и драйверы ---
    local gpu_info drivers
    gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | cut -d: -f3- | sed 's/^[ \t]*//')
    drivers=$(lspci -nnk 2>/dev/null | grep -A3 -iE 'vga|3d|display' | awk -F': ' '/Kernel driver in use/ {print $2}' | sort -u)
    [[ -n "$gpu_info" ]] && gpu_info=$(join_lines "$gpu_info") || gpu_info="не определена (pciutils не установлен?)"
    [[ -n "$drivers"  ]] && drivers=$(join_lines "$drivers")   || drivers="не определены"

    # --- Диски ---
    local disks_info
    disks_info=$(df -h -x tmpfs -x devtmpfs -x squashfs -x efivarfs --output=target,size,pcent 2>/dev/null \
        | tail -n +2 | awk '{print "    " $1 " (" $2 ", занято " $3 ")"}')

    # --- Пакеты (один вызов pacman -Qq вместо многократных) ---
    local all_pkgs total_pacman total_aur=0 total_flatpak=0 helper
    all_pkgs=$(pacman -Qq 2>/dev/null)
    total_pacman=$(count_lines "$all_pkgs")
    helper=$(aur_helper)
    total_aur=$(pacman -Qmq 2>/dev/null | wc -l)   # чужие пакеты — без зависимости от хелпера
    has flatpak && total_flatpak=$(flatpak list --app 2>/dev/null | wc -l)
    : "$helper"

    local orphans_list orphans_count orphans_str
    orphans_list=$(pacman -Qtdq 2>/dev/null)
    orphans_count=$(count_lines "$orphans_list")
    [[ -n "$orphans_list" ]] && orphans_str=$(join_lines "$orphans_list") || orphans_str="отсутствуют"

    local cache_size updates_count="н/д"
    cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}')
    has checkupdates && updates_count=$(checkupdates 2>/dev/null | wc -l)

    # --- Безопасность ---
    local fw_status="Отключен / не установлен" fw_score=0
    if has firewall-cmd && systemctl is-active --quiet firewalld; then
        fw_status="Активен (firewalld)"; fw_score=15
    elif has ufw && systemctl is-active --quiet ufw; then
        fw_status="Активен (ufw)"; fw_score=15
    elif systemctl is-active --quiet nftables; then
        fw_status="Активен (nftables)"; fw_score=15
    fi

    local mac_status="Не активен"
    systemctl is-active --quiet apparmor 2>/dev/null && mac_status="Активен (AppArmor)"

    # Микрокод: проверяем соответствие вендору CPU
    local ucode_status="Не найден" ucode_score=0 vendor expected_ucode
    vendor=$(awk -F: '/vendor_id/ {gsub(/ /,"",$2); print $2; exit}' /proc/cpuinfo)
    case "$vendor" in
        GenuineIntel) expected_ucode="intel-ucode" ;;
        AuthenticAMD) expected_ucode="amd-ucode" ;;
        *)            expected_ucode="" ;;
    esac
    if [[ -n "$expected_ucode" ]] && grep -qx "$expected_ucode" <<< "$all_pkgs"; then
        ucode_status="Установлен ($expected_ucode)"; ucode_score=10
    elif [[ -z "$expected_ucode" ]] && grep -qE '^(amd|intel)-ucode$' <<< "$all_pkgs"; then
        ucode_status="Установлен"; ucode_score=10
    elif [[ -n "$expected_ucode" ]]; then
        ucode_status="Не найден (нужен $expected_ucode)"
    fi

    # Упавшие systemd-юниты
    local failed_units failed_count failed_str="нет"
    failed_units=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
    failed_count=$(count_lines "$failed_units")
    [[ -n "$failed_units" ]] && failed_str=$(join_lines "$failed_units")

    local secureboot="н/д"
    if has bootctl; then
        secureboot=$(bootctl status 2>/dev/null | awk -F': ' '/Secure Boot/ {print $2; exit}')
        [[ -z "$secureboot" ]] && secureboot="н/д"
    fi

    # --- Dotfiles ---
    local checked_cfgs="" found=0 cfg
    for cfg in "${DOTFILES[@]}"; do
        if [[ -e "$HOME/.config/$cfg" ]]; then
            found=$((found + 1)); checked_cfgs+=$'\n'"  [✓] ~/.config/$cfg"
        else
            checked_cfgs+=$'\n'"  [✗] ~/.config/$cfg (не найден)"
        fi
    done
    local dot_score=0
    (( ${#DOTFILES[@]} > 0 )) && dot_score=$(( found * 35 / ${#DOTFILES[@]} ))

    # --- Профиль (точное совпадение имён пакетов) ---
    local has_hypr=0 has_game=0 has_dev=0
    grep -qE '^(hyprland|hyprpaper|hyprpicker)$' <<< "$all_pkgs" && has_hypr=1
    grep -qE '^(steam|lutris|mangohud|gamemode|wine|heroic-games-launcher|gamescope)$' <<< "$all_pkgs" && has_game=1
    grep -qE '^(docker|podman|virt-manager|qemu-full|qemu-desktop|neovim|code|visual-studio-code-bin|gcc|clang)$' <<< "$all_pkgs" && has_dev=1

    local pipewire="Нет" bt="Нет"
    systemctl --user is-active --quiet pipewire && pipewire="Да"
    systemctl is-active --quiet bluetooth && bt="Да"

    # --- Оценка ---
    local penalty=0 total
    (( orphans_count > 0 )) && penalty=$((penalty + 5))
    (( failed_count  > 0 )) && penalty=$((penalty + 5))
    total=$(( 40 + fw_score + ucode_score + dot_score - penalty ))
    (( total > 100 )) && total=100
    (( total < 0   )) && total=0

    local profile="Стандартный Linux Desktop"
    if   (( has_game && has_dev )); then profile="Игровая и разработческая станция"
    elif (( has_game ));            then profile="Игровой ПК"
    elif (( has_dev ));             then profile="Рабочая станция разработчика"
    elif (( has_hypr ));            then profile="Кастомное Wayland-окружение (Hyprland)"
    fi

    cat > "$report_file" << REPORT
================================================================================
                  СИСТЕМНЫЙ АУДИТ (ARCH LINUX)
================================================================================
Дата и время           : $now
Операционная система   : $os_name
Ядро                   : $kernel
Имя хоста              : $host
Аптайм                 : $uptime_str
Пользователь / шелл    : ${USER:-$(id -un)} / ${SHELL:-н/д}

--------------------------------------------------------------------------------
1. ОБОРУДОВАНИЕ И ДИСКИ
--------------------------------------------------------------------------------
Процессор              : $cpu_name
Память                 : всего $ram_total | использовано $ram_used
Подкачка               : $swap_total
Видеокарта             : $gpu_info
Драйверы GPU           : $drivers
Разделы:
$disks_info

--------------------------------------------------------------------------------
2. БЕЗОПАСНОСТЬ И СЛУЖБЫ
--------------------------------------------------------------------------------
Брандмауэр             : $fw_status [+$fw_score/15]
Микрокод CPU           : $ucode_status [+$ucode_score/10]
Мандатный доступ       : $mac_status
Secure Boot            : $secureboot
Pipewire (user)        : $pipewire
Bluetooth              : $bt
Упавшие юниты systemd  : $failed_count ($failed_str)

--------------------------------------------------------------------------------
3. ПАКЕТЫ
--------------------------------------------------------------------------------
Всего в pacman         : $total_pacman
Сторонние/AUR          : $total_aur
Flatpak                : $total_flatpak
Доступно обновлений    : $updates_count
Кэш pacman             : ${cache_size:-н/д}
Сироты                 : $orphans_count
Список сирот           : $orphans_str

--------------------------------------------------------------------------------
4. КОНФИГУРАЦИИ (~/.config)
--------------------------------------------------------------------------------
Ключевые каталоги:$checked_cfgs

Полнота окружения: $dot_score / 35

--------------------------------------------------------------------------------
5. ИТОГ
--------------------------------------------------------------------------------
Профиль                : $profile
Индекс конфигурации    : $total / 100

Детализация:
  • Базовая стабильность : 40/40
  • Брандмауэр           : $fw_score/15
  • Микрокод             : $ucode_score/10
  • Dotfiles             : $dot_score/35
  • Штрафы               : -$penalty (сироты −5, упавшие юниты −5)

Шкала:
  [85-100] Отлично сбалансированная и защищённая система
  [65-84]  Хорошая система, есть замечания
  [0-64]   Базовая установка, нужна оптимизация
================================================================================
REPORT

    ok "Аудит завершён. Отчёт: ${BOLD}$report_file"
    echo -e "${YELLOW}Рейтинг системы: ${BOLD}$total / 100${NC}"
    (( failed_count > 0 )) && warn "Есть упавшие юниты: $failed_str"
    [[ "${AUDIT_ONLY:-0}" == 1 ]] || pause
}

# ------------------------------------------------------------------------------
# 2. ОБНОВЛЕНИЕ СИСТЕМЫ
# ------------------------------------------------------------------------------
update_system_core() {
    info "=== Полное обновление системы ==="
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "[1/2] Обновление системы (pacman -Syu, keyring — в той же транзакции)..."
    sudo pacman -Syu --needed archlinux-keyring || { err "Обновление pacman завершилось с ошибкой."; return 1; }

    local helper; helper=$(aur_helper)
    if [[ -n "$helper" ]]; then
        warn "[2/2] Обновление AUR ($helper)..."
        "$helper" -Sua
    else
        warn "[2/2] AUR-хелпер не найден — пропуск."
    fi

    echo
    local n; n=$(find /etc -name '*.pacnew' 2>/dev/null | wc -l)
    (( n > 0 )) && warn "Найдено .pacnew файлов: $n — разберите их через 'sudo pacdiff' (пакет pacman-contrib)."

    if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
        warn "Запущенное ядро ($(uname -r)) больше не установлено — требуется перезагрузка."
    fi
    ok "Обновление завершено."
}

update_system() { clear; update_system_core; pause; }

# ------------------------------------------------------------------------------
# 3. AUR-ХЕЛПЕР
# ------------------------------------------------------------------------------
# Спросить, какой хелпер ставить (или вернуть уже установленный)
choose_helper() {
    local existing; existing=$(aur_helper)
    [[ -n "$existing" ]] && { echo "$existing"; return 0; }
    echo
    echo -e "${YELLOW}Какой AUR-хелпер установить?${NC}"
    echo "1) yay"
    echo "2) paru"
    local c; read -rp "Выбор [1-2] (по умолчанию yay): " c
    case "$c" in 2) echo paru ;; *) echo yay ;; esac
}

install_aur_helper_core() {
    local helper="${1:-yay}"
    if has "$helper"; then ok "$helper уже установлен."; return 0; fi

    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка base-devel и git..."
    sudo pacman -S --needed --noconfirm base-devel git || { err "Не удалось установить зависимости."; return 1; }

    ensure_work_dir
    local dir="$WORK_DIR/$helper"
    rm -rf "$dir"
    warn "Клонирование AUR-репозитория ($helper)..."
    if ! git clone --depth 1 "https://aur.archlinux.org/${helper}.git" "$dir"; then
        err "git clone не удался (проверьте сеть)."; return 1
    fi

    echo
    warn "PKGBUILD из AUR — это произвольный код. Рекомендуется просмотреть его перед сборкой."
    if confirm "Показать PKGBUILD?"; then
        ${PAGER:-less} "$dir/PKGBUILD"
    fi
    confirm "Продолжить сборку $helper?" || { warn "Отменено."; return 1; }

    if ( cd "$dir" && makepkg -si --noconfirm ); then
        ok "$helper успешно установлен!"
    else
        err "Сборка $helper завершилась с ошибкой."
        return 1
    fi
}

install_aur_helper_menu() {
    clear
    info "=== Установка AUR-хелпера ==="
    echo
    echo "1) yay"
    echo "2) paru"
    echo "0) Назад"
    local c
    read -rp "Выберите [0-2]: " c
    case "$c" in
        1) install_aur_helper_core yay ;;
        2) install_aur_helper_core paru ;;
        0) return ;;
        *) err "Неверный выбор" ;;
    esac
    pause
}

# ------------------------------------------------------------------------------
# 4. DOTFILES (SERPANTINUM)
# ------------------------------------------------------------------------------
install_dotfiles_core() {
    info "=== Установка dotfiles (Serpantinum) ==="
    echo
    warn "Будет установлено окружение Serpantinum (Hyprland, Quickshell и т.д.)."

    # Serpantinum умеет собрать yay-bin сам, но по требованиям нужен AUR-хелпер.
    local helper; helper=$(aur_helper)
    if [[ -z "$helper" ]]; then
        warn "AUR-хелпер (yay/paru) не найден."
        if confirm "Установить AUR-хелпер сейчас?"; then
            install_aur_helper_core "$(choose_helper)" || { err "Без AUR-хелпера продолжаем на свой риск."; }
            helper=$(aur_helper)
        fi
    fi

    ensure_sudo || return 1

    # Команда установки: из локального install.txt, иначе — стандартная
    local cmd="$DOTFILES_CMD"
    if resolve_configs >/dev/null 2>&1 && [[ -f "$CONFIGS_DIR/install.txt" ]]; then
        local raw line
        raw=$(tr -d '\r' < "$CONFIGS_DIR/install.txt")
        while IFS= read -r line; do
            [[ -n "${line//[[:space:]]/}" ]] && { cmd="$line"; break; }
        done <<< "$raw"
    fi
    [[ -z "$cmd" ]] && cmd="$DOTFILES_CMD"

    echo
    info "Команда установки: ${BOLD}$cmd${NC}"
    confirm "Запустить установщик dotfiles?" || { warn "Отменено."; return 1; }

    # Запускаем в подоболочке, чтобы installer не утянул за собой наш скрипт
    if bash -c "$cmd"; then
        ok "Dotfiles установлены."
    else
        err "Установщик dotfiles завершился с ошибкой."
        return 1
    fi
}

install_dotfiles() {
    clear
    install_dotfiles_core
    apply_archy_themes
    pause
}

# ------------------------------------------------------------------------------
# 5. ТЕМЫ SERPANTINUM (archy: glass / archy-style)
# ------------------------------------------------------------------------------
apply_archy_themes() {
    resolve_configs || return 1

    # Считаем, сколько файлов-пресетов реально есть в конфигах
    local f found=0
    for f in "${THEME_FILES[@]}"; do
        [[ -f "$CONFIGS_DIR/$f" ]] && found=$((found + 1))
    done
    if (( found == 0 )); then
        warn "Файлы пресетов не найдены в конфигах (${THEME_FILES[*]})."
        return 1
    fi

    # Кладём пресеты в ~/.local/state/serpantinum/presets
    mkdir -p "$THEME_DIR"
    for f in "${THEME_FILES[@]}"; do
        [[ -f "$CONFIGS_DIR/$f" ]] && cp -a "$CONFIGS_DIR/$f" "$THEME_DIR/$f"
    done
    ok "Пресеты Serpantinum применены ($found) → $THEME_DIR"

    serpantinum_notice
}

# ------------------------------------------------------------------------------
# 6. FISH
# ------------------------------------------------------------------------------
apply_fish_config() {
    resolve_configs || return 1
    local src="$CONFIGS_DIR/fish"
    [[ -d "$src" ]] || { err "Каталог fish/ не найден в конфигах."; return 1; }

    local dst="$HOME/.config/fish"
    stash_dir "$dst"
    mkdir -p "$dst"

    # Копируем только осмысленные элементы (без случайных fish_variablesXXXX)
    local item
    for item in config.fish fish_plugins fish_variables conf.d functions completions; do
        [[ -e "$src/$item" ]] && cp -a "$src/$item" "$dst/"
    done
    normalize_paths "$dst"
    ok "Конфиг fish применён → $dst"
}

install_fish_plugins() {
    has fish || return 0
    info "Установка плагинов fish (fisher/tide)..."
    if fish -c 'functions -q fisher; and fisher update' 2>/dev/null; then
        ok "Плагины fish обновлены (fisher update)."
    elif fish -c "fisher install ${FISH_PLUGINS[*]}" 2>/dev/null; then
        ok "Плагины fish установлены."
    else
        warn "Не удалось установить плагины fish. Позже вручную: fisher update"
    fi
}

set_default_shell_fish() {
    has fish || return 0
    local fsh; fsh=$(command -v fish)
    if [[ "${SHELL:-}" == "$fsh" ]]; then
        ok "fish уже является оболочкой по умолчанию."
        return 0
    fi
    if confirm "Сделать fish оболочкой по умолчанию (chsh -s $fsh)?"; then
        if chsh -s "$fsh"; then
            ok "Оболочка по умолчанию изменена на fish (вступит в силу после входа)."
        else
            err "chsh не удался."
        fi
    fi
}

install_fish_core() {
    info "=== Установка Fish + плагины ==="
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка пакета fish..."
    pac_install fish || { err "Не удалось установить fish."; return 1; }

    apply_fish_config || warn "Конфиг fish не применён."
    install_fish_plugins
    set_default_shell_fish
    ok "Fish готов."
}

install_fish() { clear; install_fish_core; pause; }

# ------------------------------------------------------------------------------
# 7. NEOVIM + NEOVIDE
# ------------------------------------------------------------------------------
apply_nvim_config() {
    resolve_configs || return 1
    local src="$CONFIGS_DIR/nvim/init.lua"
    [[ -f "$src" ]] || { err "nvim/init.lua не найден в конфигах."; return 1; }

    local dst="$HOME/.config/nvim"
    mkdir -p "$dst"
    if [[ -f "$dst/init.lua" ]]; then
        cp -a "$dst/init.lua" "$dst/init.lua.bak.$(date +%Y%m%d_%H%M%S)"
        info "Старый init.lua сохранён."
    fi
    cp -a "$src" "$dst/init.lua"
    normalize_paths "$dst"
    ok "Конфиг Neovim применён → $dst/init.lua"
}

apply_neovide_config() {
    resolve_configs || return 0
    local src="$CONFIGS_DIR/neovide"
    if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
        local dst="$HOME/.config/neovide"
        stash_dir "$dst"
        mkdir -p "$dst"
        cp -a "$src/." "$dst/"
        normalize_paths "$dst"
        ok "Конфиг Neovide применён → $dst"
    else
        info "Отдельного конфига Neovide нет (настройки внутри init.lua) — пропуск."
    fi
}

install_neovim_core() {
    info "=== Установка Neovim + Neovide ==="
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка neovim, wl-clipboard и Nerd Font..."
    pac_install neovim wl-clipboard ttf-jetbrains-mono-nerd \
        || { err "Не удалось установить базовые пакеты Neovim."; return 1; }

    if ! has neovide; then
        warn "Установка neovide..."
        if pacman -Si neovide &>/dev/null; then
            pac_install neovide || warn "neovide не установлен."
        else
            local helper; helper=$(aur_helper)
            if [[ -n "$helper" ]]; then
                "$helper" -S --needed neovide-git || warn "neovide (AUR) не установлен."
            else
                warn "neovide не установлен: нет пакета в репозиториях и нет AUR-хелпера."
            fi
        fi
    fi

    apply_nvim_config || warn "Конфиг Neovim не применён."
    apply_neovide_config
    ok "Neovim / Neovide готовы."
}

install_neovim() { clear; install_neovim_core; pause; }

# ------------------------------------------------------------------------------
# 8. ПРИМЕНИТЬ МОИ КОНФИГИ (без установки пакетов)
# ------------------------------------------------------------------------------
apply_all_configs() {
    clear
    info "=== Применение личных конфигов ==="
    echo
    resolve_configs || { pause; return; }

    apply_fish_config
    install_fish_plugins
    apply_nvim_config
    apply_neovide_config
    apply_archy_themes
    echo
    ok "Готово. Перезапустите терминал/приложения, чтобы увидеть изменения."
    pause
}

# ------------------------------------------------------------------------------
# 9. ОСНОВНОЙ НАБОР ПО
# ------------------------------------------------------------------------------
install_essentials() {
    clear
    info "=== Установка основного набора ПО ==="
    echo

    local helper; helper=$(aur_helper)
    if [[ -z "$helper" ]]; then
        err "AUR-хелпер (yay/paru) не найден. Установите его в соответствующем пункте меню."
        pause; return
    fi
    ensure_sudo || { pause; return; }
    pacman_busy && { pause; return; }

    # Steam требует репозиторий multilib
    local -a pkgs=("${ESSENTIALS[@]}")
    if printf '%s\n' "${pkgs[@]}" | grep -qx steam && ! grep -qE '^\[multilib\]' /etc/pacman.conf; then
        warn "Репозиторий [multilib] не включён в /etc/pacman.conf — steam будет пропущен."
        local -a filtered=(); local p
        for p in "${pkgs[@]}"; do [[ "$p" != steam ]] && filtered+=("$p"); done
        pkgs=("${filtered[@]}")
    fi

    echo -e "${YELLOW}Выберите браузер:${NC}"
    echo "1) Firefox"
    echo "2) LibreWolf (AUR)"
    echo "3) Chromium"
    echo "4) Не устанавливать"
    local br browser
    read -rp "Ваш выбор [1-4]: " br
    case "$br" in
        2) browser="librewolf-bin" ;;
        3) browser="chromium" ;;
        4) browser="" ;;
        *) browser="firefox" ;;
    esac
    [[ -n "$browser" ]] && pkgs+=("$browser")

    echo
    info "К установке: ${pkgs[*]}"
    confirm "Продолжить?" || { warn "Отменено."; pause; return; }

    if "$helper" -S --needed "${pkgs[@]}"; then
        ok "Установка ПО завершена!"
    else
        err "Установка завершилась с ошибкой (см. вывод выше)."
    fi
    pause
}

# ------------------------------------------------------------------------------
# 10. ОПТИМИЗАЦИЯ И ОЧИСТКА
# ------------------------------------------------------------------------------
optimize_system() {
    clear
    info "=== Оптимизация и очистка ==="
    echo
    ensure_sudo || { pause; return; }
    pacman_busy && { pause; return; }

    local before after
    before=$(du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')

    warn "[1/5] Сиротские пакеты..."
    local -a orphans
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null)
    if (( ${#orphans[@]} > 0 )); then
        echo "Будут удалены: ${orphans[*]}"
        if confirm "Удалить ${#orphans[@]} пакет(ов) вместе с зависимостями?"; then
            sudo pacman -Rns "${orphans[@]}"
        else
            warn "Пропущено."
        fi
    else
        echo "Сиротских пакетов нет."
    fi

    warn "[2/5] Кэш pacman (оставляем $PACCACHE_KEEP версии)..."
    has paccache || sudo pacman -S --needed --noconfirm pacman-contrib
    sudo paccache -rk"$PACCACHE_KEEP"
    sudo paccache -ruk0   # кэш удалённых пакетов
    sudo systemctl enable --now paccache.timer &>/dev/null && echo "paccache.timer включён."

    warn "[3/5] Журнал systemd (лимит $JOURNAL_MAX)..."
    sudo journalctl --vacuum-size="$JOURNAL_MAX"

    warn "[4/5] Кэш AUR-хелпера..."
    local helper; helper=$(aur_helper)
    if [[ -n "$helper" ]]; then
        "$helper" -Sc --noconfirm
    else
        echo "AUR-хелпер не найден — пропуск."
    fi

    warn "[5/5] Flatpak и старые крэш-дампы..."
    has flatpak && flatpak uninstall --unused -y 2>/dev/null
    sudo find /var/lib/systemd/coredump -type f -mtime +30 -delete 2>/dev/null

    after=$(du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')
    echo
    if [[ -n "$before" && -n "$after" ]]; then
        ok "Очистка завершена. Освобождено из кэша pacman: ~$(( (before - after) / 1024 / 1024 )) МБ."
    else
        ok "Очистка завершена."
    fi
    pause
}

# ------------------------------------------------------------------------------
# 11. БЭКАП DOTFILES
# ------------------------------------------------------------------------------
backup_dotfiles() {
    clear
    info "=== Бэкап конфигураций (~/.config) ==="
    echo

    has zstd || { err "zstd не установлен: sudo pacman -S zstd"; pause; return; }

    local -a existing=(); local cfg
    for cfg in "${DOTFILES[@]}"; do
        if [[ -e "$HOME/.config/$cfg" ]]; then existing+=("$cfg"); else warn "Пропуск (нет): $cfg"; fi
    done
    if (( ${#existing[@]} == 0 )); then
        err "Нет ни одного каталога для бэкапа."; pause; return
    fi

    mkdir -p "$BACKUP_DIR"
    local backup
    backup="$BACKUP_DIR/dotfiles_backup_$(date +%Y-%m-%d_%H%M%S).tar.zst"

    if tar --zstd -cf "$backup" -C "$HOME/.config" "${existing[@]}" 2>>"$LOG_FILE"; then
        if tar --zstd -tf "$backup" &>/dev/null; then
            ok "Бэкап создан и проверен: ${BOLD}$backup${NC}${GREEN} ($(du -h "$backup" | awk '{print $1}'))"
        else
            err "Архив создан, но проверка целостности не пройдена!"
        fi
    else
        err "Ошибка создания архива (подробности: $LOG_FILE)."
        rm -f "$backup"; pause; return
    fi

    local -a old
    mapfile -t old < <(ls -1t "$BACKUP_DIR"/dotfiles_backup_*.tar.zst 2>/dev/null | tail -n +$((BACKUP_KEEP + 1)))
    if (( ${#old[@]} > 0 )); then
        rm -f -- "${old[@]}"
        echo "Удалено старых бэкапов: ${#old[@]} (хранится последних: $BACKUP_KEEP)."
    fi
    pause
}

# ------------------------------------------------------------------------------
# 12. РЕМОНТ КЛЮЧЕЙ PACMAN
# ------------------------------------------------------------------------------
fix_pacman_keys() {
    clear
    info "=== Ремонт ключей pacman ==="
    echo
    ensure_sudo || { pause; return; }
    pacman_busy && { pause; return; }

    echo "1) Мягкий ремонт: обновить keyring и заново populate (рекомендуется)"
    echo "2) Полный сброс: переместить /etc/pacman.d/gnupg в .bak и инициализировать заново"
    echo "0) Назад"
    local c
    read -rp "Выберите [0-2]: " c
    case "$c" in
        1)
            sudo pacman-key --init
            sudo pacman-key --populate archlinux
            sudo pacman -Sy --needed archlinux-keyring
            ;;
        2)
            warn "База ключей будет пересоздана (копия: /etc/pacman.d/gnupg.bak)."
            confirm "Продолжить?" || { warn "Отменено."; pause; return; }
            sudo rm -rf /etc/pacman.d/gnupg.bak
            sudo mv /etc/pacman.d/gnupg /etc/pacman.d/gnupg.bak
            sudo pacman-key --init
            sudo pacman-key --populate archlinux
            sudo pacman -Sy --needed archlinux-keyring
            ;;
        0) return ;;
        *) err "Неверный выбор"; pause; return ;;
    esac
    warn "Сразу выполните полное обновление системы (пункт 2), чтобы избежать частичного апгрейда."
    ok "Операция с ключами завершена."
    pause
}

# ------------------------------------------------------------------------------
# 13. ЗЕРКАЛА (REFLECTOR)
# ------------------------------------------------------------------------------
update_mirrors() {
    clear
    info "=== Обновление списка зеркал ==="
    echo
    ensure_sudo || { pause; return; }
    if ! has reflector; then
        warn "Установка reflector..."
        sudo pacman -S --needed --noconfirm reflector || { pause; return; }
    fi

    local country
    read -rp "Коды стран через запятую (напр. DE,PL; пусто = лучшие по скорости): " country
    local -a args=(--protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist)
    [[ -n "$country" ]] && args+=(--country "$country")

    local bak
    bak="/etc/pacman.d/mirrorlist.bak.$(date +%s)"
    sudo cp /etc/pacman.d/mirrorlist "$bak"
    if sudo reflector "${args[@]}"; then
        ok "Зеркала обновлены (резервная копия: $bak)."
    else
        err "reflector завершился с ошибкой — восстанавливаю старый список."
        sudo cp "$bak" /etc/pacman.d/mirrorlist
    fi
    pause
}

# ------------------------------------------------------------------------------
# 14. HYPRLAND / WAYLAND / AUDIO / SERPANTINUM
# ------------------------------------------------------------------------------
hypr_tools() {
    clear
    info "=== Утилиты Hyprland / Wayland / Audio ==="
    echo
    echo "1) Перезапустить Waybar"
    echo "2) Перезапустить Pipewire / WirePlumber (проблемы со звуком)"
    echo "3) Перезагрузить конфиг Hyprland"
    echo "4) Показать последние ошибки из лога Hyprland"
    echo "5) Перезапустить Serpantinum / Quickshell"
    echo "0) Назад"
    local c
    read -rp "Выберите [0-5]: " c
    case "$c" in
        1)
            if has waybar; then
                pkill -x waybar 2>/dev/null; sleep 0.3
                nohup waybar &>/dev/null & disown
                ok "Waybar перезапущен."
            else
                err "waybar не установлен."
            fi ;;
        2)
            if systemctl --user restart pipewire pipewire-pulse wireplumber; then
                ok "Звуковой стек перезапущен."
            else
                err "Не удалось перезапустить сервисы."
            fi ;;
        3)
            if has hyprctl && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
                hyprctl reload && ok "Конфиг Hyprland перезагружен."
            else
                err "Hyprland не запущен в этой сессии."
            fi ;;
        4)
            local d last
            d="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr"
            last=$(ls -1t "$d"/*/hyprland.log 2>/dev/null | head -1)
            if [[ -n "$last" ]]; then
                grep -iE 'err|warn|crit' "$last" | tail -n 30
            else
                err "Лог не найден в $d."
            fi ;;
        5)
            if has quickshell; then
                pkill -f quickshell 2>/dev/null
                has serpantinumd && (nohup serpantinumd start &>/dev/null & disown)
                ok "Serpantinum/Quickshell перезапущен."
            else
                err "quickshell не установлен."
            fi ;;
        0) return ;;
        *) err "Неверный выбор" ;;
    esac
    pause
}

# ------------------------------------------------------------------------------
# ПОДМЕНЮ «ИНСТРУМЕНТЫ СИСТЕМЫ»
# ------------------------------------------------------------------------------
system_menu() {
    local choice
    while true; do
        clear
        echo -e "${BOLD}${CYAN}====================================================${NC}"
        echo -e "${BOLD}${CYAN}              ИНСТРУМЕНТЫ СИСТЕМЫ                    ${NC}"
        echo -e "${BOLD}${CYAN}====================================================${NC}\n"
        echo -e "  ${GREEN}1)${NC} ${BOLD}Аудит и оценка системы${NC}"
        echo -e "  ${GREEN}2)${NC} Полное обновление системы (pacman + AUR)"
        echo -e "  ${GREEN}3)${NC} Оптимизация и очистка"
        echo -e "  ${GREEN}4)${NC} Бэкап конфигураций (.tar.zst)"
        echo -e "  ${GREEN}5)${NC} Ремонт ключей pacman"
        echo -e "  ${GREEN}6)${NC} Обновить зеркала (reflector)"
        echo -e "  ${GREEN}7)${NC} Утилиты Hyprland / Wayland / Audio"
        echo -e "  ${RED}0)${NC} Назад"
        echo
        read -rp "Номер пункта [0-7]: " choice
        case "$choice" in
            1) run_audit ;;
            2) update_system ;;
            3) optimize_system ;;
            4) backup_dotfiles ;;
            5) fix_pacman_keys ;;
            6) update_mirrors ;;
            7) hypr_tools ;;
            0) return ;;
            *) err "Неверный пункт меню"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# ПОЛНАЯ УСТАНОВКА
# ------------------------------------------------------------------------------
full_setup() {
    clear
    info "===================================================="
    info "        ПОЛНАЯ УСТАНОВКА И НАСТРОЙКА СИСТЕМЫ         "
    info "===================================================="
    echo
    echo "Будет выполнено:"
    echo "  1. Обновление системы"
    echo "  2. Установка AUR-хелпера (yay/paru)"
    echo "  3. Установка dotfiles (Serpantinum)"
    echo "  4. Установка Fish + плагины + конфиг"
    echo "  5. Установка Neovim + Neovide + конфиг"
    echo "  6. Применение тем Serpantinum (archy)"
    echo
    confirm "Начать полную установку?" || { warn "Отменено."; pause; return; }

    ensure_sudo || { pause; return; }

    update_system_core
    install_aur_helper_core "$(choose_helper)" || warn "AUR-хелпер не установлен — часть шагов может не сработать."
    install_dotfiles_core || warn "Dotfiles не установлены."
    install_fish_core
    install_neovim_core
    apply_archy_themes

    echo
    ok "Полная установка завершена! Рекомендуется перезагрузка."
    serpantinum_notice
    pause
}

# ------------------------------------------------------------------------------
# ГЛАВНОЕ МЕНЮ
# ------------------------------------------------------------------------------
usage() {
    cat << USAGE
Использование: ${0##*/} [-a] [-f] [-h]
  -a   выполнить системный аудит без меню и выйти
  -f   выполнить полную установку и настройку без меню
  -h   показать справку
Конфигурация (необязательно): $CONFIG_FILE
Лог операций: $LOG_FILE
Репозиторий конфигов: https://github.com/$REPO_SLUG
USAGE
}

main_menu() {
    local choice
    while true; do
        clear
        echo -e "${BOLD}${CYAN}====================================================${NC}"
        echo -e "${BOLD}${CYAN}            ARCH MULTITOOL v3                        ${NC}"
        echo -e "${BOLD}${CYAN}====================================================${NC}\n"
        echo -e "  ${GREEN}1)${NC} ${BOLD}Полная установка и настройка (всё)${NC}"
        echo -e "  ${GREEN}2)${NC} Инструменты системы (аудит, очистка, бэкап...)"
        echo -e "  ${CYAN}--------------------------------------------------${NC}"
        echo -e "  ${GREEN}3)${NC} Установить AUR-хелпер (yay / paru)"
        echo -e "  ${GREEN}4)${NC} Установить dotfiles (Serpantinum) + темы"
        echo -e "  ${GREEN}5)${NC} Установить Fish + плагины + конфиг"
        echo -e "  ${GREEN}6)${NC} Установить Neovim + Neovide + конфиг"
        echo -e "  ${GREEN}7)${NC} Применить мои конфиги (fish / nvim / темы)"
        echo -e "  ${GREEN}8)${NC} Установить основной набор ПО"
        echo -e "  ${RED}0)${NC} Выход"
        echo
        read -rp "Номер пункта [0-8]: " choice

        case "$choice" in
            1) full_setup ;;
            2) system_menu ;;
            3) install_aur_helper_menu ;;
            4) install_dotfiles ;;
            5) install_fish ;;
            6) install_neovim ;;
            7) apply_all_configs ;;
            8) install_essentials ;;
            0) clear; echo "До связи!"; exit 0 ;;
            *) err "Неверный пункт меню"; sleep 1 ;;
        esac
    done
}

# ---------------------------------- Старт ------------------------------------
AUDIT_ONLY=0
FULL_ONLY=0
while getopts ":afh" opt; do
    case "$opt" in
        a) AUDIT_ONLY=1 ;;
        f) FULL_ONLY=1 ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

require_arch
if (( AUDIT_ONLY )); then
    run_audit
elif (( FULL_ONLY )); then
    full_setup
else
    main_menu
fi
