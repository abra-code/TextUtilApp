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
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

DEBUG=false

_lib_log() { [ "$DEBUG" = "true" ] && printf '%s\n' "$*" >> /tmp/textutil_drop.log; }

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

    if [ -n "$buffer" ]; then
        printf "%s" "$buffer" | /usr/bin/sort -u | "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin
    else
        _lib_log "buffer empty, clearing table"
        printf '' | "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin
    fi
    _lib_log "--- add_files_to_table done ---"
}
