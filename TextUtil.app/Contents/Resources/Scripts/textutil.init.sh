#!/bin/bash
# textutil.init.sh - Initialize the window

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.textutil.sh"

# Set up table columns - one visible column (path is hidden in data)
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_columns "Documents"
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_column_widths 270

# Start with an empty document list
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_remove_all_rows

"$dialog_tool" "$window_uuid" ${FILE_INFO_VIEW_ID} \
    "Drop documents into the list, pick an output format, then press Convert."

# Seed the document list: from objects dropped on the app icon, or from the
# Open... panel selection handed off via the private pasteboard
seed_paths="$OMC_OBJ_PATH"
if [ -z "$seed_paths" ]; then
    seed_paths="$("$pasteboard_tool" "$OPEN_PATHS_PB_KEY" get)"
    if [ -n "$seed_paths" ]; then
        "$pasteboard_tool" "$OPEN_PATHS_PB_KEY" set ""
    fi
fi

if [ -n "$seed_paths" ]; then
    add_files_to_table "$seed_paths"
    if [ -n "$_first_row_path" ]; then
        # Visual selection only (fires no actionID); update the info pane
        # directly from the known path to avoid the selection-vs-handler race.
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_select_row 0
        apply_file_selection "$_first_row_path"
    fi
fi
