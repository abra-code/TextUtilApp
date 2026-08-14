# Tests/lib.test.textutil.sh - TextUtil's own test vocabulary, for omctest.
#
# Sourced after omctest.sh by every Tests/*.test.sh file. Holds what the harness
# has no business knowing: how this applet's table is shaped, which pasteboard
# key its Open... handoff uses, and how to call into lib.textutil.sh directly.

# omc_control_defaults arrived in API 2. Without it a test would start from a
# blank window - every toggle unset - which is not a window any user can reach.
if [ "${OMCTEST_API_VERSION:-0}" -lt 2 ]; then
    printf 'lib.test.textutil: needs omctest API 2 or newer, found %s\n' \
        "${OMCTEST_API_VERSION:-none}" >&2
    exit 1
fi

APP_SCRIPTS="$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts"
APP_LIB="$APP_SCRIPTS/lib.textutil.sh"

# ---------------------------------------------------------------------------
# View ids, imported from the applet rather than restated
# ---------------------------------------------------------------------------

eval "$(/usr/bin/sed -n 's/^\([A-Z][A-Z0-9_]*_ID\)=\([0-9][0-9]*\)$/\1=\2/p' "$APP_LIB")"

# Without this guard a renamed constant expands to the empty string, omc_control
# writes OMC_ACTIONUI_VIEW__VALUE, and the file fails check by check with no hint
# why. With it, it fails once and names what went missing.
for _required in TABLE_ID FILE_INFO_VIEW_ID REMOVE_BUTTON_ID REVEAL_BUTTON_ID \
                 QUICKLOOK_BUTTON_ID FORMAT_PICKER_ID; do
    eval "_value=\${$_required}"
    if [ -z "$_value" ]; then
        printf 'lib.test.textutil: %s did not import from lib.textutil.sh\n' "$_required" >&2
        exit 1
    fi
done
unset _required _value

# The toggles have no named constants in the applet, which is itself worth
# knowing: these two numbers are the only place the suite restates an id, so
# they get an assertion of their own in 10-window.
OVERWRITE_TOGGLE_ID=14
STRIP_TOGGLE_ID=15

# The hidden path column. The applet names it only inside variable names it
# builds by hand, so there is no constant to import - which makes it exactly the
# kind of number that drifts. Pin it, and check the applet still agrees.
TABLE_PATH_COLUMN=2

app_uses_path_column() { # -> yes | no
    if /usr/bin/grep -q "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS" \
        "$APP_LIB"; then
        echo yes
    else
        echo no
    fi
}

# ---------------------------------------------------------------------------
# Calling into the applet's library
# ---------------------------------------------------------------------------

textutil_call() { # <function> [argument ...]
    ( . "$APP_LIB" >/dev/null 2>&1
      "$@" )
}

# ---------------------------------------------------------------------------
# The document list: table 10, and the env var the engine derives from it
# ---------------------------------------------------------------------------

file_list() { ui_rows "$TABLE_ID" | /usr/bin/cut -f "$TABLE_PATH_COLUMN"; }
file_list_names() { ui_rows "$TABLE_ID" | /usr/bin/cut -f 1; }
file_count() { ui_row_count "$TABLE_ID"; }

info_text() { ui_value "$FILE_INFO_VIEW_ID"; }

# Export the document list the way the engine would, from whatever the table now
# holds. The harness records what a handler wrote to the table but does not feed
# it back on the next dispatch, and every handler here that acts on more than the
# selected row reads the list through that variable - so without this bridge they
# would all see an empty list and pass for the wrong reason.
sync_file_list() {
    local rows
    rows=$(file_list)
    omctest_setvar "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS" "$rows"
}

run_with_list() { # <script-stem>
    sync_file_list
    omc_run "$1"
}

select_file() { omc_table_cell "$TABLE_ID" "$TABLE_PATH_COLUMN" "$1"; }
clear_selection() { omc_table_cell "$TABLE_ID" "$TABLE_PATH_COLUMN" ""; }

