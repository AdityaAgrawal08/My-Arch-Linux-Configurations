# Turn on useful features
set -g fish_color_command green
set -g fish_color_error red
set -g fish_greeting


# Useful abbreviations
abbr -a upd "sudo pacman -Syu"
abbr -a inst "sudo pacman -S"
abbr -a rem "sudo pacman -Rns"

# Set editor
set -gx EDITOR nvim

# Add local bin to PATH
if test -d ~/.local/bin
    set -gx PATH ~/.local/bin $PATH
end

# Enable syntax highlighting (built-in)
set -g fish_color_match cyan

# Enable autosuggestions (built-in)
set -g fish_color_autosuggestion brgrey

# Starship prompt (optional, recommended)
if type -q starship
    starship init fish | source
end
