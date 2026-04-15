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


# Trash System
## 1. Overview

This system is a **Content Addressable Storage (CAS)-based trash management system** built on top of:

* Filesystem (CAS layer) → stores file blobs using hash
* SQLite database (metadata layer) → tracks logical state
* Shell interface (`trash`, `safe-rm`) → user interaction
* systemd timers → lifecycle automation

---

## 2. Core Architecture

### 2.1 Storage Model

```
User deletes file
        ↓
safe-rm intercepts
        ↓
File → hashed (sha256)
        ↓
Stored in CAS (objects/)
        ↓
Metadata stored in SQLite (trash.db)
```

---

### 2.2 Components

| Component  | Role               |
| ---------- | ------------------ |
| safe-rm    | intercept deletion |
| trash      | CLI interface      |
| objects/   | CAS storage        |
| trash.db   | metadata           |
| meta table | schema version     |
| systemd    | automation         |

---

### 2.3 Directory Layout

```
~/.local/share/trash-system/
├── db/
│   ├── trash.db
│   └── trash.db.lock
└── objects/
    └── <hash-prefix>/<hash>
```

---

## 3. Data Model

### 3.1 Main Table

```sql
CREATE TABLE trash (
    id TEXT PRIMARY KEY,
    original_path TEXT,
    filename TEXT,
    extension TEXT,
    deletion_time INTEGER,
    mime_type TEXT,
    category TEXT,
    origin_root TEXT,
    project_root TEXT,
    storage_path TEXT,
    size INTEGER,
    hash TEXT,
    is_restored INTEGER DEFAULT 0,
    active_days INTEGER DEFAULT 0,
    pinned INTEGER DEFAULT 0
);
```

---

### 3.2 Meta Table

```sql
CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT
);
```

---

### 3.3 Index

```sql
CREATE INDEX idx_hash_active
ON trash(hash)
WHERE is_restored=0;
```

---

## 4. CAS Storage

### 4.1 Object Path

```
$OBJ/${hash:0:2}/${hash:2:2}/$hash
```

---

### 4.2 Deduplication

```
mv -n tmp dest
```

* If exists → reuse
* Else → create

---

## 5. Commands

---

### 5.1 Delete (safe-rm)

```
rm file
```

Flow:

1. hash file
2. move to temp
3. CAS placement
4. DB insert
5. rollback on failure

---

### 5.2 List

```
trash list
```

---

### 5.3 Restore

```
trash restore <id>
```

Flow:

1. fetch DB
2. resolve object
3. verify hash
4. restore file
5. mark restored

---

### 5.4 Delete (permanent)

```
trash delete <id>
trash delete 1-5
```

* pinned → blocked
* range → skips pinned

---

### 5.5 Clear

```
trash clear
```

Deletes everything:

* DB entries
* CAS objects

---

### 5.6 Pin / Unpin

```
trash pin <id>
trash unpin <id>
```

Pinned items:

* cannot be deleted
* not cleaned automatically

---

### 5.7 Cleanup (systemd)

```
trash cleanup 100
```

Deletes:

* unpinned
* older than N days

---

### 5.8 Scan (GC)

```
trash scan
```

Removes orphan objects:

```
if object not referenced in DB → delete
```

---

### 5.9 Health

```
trash health
```

Checks:

* DB integrity
* object store

---

## 6. Consistency Model

```
DB = source of truth
CAS = storage
```

---

### Valid State

```
DB entry exists → object exists
```

---

### Orphan State

```
object exists, DB missing → removed by scan
```

---

### Broken State

```
DB exists, object missing → restore fails
```

---

## 7. Concurrency

Locking:

```
exec 200>"$LOCK"
flock -n 200
```

Guarantee:

* single writer
* no race conditions

---

## 8. SQLite Configuration

```sql
PRAGMA journal_mode=WAL;
PRAGMA synchronous=FULL;
PRAGMA foreign_keys=ON;
```

---

## 9. Systemd

### Timer

```
trash-cleanup.timer
```

### Service

```
ExecStart=trash cleanup 100
```

---

## 10. Shell Integration

Fish function:

```
files → safe-rm
directories → rm
recursive → bypass
```

---

## 11. Repo Structure

```
trash/
├── bin/
├── scripts/
├── config/
├── systemd/
├── install.sh
└── uninstall.sh
```

---

## 12. .gitignore

```
.local/share/trash-system/
*.db
*.db-wal
*.db-shm
*.db.lock
objects/
```

---

## 13. Failure Handling

| Case       | Behavior |
| ---------- | -------- |
| DB failure | rollback |
| corruption | abort    |
| lock fail  | exit     |

---

## 14. Safety Rules

* protects system paths
* prevents overwrite
* skips directories
* enforces pin

---

## 15. Limitations

* no recovery without DB
* full hashing cost
* single writer
* no versioning

---

## 16. Future Enhancements

* force restore
* compression
* logging
* chunk hashing

---

## 17. Final Guarantees

* no accidental loss
* deduplicated storage
* crash-safe
* consistent state
* reproducible setup

---

## Final Statement

This system is a:

```
CAS + SQLite + WAL + Locking + GC + Systemd
```

based trash architecture that is:

* consistent
* durable
* production-grade
* fully operational

