#!/bin/bash
# TextUtil.main.sh - Entry point for TextUtil applet

echo "[$(/usr/bin/basename "$0")]"
env | sort

# This is the main command handler. The ActionUI window is already shown
# via the ACTIONUI_WINDOW definition in Command.plist.
# The INIT_SUBCOMMAND_ID (textutil.init) will run automatically.
