function clear --description 'Очистка экрана с учётом закреплённой шапки/подвала keyfetch'
    # Сначала обычная очистка экрана (курсор встаёт в (1;1))
    if command -sq clear
        command clear
    else
        printf '\e[H\e[2J\e[3J'
    end

    # Если приветствие — закреплённый keyfetch, учитываем его положение:
    #   position=top    — ключ занимает верхние строки, clear() ставит курсор
    #                     в (1;1), поэтому возвращаем его сразу под шапку;
    #   position=bottom — ключ внизу, а область шелла начинается с первой строки,
    #                     так что (1;1) уже правильный и двигать курсор не нужно.
    set -l conf $HOME/.config/arch_multitool/greeting.fish
    if test -f $conf
        source $conf
    end
    if set -q greeting_mode; and test "$greeting_mode" = keyfetch
        set -l pos top
        set -q greeting_position; and set pos $greeting_position
        if test "$pos" != bottom
            set -l h 16
            set -q greeting_height; and set h $greeting_height
            printf '\e[%d;1H' (math $h + 1)
        end
    end
end
