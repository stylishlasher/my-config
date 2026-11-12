function spotify --wraps='flatpak run com.spotify.Client >/dev/null 2>&1 &'
    flatpak run com.spotify.Client $argv >/dev/null 2>&1 &
end
