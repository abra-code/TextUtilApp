#!/bin/bash
# TextUtil.main.sh - Entry point for the TextUtil applet
#
# The window is opened by NEXT_COMMAND_ID = textutil.new; the object context
# (documents dropped on the app icon) propagates to the chained command, and
# textutil.init seeds the document list from OMC_OBJ_PATH.
#
# A non-blocking window's main command runs at an unpredictable time relative to
# the window appearing, so this stays empty on purpose - all initialization
# belongs in textutil.init.
exit 0
