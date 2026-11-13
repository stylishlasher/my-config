# Отключаем стандартное приветствие Fish
set -g fish_greeting ""

# Запускаем fastfetch при старте (только в интерактивном режиме)
if status is-interactive
    fastfetch
end

# Пользовательские бинарники (~/.local/bin)
set PATH $PATH $HOME/.local/bin
