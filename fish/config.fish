# Отключаем стандартное приветствие Fish
set -g fish_greeting ""

# Пользовательские бинарники (~/.local/bin)
set PATH $PATH $HOME/.local/bin

# Запускаем keyfetch при старте (только в интерактивном режиме).
# keyfetch — анимированный 3D-фетч с вращающимся ключом (функция keyfetch.fish).
# Нажмите любую клавишу, чтобы остановить и продолжить работу.
if status is-interactive
    if functions -q keyfetch; and test -f $HOME/.config/fish/keyfetch.c
        keyfetch
    end
end

# Обычный fastfetch тоже доступен — раскомментируйте, если нужен вместо keyfetch:
# if status is-interactive
#     fastfetch
# end
