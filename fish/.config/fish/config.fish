# Turn on useful features
set -g fish_color_command green
set -g fish_color_error red
set -g fish_color_match cyan
set -g fish_color_autosuggestion brgrey
set -g fish_greeting ""

# Useful abbreviations
abbr --add upd "sudo pacman -Syu"
abbr --add inst "sudo pacman -S"
abbr --add rem "sudo pacman -Rns"

# Set editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# PATH (deduplicated + persistent)
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $fish_user_paths
        set -U fish_user_paths ~/.local/bin $fish_user_paths
    end
end

# Pager
set -gx PAGER less
set -gx LESS "-R"
set -gx MANPAGER "less -R"
set -gx LESSHISTFILE "-"

# Starship prompt (optional, recommended)
if type -q starship
    starship init fish | source
end

# Dependency check
for bin in zathura imv mpv libreoffice xdg-open
    if not type -q $bin
        echo "warning: missing dependency -> $bin"
    end
end


