function keyfetch --description 'Анимированный 3D-фетч с вращающимся ключом (собирается из keyfetch.c)'
    # Ищем исходник keyfetch.c в местах, куда его кладёт установщик/конфиг.
    set -l candidates \
        "$HOME/.config/fish/keyfetch.c" \
        "$HOME/.config/fish/functions/keyfetch.c" \
        "$HOME/.local/share/keyfetch/keyfetch.c"

    set -l src
    for c in $candidates
        if test -f "$c"
            set src "$c"
            break
        end
    end

    if test -z "$src"
        echo "keyfetch: не найден keyfetch.c (ожидается в ~/.config/fish/)" >&2
        return 1
    end

    set -l bin "$HOME/.local/bin/keyfetch"

    # Собираем, если бинарника нет или исходник новее.
    if not test -x "$bin"; or test "$src" -nt "$bin"
        if not type -q cc
            echo "keyfetch: нужен компилятор C (cc/gcc)." >&2
            return 1
        end
        command mkdir -p (dirname "$bin")
        if not cc -O2 -o "$bin" "$src" -lm
            echo "keyfetch: не удалось собрать." >&2
            return 1
        end
    end

    command "$bin" $argv
end
