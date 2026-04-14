#!/usr/bin/env bash

rm -f ~/.local/bin/safe-rm
rm -f ~/.local/bin/trash
rm -f ~/.local/bin/trash-ui

rm -rf ~/.local/share/trash-system

systemctl --user disable --now trash-cleanup.timer 2>/dev/null || true
rm -f ~/.config/systemd/user/trash-cleanup.*

echo "trash system removed"
