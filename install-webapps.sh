#!/bin/bash

echo "[webapps] Installing web apps..."

# omarchy-webapp-install <name> <url> <icon-ref>
# Empty icon-ref auto-fetches favicon via Google S2
omarchy-webapp-install "Claude" "https://claude.ai" ""
omarchy-webapp-install "Claude Code" "https://claude.ai/code" ""
omarchy-webapp-install "Google Mail" "https://mail.google.com/mail/u/0/" ""
omarchy-webapp-install "Google Calendar" "https://calendar.google.com/calendar/u/0/r" ""

echo "[webapps] Done."
