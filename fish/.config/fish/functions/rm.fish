function rm
    set files
    set dirs

    # Separate files and directories
    for arg in $argv
        if test -d $arg
            set dirs $dirs $arg
        else
            set files $files $arg
        end
    end

    # If recursive flag → normal rm (no change)
    if contains -- -r $argv; or contains -- -rf $argv; or contains -- -fr $argv
        command rm $argv
        return
    end

    # Send files to trash
    if test (count $files) -gt 0
        /usr/bin/env bash ~/.local/bin/safe-rm $files
    end

    # Keep directory behavior same as default rm
    if test (count $dirs) -gt 0
        command rm $dirs
    end
end
