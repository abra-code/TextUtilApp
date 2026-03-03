#!/bin/bash
# textutil.startBatch.sh - Run batch conversion using textutil

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.textutil.sh"

echo "[DEBUG textutil.start.batch]"

# Get destination folder from CHOOSE_FOLDER_DIALOG
destination="$OMC_DLG_CHOOSE_FOLDER_PATH"
echo "[DEBUG] destination = $destination"

if [ -z "$destination" ]; then
    echo "[DEBUG] No destination selected"
    exit 0
fi

# Get output format from Picker id 13
output_format="$OMC_ACTIONUI_VIEW_13_VALUE"
echo "[DEBUG] output_format = $output_format"

if [ -z "$output_format" ]; then
    output_format="txt"
fi

# Get all file paths from the table (column 2)
file_paths="$OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS"
echo "[DEBUG] file_paths = $file_paths"

if [ -z "$file_paths" ]; then
    echo "[DEBUG] No files to convert"
    exit 0
fi

# Convert newline-separated paths to array
IFS=$'\n' read -r -d '' -a files <<< "$file_paths" || true

echo "[DEBUG] Number of files: ${#files[@]}"

# Get options
overwrite="$OMC_ACTIONUI_VIEW_14_VALUE"
strip="$OMC_ACTIONUI_VIEW_15_VALUE"

echo "[DEBUG] overwrite = $overwrite, strip = $strip"

# Build strip flag
strip_flag=""
if [ "$strip" = "true" ]; then
    strip_flag="-strip"
fi

# Collect errors and results
errors=""
results=""
skipped=""

# Process each file
success_count=0
error_count=0
skipped_count=0

for file_path in "${files[@]}"; do
    echo "[DEBUG] Processing: $file_path"
    if [ -e "$file_path" ]; then
        filename="$("/usr/bin/basename" "$file_path")"
        name_without_ext="${filename%.*}"
        
        output_file="$destination/${name_without_ext}.${output_format}"
        
        # Check if output exists - skip if overwrite is not enabled
        if [ -e "$output_file" ] && [ "$overwrite" != "true" ]; then
            ((skipped_count++))
            skipped="${skipped}
- ${name_without_ext}.${output_format}: skipped"
        else
            # Run textutil conversion and capture output
            output="$(/usr/bin/textutil -convert "$output_format" $strip_flag -output "$output_file" "$file_path" 2>&1)"
            exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                ((success_count++))
                results="${results}
✓ ${name_without_ext}.${output_format}"
            else
                ((error_count++))
                errors="${errors}
✗ ${name_without_ext}.${output_format}: ${output}"
            fi
        fi
    else
        echo "[DEBUG] File does not exist: $file_path"
        ((error_count++))
        errors="${errors}
✗ ${file_path}: file does not exist"
    fi
done

# Build completion message
result_message="Destination Folder:
${destination}

Converted: ${success_count} succeeded, ${skipped_count} skipped, ${error_count} failed${results}${skipped}${errors}"

echo "[DEBUG] Result: $result_message"
echo "[DEBUG] Setting text view ${FILE_INFO_VIEW_ID}"

"$dialog_tool" "$window_uuid" ${FILE_INFO_VIEW_ID} "$result_message"

echo "[DEBUG] Done"
