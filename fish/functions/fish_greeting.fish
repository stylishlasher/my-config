function fish_greeting --description 'Приветствие терминала: fastfetch / 3D-фетч / ничего'
    # Настройки пишет установщик arch_multitool в ~/.config/arch_multitool/greeting.fish
    set -l conf $HOME/.config/arch_multitool/greeting.fish
    if test -f $conf
        source $conf
    end

    set -q greeting_mode; or set -g greeting_mode fastfetch
    set -q greeting_color; or set -g greeting_color '#ffc828'
    set -q greeting_rainbow; or set -g greeting_rainbow 0
    set -q greeting_height; or set -g greeting_height 16

    # Анимированные 3D-фетчи (см. fish/functions/_animfetch.fish).
    set -l anim_fetches keyfetch treefetch tomatofetch stoolfetch skeletonfetch
    # У каких фетчей есть второй цвет (флаг -a/--accent). keyfetch — без акцента.
    set -l anim_fetches_accent treefetch tomatofetch stoolfetch skeletonfetch

    switch $greeting_mode
        case $anim_fetches
            # Фетч закрепляется ВНИЗУ и живёт, пока открыт терминал.
            # Шелл остаётся сверху и сохраняет обычный скроллбек.
            if functions -q $greeting_mode
                set -l args --pin-bottom --height $greeting_height
                if test "$greeting_rainbow" = 1
                    set -a args --rainbow
                else
                    set -a args -c "$greeting_color"
                end
                # --accent передаём только тем фетчам, которые его понимают.
                if contains -- $greeting_mode $anim_fetches_accent
                    if set -q greeting_accent; and test -n "$greeting_accent"
                        set -a args --accent "$greeting_accent"
                    end
                end
                $greeting_mode $args
            end
        case fastfetch
            if type -q fastfetch
                fastfetch
            end
        case none
            # пустое приветствие — ничего не выводим
    end
end
