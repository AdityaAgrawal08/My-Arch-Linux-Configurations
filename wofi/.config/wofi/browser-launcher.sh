ZEN="/opt/zen-browser-bin/zen-bin"
BRAVE="/usr/bin/brave"
FIREFOX="/usr/bin/firefox"

choice=$(printf "Zen\nBrave\nFirefox" | wofi --dmenu --prompt="Choose browser: ")

case "$choice" in
    Zen) "$ZEN" & ;;
    Brave) "$BRAVE" & ;;
    Firefox) "$FIREFOX" & ;;
esac

