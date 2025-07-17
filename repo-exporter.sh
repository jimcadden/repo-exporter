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

# Find and append files with the specified extension 
find "$SOURCE_DIR" -type f -name "*$FILE_EXTENSION" | while read -r FILE; do 

    echo "Processing $FILE..." 

    # Append file path as header 
    echo -e "// FILE: === $FILE ===\n" >> "$OUTPUT_FILE" 

    # Append file content 
    cat "$FILE" >> "$OUTPUT_FILE" 
done 

echo "All files have been appended to $OUTPUT_FILE." 

 

 

 