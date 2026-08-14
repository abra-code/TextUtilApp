#!/bin/sh
# Tests/30-batch.test.sh - the Convert run, end to end against the real textutil.
#
# Real documents in, real documents out, with the results read back through
# textutil itself. Naming a file correctly is not the same as converting it, and
# only reading the output back can tell the two apart.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.textutil.sh"

section "preconditions"
check_preconditions

notes="$(fixture_copy notes.txt)"
memo="$(fixture_copy memo.rtf)"
page="$(fixture_copy page.html)"

# Convert into a fresh empty folder each time, so "the file is there" cannot be
# satisfied by something an earlier section left behind.
new_destination() { # -> path
    local dir
    dir="$(/usr/bin/mktemp -d "$OMCTEST_WORK/dest.XXXXXX")"
    printf '%s' "$dir"
}

load_documents() { # <path ...>
    reset_window
    omc_run textutil.init
    omc_dialog_answer choose_object "$(printf '%s\n' "$@")"
    run_with_list textutil.add.files
}

# --------------------------------------------------------------------------
section "pressing Convert with an empty list says so"
# --------------------------------------------------------------------------
# The window now opens empty, so Convert is reachable with nothing to convert.
# It used to exit silently, which returned the user from the destination panel
# to a screen where nothing had changed.
reset_window
omc_run textutil.init
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check_status "the handler succeeded" 0
check "the info pane explains the empty list" "yes" \
    "$(contains "$(info_text)" "Nothing to convert")"
check "and nothing was written to the destination" "0" \
    "$(/usr/bin/find "$destination" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

# --------------------------------------------------------------------------
section "converting to rtf really produces rtf"
# --------------------------------------------------------------------------
load_documents "$notes"
omc_control "$FORMAT_PICKER_ID" rtf
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check_status "the batch succeeded" 0

check "the output is named for the chosen format" "yes" \
    "$([ -f "$destination/notes.rtf" ] && echo yes || echo no)"
check "and textutil agrees it is rtf" "yes" \
    "$(contains "$(document_format "$destination/notes.rtf")" "RTF")"
check "the format reader works at all" "no" \
    "$(contains "$(document_format "$destination/notes.rtf")" "missing")"
check "the content came through" "1" \
    "$(count_matches 'MARKER-TXT' "$destination/notes.rtf")"
check "the info pane reports the success" "yes" "$(contains "$(info_text)" "1 succeeded")"
check "and no failures" "yes" "$(contains "$(info_text)" "0 failed")"

# --------------------------------------------------------------------------
section "a mixed batch converts every input format"
# --------------------------------------------------------------------------
load_documents "$notes" "$memo" "$page"
omc_control "$FORMAT_PICKER_ID" txt
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check_status "the batch succeeded" 0

check "all three were written" "3" \
    "$(/usr/bin/find "$destination" -type f -name '*.txt' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
check "the rtf's text came through"  "1" \
    "$(count_matches 'MARKER-RTF' "$destination/memo.txt")"
check "the html's text came through" "1" \
    "$(count_matches 'MARKER-HTML' "$destination/page.txt")"
# Converting html to text has to strip the markup, not carry it across.
check "and the html markup did not" "0" \
    "$(count_matches '<h1>' "$destination/page.txt")"
check "the info pane reports three successes" "yes" "$(contains "$(info_text)" "3 succeeded")"

# --------------------------------------------------------------------------
section "an existing file is kept unless overwrite is on"
# --------------------------------------------------------------------------
load_documents "$notes"
omc_control "$FORMAT_PICKER_ID" txt
destination="$(new_destination)"
printf 'PREVIOUS CONTENT\n' > "$destination/notes.txt"

omc_control "$OVERWRITE_TOGGLE_ID" false
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check "the existing file was left alone" "PREVIOUS CONTENT" \
    "$(cat "$destination/notes.txt")"
check "and the run says it skipped one" "yes" "$(contains "$(info_text)" "1 skipped")"

omc_control "$OVERWRITE_TOGGLE_ID" true
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check "with overwrite on it was replaced" "1" \
    "$(count_matches 'MARKER-TXT' "$destination/notes.txt")"
check "and counted as a success" "yes" "$(contains "$(info_text)" "1 succeeded")"

# --------------------------------------------------------------------------
section "an unpromising input does not derail the rest of the batch"
# --------------------------------------------------------------------------
# blob.bin is binary. The applet lists it - it filters on extension and .bin is
# simply not in its skip list - and hands it to textutil like anything else.
#
# What this section does NOT claim is that the applet notices. textutil exits 0
# for content it cannot make sense of, and prints its complaint on stderr; the
# applet counts successes and failures by exit code, so a bad document is
# counted as converted. That is worth knowing and worth writing down, but it is
# a property of textutil, not a defect this suite can assert away. The claim
# here is the one that matters to a user: one bad document does not cost them
# the rest of the run.
blob="$(fixture_copy blob.bin)"
load_documents "$blob" "$notes"
omc_control "$FORMAT_PICKER_ID" txt
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check_status "the batch still finished" 0

check "the good document was converted anyway" "1" \
    "$(count_matches 'MARKER-TXT' "$destination/notes.txt")"
check "and the run accounted for both files" "yes" \
    "$(contains "$(info_text)" "2 succeeded")"

# --------------------------------------------------------------------------
section "a listed document that has gone missing is reported"
# --------------------------------------------------------------------------
vanishing="$OMCTEST_WORK/vanishing.txt"
/bin/cp "$notes" "$vanishing"
/bin/chmod u+w "$vanishing"
load_documents "$vanishing" "$memo"
omc_control "$FORMAT_PICKER_ID" txt
/bin/rm -f "$vanishing"

destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list textutil.start.batch
check_status "the batch still finished" 0
check "the surviving document was converted" "1" \
    "$(count_matches 'MARKER-RTF' "$destination/memo.txt")"
check "the missing one is counted as a failure" "yes" "$(contains "$(info_text)" "1 failed")"
check "and named in the report" "yes" "$(contains "$(info_text)" "vanishing")"

# --------------------------------------------------------------------------
section "canceling the destination panel converts nothing"
# --------------------------------------------------------------------------
load_documents "$notes"
before="$(info_text)"
omc_dialog_answer choose_folder ""
run_with_list textutil.start.batch
check_status "the handler exited cleanly" 0
check "the info pane was not touched" "$before" "$(info_text)"

# --------------------------------------------------------------------------
section "cumulative: the last section's window writes were all declared"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
