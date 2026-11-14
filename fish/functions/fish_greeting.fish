function fish_greeting --description 'Приветствие терминала: fastfetch / keyfetch / ничего'
    # Настройки пишет установщик arch_multitool в ~/.config/arch_multitool/greeting.fish
    set -l conf $HOME/.config/arch_multitool/greeting.fish
    if test -f $conf
        source $conf
    end

    set -q greeting_mode; or set -g greeting_mode fastfetch
    set -q greeting_color; or set -g greeting_color '#ffc828'
    set -q greeting_rainbow; or set -g greeting_rainbow 0
    set -q greeting_height; or set -g greeting_height 16

    switch $greeting_mode
        case keyfetch
            # Вращающийся 3D-ключ закрепляется сверху, промпт живёт ниже.
            if functions -q keyfetch
                if test "$greeting_rainbow" = 1
                    keyfetch --pin --rainbow --height $greeting_height
                else
                    keyfetch --pin -c "$greeting_color" --height $greeting_height
                end
            end
        case fastfetch
            if type -q fastfetch
                fastfetch
            end
        case none
            # пустое приветствие — ничего не выводим
    end
end
