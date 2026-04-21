#!/bin/bash
# Launcher for ClaudeUsageMonitor that bypasses Gatekeeper.
# Double-click this file to start the monitor.
cd "$(dirname "$0")"
# If already running, don't start another instance.
if pgrep -f "ClaudeUsageMonitor.app/Contents/MacOS/ClaudeUsageMonitor" > /dev/null; then
    echo "Claude Usage Monitor is already running."
else
    # Launch detached from this terminal so closing the window doesn't kill it.
    nohup ./dist/ClaudeUsageMonitor.app/Contents/MacOS/ClaudeUsageMonitor > /dev/null 2>&1 &
    disown
    echo "Claude Usage Monitor started — check the menu bar."
fi
# Auto-close this terminal window after a couple seconds.
sleep 2
osascript -e 'tell application "Terminal" to close (every window whose name contains "Launch Claude Monitor")' &
exit 0
