function clear --description 'Очистка экрана с учётом закреплённой шапки keyfetch'
    # Сначала обычная очистка экрана
    if command -sq clear
        command clear
    else
        printf '\e[H\e[2J\e[3J'
    end

    # Если приветствие — закреплённый keyfetch, шапка занимает верхние строки.
    # clear() ставит курсор в (1;1), поэтому возвращаем его сразу под шапку,
    # чтобы промпт не рисовался поверх ключа.
    set -l conf $HOME/.config/arch_multitool/greeting.fish
    if test -f $conf
        source $conf
    end
    if set -q greeting_mode; and test "$greeting_mode" = keyfetch
        set -l h 16
        set -q greeting_height; and set h $greeting_height
        printf '\e[%d;1H' (math $h + 1)
    end
end
