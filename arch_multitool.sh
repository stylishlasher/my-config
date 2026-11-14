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

# Пресеты Serpantinum (archy) определяются автоматически: функция
# apply_archy_themes сама находит все *.json с полем "palette" в каталоге
# репозитория и копирует их в presets — новые темы подхватываются сами.
# Каталог состояния Serpantinum и подкаталог для пресетов (archy)
SERPANTINUM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum"
THEME_DIR="$SERPANTINUM_STATE_DIR/presets"
# Плагины fish (для fisher)
FISH_PLUGINS=(jorgebucaran/fisher ilancosman/tide@v6)
# Flatpak: репозиторий Flathub и Sober (Roblox на Linux)
FLATPAK_REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
SOBER_APP="org.vinegarhq.Sober"
# FreeSM Launcher (Minecraft, офлайн-аккаунты) из AUR
FREESM_PKG="freesmlauncher-bin"

# Настройки приветствия терминала (fastfetch / keyfetch). Файл в fish-синтаксисе,
# его читают функции fish_greeting и clear; пишет его configure_greeting.
GREETING_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/arch_multitool"
GREETING_FILE="$GREETING_DIR/greeting.fish"

# --- Прочее ---
DOTFILES=(hypr kitty fish nvim neovide serpantinum gpu-screen-recorder nwg-look)

# --- ПО, выбираемое галочками (см. select_packages) ---
# Формат строки: "пакет|описание|on|off"  ("on" — отмечено по умолчанию).
#
# Базовый набор: системные утилиты, которые обычно нужны всем.
ESSENTIALS_MENU=(
    "gpu-screen-recorder|Запись экрана GPU (движок)|on"
    "gpu-screen-recorder-ui|Запись экрана GPU (оверлей UI)|on"
    "btop|Системный монитор btop|on"
    "mpv|Медиаплеер mpv|on"
)

# Приложения: всё необязательное — браузеры, мессенджеры, игры и т.д.
APPS_MENU=(
    "firefox|Браузер Firefox|on"
    "chromium|Браузер Chromium|off"
    "librewolf|Браузер LibreWolf (приватный)|off"
    "brave-bin|Браузер Brave (AUR)|off"
    "telegram-desktop|Мессенджер Telegram|on"
    "vesktop-bin|Discord + Vencord (AUR)|on"
    "discord|Клиент Discord (официальный)|off"
    "element-desktop|Matrix-клиент Element|off"
    "signal-desktop|Мессенджер Signal|off"
    "thunderbird|Почта Thunderbird|off"
    "spotify|Музыка Spotify (AUR)|on"
    "vlc|Медиаплеер VLC|off"
    "obs-studio|Запись/стриминг OBS Studio|off"
    "gimp|Редактор изображений GIMP|off"
    "qbittorrent|Торрент-клиент qBittorrent|off"
    "steam|Игры Steam (нужен [multilib])|off"
    "lutris|Запуск игр Lutris|off"
    "heroic-games-launcher-bin|Epic/GOG Heroic Launcher (AUR)|off"
    "prismlauncher|Minecraft Prism Launcher|off"
    "bottles|Запуск Windows-программ Bottles (AUR)|off"
    "libreoffice-fresh|Офисный пакет LibreOffice|off"
    "keepassxc|Менеджер паролей KeePassXC|off"
)

# --- Консольные «приколы» (вкладка «Консольные приколы», пункт 8/15). AUR-пакеты помечены. ---
# Все пункты по умолчанию ВЫКЛЮЧЕНЫ — ставятся только по явному выбору.

# Приколы и визуализации
FUN_TOOLS_MENU=(
    "cava|Аудиовизуализатор в терминале|off"
    "lavat|Анимация лавы в терминале (AUR)|off"
    "cbonsai|Растущий бонсай в терминале (AUR)|off"
    "tty-clock|Часы в терминале (AUR)|off"
    "cmatrix|«Матрица» из символов|off"
    "unimatrix-git|Улучшенная «Матрица» (AUR)|off"
    "pipes.sh|Анимация труб (AUR)|off"
    "lolcat|Радужный вывод текста|off"
    "figlet|Большой ASCII-текст|off"
    "toilet|Цветной ASCII-текст|off"
    "cowsay|Говорящая корова|off"
    "ponysay|Говорящий пони|off"
    "fortune-mod|Случайные цитаты (для cowsay)|off"
    "asciinema|Запись терминальной сессии|off"
    "chafa|Просмотр изображений в терминале|off"
    "catimg|Картинки в терминале|off"
    "viu|Просмотр картинок в терминале|off"
    "timg|Картинки/видео в терминале (AUR)|off"
    "jp2a|JPEG/PNG в ASCII|off"
    "glow|Чтение Markdown в терминале|off"
    "boxes|Рамки вокруг текста (AUR)|off"
    "bb|ASCII-анимация (AUR)|off"
    "rain|Дождь из символов (AUR)|off"
    "terminal-parrot|Попугай в терминале (AUR)|off"
    "hollywood|«Хакерский» экран (AUR)|off"
    "genact|Фейковая бурная деятельность|off"
    "asciiquarium|Аквариум в терминале|off"
    "nyancat|Nyan Cat|off"
    "peaclock|Часы-помодоро в терминале (AUR)|off"
    "sl|Паровозик (набери sl вместо ls)|off"
    "aalib|ASCII-арт библиотека (aafire)|off"
    "libcaca|Цветной ASCII-арт (cacafire)|off"
)

# Консольные игры
FUN_GAMES_MENU=(
    "nudoku|Судоку в терминале (AUR)|off"
    "tty-solitaire|Косынка в терминале|off"
    "bastet|Тетрис «Bastard» (AUR)|off"
    "vitetris|Тетрис в терминале (AUR)|off"
    "ninvaders|Space Invaders в терминале (AUR)|off"
    "moon-buggy|Луноход (AUR)|off"
    "greed|Игра «Жадность» (AUR)|off"
    "myman|Пакман в терминале (AUR)|off"
    "pacman4console|Ещё один пакман (AUR)|off"
    "gnugo|Го (GNU Go)|off"
    "gnuchess|Шахматы (GNU Chess)|off"
    "nethack|Roguelike NetHack|off"
    "crawl|Roguelike Dungeon Crawl Stone Soup (AUR)|off"
    "angband|Roguelike Angband|off"
    "cataclysm-dda|Roguelike Cataclysm: DDA|off"
)

