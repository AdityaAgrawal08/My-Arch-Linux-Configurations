ZEN="/opt/zen-browser-bin/zen-bin"
BRAVE="/usr/bin/brave"

choice=$(printf "Zen\nBrave" | wofi --dmenu --prompt="Choose browser: ")

case "$choice" in
    Zen) env MOZ_ENABLE_WAYLAND=1 "$ZEN" & ;;
    Brave) "$BRAVE" & ;;
esac

