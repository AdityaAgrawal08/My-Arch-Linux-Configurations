function rm
    set files
    set dirs

    for arg in $argv
        if test -d $arg
            set dirs $dirs $arg
        else
            set files $files $arg
        end
    end

    # Recursive delete → bypass trash (explicit + consistent)
    if contains -- -r $argv; or contains -- -rf $argv; or contains -- -fr $argv
        echo "Recursive delete bypasses trash"
        command rm $argv
        return
    end

    # Files → trash
    if test (count $files) -gt 0
        /usr/bin/env bash ~/.local/bin/safe-rm $files
    end

    # Directories → normal rm
    if test (count $dirs) -gt 0
        command rm $dirs
    end
end
