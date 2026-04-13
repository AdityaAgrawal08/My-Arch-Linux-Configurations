function open
    if test (count $argv) -eq 0
        echo "open: missing file operand"
        return 1
    end

    for file in $argv
        if not test -e "$file"
            echo "open: file not found -> $file"
            continue
        end

        set ext (string lower (path extension $file))

        switch $ext
            case ".pdf"
                zathura "$file" >/dev/null 2>&1 &
            case ".png" ".jpg" ".jpeg" ".webp" ".gif"
                imv "$file" >/dev/null 2>&1 &
            case ".mp4" ".mkv" ".webm" ".mp3"
                mpv "$file" >/dev/null 2>&1 &
            case ".docx" ".pptx" ".xlsx"
                libreoffice "$file" >/dev/null 2>&1 &
            case "*"
                xdg-open "$file" >/dev/null 2>&1 &
        end
    end
end
