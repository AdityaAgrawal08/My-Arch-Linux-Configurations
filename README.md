# My Arch Linux Configurations

A collection of personal configuration files (dotfiles) for my Arch Linux setup featuring Hyprland, a dynamic tiling Wayland compositor.

## Overview

This repository contains my customized configuration files for a clean, efficient, and visually appealing Arch Linux desktop environment. The setup is centered around Hyprland with carefully curated complementary tools to create a smooth and productive workflow.

## Components

### Window Manager & Desktop Environment
- **Hyprland** - A dynamic tiling Wayland compositor with smooth animations and modern features
- **Waybar** - Highly customizable status bar for Wayland compositors
- **Wofi** - Application launcher for Wayland

### Shell & Terminal
- **Fish** - User-friendly command line shell with syntax highlighting and autosuggestions
- **Starship** - Fast, customizable prompt for any shell
- **Neovim** - Extensible text editor configured for development

## Directory Structure

```
.
├── fish/.config/fish/          # Fish shell configuration
├── hypr/.config/hypr/          # Hyprland window manager configuration
├── nvim/.config/nvim/          # Neovim editor configuration
├── starship/.config/           # Starship prompt configuration
├── waybar/.config/waybar/      # Waybar status bar configuration
└── wofi/.config/wofi/          # Wofi launcher configuration
```

## Prerequisites

Before using these configurations, ensure you have Arch Linux installed with the following packages:

### Core Components
```bash
sudo pacman -S hyprland waybar wofi fish starship neovim
```

### Recommended Additional Packages
```bash
# Hyprland utilities
sudo pacman -S hyprpaper hypridle hyprlock

# Terminal and fonts
sudo pacman -S kitty ttf-jetbrains-mono-nerd

# System utilities
sudo pacman -S brightnessctl playerctl pavucontrol
```

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AdityaAgrawal08/My-Arch-Linux-Configurations.git
   cd My-Arch-Linux-Configurations
   ```

2. **Backup your existing configurations:**
   ```bash
   mkdir -p ~/.config/backup
   cp -r ~/.config/hypr ~/.config/backup/
   cp -r ~/.config/waybar ~/.config/backup/
   # Backup other configs as needed
   ```

3. **Install configurations using GNU Stow (recommended):**
   ```bash
   sudo pacman -S stow
   
   # Stow individual configurations
   stow hypr
   stow waybar
   stow fish
   stow nvim
   stow starship
   stow wofi
   
   # Or stow everything at once
   stow */
   ```

4. **Manual installation (alternative):**
   ```bash
   cp -r hypr/.config/hypr ~/.config/
   cp -r waybar/.config/waybar ~/.config/
   cp -r fish/.config/fish ~/.config/
   cp -r nvim/.config/nvim ~/.config/
   cp -r starship/.config/* ~/.config/
   cp -r wofi/.config/wofi ~/.config/
   ```

## Configuration Details

### Hyprland
The Hyprland configuration includes custom keybindings, window rules, and animation settings optimized for daily use. Key features:
- Smooth animations and transitions
- Efficient workspace management
- Custom keybindings for productivity
- Monitor configuration

### Waybar
A customized status bar showing:
- Workspace indicators
- System resources (CPU, memory, disk)
- Network status
- Audio controls
- Date and time
- System tray

### Fish Shell
Configured with:
- Custom aliases and functions
- Environment variables
- Integration with Starship prompt

### Neovim
A personalized Neovim setup featuring:
- Plugin management
- Language server protocol (LSP) support
- Custom keybindings
- Syntax highlighting and autocompletion

## Usage

After installation, you can start Hyprland by:
1. Logging out of your current session
2. At the login manager, select Hyprland
3. Log in with your credentials

Alternatively, from a TTY:
```bash
Hyprland
```

### Key Bindings (Default Examples)

These are common Hyprland keybindings (check `hypr/.config/hypr/hyprland.conf` for your specific bindings):

- `SUPER + Return` - Open terminal
- `SUPER + D` - Open application launcher (Wofi)
- `SUPER + Q` - Close focused window
- `SUPER + [1-9]` - Switch to workspace
- `SUPER + SHIFT + [1-9]` - Move window to workspace
- `SUPER + Mouse` - Move/resize windows

## Customization

Feel free to modify these configurations to suit your preferences:

1. **Hyprland settings:** Edit `hypr/.config/hypr/hyprland.conf`
2. **Waybar appearance:** Modify `waybar/.config/waybar/config` and `style.css`
3. **Wofi styling:** Edit `wofi/.config/wofi/style.css`
4. **Fish aliases:** Add to `fish/.config/fish/config.fish`
5. **Starship prompt:** Customize `starship/.config/starship.toml`

## Updating

To update your configurations:

```bash
cd My-Arch-Linux-Configurations
git pull origin main

# If using stow
stow -R */  # Restow all packages

# Or copy manually
cp -r hypr/.config/hypr ~/.config/
# Repeat for other configs
```

## Troubleshooting

### Hyprland won't start
- Ensure all dependencies are installed
- Check logs: `cat /tmp/hypr/$(echo $HYPRLAND_INSTANCE_SIGNATURE)/hyprland.log`
- Verify your graphics drivers are properly installed

### Waybar not appearing
- Make sure Waybar is set to auto-start in `hyprland.conf`
- Check if Waybar is running: `ps aux | grep waybar`
- Try launching manually: `waybar`

### Font issues
- Install Nerd Fonts: `sudo pacman -S ttf-nerd-fonts-symbols`
- Rebuild font cache: `fc-cache -fv`

## Screenshots

*Add screenshots of your setup here*

## Contributing

This is a personal configuration repository, but suggestions and improvements are welcome! Feel free to:
- Open an issue for questions or problems
- Submit a pull request with improvements
- Fork this repository and customize it for your own use

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- [Hyprland](https://hyprland.org/) - Amazing Wayland compositor
- [Waybar](https://github.com/Alexays/Waybar) - Customizable status bar
- The Arch Linux community for excellent documentation
- All the developers of the tools used in this configuration

## Contact

For questions or feedback, feel free to open an issue on this repository.

---

**Note:** These configurations are personal and may need adjustments for your specific hardware and preferences. Always backup your existing configurations before applying new ones.
