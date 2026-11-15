function _animfetch --argument-names name --description 'Анимированный 3D-фетч: собирает <name>.c и запускает бинарник'
    if test -z "$name"
        echo "animfetch: не указано имя фетча (keyfetch, treefetch, ...)" >&2
        return 1
    end

    # Ищем исходник <name>.c в местах, куда его кладёт установщик/конфиг.
    set -l candidates \
        "$HOME/.config/fish/$name.c" \
        "$HOME/.config/fish/functions/$name.c" \
        "$HOME/.local/share/$name/$name.c"

    set -l src
    for c in $candidates
        if test -f "$c"
            set src "$c"
            break
        end
    end

    if test -z "$src"
        echo "$name: не найден $name.c (ожидается в ~/.config/fish/)" >&2
        return 1
    end

    set -l bin "$HOME/.local/bin/$name"

    # Собираем, если бинарника нет или исходник новее.
    if not test -x "$bin"; or test "$src" -nt "$bin"
        if not type -q cc
            echo "$name: нужен компилятор C (cc/gcc)." >&2
            return 1
        end
        command mkdir -p (dirname "$bin")
        if not cc -O2 -o "$bin" "$src" -lm
            echo "$name: не удалось собрать." >&2
            return 1
        end
    end

    command "$bin" $argv[2..-1]
end
