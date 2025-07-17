# repo-exporter

A shell script to consolidate a source code repository into a single, well-structured Markdown file. This is useful for passing the entire context of a project to a Large Language Model (LLM), for code reviews, or for creating a comprehensive project archive.

The script can process a local directory or clone a remote Git repository. It intelligently excludes common unnecessary files and directories, and can be customized to include specific file types or add more exclusions.

## Usage

```bash
./repo-exporter.sh <path_or_url> [OPTIONS]
```

### Arguments

-   `<path_or_url>`: **Required**. The path to a local source code directory or the URL of a remote Git repository.

### Options

-   `-o <output_file>`: Optional. The name of the output Markdown file.
    -   **Default**: `export.md`
-   `-e <extensions>`: Optional. A comma-separated list of file extensions to include in the export.
    -   **Default**: A comprehensive list of common programming and configuration file extensions.
-   `-x <exclude_patterns>`: Optional. A comma-separated list of patterns to exclude from the export. These are added to the default exclusion list.
    -   **Default exclusions**: `*/.git/*`, `*/node_modules/*`, `*/dist/*`, `*/build/*`, `*/.vscode/*`, `*/.idea/*`, `*.log`, `*.lock`
-   `-h`, `--help`: Show the help message and exit.

## Examples

### 1. Export a Local Directory

This will scan the `~/projects/my-cool-app` directory and create a file named `export.md` in your current directory.

```bash
./repo-exporter.sh ~/projects/my-cool-app
```

### 2. Export a Local Directory to a Specific File

This will scan the `~/projects/my-cool-app` directory and create a file named `my-cool-app-export.md`.

```bash
./repo-exporter.sh ~/projects/my-cool-app -o my-cool-app-export.md
```

### 3. Clone and Export a Remote Repository

The script will clone the specified repository into a temporary directory, export its contents to `export.md`, and then ask if you want to delete the temporary directory.

```bash
./repo-exporter.sh https://github.com/user/repo.git
```

### 4. Export Only Python and Markdown Files

This example overrides the default list of extensions to only include `.py` and `.md` files.

```bash
./repo-exporter.sh ~/projects/my-python-project -e py,md
```

### 5. Add a Custom Exclusion Pattern

In addition to the default exclusions, this will also ignore any `backups` directory.

```bash
./repo-exporter.sh ~/projects/my-cool-app -x "*/backups/*"
