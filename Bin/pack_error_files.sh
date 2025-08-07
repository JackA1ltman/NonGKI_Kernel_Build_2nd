#!/usr/bin/env bash

LOG_FILE="error.log"
OUTPUT_ZIP_FILE="compile_errors_files.zip"
TEMP_DIR="temp_error_files_$(date +%Y%m%d%H%M%S)"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file '$LOG_FILE' not existed." >&2
    exit 1
fi

echo "Extracting filenames from '$LOG_FILE' that contain errors..."

ERROR_FILES_LIST=$(grep -E '^(../)?([a-zA-Z0-9_/.-]+):[0-9]+:[0-9]+: error:' "$LOG_FILE" | \
                   awk -F ':' '{ print $1 }' | \
                   sort -u)

if [ -z "$ERROR_FILES_LIST" ]; then
    echo "No obvious compilation error files found in '$LOG_FILE'."
    exit 0
fi

echo "--------------------------------------------------------"
echo "The following file contains compilation errors:"
echo "--------------------------------------------------------"
for file in $ERROR_FILES_LIST; do
    echo "- $file"
done
echo "--------------------------------------------------------"

echo "Preparing to package the error file..."

if ! command -v zip &> /dev/null; then
    echo "Error: 'zip' command not found. Please install zip (e.g. sudo apt install zip)." >&2
    exit 1
fi

mkdir -p "$TEMP_DIR"

for file_path in $ERROR_FILES_LIST; do
    cleaned_path="${file_path#../}"

    dir_name=$(dirname "$cleaned_path")

    mkdir -p "$TEMP_DIR/$dir_name"

    if [ -f "$file_path" ]; then
        cp -L "$file_path" "$TEMP_DIR/$cleaned_path"
        if [ $? -eq 0 ]; then
            echo "Copying '$file_path' to '$TEMP_DIR/$cleaned_path'"
        else
            echo "Warning: Could not copy '$file_path'. Possible file does not exist or permissions issue." >&2
        fi
    else
        echo "Warning: The file '$file_path' referenced in the error log does not actually exist. Skip copying." >&2
    fi
done

echo "The error file is being packaged into the '$OUTPUT_ZIP_FILE'..."
zip -r "$OUTPUT_ZIP_FILE" "$TEMP_DIR"
if [ $? -eq 0 ]; then
    echo "Successfully packaged the error file into the '$OUTPUT_ZIP_FILE'"
else
    echo "Error: Packing Failure." >&2
fi

echo "Temporary directory being cleaned up '$TEMP_DIR'..."
rm -rf "$TEMP_DIR"
echo "Clearance completed."

exit 0
