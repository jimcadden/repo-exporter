#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source-directory> <extension> <output-file>"
    exit 1
fi

SOURCE_DIR="$1"
FILE_EXTENSION="$2"
OUTPUT_FILE="$3"

# Remove existing output file if it exists
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Extract the language identifier from the file extension (e.g., ".js" -> "js")
LANG=$(echo "$FILE_EXTENSION" | sed 's/^\.//')

# Find and append files with the specified extension
find "$SOURCE_DIR" -type f -name "*$FILE_EXTENSION" -not -path "*/.git/*" -not -path "*/node_modules/*" | while read -r FILE; do

    echo "Processing $FILE..."

    # Append file path as a markdown header
    echo -e "# File: $FILE\n" >> "$OUTPUT_FILE"

    # Append file content within a markdown fenced code block
    echo -e "\`\`\`$LANG" >> "$OUTPUT_FILE"
    cat "$FILE" >> "$OUTPUT_FILE"
    echo -e "\n\`\`\`\n" >> "$OUTPUT_FILE"
done

echo "All files have been appended to $OUTPUT_FILE."