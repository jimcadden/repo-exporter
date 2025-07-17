#!/bin/bash

# Default values
SOURCE_DIR="."
OUTPUT_FILE="repo_export.md"
EXTENSIONS=""
EXCLUDE_PATTERNS="*/.git/*,*/node_modules/*" # Default excludes

function usage {
    echo "Usage: $0 -d <source-dir> -e <extensions> -o <output-file> [-x <exclude-patterns>]"
    echo "  -d: Source directory (default: .)"
    echo "  -e: Comma-separated file extensions (e.g., 'js,css,html')"
    echo "  -o: Output file (default: repo_export.md)"
    echo "  -x: Comma-separated exclude patterns (e.g., '*/dist/*,*.log')"
    exit 1
}

while getopts "d:e:o:x:" opt; do
    case "${opt}" in
        d) SOURCE_DIR=${OPTARG} ;;
        e) EXTENSIONS=${OPTARG} ;;
        o) OUTPUT_FILE=${OPTARG} ;;
        x) EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS},${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -z "$EXTENSIONS" ]; then
    echo "Error: File extensions must be provided with -e."
    usage
fi

# Start with a clean output file
> "$OUTPUT_FILE"

# --- 1. Add Directory Tree ---
echo "# Repository Structure" >> "$OUTPUT_FILE"
echo '```' >> "$OUTPUT_FILE"
tree -L 3 "$SOURCE_DIR" >> "$OUTPUT_FILE"
echo '```' >> "$OUTPUT_FILE"
echo -e "\n" >> "$OUTPUT_FILE"

# --- 2. Build Find Command ---
find_cmd="find \"$SOURCE_DIR\" -type f"

# Add extension patterns
IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
find_cmd+=" \( "
for i in "${!EXT_ARRAY[@]}"; do
    find_cmd+=" -name \"*.${EXT_ARRAY[$i]}\""
    if [ $i -lt $((${#EXT_ARRAY[@]} - 1)) ]; then
        find_cmd+=" -o"
    fi
done
find_cmd+=" \)"

# Add exclude patterns
IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATTERNS"
for pattern in "${EXCLUDE_ARRAY[@]}"; do
    find_cmd+=" -not -path \"$pattern\""
done

# --- 3. Execute and Process Files ---
eval "$find_cmd" | while read -r FILE; do
    echo "Processing $FILE..."

    # Get language from extension
    LANG="${FILE##*.}"

    # Append file path as a markdown header
    echo -e "# File: $FILE\n" >> "$OUTPUT_FILE"

    # Append file content within a markdown fenced code block
    echo -e "\`\`\`$LANG" >> "$OUTPUT_FILE"
    cat "$FILE" >> "$OUTPUT_FILE"
    echo -e "\n\`\`\`\n" >> "$OUTPUT_FILE"
done

echo "All files have been appended to $OUTPUT_FILE."