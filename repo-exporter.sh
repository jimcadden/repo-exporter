#!/bin/bash

# Default values
# --- Configuration ---
OUTPUT_FILE="repo_export.md"
EXTENSIONS="js,css,html,py,go,java,rb,php,ts,tsx,jsx,c,cpp,h,hpp,cs,swift,kt,kts,scala,pl,pm,sh,bash,zsh,ps1,rs,lua,sql,md,json,yml,yaml,xml,toml,ini,cfg,conf,properties,env,dockerfile,tf,hcl,groovy,gradle,jenkinsfile"
EXCLUDE_PATTERNS="*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/.vscode/*,*/.idea/*,*.log,*.lock"
CLONED_REPO=false

# --- Functions ---
function usage {
    echo "Usage: $0 <path_or_url> [-e <extensions>] [-o <output_file>] [-x <exclude_patterns>]"
    echo "  <path_or_url>       : Required. Local directory path or remote Git repository URL."
    echo "  -e <extensions>     : Comma-separated file extensions to include."
    echo "                      (default: a comprehensive list of common extensions)"
    echo "  -o <output_file>    : Output file name (default: repo_export.md)."
    echo "  -x <exclude_patterns>: Comma-separated patterns to exclude."
    echo "                      (default: .git, node_modules, build directories, etc.)"
    exit 1
}

# --- Argument Parsing ---
if [ $# -eq 0 ]; then
    echo "Error: Missing required argument <path_or_url>."
    usage
fi

SOURCE_INPUT="$1"
shift # Remove the first argument, so getopts can process the rest

while getopts "e:o:x:" opt; do
    case "${opt}" in
        e) EXTENSIONS=${OPTARG} ;;
        o) OUTPUT_FILE=${OPTARG} ;;
        x) EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS},${OPTARG}" ;;
        *) usage ;;
    esac
done

# --- Source Validation and Handling ---
SOURCE_DIR=""
if [[ "$SOURCE_INPUT" == http* || "$SOURCE_INPUT" == git@* ]]; then
    # It's a URL, clone it
    TEMP_DIR=$(mktemp -d)
    echo "Cloning repository from $SOURCE_INPUT into $TEMP_DIR..."
    if git clone "$SOURCE_INPUT" "$TEMP_DIR"; then
        SOURCE_DIR="$TEMP_DIR"
        CLONED_REPO=true
    else
        echo "Error: Failed to clone repository."
        exit 1
    fi
elif [ -d "$SOURCE_INPUT" ]; then
    # It's a local directory
    SOURCE_DIR=$(realpath "$SOURCE_INPUT")
else
    echo "Error: The specified local path '$SOURCE_INPUT' does not exist or is not a directory."
    exit 1
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

echo "✅ All files have been appended to $OUTPUT_FILE."

# --- Cleanup ---
if [ "$CLONED_REPO" = true ]; then
    read -p "Do you want to delete the cloned repository at '$SOURCE_DIR'? (y/N) " -n 1 -r
    echo # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting cloned repository..."
        rm -rf "$SOURCE_DIR"
        echo "Cleanup complete."
    else
        echo "Skipping deletion. The cloned repository is at '$SOURCE_DIR'."
    fi
fi