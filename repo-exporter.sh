#!/bin/bash

# Default values
# --- Configuration ---
OUTPUT_FILE="export.md"
EXTENSIONS=""
EXCLUDE_PATTERNS="*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/.vscode/*,*/.idea/*,*.log,*.lock,*/.aider*"
CLONED_REPO=false

# --- Functions ---
function usage {
    echo "Usage: $0 <path_or_url> [-e <extensions>] [-o <output_file>] [-x <exclude_patterns>] [-h|--help]"
    echo "  <path_or_url>       : Required. Local directory path or remote Git repository URL."
    echo "                        For remote repositories, you can specify a tag/commit by appending @tag_or_commit"
    echo "                        Example: https://github.com/user/repo.git@v1.0.0 or git@github.com:user/repo.git@abc123"
    echo "  -e <extensions>     : Comma-separated file extensions to include."
    echo "                      (default: a comprehensive list of common extensions)"
    echo "  -o <output_file>    : Output file name (default: export.md)."
    echo "  -x <exclude_patterns>: Comma-separated patterns to exclude."
    echo "                      (default: .git, node_modules, build directories, etc.)"
    echo "  -h, --help          : Show this help message and exit."
    exit ${1:-1}
}

# --- Argument Parsing ---
# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage 0
fi

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
    # Check if the URL contains a tag/commit specification
    REPO_URL="$SOURCE_INPUT"
    TAG_COMMIT=""
    
    # For HTTPS URLs: https://github.com/user/repo.git@tag
    if [[ "$SOURCE_INPUT" == http* && "$SOURCE_INPUT" == *"@"* ]]; then
        REPO_URL=${SOURCE_INPUT%@*}
        TAG_COMMIT=${SOURCE_INPUT##*@}
        echo "Repository URL: $REPO_URL"
        echo "Tag/Commit: $TAG_COMMIT"
    # For SSH URLs: git@github.com:user/repo.git@tag
    elif [[ "$SOURCE_INPUT" == git@* ]]; then
        # Count the number of @ symbols
        AT_COUNT=$(grep -o "@" <<< "$SOURCE_INPUT" | wc -l)
        if [[ $AT_COUNT -eq 2 ]]; then
            # Extract everything after the last @
            TAG_COMMIT=${SOURCE_INPUT##*@}
            # Remove the tag/commit part from the original URL
            REPO_URL=${SOURCE_INPUT%@$TAG_COMMIT}
            echo "Repository URL: $REPO_URL"
            echo "Tag/Commit: $TAG_COMMIT"
        fi
    fi
    
    # It's a URL, clone it
    TEMP_DIR=$(mktemp -d)
    echo "Cloning repository from $REPO_URL into $TEMP_DIR..."
    if git clone "$REPO_URL" "$TEMP_DIR"; then
        SOURCE_DIR="$TEMP_DIR"
        CLONED_REPO=true
        
        # If a tag/commit was specified, checkout that specific tag/commit
        if [[ -n "$TAG_COMMIT" ]]; then
            echo "Checking out tag/commit: $TAG_COMMIT..."
            if ! (cd "$TEMP_DIR" && git checkout "$TAG_COMMIT"); then
                echo "Error: Failed to checkout tag/commit: $TAG_COMMIT"
                exit 1
            fi
        fi
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

# Check if tree command is available
if command -v tree &> /dev/null; then
    # Create tree exclude patterns
    TREE_EXCLUDE=""
    for pattern in "${EXCLUDE_ARRAY[@]}"; do
        # Convert glob pattern to tree-compatible pattern
        # Remove asterisks and extract the core pattern
        clean_pattern=$(echo "$pattern" | sed 's/\*//g')
        if [[ -n "$clean_pattern" ]]; then
            TREE_EXCLUDE="$TREE_EXCLUDE -I '$(basename "$clean_pattern")'"
        fi
    done
    
    # Execute tree with exclusions
    eval "tree -L 3 $TREE_EXCLUDE \"$SOURCE_DIR\"" >> "$OUTPUT_FILE"
else
    echo "Directory listing (tree command not available):" >> "$OUTPUT_FILE"
    # Fallback to find + ls for directory structure with exclusions
    find_cmd="find \"$SOURCE_DIR\" -type d -maxdepth 3"
    
    # Add exclusion patterns to find command
    for pattern in "${EXCLUDE_ARRAY[@]}"; do
        # Convert glob pattern to find-compatible pattern
        find_pattern=$(echo "$pattern" | sed 's/\*/*/g')
        find_cmd="$find_cmd -not -path \"$find_pattern\""
    done
    
    eval "$find_cmd" | sort | while read -r dir; do
        level=$(echo "$dir" | sed "s|$SOURCE_DIR||" | tr -cd '/' | wc -c)
        indent=$(printf '%*s' "$level" '' | tr ' ' '  ')
        echo "$indent$(basename "$dir")/" >> "$OUTPUT_FILE"
    done
fi

echo '```' >> "$OUTPUT_FILE"
echo -e "\n" >> "$OUTPUT_FILE"

# --- 2. Process Files ---
# Create arrays for extensions and exclude patterns
IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATTERNS"

echo "DEBUG: Processing files with extensions: ${EXT_ARRAY[*]}"
echo "DEBUG: Excluding patterns: ${EXCLUDE_ARRAY[*]}"

# --- 3. Execute and Process Files ---
# Process files directly without complex find command construction
echo "DEBUG: Finding files in $SOURCE_DIR"

# Simple test to verify find works
echo "DEBUG: Testing basic find command..."
find "$SOURCE_DIR" -type f -name "*.sh" -print

# Process files directly
find "$SOURCE_DIR" -type f -not -type l | while read -r FILE; do
    # Skip files that don't match our extensions
    MATCHED=0
    for ext in "${EXT_ARRAY[@]}"; do
        if [[ "$FILE" == *.$ext ]]; then
            MATCHED=1
            break
        fi
    done
    
    # Skip if extension doesn't match
    if [ $MATCHED -eq 0 ]; then
        continue
    fi
    
    # Skip files that match exclude patterns
    for pattern in "${EXCLUDE_ARRAY[@]}"; do
        # Convert glob pattern to regex for bash matching
        regex_pattern=$(echo "$pattern" | sed 's/\*/[^\/]*/g')
        if [[ "$FILE" =~ $regex_pattern ]]; then
            echo "Skipping excluded file: $FILE"
            continue 2  # Skip to next file
        fi
    done
    
    echo "Processing $FILE..."
    
    # Validate filename - skip files with suspicious characters
    if [[ "$FILE" =~ [[:cntrl:]] ]]; then
        echo "Warning: Skipping file with control characters in name: $FILE"
        continue
    fi
    
    # Check if file exists and is readable
    if [ ! -f "$FILE" ] || [ ! -r "$FILE" ]; then
        echo "Warning: Cannot read file: $FILE"
        continue
    fi
    
    # More strict check for text files
    if ! file -b "$FILE" | grep -q -E "text|ASCII|UTF-8"; then
        echo "Skipping binary file: $FILE"
        continue
    fi
    
    # Only process text files
    echo "Processing text file: $FILE..."
    
    # Get language from extension
    LANG="${FILE##*.}"
    
    # Append file path as a markdown header
    echo -e "# File: $FILE\n" >> "$OUTPUT_FILE"
    
    # Append file content within a markdown fenced code block
    echo -e "\`\`\`$LANG" >> "$OUTPUT_FILE"
    # Output the entire file content
    cat "$FILE" >> "$OUTPUT_FILE"
    echo -e "\`\`\`\n" >> "$OUTPUT_FILE"
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