# ---------------------------------------------------------------------------
# The Open... handoff
# ---------------------------------------------------------------------------

# Global rather than per-window - it has to be, since the window it feeds does
# not exist yet - so a value left behind by one section silently seeds the next
# one's window. Cleared in reset_window.
pb_open_paths() { "$OMC_OMC_SUPPORT_PATH/pasteboard" TEXTUTIL_OPEN_PATHS "$@"; }

# ---------------------------------------------------------------------------
# Resetting between sections
# ---------------------------------------------------------------------------

reset_window() {
    omc_control_defaults TextUtil
    pb_open_paths set "" >/dev/null 2>&1
    omc_object ""
    # ui_reset deletes unknown_ids.log, so a single check at the end of a file
    # would only ever see the last section and would read as a standing
    # guarantee while being inert. Check here, so every section is covered by
    # the reset that follows it.
    check "no writes to undeclared view ids in the section just ended" "" "$(ui_unknown_writes)"
    check "no bare value write clobbered the table's rows" "" "$(ui_suspect_writes)"
    check "the harness detected no misuse" "" "$(ui_errors)"
    ui_reset
    alerts_reset
    alert_answers_reset
    # Chain history is cumulative across the file, so a section asserting a
    # chain did NOT happen would inherit an earlier section's legitimate one.
    chains_reset
    unset "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

contains() { # <haystack> <needle> -> yes | no
    # A function rather than an inline `case`: a case pattern's ")" terminates a
    # $( ) command substitution in bash 3.2, so the obvious one-liner is a parse
    # error rather than a wrong answer.
    case "$1" in
        *"$2"*) echo yes ;;
        *) echo no ;;
    esac
}

# What textutil says a document is. The assertion that a conversion really
# happened, rather than that a file with the right name exists.
#
# textutil -info prints an indented "Type:" line, e.g. "rich text format (RTF)".
document_format() { # <path> -> the format textutil reports, or "missing"
    [ -e "$1" ] || { printf 'missing'; return; }
    /usr/bin/textutil -info "$1" 2>/dev/null \
        | /usr/bin/awk -F': *' '/^ *Type:/ { print $2; exit }'
}

# How many lines of a file match a pattern, as exactly one number.
#
# The obvious `grep -c ... || echo 0` is a trap: grep -c PRINTS 0 and EXITS 1
# when nothing matches, so the fallback fires too and the caller gets two lines.
# A check comparing against "0" then fails with a baffling multi-line actual.
count_matches() { # <pattern> <path> -> a count
    [ -f "$2" ] || { printf '0'; return; }
    /usr/bin/grep -c "$1" "$2" 2>/dev/null || true
}

# Tests/fixtures is gitignored and generated by Tests/make-fixtures.sh.
ensure_fixtures() {
    local marker="$OMCTEST_FIXTURES/notes.txt"
    [ -f "$marker" ] && return 0
    if [ ! -f "$OMCTEST_TESTS/make-fixtures.sh" ]; then
        printf 'lib.test.textutil: no fixtures and no Tests/make-fixtures.sh to build them\n' >&2
        return 1
    fi
    if ! /bin/sh "$OMCTEST_TESTS/make-fixtures.sh" "$OMCTEST_FIXTURES" >/dev/null 2>&1; then
        /bin/chmod -R u+w "$OMCTEST_FIXTURES" 2>/dev/null
        /bin/rm -rf "$OMCTEST_FIXTURES"
        printf 'lib.test.textutil: fixture generation failed\n' >&2
        return 1
    fi
    return 0
}

check_preconditions() {
    check_exists "precondition: textutil is present" /usr/bin/textutil
    check "precondition: the fixtures are present" "yes" \
        "$(ensure_fixtures && echo yes || echo no)"
    check "precondition: the applet still reads the path from column $TABLE_PATH_COLUMN" \
        "yes" "$(app_uses_path_column)"
}
