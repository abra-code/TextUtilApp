#!/bin/sh
# Tests/20-filelist.test.sh - building the document list, and what a selection
# does.
#
# The list is the applet's only model - the batch reads from it and nothing else
# - so the handlers that add to it and take away from it are worth pinning.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.textutil.sh"

section "preconditions"
check_preconditions

# --------------------------------------------------------------------------
section "the add panel puts chosen documents in the list"
# --------------------------------------------------------------------------
reset_window
omc_run textutil.init

omc_dialog_answer choose_object "$(fixture notes.txt)
$(fixture memo.rtf)"
run_with_list textutil.add.files
check_status "the add handler succeeded" 0

check "both documents were added" "2" "$(file_count)"
check "sorted by display name" "memo.rtf
notes.txt" "$(file_list_names)"
check "and it refreshed the row buttons afterwards" "1" \
    "$(chain_asked textutil.files.selection.changed)"

# --------------------------------------------------------------------------
section "adding more keeps what was already there"
# --------------------------------------------------------------------------
# add_files_to_table rebuilds the whole table from the engine's ALL_ROWS export
# plus the new paths, so "preserves the existing rows" is a real behavior with a
# real way to break: run_with_list is what supplies that export.
omc_dialog_answer choose_object "$(fixture page.html)"
run_with_list textutil.add.files
check "the list grew rather than being replaced" "3" "$(file_count)"
check "the earlier documents are still there" "yes" \
    "$(contains "$(file_list_names)" "notes.txt")"

# --------------------------------------------------------------------------
section "the same document added twice appears once"
# --------------------------------------------------------------------------
omc_dialog_answer choose_object "$(fixture page.html)"
run_with_list textutil.add.files
check "the duplicate collapsed" "3" "$(file_count)"

# --------------------------------------------------------------------------
section "a folder is scanned for the document types textutil reads"
# --------------------------------------------------------------------------
reset_window
omc_run textutil.init

folder="$OMCTEST_WORK/papers"
/bin/mkdir -p "$folder/nested"
/bin/cp "$(fixture notes.txt)" "$folder/one.txt"
/bin/cp "$(fixture page.html)" "$folder/nested/two.html"
/bin/cp "$(fixture blob.bin)" "$folder/three.bin"
/bin/chmod -R u+w "$folder"

omc_dialog_answer choose_object "$folder"
run_with_list textutil.add.files
check "documents were found, including in subfolders" "2" "$(file_count)"
check "and a type textutil cannot read was left out" "no" \
    "$(contains "$(file_list_names)" "three.bin")"

# --------------------------------------------------------------------------
section "an .rtfd bundle is treated as one document, not as a folder"
# --------------------------------------------------------------------------
# .rtfd is a directory on disk. Scanning into it would list its internal parts
# as separate documents, which is the bug the applet's dedicated rtfd pass
# exists to avoid.
reset_window
omc_run textutil.init

bundle="$OMCTEST_WORK/rich.rtfd"
/bin/mkdir -p "$bundle"
/bin/cp "$(fixture memo.rtf)" "$bundle/TXT.rtf"
/bin/chmod -R u+w "$bundle"

omc_dialog_answer choose_object "$OMCTEST_WORK"
run_with_list textutil.add.files
check "the bundle is listed" "yes" "$(contains "$(file_list_names)" "rich.rtfd")"
check "and its innards are not" "no" "$(contains "$(file_list_names)" "TXT.rtf")"

# --------------------------------------------------------------------------
section "dropping documents on the table adds them"
# --------------------------------------------------------------------------
reset_window
omc_run textutil.init

omc_drop "$(fixture notes.txt)" "$(fixture memo.rtf)"
run_with_list textutil.files.drop
check_status "the drop handler succeeded" 0
check "both dropped documents landed" "2" "$(file_count)"
check "and the row buttons were refreshed" "1" \
    "$(chain_asked textutil.files.selection.changed)"

# --------------------------------------------------------------------------
section "a drop with no payload changes nothing"
# --------------------------------------------------------------------------
chains_reset
omc_trigger "$TABLE_ID"
run_with_list textutil.files.drop
check_status "the handler exited cleanly" 0
check "the list is untouched" "2" "$(file_count)"
check "and nothing was refreshed" "0" "$(chain_asked textutil.files.selection.changed)"

# --------------------------------------------------------------------------
section "selecting a row lights up its buttons and describes it"
# --------------------------------------------------------------------------
reset_window
omc_run textutil.init
select_file "$(fixture memo.rtf)"
omc_run textutil.files.selection.changed
check_status "the selection handler succeeded" 0

check "remove is live"     "1" "$(ui_enabled "$REMOVE_BUTTON_ID")"
check "reveal is live"     "1" "$(ui_enabled "$REVEAL_BUTTON_ID")"
check "quick look is live" "1" "$(ui_enabled "$QUICKLOOK_BUTTON_ID")"
# The description comes from textutil itself, so this proves the applet asked
# the right tool about the right file rather than only that it wrote something.
check "the info pane names the file"    "yes" "$(contains "$(info_text)" "memo.rtf")"
check "and reports what textutil sees"  "yes" "$(contains "$(info_text)" "rtf")"
check "with the dates the applet adds"  "yes" "$(contains "$(info_text)" "Modified:")"

# --------------------------------------------------------------------------
section "losing the selection puts them back to sleep"
# --------------------------------------------------------------------------
clear_selection
omc_run textutil.files.selection.changed
check "remove is dead"     "0" "$(ui_enabled "$REMOVE_BUTTON_ID")"
check "reveal is dead"     "0" "$(ui_enabled "$REVEAL_BUTTON_ID")"
check "quick look is dead" "0" "$(ui_enabled "$QUICKLOOK_BUTTON_ID")"
check "and the info pane was cleared" "" "$(info_text)"

# --------------------------------------------------------------------------
section "remove takes out the selected row and leaves the rest"
# --------------------------------------------------------------------------
reset_window
omc_run textutil.init
omc_dialog_answer choose_object "$(fixture notes.txt)
$(fixture memo.rtf)
$(fixture page.html)"
run_with_list textutil.add.files
check "three documents to start with" "3" "$(file_count)"

select_file "$(fixture memo.rtf)"
run_with_list textutil.remove.selected
check_status "the remove handler succeeded" 0
check "one row went"                "2" "$(file_count)"
check "and it was the selected one" "no" "$(contains "$(file_list_names)" "memo.rtf")"
check "the others stayed"           "yes" "$(contains "$(file_list_names)" "notes.txt")"

# --------------------------------------------------------------------------
section "remove with nothing selected removes nothing"
# --------------------------------------------------------------------------
clear_selection
run_with_list textutil.remove.selected
check "the list is unchanged" "2" "$(file_count)"

# --------------------------------------------------------------------------
section "clear all empties the list"
# --------------------------------------------------------------------------
run_with_list textutil.clear.all
check_status "the clear handler succeeded" 0
check "the list is empty" "0" "$(file_count)"
check "the table was actively emptied" "yes" \
    "$([ "$(ui_calls "omc_table_remove_all_rows")" -ge 1 ] && echo yes || echo no)"

# --------------------------------------------------------------------------
section "cumulative: the last section's window writes were all declared"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
