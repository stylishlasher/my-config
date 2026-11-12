# Отключаем стандартное приветствие Fish
set -g fish_greeting ""

# Запускаем fastfetch при старте (только в интерактивном режиме)
if status is-interactive
    fastfetch
end

fish_add_path /home/lislash/.spicetify

# Created by `pipx` on 2026-09-27 17:50:15
set PATH $PATH /home/lislash/.local/bin

# opencode
fish_add_path /home/lislash/.opencode/bin
