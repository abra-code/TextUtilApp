#!/bin/sh
# lib.textutil.sh - Shared functions and variables for TextUtil

# Control IDs
TABLE_ID=10
FILE_INFO_VIEW_ID=12
REMOVE_BUTTON_ID=102
REVEAL_BUTTON_ID=104
QUICKLOOK_BUTTON_ID=105
FORMAT_PICKER_ID=13

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
next_cmd="$OMC_OMC_SUPPORT_PATH/omc_next_command"
pasteboard_tool="$OMC_OMC_SUPPORT_PATH/pasteboard"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Private pasteboard key: hand a selection from the Open... panel to a window
# that does not exist yet, so its init script can pick it up.
OPEN_PATHS_PB_KEY="TEXTUTIL_OPEN_PATHS"

DEBUG=false

# The trailing "return 0" is load-bearing. With logging off the && short-circuits
# to false, and every caller that ends with a _lib_log call - textutil.files.drop
# does - would hand that back as its own exit status. A logging helper must never
# decide whether the handler succeeded.
_lib_log() { [ "$DEBUG" = "true" ] && printf '%s\n' "$*" >> /tmp/textutil_drop.log; return 0; }

# Add files to the table.
# Argument: newline-separated list of file or directory paths to add.
# Directories are scanned recursively for supported documents.
add_files_to_table() {
    local new_paths="$1"
    local buffer=""
    local file_path="" filename="" rtfd_bundle="" found_file=""

    _lib_log "--- add_files_to_table ---"
    _lib_log "new_paths='${new_paths}'"

    # Preserve existing table rows
    local existing_paths="$OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS"
    if [ -n "$existing_paths" ]; then
        local tmp_existing="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/textutil.XXXXXX")"
        printf '%s\n' "$existing_paths" > "$tmp_existing"
        while IFS= read -r file_path; do
            [ -z "$file_path" ] && continue
            filename="$(/usr/bin/basename "$file_path")"
            buffer="${buffer}${filename}	${file_path}
"
        done < "$tmp_existing"
        /bin/rm -f "$tmp_existing"
    fi

    # Process each new path
    local tmp_new="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/textutil.XXXXXX")"
    printf '%s\n' "$new_paths" > "$tmp_new"
    while IFS= read -r file_path; do
        [ -z "$file_path" ] && continue
        _lib_log "processing path='${file_path}'"

        if [ -d "$file_path" ]; then
            _lib_log "  is directory, scanning..."

            # .rtfd bundles are directories — find them first
            local tmp_rtfd="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/textutil.XXXXXX")"
            /usr/bin/find "$file_path" -type d -iname "*.rtfd" ! -path "*/.*" -print > "$tmp_rtfd" 2>/dev/null
            while IFS= read -r rtfd_bundle; do
                [ -z "$rtfd_bundle" ] && continue
                _lib_log "  rtfd: '${rtfd_bundle}'"
                filename="$(/usr/bin/basename "$rtfd_bundle")"
                buffer="${buffer}${filename}	${rtfd_bundle}
"
            done < "$tmp_rtfd"
            /bin/rm -f "$tmp_rtfd"

            # Find supported text documents, skip hidden paths and .rtfd internals
            local tmp_files="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/textutil.XXXXXX")"
            /usr/bin/find "$file_path" -type f \
                \( -iname "*.txt" -o -iname "*.rtf" -o -iname "*.html" -o -iname "*.htm" \
                -o -iname "*.doc" -o -iname "*.docx" -o -iname "*.odt" \
                -o -iname "*.wordml" -o -iname "*.webarchive" \) \
                ! -path "*/.*" -print > "$tmp_files" 2>/dev/null
            while IFS= read -r found_file; do
                [ -z "$found_file" ] && continue
                case "$found_file" in
                    *.rtfd/*) continue ;;
                esac
                _lib_log "  found: '${found_file}'"
                filename="$(/usr/bin/basename "$found_file")"
                buffer="${buffer}${filename}	${found_file}
"
            done < "$tmp_files"
            /bin/rm -f "$tmp_files"

        elif [ -e "$file_path" ]; then
            _lib_log "  is file"
            filename="$(/usr/bin/basename "$file_path")"
            buffer="${buffer}${filename}	${file_path}
"
        else
            _lib_log "  does not exist, skipping"
        fi
    done < "$tmp_new"
    /bin/rm -f "$tmp_new"

    _lib_log "buffer='${buffer}'"

    # The sorted rows go through a temp file so the path that ends up in row 0
    # can be read back - callers use it to select and describe the first document
    # without waiting for a selection event that may not have landed yet.
    _first_row_path=""
    if [ -n "$buffer" ]; then
        local tmp_rows="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/textutil.XXXXXX")"
        printf "%s" "$buffer" | /usr/bin/sort -u > "$tmp_rows"
        _first_row_path="$(/usr/bin/head -1 "$tmp_rows" | /usr/bin/cut -f2)"
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin < "$tmp_rows"
        /bin/rm -f "$tmp_rows"
    else
        _lib_log "buffer empty, clearing table"
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_remove_all_rows
    fi
    _lib_log "--- add_files_to_table done ---"
}

# Bring the selection-dependent controls in line with a file path, or with
# nothing selected when the path is empty.
# Arguments: file_path (may be empty)
apply_file_selection() {
    local selected_path="$1"

    if [ -z "$selected_path" ]; then
        "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_disable
        "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_disable
        "$dialog_tool" "$window_uuid" ${QUICKLOOK_BUTTON_ID} omc_disable
        "$dialog_tool" "$window_uuid" ${FILE_INFO_VIEW_ID} ""
        return
    fi

    "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_enable
    "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_enable
    "$dialog_tool" "$window_uuid" ${QUICKLOOK_BUTTON_ID} omc_enable

    # Get file info using textutil -info, filter out Contents line
    local file_info="$(/usr/bin/textutil -info "$selected_path" 2>&1 | /usr/bin/grep -v "^  Contents:")"

    if [ -e "$selected_path" ]; then
        local created="$(/usr/bin/stat -f "%SB" "$selected_path" 2>/dev/null)"
        local modified="$(/usr/bin/stat -f "%Sm" "$selected_path" 2>/dev/null)"

        if [ -n "$created" ] || [ -n "$modified" ]; then
            file_info="${file_info}

  Created: ${created}
  Modified: ${modified}"
        fi
    fi

    "$dialog_tool" "$window_uuid" ${FILE_INFO_VIEW_ID} "$file_info"
}