# Мониторы и системные утилиты
FUN_MONITOR_MENU=(
    "bottom|Системный монитор btm|off"
    "glances|Монитор системы Glances|off"
    "htop|Классический htop|off"
    "nvtop|Монитор GPU (NVIDIA/AMD/Intel)|off"
    "ncdu|Анализ занятого места (NCurses)|off"
    "dust|Быстрый аналог du (Rust)|off"
    "duf|Просмотр дисков (df) таблицей|off"
    "procs|Современный ps|off"
    "pv|Прогресс-бар для пайпов|off"
    "gtop|Графический монитор в терминале|off"
    "bandwhich|Сетевой трафик по процессам|off"
    "nmon|Монитор ресурсов nmon|off"
    "iftop|Сетевой трафик по соединениям|off"
    "nethogs|Сетевой трафик по процессам|off"
    "ttyplot|График значений из stdin (AUR)|off"
)

# Музыка, медиа, браузеры в терминале
FUN_MEDIA_MENU=(
    "cmus|Музыкальный плеер в терминале|off"
    "ncmpcpp|Клиент MPD в терминале|off"
    "mpd|Сервер музыки MPD|off"
    "yt-dlp|Скачивание видео/музыки (YouTube и др.)|off"
    "aria2|Многопоточный загрузчик|off"
    "w3m|Текстовый браузер w3m|off"
    "lynx|Текстовый браузер Lynx|off"
    "elinks|Текстовый браузер ELinks|off"
    "browsh|Полноценный браузер в терминале (AUR)|off"
    "neomutt|Почтовый клиент в терминале|off"
    "termusic|Музыкальный плеер (Rust)|off"
)

# Полезные CLI-утилиты
CLI_TOOLS_MENU=(
    "bat|cat с подсветкой синтаксиса|off"
    "eza|Современный ls|off"
    "fd|Современный find|off"
    "ripgrep|Современный grep|off"
    "fzf|Нечёткий поиск по спискам|off"
    "zoxide|Умный cd (команда z)|off"
    "jq|Обработка JSON|off"
    "yq|Обработка YAML|off"
    "tree|Дерево каталогов|off"
    "tmux|Мультиплексор терминала|off"
    "zellij|Современный мультиплексор (Rust)|off"
    "mc|Файловый менеджер Midnight Commander|off"
    "ranger|Файловый менеджер Ranger|off"
    "yazi|Файловый менеджер Yazi (Rust)|off"
    "lf|Файловый менеджер lf|off"
    "nnn|Файловый менеджер nnn|off"
    "tig|Просмотр git в терминале|off"
    "lazygit|TUI для git|off"
    "gitui|TUI для git (Rust)|off"
    "calcurse|Календарь и задачи|off"
    "task|Менеджер задач Taskwarrior|off"
    "lsd|ls с иконками|off"
)

# Кастомные фетчи (пункт 15, категория «Кастомные фетчи»).
# "areofyl-fetch" — маркер: ставится из AUR (fetch-git), иначе сборкой из исходников
# (см. install_areofyl_fetch).
CUSTOM_SRC_FETCH="areofyl-fetch"
CUSTOM_FETCH_MENU=(
    "fastfetch|Быстрый и гибкий fastfetch|off"
    "uwufetch|UwU-фетч (uwufetch)|off"
    "hyfetch|Hyfetch (neofetch с pride-флагами)|off"
    "macchina|Macchina — настраиваемый фетч|off"
    "cpufetch|Фетч про CPU|off"
    "onefetch|Фетч для git-репозиториев|off"
    "neofetch|Классический neofetch (AUR)|off"
    "pfetch|Минималистичный pfetch (AUR)|off"
    "afetch|Простой afetch (AUR)|off"
    "nerdfetch|Фетч с иконками Nerd Font (AUR)|off"
    "nitch|Крошечный nitch (AUR)|off"
    "bunnyfetch|Bunnyfetch (AUR)|off"
    "ramfetch|Фетч про оперативку (AUR)|off"
    "yafetch|Yafetch (AUR)|off"
    "archfetch|Archfetch (AUR)|off"
    "wfetch|Wfetch (AUR)|off"
    "newfetch|Newfetch (AUR)|off"
    "rainbowfetch|Rainbowfetch (AUR)|off"
    "paleofetch-git|Paleofetch на C (AUR)|off"
    "gfetch-git|Gfetch (AUR)|off"
    "fet.sh-git|Фетч на чистом shell (AUR)|off"
    "gpufetch|Фетч про GPU (AUR)|off"
    "${CUSTOM_SRC_FETCH}|areofyl/fetch — 3D-логотип (AUR: fetch-git)|off"
)

# Утилиты для работы с архивами (Xarchiver — GUI, остальное — консоль)
ARCHIVE_TOOLS=(xarchiver tar zip unzip unrar 7zip zstd xz bzip2)
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

# Интерактивный ли запуск (есть реальный терминал на stdin/stdout)
is_interactive() { [[ -t 0 && -t 1 ]]; }

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

