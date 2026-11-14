# Отключаем стандартное приветствие Fish (за него отвечает функция fish_greeting)
set -g fish_greeting ""

# Пользовательские бинарники (~/.local/bin)
set PATH $PATH $HOME/.local/bin

# Ctrl-L: очистить экран и перерисовать строку ввода.
# Функция clear учитывает закреплённую шапку keyfetch и возвращает курсор под неё.
bind \cl 'clear; commandline -f repaint'
