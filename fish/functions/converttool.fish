function converttool --description 'ffmpeg: конвертер/сжатие'
    if test (count $argv) -lt 2
        echo "Использование: converttool ФАЙЛ действие...  (shrink | xN | 480p/720p/1080p | mute | расширение)"
        return 1
    end
    set in $argv[1]
    test -f "$in"; or begin; echo "Нет такого файла: $in"; return 1; end
    set dir (dirname "$in")
    set name (basename "$in")
    set base (string replace -r '\.[^.]*$' '' -- "$name")
    set inext (string lower (string replace -r '^.*\.' '' -- "$name"))
    set ext $inext
    set shrink 0; set mute 0; set speed 1; set height ""
    for a in $argv[2..-1]
        if test $a = shrink
            set shrink 1
        else if test $a = mute
            set mute 1
        else if string match -qr '^x[0-9.]+$' -- $a
            set speed (string sub -s 2 -- $a)
        else if string match -qr '^[0-9]+p$' -- $a
            set height (string replace p '' -- $a)
        else
            set ext (string lower (string replace '.' '' -- $a))
        end
    end
    set img jpg jpeg png webp bmp tiff avif
    set aud mp3 m4a aac ogg opus wav flac
    set inimg 0; contains -- $inext $img gif; and set inimg 1
    set outimg 0; contains -- $ext $img; and set outimg 1
    set outaud 0; contains -- $ext $aud; and set outaud 1
    
    set suffix ""
    test $shrink = 1; and set suffix _small
    test $speed != 1; and set suffix "$suffix"_x$speed
    set out "$dir/$base$suffix.$ext"
    test -e "$out"; and set out "$dir/$base$suffix"_out.$ext
    
    set vf; set af; set opts; set map
    if test $outaud = 0
        if test -n "$height"
            test $inimg = 1; and set vf $vf scale=-1:$height; or set vf $vf scale=-2:$height
        else if test $outimg = 1; and test $shrink = 1
            set vf $vf "scale='min(1920,iw)':-1"
        end
        test $speed != 1; and test $inimg = 0; and set vf $vf setpts=PTS/$speed
        if test $ext = gif; and test $inimg = 0
            set vf fps=12 (test -n "$height"; or echo "scale=480:-1:flags=lanczos")
            test -n "$height"; and set vf fps=12 scale=-1:$height
        end
    end
    if test $speed != 1; and test $inimg = 0
        set s $speed
        while test (math "$s > 2") = 1
            set af $af atempo=2
            set s (math "$s / 2")
        end
        set af $af atempo=$s
    end
    
    if test $outimg = 1
        set opts -frames:v 1 -update 1
        if test $shrink = 1
            switch $ext
                case jpg jpeg; set opts $opts -q:v 7
                case webp; set opts $opts -quality 70
                case png; set opts $opts -compression_level 9
                case avif; set opts $opts -crf 35
            end
        end
    else if test $outaud = 1
        set opts -vn
        test $shrink = 1; and set opts $opts -b:a 96k
    else if test $ext = gif
        set opts -an
    else
        set map -map "0:v?" -map "0:a?"
        test $mute = 1; and set opts $opts -an
        if test $shrink = 1
            if test $ext = webm
                set opts $opts -c:v libvpx-vp9 -crf 35 -b:v 0 -c:a libopus -b:a 96k
            else
                set opts $opts -c:v libx264 -crf 28 -preset medium -pix_fmt yuv420p -c:a aac -b:a 128k
            end
        end
        test $ext = mp4; and set opts $opts -movflags +faststart
    end
    
    set vfa; test (count $vf) -gt 0; and set vfa -vf (string join , $vf)
    set afa; test (count $af) -gt 0; and set afa -af (string join , $af)
    ffmpeg -hide_banner -loglevel error -stats -i "$in" $map $vfa $afa $opts "$out"
    and printf "✓ %s  %s → %s\n" "$out" (du -h "$in" | cut -f1) (du -h "$out" | cut -f1)
end