# Установка пакета(ов): через AUR-хелпер, если он есть, иначе через pacman.
# AUR-хелпер сам умеет ставить и официальные, и AUR-пакеты.
pkg_install() {
    ensure_sudo || return 1
    local helper; helper=$(aur_helper)
    if [[ -n "$helper" ]]; then
        "$helper" -S --needed --noconfirm "$@"
        return
    fi

    # AUR-хелпера нет: pacman умеет ставить только официальные пакеты.
    # Если синхробазы нет — просто пробуем как есть.
    if [[ ! -e /var/lib/pacman/sync/core.db ]]; then
        pac_install "$@"
        return
    fi

    local -a repo=() aur=() p
    for p in "$@"; do
        if pacman -Si "$p" &>/dev/null; then repo+=("$p"); else aur+=("$p"); fi
    done
    (( ${#aur[@]} )) && warn "Нет AUR-хелпера (yay/paru) — пропускаю: ${aur[*]}"
    (( ${#repo[@]} == 0 )) && { err "Нечего устанавливать из официальных репозиториев."; return 1; }
    pac_install "${repo[@]}"
}

# Выбор пакетов галочками.
# Аргументы: строки вида "пакет|описание|on|off".
# whiptail --checklist, а без whiptail — текстовый переключатель.
# Результат кладётся в глобальный массив SELECTED_PACKAGES.
SELECTED_PACKAGES=()
select_packages() {
    local title="$1"; shift
    local -a items=("$@")
    SELECTED_PACKAGES=()

    if has whiptail && is_interactive; then
        local -a args=() it pkg desc state
        for it in "${items[@]}"; do
            IFS='|' read -r pkg desc state <<< "$it"
            args+=("$pkg" "$desc" "$state")
        done
        local out
        out=$(whiptail --title "$title" \
            --checklist "Пробел — отметить/снять, Enter — подтвердить:" \
            22 80 14 "${args[@]}" 3>&1 1>&2 2>&3) || return 1
        # whiptail возвращает список в кавычках: "pkg1" "pkg2"
        eval "SELECTED_PACKAGES=($out)"
        return 0
    fi

    # Текстовый режим (без whiptail): номера через пробел переключают галочку
    local -a states=()
    local i
    for i in "${items[@]}"; do
        states+=("$(cut -d'|' -f3 <<< "$i")")
    done
    while true; do
        clear
        echo -e "${BOLD}${CYAN}${title}${NC}"
        echo "Введите номера через пробел, чтобы отметить/снять. Enter — готово."
        echo
        local n=0 pkg desc st mark
        for i in "${items[@]}"; do
            IFS='|' read -r pkg desc _ <<< "$i"
            st="${states[$n]}"
            mark="[ ]"; [[ "$st" == on ]] && mark="[x]"
            printf '  %s %2d) %-26s %s\n' "$mark" "$((n + 1))" "$pkg" "$desc"
            n=$((n + 1))
        done
        echo
        local ans
        read -rp "Номера (Enter — подтвердить, 'q' — отмена): " ans
        [[ "$ans" == q || "$ans" == Q ]] && return 1
        [[ -z "${ans//[[:space:]]/}" ]] && break
        local tok
        for tok in $ans; do
            [[ "$tok" =~ ^[0-9]+$ ]] || continue
            local idx=$((tok - 1))
            (( idx >= 0 && idx < ${#items[@]} )) || continue
            if [[ "${states[$idx]}" == on ]]; then states[$idx]=off; else states[$idx]=on; fi
        done
    done
    local n=0
    for i in "${items[@]}"; do
        IFS='|' read -r pkg _ <<< "$i"
        [[ "${states[$n]}" == on ]] && SELECTED_PACKAGES+=("$pkg")
        n=$((n + 1))
    done
    return 0
}

# Меню-«вкладки»: выбор одного пункта.
# Аргументы: заголовок, затем строки "id|описание".
# Результат — в MENU_CHOICE; 0 при выборе, 1 при отмене.
MENU_CHOICE=""
menu_select() {
    local title="$1"; shift
    local -a items=("$@")
    MENU_CHOICE=""

    if has whiptail && is_interactive; then
        local -a args=() it id desc
        for it in "${items[@]}"; do
            IFS='|' read -r id desc <<< "$it"
            args+=("$id" "$desc")
        done
        local out
        out=$(whiptail --title "$title" \
            --menu "Стрелки — выбор, Enter — подтвердить:" \
            22 80 14 "${args[@]}" 3>&1 1>&2 2>&3) || return 1
        MENU_CHOICE="$out"
        return 0
    fi

    # Текстовый режим
    while true; do
        clear
        echo -e "${BOLD}${CYAN}${title}${NC}"
        echo
        local it id desc
        for it in "${items[@]}"; do
            IFS='|' read -r id desc <<< "$it"
            printf '  %2s) %s\n' "$id" "$desc"
        done
        echo
        local ans
        read -rp "Ваш выбор (Enter/'q' — отмена): " ans
        [[ -z "${ans//[[:space:]]/}" || "$ans" == q || "$ans" == Q ]] && return 1
        for it in "${items[@]}"; do
            IFS='|' read -r id desc <<< "$it"
            [[ "$id" == "$ans" ]] && { MENU_CHOICE="$id"; return 0; }
        done
        warn "Нет такого пункта: $ans"
        sleep 1
    done
}

# Включить репозиторий [multilib] в /etc/pacman.conf (нужен для steam)
enable_multilib() {
    local conf=/etc/pacman.conf
    grep -qE '^\[multilib\]' "$conf" 2>/dev/null && return 0

    if ! grep -qE '^#[[:space:]]*\[multilib\]' "$conf" 2>/dev/null; then
        warn "Секция [multilib] не найдена в $conf — включите её вручную."
        return 1
    fi

    ensure_sudo || return 1
    info "Включаю репозиторий [multilib] (нужен для steam)..."
    sudo cp -a "$conf" "${conf}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    sudo sed -i '/^#[[:space:]]*\[multilib\]/{s/^#[[:space:]]*//;n;s/^#[[:space:]]*//}' "$conf"
    if ! grep -qE '^\[multilib\]' "$conf"; then
        err "Не удалось включить [multilib]."
        return 1
    fi
    sudo pacman -Sy --noconfirm || { err "pacman -Sy не удался."; return 1; }
    ok "[multilib] включён. Рекомендуется полное обновление системы (пункт 2)."
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
    local -a themes=("$@")
    (( ${#themes[@]} == 0 )) && themes=(glass archy-style)
    local list; list=$(printf '%s / ' "${themes[@]}"); list=${list% / }
    local b="${BOLD}${YELLOW}" n="${NC}"
    local bar="████████████████████████████████████████████████████████████████████████████████████"
    echo
    echo -e "${b}${bar}${n}"
    echo -e "${b}  ⚠  ВАЖНО: ПРЕСЕТЫ ПРИМЕНЕНЫ, НО ИХ НУЖНО ВКЛЮЧИТЬ ВРУЧНУЮ!${n}"
    echo -e "${b}${bar}${n}"
    echo -e "${b}  Serpantinum  →  Настройки  →  Presets (Пресеты)  →  выбрать тему${n}"
    echo -e "${b}  Доступные темы:  ${list}${n}"
    echo -e "${b}  Если тема забагалась — перевыберите её (не пресет) в:${n}"
    echo -e "${b}    Настройки  →  Тема (Оформление)  →  список тем${n}"
    echo -e "${b}${bar}${n}"
    echo
}

# ОГРОМНАЯ плашка: драйверы GPU НЕ ставятся автоматически
gpu_drivers_notice() {
    local b="${BOLD}${RED}" n="${NC}"
    local bar="████████████████████████████████████████████████████████████████████████████████████"
    echo
    echo -e "${b}${bar}${n}"
    echo -e "${b}  ⚠  ДРАЙВЕРЫ GPU НЕ УСТАНАВЛИВАЮТСЯ АВТОМАТИЧЕСКИ!${n}"
    echo -e "${b}${bar}${n}"
    echo -e "${b}  Установите их под свою видеокарту (до перезагрузки):${n}"
    echo -e "${b}    NVIDIA:  sudo pacman -S nvidia nvidia-utils nvidia-settings${n}"
    echo -e "${b}    AMD:     sudo pacman -S mesa vulkan-radeon libva-mesa-driver${n}"
    echo -e "${b}    Intel:   sudo pacman -S mesa vulkan-intel intel-media-driver${n}"
    echo -e "${b}  Иначе Hyprland / Serpantinum могут не запуститься.${n}"
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

    # Берём готовый бинарный пакет (-bin), как делает и установщик Serpantinum:
    # без долгой компиляции, а бинарь всё равно называется yay/paru.
    local pkg="$helper"
    case "$helper" in
        yay)  pkg="yay-bin"  ;;
        paru) pkg="paru-bin" ;;
    esac

    ensure_work_dir
    local dir="$WORK_DIR/$pkg"
    rm -rf "$dir"
    warn "Клонирование AUR-репозитория ($pkg)..."
    if ! git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$dir"; then
        err "git clone не удался (проверьте сеть)."; return 1
    fi

    echo
    warn "PKGBUILD из AUR — это произвольный код. Рекомендуется просмотреть его перед сборкой."
    if confirm "Показать PKGBUILD?"; then
        ${PAGER:-less} "$dir/PKGBUILD"
    fi
    confirm "Продолжить установку $helper?" || { warn "Отменено."; return 1; }

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
        info "AUR-хелпер (yay/paru) не найден — установщик Serpantinum соберёт yay-bin сам."
        if confirm "Поставить AUR-хелпер заранее (быстрее, чем ждать установщик)?"; then
            install_aur_helper_core "$(choose_helper)" || warn "Не удалось поставить заранее — Serpantinum соберёт yay-bin сам."
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
        # После установки правим раскладку клавиатуры в конфиге Hyprland
        configure_hypr_kb_layout
    else
        err "Установщик dotfiles завершился с ошибкой."
        return 1
    fi
}

install_dotfiles() {
    clear
    gpu_drivers_notice
    install_dotfiles_core
    apply_archy_themes
    pause
}

# ------------------------------------------------------------------------------
# 5. ТЕМЫ SERPANTINUM (archy: авто-поиск всех *.json в репозитории)
# ------------------------------------------------------------------------------
apply_archy_themes() {
    resolve_configs || return 1

    # Автопоиск всех пресетов: все *.json в каталоге репозитория.
    # Так новые темы из репозитория подхватываются автоматически.
    local -a presets=() names=()
    local f
    shopt -s nullglob
    for f in "$CONFIGS_DIR"/*.json; do
        presets+=("$f")
    done
    shopt -u nullglob

    if (( ${#presets[@]} == 0 )); then
        warn "Пресеты Serpantinum (*.json) не найдены в конфигах."
        return 1
    fi

    # Кладём пресеты в ~/.local/state/serpantinum/presets
    mkdir -p "$THEME_DIR"
    for f in "${presets[@]}"; do
        cp -a "$f" "$THEME_DIR/$(basename "$f")"
        names+=("$(basename "$f" .json)")
        # Предупреждаем, если файл не похож на пресет Serpantinum
        if ! grep -q '"settings"\|"palette"' "$f" 2>/dev/null; then
            warn "$(basename "$f"): не похож на пресет Serpantinum (нет полей \"settings\"/\"palette\")."
        fi
    done
    ok "Пресеты Serpantinum применены (${#presets[@]}): ${names[*]}"
    info "Каталог: $THEME_DIR"

    serpantinum_notice "${names[@]}"
}

# ------------------------------------------------------------------------------
# 5.1 РАСКЛАДКА КЛАВИАТУРЫ (us,ru) в конфиге Hyprland
# ------------------------------------------------------------------------------
configure_hypr_kb_layout() {
    local f="$HOME/.config/hypr/config/settings.lua"
    if [[ ! -f "$f" ]]; then
        info "Файл $f не найден — пропускаю настройку раскладки (Hyprland ещё не установлен?)."
        return 0
    fi

    if grep -qE 'kb_layout[[:space:]]*=[[:space:]]*"us,ru"' "$f"; then
        ok "Раскладка клавиатуры уже настроена (us,ru)."
        return 0
    fi

    cp -a "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    sed -i -E 's/kb_layout[[:space:]]*=[[:space:]]*"us"/kb_layout = "us,ru"/' "$f"
    if grep -qE 'kb_layout[[:space:]]*=[[:space:]]*"us,ru"' "$f"; then
        ok "Раскладка клавиатуры: us,ru (переключение — Alt+Shift)."
    else
        warn "Не удалось автоматически изменить kb_layout в $f."
        warn "Поправьте вручную: kb_layout = \"us,ru\","
    fi
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

    # Исходник keyfetch.c (анимированный фетч) — кладём рядом с конфигом,
    # функция keyfetch сама соберёт его при первом запуске.
    local keyfetch_src=""
    for keyfetch_src in "$CONFIGS_DIR/keyfetch.c" "$src/keyfetch.c" "$src/functions/keyfetch.c"; do
        [[ -f "$keyfetch_src" ]] && break
    done
    if [[ -f "$keyfetch_src" ]]; then
        cp -a "$keyfetch_src" "$dst/keyfetch.c"
        ok "keyfetch.c скопирован → $dst/keyfetch.c"
    fi

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

    # ffmpeg нужен для пользовательской функции converttool (конвертер/сжатие)
    if ! has ffmpeg; then
        warn "Установка ffmpeg (нужен для функции converttool)..."
        pac_install ffmpeg || warn "ffmpeg не установлен — функция converttool будет недоступна."
    fi

    apply_fish_config || warn "Конфиг fish не применён."

    # Приветствие терминала: fastfetch или keyfetch (по выбору)
    configure_greeting

    # keyfetch (анимированный фетч) собирается из C — нужен компилятор
    build_keyfetch

    install_fish_plugins
    set_default_shell_fish
    ok "Fish готов."
}

# --- Приветствие терминала (fastfetch / keyfetch) ----------------------------
# Пишем fish-файл с настройками (его читают функции fish_greeting и clear).
# $1 = mode (fastfetch|keyfetch|none), $2 = цвет, $3 = rainbow (0/1), $4 = высота
write_greeting_file() {
    local mode="${1:-fastfetch}" color="${2:-#ffc828}" rainbow="${3:-0}" height="${4:-16}"
    mkdir -p "$GREETING_DIR"
    {
        echo "# Настройки приветствия терминала (создано arch_multitool)."
        echo "# mode: fastfetch | keyfetch | none"
        echo "set -g greeting_mode $mode"
        echo "set -g greeting_color \"$color\""
        echo "set -g greeting_rainbow $rainbow"
        echo "set -g greeting_height $height"
    } > "$GREETING_FILE"
    ok "Приветствие: $mode → $GREETING_FILE"
}

# Интерактивный выбор приветствия (fastfetch / keyfetch + цвет).
configure_greeting() {
    # Не интерактивно — просто гарантируем наличие файла настроек.
    if ! is_interactive; then
        [[ -f "$GREETING_FILE" ]] || write_greeting_file fastfetch "#ffc828" 0 16
        return 0
    fi

    menu_select "Приветствие терминала" \
        "1|fastfetch — статичная информация о системе" \
        "2|keyfetch — вращающийся 3D-ключ (закрепляется сверху, живёт всё время)" \
        "3|Ничего (пустое приветствие)" \
        "0|Оставить как есть" || return 0

    case "$MENU_CHOICE" in
        1) write_greeting_file fastfetch "#ffc828" 0 16 ;;
        3) write_greeting_file none "#ffc828" 0 16 ;;
        2)
            local color="#ffc828" rainbow=0
            # name|hex — цвета keyfetch (можно и словом, но храним hex)
            local -a cols=(
                "gold|#ffc828" "orange|#ff8c1e" "yellow|#ffdc3c" "lime|#a0ff3c"
                "green|#46dc5a" "teal|#1ebea9" "cyan|#3cdce6" "blue|#4678ff"
                "purple|#a05aff" "magenta|#e646dc" "pink|#ff82be" "red|#ff3c3c"
                "silver|#bec3cd" "white|#ebebeb"
            )
            local -a items=() c i=1
            for c in "${cols[@]}"; do
                items+=("$i|${c%%|*} (${c##*|})")
                i=$((i + 1))
            done
            items+=("$i|Радужный — цвет переливается")
            local rainbow_idx=$i
            i=$((i + 1))
            items+=("$i|Свой HEX-цвет (например #ff8800)")

            menu_select "Цвет ключа keyfetch" "${items[@]}" || return 0

            if [[ "$MENU_CHOICE" == "$rainbow_idx" ]]; then
                rainbow=1
            elif [[ "$MENU_CHOICE" == "$i" ]]; then
                local hex
                read -rp "Введите HEX-цвет (например #ff8800): " hex
                if [[ "$hex" =~ ^#?[0-9a-fA-F]{6}$ ]]; then
                    color="#${hex#\#}"
                else
                    warn "Некорректный HEX — оставляю золотой (#ffc828)."
                    color="#ffc828"
                fi
            elif [[ "$MENU_CHOICE" =~ ^[0-9]+$ ]] && (( MENU_CHOICE >= 1 && MENU_CHOICE <= ${#cols[@]} )); then
                color="${cols[$((MENU_CHOICE - 1))]##*|}"
            fi

            write_greeting_file keyfetch "$color" "$rainbow" 16
            info "Подсказка: keyfetch запускается сам; остановить — 'keyfetch --stop'."
            ;;
        0|"") return 0 ;;
    esac
    return 0
}

# Сборка keyfetch из ~/.config/fish/keyfetch.c в ~/.local/bin/keyfetch.
# Если компилятора нет — ставим gcc; если исходника нет — тихо пропускаем.
build_keyfetch() {
    local src="$HOME/.config/fish/keyfetch.c"
    local bin="$HOME/.local/bin/keyfetch"
    [[ -f "$src" ]] || return 0

    if ! has cc; then
        warn "Установка gcc (нужен для сборки keyfetch)..."
        pac_install gcc || { warn "gcc не установлен — keyfetch соберётся при первом запуске (если появится cc)."; return 0; }
    fi

    mkdir -p "$(dirname "$bin")"
    if cc -O2 -o "$bin" "$src" -lm; then
        ok "keyfetch собран → $bin"
    else
        warn "Не удалось собрать keyfetch (соберётся при первом запуске терминала)."
    fi
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
# 7.1 MPV (медиаплеер)
# ------------------------------------------------------------------------------
install_mpv_core() {
    info "=== Установка mpv ==="
    if has mpv; then ok "mpv уже установлен."; return 0; fi
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка mpv..."
    pac_install mpv || { err "Не удалось установить mpv."; return 1; }
    ok "mpv установлен."
}

install_mpv() { clear; install_mpv_core; pause; }

# ------------------------------------------------------------------------------
# 8. ПРИМЕНИТЬ МОИ КОНФИГИ (без установки пакетов)
# ------------------------------------------------------------------------------
apply_all_configs() {
    clear
    info "=== Применение личных конфигов ==="
    echo
    resolve_configs || { pause; return; }

    apply_fish_config
    configure_greeting
    install_fish_plugins
    apply_nvim_config
    apply_neovide_config
    configure_hypr_kb_layout
    apply_archy_themes
    echo
    ok "Готово. Перезапустите терминал/приложения, чтобы увидеть изменения."
    pause
}

# ------------------------------------------------------------------------------
# 9. УСТАНОВКА ПО (вкладки + галочки)
# ------------------------------------------------------------------------------
# Установить пакеты (авто-включение [multilib] при выборе steam).
software_install_pkgs() {
    local -a pkgs=("$@")
    (( ${#pkgs[@]} == 0 )) && { warn "Ничего не выбрано."; return 1; }

    if printf '%s\n' "${pkgs[@]}" | grep -qx steam; then
        enable_multilib || warn "Без [multilib] steam не установится."
    fi

    echo
    info "К установке: ${pkgs[*]}"
    pkg_install "${pkgs[@]}" \
        || { err "Установка завершилась с ошибкой (см. вывод выше)."; return 1; }
    ok "Установка ПО завершена!"
}

# Выбор пакетов чек-листами. Результат — в массиве ESSENTIALS_PKGS.
# $1 = "all" (по умолчанию: базовый набор + приложения) | "apps" (только приложения).
ESSENTIALS_PKGS=()
choose_essentials_packages() {
    local mode="${1:-all}"
    ESSENTIALS_PKGS=()

    if [[ "$mode" == all ]]; then
        if select_packages "Базовый набор (рекомендуется)" "${ESSENTIALS_MENU[@]}"; then
            ESSENTIALS_PKGS+=("${SELECTED_PACKAGES[@]}")
        else
            warn "Базовый набор пропущен."
        fi
    fi

    if select_packages "Приложения (необязательно)" "${APPS_MENU[@]}"; then
        ESSENTIALS_PKGS+=("${SELECTED_PACKAGES[@]}")
    else
        warn "Приложения пропущены."
    fi

    (( ${#ESSENTIALS_PKGS[@]} > 0 ))
}

# Установка выбранного ПО (без Flatpak/Sober/FreeSM — они отдельно).
install_essentials_core() {
    choose_essentials_packages "${1:-all}" || { warn "Ничего не выбрано."; return 1; }
    software_install_pkgs "${ESSENTIALS_PKGS[@]}"
}

# ------------------------------ Вкладки ПО ------------------------------------

# Вкладка «Базовый набор»
software_tab_base() {
    select_packages "Базовый набор (рекомендуется)" "${ESSENTIALS_MENU[@]}" \
        || { warn "Отменено."; return 0; }
    software_install_pkgs "${SELECTED_PACKAGES[@]}"
}

# Вкладка «Приложения»
software_tab_apps() {
    select_packages "Приложения (необязательно)" "${APPS_MENU[@]}" \
        || { warn "Отменено."; return 0; }
    software_install_pkgs "${SELECTED_PACKAGES[@]}"
}

# Вкладка «Всё по галочкам» (базовый набор + приложения)
software_tab_all() {
    install_essentials_core all
}

# Вкладка «Flatpak + Flathub (+ Sober / FreeSM)»
software_tab_flatpak() {
    setup_flatpak_core || warn "Flatpak не настроен."
    confirm "Установить Sober (Roblox на Linux) через Flatpak?" && install_sober
    confirm "Установить FreeSM Launcher (Minecraft, AUR)?" && install_freesm_core
}

# Центральное меню установки ПО (вкладки)
install_software_menu() {
    while true; do
        menu_select "Установка ПО" \
            "1|Базовый набор (рекомендуется)" \
            "2|Приложения (браузеры, мессенджеры, игры...)" \
            "3|Консольные приколы (визуализации, игры, фетчи, CLI...)" \
            "4|Кастомные фетчи (fastfetch, uwufetch, areofyl/fetch...)" \
            "5|Flatpak + Flathub (+ Sober / FreeSM)" \
            "6|Всё по галочкам (базовый набор + приложения)" \
            "0|Назад" || return 0

        [[ "$MENU_CHOICE" == 0 ]] && return 0

        [[ -z "$(aur_helper)" ]] && \
            warn "AUR-хелпер (yay/paru) не найден — AUR-пакеты будут пропущены (пункт 3 главного меню)."

        ensure_sudo || { pause; continue; }
        pacman_busy && { pause; continue; }

        case "$MENU_CHOICE" in
            1) software_tab_base; pause ;;
            2) software_tab_apps; pause ;;
            3) software_tab_console ;;
            4) software_tab_fetches; pause ;;
            5) software_tab_flatpak; pause ;;
            6) software_tab_all; pause ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 9.1 КОНСОЛЬНЫЕ «ПРИКОЛЫ» (визуализации, игры, мониторы, медиа, CLI, фетчи)
# ------------------------------------------------------------------------------
# Печатает строки меню для категории $1
fun_group_items() {
    local name
    case "$1" in
        1) name=FUN_TOOLS_MENU ;;
        2) name=FUN_GAMES_MENU ;;
        3) name=FUN_MONITOR_MENU ;;
        4) name=FUN_MEDIA_MENU ;;
        5) name=CLI_TOOLS_MENU ;;
        6) name=CUSTOM_FETCH_MENU ;;
        *) return 0 ;;
    esac
    local -n g="$name"
    (( ${#g[@]} )) && printf '%s\n' "${g[@]}"
}

# Установка areofyl/fetch (https://github.com/areofyl/fetch).
# Приоритет: AUR-пакет fetch-git; если AUR-хелпера нет — сборка из исходников.
install_areofyl_fetch() {
    if [[ -n "$(aur_helper)" ]]; then
        info "=== areofyl/fetch: установка из AUR (fetch-git) ==="
        if pkg_install fetch-git; then
            ok "areofyl/fetch установлен из AUR (fetch-git) — команда 'fetch'."
            return 0
        fi
        warn "AUR-пакет fetch-git не установился — пробую собрать из исходников."
    fi

    info "=== areofyl/fetch (сборка из исходников) ==="
    ensure_sudo || return 1
    ensure_tools git make gcc || { err "Нужны git, make и gcc."; return 1; }
    ensure_work_dir

    local dir="$WORK_DIR/areofyl-fetch"
    rm -rf "$dir"
    info "Скачиваю https://github.com/areofyl/fetch ..."
    git clone --depth 1 https://github.com/areofyl/fetch "$dir" \
        || { err "Не удалось скачать репозиторий."; return 1; }

    info "Собираю (make)..."
    ( cd "$dir" && make ) || { err "Сборка не удалась."; return 1; }

    info "Устанавливаю в /usr/local/bin (sudo make install)..."
    ( cd "$dir" && sudo make install ) || { err "Установка не удалась."; return 1; }

    if has fetch; then
        ok "areofyl/fetch установлен: команда 'fetch' (например: fetch -l arch)."
    else
        warn "Собрано, но команда fetch не найдена в PATH."
    fi
}

# Установка выбранных категорий (аргументы — номера категорий).
software_install_console() {
    local -a items=() c
    for c in "$@"; do
        mapfile -t -O "${#items[@]}" items < <(fun_group_items "$c")
    done
    (( ${#items[@]} == 0 )) && { warn "Нет пакетов в выбранных категориях."; return 1; }

    select_packages "Консольные приколы" "${items[@]}" || { warn "Отменено."; return 0; }
    (( ${#SELECTED_PACKAGES[@]} == 0 )) && { warn "Ничего не выбрано."; return 0; }

    # Отделяем пакеты от того, что собирается из исходников
    local -a pkgs=() p
    local want_areofyl=0
    for p in "${SELECTED_PACKAGES[@]}"; do
        if [[ "$p" == "$CUSTOM_SRC_FETCH" ]]; then want_areofyl=1; else pkgs+=("$p"); fi
    done

    local rc=0
    (( ${#pkgs[@]} )) && { software_install_pkgs "${pkgs[@]}" || rc=1; }
    (( want_areofyl )) && { install_areofyl_fetch || rc=1; }
    return $rc
}

# Вкладка «Консольные приколы»: подпапки по категориям
software_tab_console() {
    while true; do
        menu_select "Консольные приколы — выберите раздел" \
            "1|Приколы и визуализации" \
            "2|Консольные игры" \
            "3|Мониторы и системные утилиты" \
            "4|Музыка, медиа, браузеры" \
            "5|Полезные CLI-утилиты" \
            "6|Кастомные фетчи" \
            "7|Всё подряд (все разделы)" \
            "0|Назад" || return 0

        case "$MENU_CHOICE" in
            0) return 0 ;;
            7) software_install_console 1 2 3 4 5 6; pause ;;
            [1-6]) software_install_console "$MENU_CHOICE"; pause ;;
        esac
    done
}

# Вкладка «Кастомные фетчи» (ярлык на раздел 6)
software_tab_fetches() { software_install_console 6; }

# Совместимость: используется в полной установке (пункт 1)
install_fun_tools_core() { software_tab_console; }

install_fun_tools() {
    clear
    info "=== Консольные приколы ==="
    echo
    software_tab_console
}

# ------------------------------------------------------------------------------
# 8.1 GPU SCREEN RECORDER
# ------------------------------------------------------------------------------
install_gsr_core() {
    info "=== Установка GPU Screen Recorder ==="
    if has gpu-screen-recorder && has gpu-screen-recorder-ui; then
        ok "GPU Screen Recorder уже установлен."
        return 0
    fi
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка gpu-screen-recorder + gpu-screen-recorder-ui..."
    pkg_install gpu-screen-recorder gpu-screen-recorder-ui \
        || { err "Не удалось установить GPU Screen Recorder."; return 1; }
    ok "GPU Screen Recorder установлен (движок + оверлей UI)."
}

install_gsr() { clear; install_gsr_core; pause; }

# ------------------------------------------------------------------------------
# 8.2 УТИЛИТЫ ДЛЯ АРХИВОВ
# ------------------------------------------------------------------------------
install_archive_tools_core() {
    info "=== Установка утилит для архивов ==="
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Устанавливаю: ${ARCHIVE_TOOLS[*]}"
    pkg_install "${ARCHIVE_TOOLS[@]}" \
        || { err "Часть утилит для архивов не установилась."; return 1; }
    ok "Утилиты для архивов установлены (GUI: Xarchiver; консоль: tar/zip/unzip/unrar/7zip/...)."
}

install_archive_tools() { clear; install_archive_tools_core; pause; }

# ------------------------------------------------------------------------------
# 8.3 ФАЙРВОЛ (ufw или firewalld)
# ------------------------------------------------------------------------------
configure_firewall() {
    clear
    info "=== Настройка файрвола ==="
    echo
    echo -e "${BOLD}Разница между ufw и firewalld:${NC}"
    echo "  • ufw (Uncomplicated Firewall) — простой фронтенд к nftables/iptables."
    echo "    Лёгкий и понятный, идеален для домашнего ПК и ноутбука."
    echo "  • firewalld — динамический менеджер зон (zones) и сервисов."
    echo "    Гибче (профили сетей, зоны), удобнее для серверов и частой смены сетей."
    echo "  Оба фильтруют трафик одинаково. Для личной системы проще ufw."
    echo

    local fw=""
    has ufw && fw=ufw
    [[ -z "$fw" ]] && has firewall-cmd && fw=firewalld

    if [[ -z "$fw" ]]; then
        echo "Какой файрвол установить?"
        echo "1) ufw (проще, рекомендую для ПК)"
        echo "2) firewalld (зоны, для серверов)"
        echo "3) Не устанавливать"
        local c; read -rp "Ваш выбор [1-3]: " c
        case "$c" in
            2) fw=firewalld ;;
            3) info "Пропущено."; pause; return 0 ;;
            *) fw=ufw ;;
        esac
    else
        info "Уже установлен файрвол: $fw"
    fi

    ensure_sudo || { pause; return; }

    if [[ "$fw" == ufw ]]; then
        has ufw || pkg_install ufw || { err "Не удалось установить ufw."; pause; return; }
        info "Включаю ufw: входящие запрещены, исходящие разрешены..."
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        sudo systemctl enable --now ufw 2>/dev/null || true
        ok "ufw включён (входящие запрещены, исходящие разрешены)."
        sudo ufw status verbose
    else
        has firewall-cmd || pkg_install firewalld || { err "Не удалось установить firewalld."; pause; return; }
        info "Включаю firewalld (зона public)..."
        sudo systemctl enable --now firewalld
        sudo firewall-cmd --set-default-zone=public
        sudo firewall-cmd --permanent --zone=public --set-target=default
        sudo firewall-cmd --reload
        ok "firewalld включён (зона public)."
        sudo firewall-cmd --list-all
    fi
    pause
}

# ------------------------------------------------------------------------------
# 9.2 FLATPAK + FLATHUB (+ SOBER / ROBLOX)
# ------------------------------------------------------------------------------
# Установка и базовая настройка Flatpak: сам flatpak + портал + репозиторий Flathub
setup_flatpak_core() {
    info "=== Установка и настройка Flatpak ==="
    ensure_sudo || return 1
    pacman_busy && return 1

    if has flatpak; then
        ok "Flatpak уже установлен."
    else
        warn "Установка flatpak и xdg-desktop-portal-gtk..."
        pac_install flatpak xdg-desktop-portal-gtk || { err "Не удалось установить flatpak."; return 1; }
    fi

    warn "Добавляю репозиторий Flathub..."
    if sudo flatpak remote-add --if-not-exists flathub "$FLATPAK_REMOTE_URL"; then
        ok "Flathub готов."
    else
        warn "Системное добавление не удалось — пробую для пользователя."
        if flatpak remote-add --user --if-not-exists flathub "$FLATPAK_REMOTE_URL"; then
            ok "Flathub добавлен для пользователя."
        else
            err "Не удалось добавить Flathub."
            return 1
        fi
    fi
    return 0
}

# Установка Sober (Roblox) из Flathub
install_sober() {
    has flatpak || { err "Flatpak не установлен — сначала выполните настройку Flatpak."; return 1; }
    ensure_sudo || return 1

    info "Установка Sober (Roblox на Linux) из Flathub..."
    if sudo flatpak install -y --noninteractive flathub "$SOBER_APP"; then
        ok "Sober установлен. Запуск: flatpak run $SOBER_APP"
        return 0
    fi
    warn "Системная установка не удалась — пробую для пользователя."
    if flatpak install -y --noninteractive --user flathub "$SOBER_APP"; then
        ok "Sober установлен (для пользователя). Запуск: flatpak run $SOBER_APP"
        return 0
    fi
    err "Не удалось установить Sober."
    return 1
}

setup_flatpak() {
    clear
    setup_flatpak_core || { pause; return; }
    if confirm "Установить Sober (Roblox на Linux) из Flathub?"; then
        install_sober
    else
        info "Sober пропущен."
    fi
    pause
}

# ------------------------------------------------------------------------------
# 9.3 FREESM LAUNCHER (MINECRAFT, AUR)
# ------------------------------------------------------------------------------
install_freesm_core() {
    info "=== Установка FreeSM Launcher ($FREESM_PKG) ==="
    if pacman -Qq "$FREESM_PKG" &>/dev/null; then
        ok "FreeSM Launcher уже установлен."
        return 0
    fi

    local helper; helper=$(aur_helper)
    if [[ -z "$helper" ]]; then
        err "AUR-хелпер (yay/paru) не найден. Установите его в пункте 3 меню."
        return 1
    fi
    ensure_sudo || return 1
    pacman_busy && return 1

    warn "Установка FreeSM Launcher из AUR..."
    "$helper" -S --needed "$FREESM_PKG" || { err "Не удалось установить $FREESM_PKG."; return 1; }
    ok "FreeSM Launcher установлен."
}

install_freesm() { clear; install_freesm_core; pause; }

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
    echo "  3. Установка dotfiles (Serpantinum) + раскладка us,ru"
    echo "  4. Установка Fish + плагины + конфиг"
    echo "  5. Установка Neovim + Neovide + конфиг"
    echo "  6. Установка mpv"
    echo "  7. GPU Screen Recorder + утилиты для архивов (Xarchiver)"
    echo "  8. Flatpak + Flathub (и Sober по выбору)"
    echo "  9. FreeSM Launcher (по выбору)"
    echo " 10. Необязательное ПО — по галочкам (браузеры, мессенджеры, игры...)"
    echo " 11. Консольные приколы — по галочкам (игры, фетчи, визуализации, CLI...)"
    echo " 12. Файрвол (ufw / firewalld — по выбору)"
    echo " 13. Применение тем Serpantinum (archy, авто-поиск)"
    echo
    gpu_drivers_notice
    confirm "Начать полную установку?" || { warn "Отменено."; pause; return; }

    ensure_sudo || { pause; return; }

    # Serpantinum на «чистой» системе сам делает полный апгрейд (pacman -Syyu),
    # поэтому не дублируем его: обновляемся сами только если Serpantinum уже стоит.
    if [[ -f "$SERPANTINUM_STATE_DIR/version" ]]; then
        update_system_core
    else
        info "Serpantinum ещё не установлен: полный апгрейд системы выполнит его установщик — пропускаю дублирование."
    fi

    install_aur_helper_core "$(choose_helper)" || warn "AUR-хелпер не установлен — часть шагов может не сработать."

    if ! install_dotfiles_core; then
        warn "Dotfiles не установлены."
        # Если апгрейд был пропущен, а Serpantinum так и не отработал — обновляемся сами.
        [[ -f "$SERPANTINUM_STATE_DIR/version" ]] || update_system_core
    fi

    install_fish_core
    install_neovim_core
    install_mpv_core || warn "mpv не установлен."
    install_gsr_core || warn "GPU Screen Recorder не установлен."
    install_archive_tools_core || warn "Утилиты для архивов не установлены."
    setup_flatpak_core || warn "Flatpak не настроен."
    if confirm "Установить Sober (Roblox) через Flatpak?"; then install_sober; fi
    if confirm "Установить FreeSM Launcher (Minecraft, AUR)?"; then install_freesm_core; fi

    # Необязательное ПО — по галочкам (браузеры, мессенджеры, игры и т.д.)
    echo
    if confirm "Выбрать необязательное ПО (браузеры, мессенджеры, игры)?"; then
        install_essentials_core apps || warn "Дополнительное ПО не установлено."
    fi

    # Консольные «приколы» — тоже по галочкам
    echo
    if confirm "Выбрать консольные приколы (cava, cbonsai, tty-clock, ...)?"; then
        install_fun_tools_core || warn "Консольные приколы не установлены."
    fi

    configure_firewall
    apply_archy_themes

    echo
    ok "Полная установка завершена! Рекомендуется перезагрузка."
    gpu_drivers_notice
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
        echo -e "  ${GREEN}8)${NC} Установить ПО (вкладки: базовое / приложения / приколы / фетчи)"
        echo -e "  ${GREEN}9)${NC} Установить Flatpak + Flathub (+ Sober)"
        echo -e "  ${GREEN}10)${NC} Установить mpv"
        echo -e "  ${GREEN}11)${NC} Установить FreeSM Launcher (Minecraft)"
        echo -e "  ${GREEN}12)${NC} Установить GPU Screen Recorder"
        echo -e "  ${GREEN}13)${NC} Установить утилиты для архивов (Xarchiver и др.)"
        echo -e "  ${GREEN}14)${NC} Настроить файрвол (ufw / firewalld)"
        echo -e "  ${GREEN}15)${NC} Установить консольные приколы (игры, фетчи, визуализации, CLI...)"
        echo -e "  ${RED}0)${NC} Выход"
        echo
        read -rp "Номер пункта [0-15]: " choice

        case "$choice" in
            1) full_setup ;;
            2) system_menu ;;
            3) install_aur_helper_menu ;;
            4) install_dotfiles ;;
            5) install_fish ;;
            6) install_neovim ;;
            7) apply_all_configs ;;
            8) install_software_menu ;;
            9) setup_flatpak ;;
            10) install_mpv ;;
            11) install_freesm ;;
            12) install_gsr ;;
            13) install_archive_tools ;;
            14) configure_firewall ;;
            15) install_fun_tools ;;
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
