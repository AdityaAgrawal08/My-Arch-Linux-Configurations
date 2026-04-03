# Turn on useful features
set -g fish_color_command green
set -g fish_color_error red
set -g fish_greeting ""
set -g fish_color_command green
set -g fish_color_error red
set -g fish_color_match cyan
set -g fish_color_autosuggestion brgrey

# Useful abbreviations
abbr --add upd "sudo pacman -Syu"
abbr --add inst "sudo pacman -S"
abbr --add rem "sudo pacman -Rns"

# Set editor
set -gx EDITOR nvim
set -gx PATH $HOME/.local/bin $PATH

# Add local bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -gx PATH ~/.local/bin $PATH
    end
end

# Starship prompt (optional, recommended)
if type -q starship
    starship init fish | source
end

function open
    zathura $argv
end
