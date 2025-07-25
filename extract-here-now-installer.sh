#!/bin/bash

# Universal "Extract Here" Immediate Archive Extractor
# Automatically extracts archives to subdirectories without opening GUI applications
# Author: https://github.com/RedBearAK/
# Email:  64876997+RedBearAK@users.noreply.github.com

# Version (YYYYMMDD.patch format)
VERSION="20250724.2"

set -euo pipefail

# Configuration
SCRIPT_NAME="extract-here-now"
DESKTOP_FILE="extract-here-now.desktop"
SCRIPT_DIR="$HOME/.local/lib/extract-here-now"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
# SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
SYMLINK_PATH="$BIN_DIR/$SCRIPT_NAME"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to show error and exit
error_exit() {
    local message="$1"
    print_color "$RED" "ERROR: $message"
    
    # Try to show GUI error dialog
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --text="Archive Extractor Error: $message" 2>/dev/null || true
    else
        print_color "$YELLOW" "WARNING: zenity not available for GUI error dialog"
    fi
    exit 1
}

# Function to show info message
show_info() {
    local message="$1"
    print_color "$BLUE" "INFO: $message"
    
    if command -v zenity >/dev/null 2>&1; then
        zenity --info --text="$message" 2>/dev/null || true
    fi
}

# Function to detect if running in terminal context
is_terminal() {
    # Check multiple indicators for terminal context
    [ -t 0 ] || [ -t 1 ] || [ -t 2 ] || [ -n "${TERM:-}" ] || [ -n "${SSH_TTY:-}" ]
}

# Function to prompt for password
prompt_password() {
    local archive_name="$1"
    local password=""
    
    # Try GUI password prompt first
    if command -v zenity >/dev/null 2>&1; then
        password=$(zenity --password --title="Archive Password" --text="Enter password for: $archive_name" 2>/dev/null || echo "")
    elif is_terminal; then
        # Terminal input available
        echo -n "Enter password for '$archive_name': "
        read -s password
        echo
    else
        error_exit "Password required but no GUI dialog available and not running in terminal"
    fi
    
    if [ -z "$password" ]; then
        error_exit "Password required but none provided"
    fi
    
    echo "$password"
}

# Function to detect archive type
detect_archive_type() {
    local file="$1"
    local file_output
    local extension
    
    # Get file type using file command
    file_output=$(file -b --mime-type "$file" 2>/dev/null || echo "unknown")
    
    # Get file extension (lowercase)
    extension=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    
    # Detect based on MIME type and extension
    case "$file_output" in
        "application/zip"|"application/x-zip-compressed")
            echo "zip" ;;
        "application/x-tar")
            echo "tar" ;;
        "application/gzip"|"application/x-gzip")
            case "$extension" in
                "tar.gz"|"tgz") echo "tar.gz" ;;
                "gz") echo "gzip" ;;
                *) echo "gzip" ;;
            esac ;;
        "application/x-bzip2")
            case "$extension" in
                "tar.bz2"|"tbz2"|"tbz") echo "tar.bz2" ;;
                "bz2") echo "bzip2" ;;
                *) echo "bzip2" ;;
            esac ;;
        "application/x-xz")
            case "$extension" in
                "tar.xz"|"txz") echo "tar.xz" ;;
                "xz") echo "xz" ;;
                *) echo "xz" ;;
            esac ;;
        "application/x-rar"|"application/vnd.rar")
            echo "rar" ;;
        "application/x-7z-compressed")
            echo "7z" ;;
        *)
            # Fall back to extension-based detection
            case "$extension" in
                "zip"|"jar"|"war"|"ear") echo "zip" ;;
                "tar") echo "tar" ;;
                "tar.gz"|"tgz") echo "tar.gz" ;;
                "tar.bz2"|"tbz2"|"tbz") echo "tar.bz2" ;;
                "tar.xz"|"txz") echo "tar.xz" ;;
                "tar.lz"|"tar.lzma") echo "tar.lzma" ;;
                "gz") echo "gzip" ;;
                "bz2") echo "bzip2" ;;
                "xz") echo "xz" ;;
                "lz"|"lzma") echo "lzma" ;;
                "rar") echo "rar" ;;
                "7z") echo "7z" ;;
                *) echo "unknown" ;;
            esac ;;
    esac
}

# Function to get base name without extension
get_base_name() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
    # Remove various archive extensions
    case "$basename" in
        *.tar.gz|*.tar.bz2|*.tar.xz|*.tar.lz|*.tar.lzma)
            echo "${basename%%.tar.*}" ;;
        *.tgz|*.tbz|*.tbz2|*.txz)
            echo "${basename%%.*}" ;;
        *)
            echo "${basename%.*}" ;;
    esac
}

# Function to create unique directory name
create_unique_dir() {
    local base_dir="$1"
    local base_name="$2"
    local target_dir="$base_dir/$base_name"
    local counter=1
    
    while [ -e "$target_dir" ]; do
        target_dir="$base_dir/${base_name}_copy_$(printf "%02d" $counter)"
        counter=$((counter + 1))
    done
    
    echo "$target_dir"
}

# Function to check if archive has root directory
has_root_directory() {
    local file="$1"
    local archive_type="$2"
    local temp_list
    local first_level_items
    local unique_dirs
    
    case "$archive_type" in
        "zip")
            if command -v unzip >/dev/null 2>&1; then
                temp_list=$(unzip -l "$file" 2>/dev/null | tail -n +4 | head -n -2 | awk '{print $4}' | grep -v '^$' || echo "")
            else
                return 1
            fi ;;
        "tar"|"tar.gz"|"tar.bz2"|"tar.xz"|"tar.lzma")
            if command -v tar >/dev/null 2>&1; then
                temp_list=$(tar -tf "$file" 2>/dev/null || echo "")
            else
                return 1
            fi ;;
        "rar")
            if command -v unrar >/dev/null 2>&1; then
                temp_list=$(unrar lb "$file" 2>/dev/null || echo "")
            else
                return 1
            fi ;;
        "7z")
            if command -v 7z >/dev/null 2>&1; then
                temp_list=$(7z l -slt "$file" 2>/dev/null | grep "^Path = " | sed 's/^Path = //' | tail -n +2 || echo "")
            else
                return 1
            fi ;;
        *)
            return 1 ;;
    esac
    
    if [ -z "$temp_list" ]; then
        return 1
    fi
    
    # Get first-level items (no slashes or only trailing slash)
    first_level_items=$(echo "$temp_list" | grep -E '^[^/]+/?$' | sed 's|/$||' | sort -u)
    unique_dirs=$(echo "$first_level_items" | wc -l)
    
    # If there's exactly one first-level directory, check if it contains most files
    if [ "$unique_dirs" -eq 1 ]; then
        local root_candidate
        root_candidate=$(echo "$first_level_items" | head -n 1)
        local total_items
        local items_in_root
        total_items=$(echo "$temp_list" | wc -l)
        items_in_root=$(echo "$temp_list" | grep -c "^$root_candidate/" || echo 0)
        
        # If most items are in the root directory, it has a root directory
        if [ "$items_in_root" -gt $((total_items / 2)) ]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to extract archive
extract_archive() {
    local file="$1"
    local archive_type="$2"
    local target_dir="$3"
    local password="$4"
    
    print_color "$BLUE" "Extracting $archive_type archive to: $target_dir"
    
    case "$archive_type" in
        "zip")
            if command -v unzip >/dev/null 2>&1; then
                if [ -n "$password" ]; then
                    unzip -o -q -P "$password" "$file" -d "$target_dir"
                else
                    unzip -o -q "$file" -d "$target_dir"
                fi
            elif command -v 7z >/dev/null 2>&1; then
                if [ -n "$password" ]; then
                    7z x "$file" -o"$target_dir" -p"$password" -y -bb0 >/dev/null 2>&1
                else
                    7z x "$file" -o"$target_dir" -y -bb0 >/dev/null 2>&1
                fi
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "tar")
            if command -v tar >/dev/null 2>&1; then
                tar -xf "$file" -C "$target_dir" 2>/dev/null || error_exit "Failed to extract tar archive"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "tar.gz")
            if command -v tar >/dev/null 2>&1; then
                tar -xzf "$file" -C "$target_dir" 2>/dev/null || error_exit "Failed to extract tar.gz archive"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "tar.bz2")
            if command -v tar >/dev/null 2>&1; then
                tar -xjf "$file" -C "$target_dir" 2>/dev/null || error_exit "Failed to extract tar.bz2 archive"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "tar.xz")
            if command -v tar >/dev/null 2>&1; then
                tar -xJf "$file" -C "$target_dir" 2>/dev/null || error_exit "Failed to extract tar.xz archive"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "tar.lzma")
            if command -v tar >/dev/null 2>&1; then
                tar --lzma -xf "$file" -C "$target_dir" 2>/dev/null || error_exit "Failed to extract tar.lzma archive"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "gzip")
            local base_name
            base_name=$(basename "$file" .gz)
            if command -v gunzip >/dev/null 2>&1; then
                gunzip -c "$file" > "$target_dir/$base_name" 2>/dev/null || error_exit "Failed to extract gzip file"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "bzip2")
            local base_name
            base_name=$(basename "$file" .bz2)
            if command -v bunzip2 >/dev/null 2>&1; then
                bunzip2 -c "$file" > "$target_dir/$base_name" 2>/dev/null || error_exit "Failed to extract bzip2 file"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "xz")
            local base_name
            base_name=$(basename "$file" .xz)
            if command -v unxz >/dev/null 2>&1; then
                unxz -c "$file" > "$target_dir/$base_name" 2>/dev/null || error_exit "Failed to extract xz file"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "lzma")
            local base_name
            base_name=$(basename "$file" .lzma)
            if command -v unlzma >/dev/null 2>&1; then
                unlzma -c "$file" > "$target_dir/$base_name" 2>/dev/null || error_exit "Failed to extract lzma file"
            elif command -v lzip >/dev/null 2>&1; then
                lzip -dc "$file" > "$target_dir/$base_name" 2>/dev/null || error_exit "Failed to extract lzma file"
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "rar")
            if command -v unrar >/dev/null 2>&1; then
                if [ -n "$password" ]; then
                    unrar x -o+ -p"$password" "$file" "$target_dir/" >/dev/null 2>&1 || error_exit "Failed to extract RAR archive (wrong password?)"
                else
                    unrar x -o+ "$file" "$target_dir/" >/dev/null 2>&1 || error_exit "Failed to extract RAR archive"
                fi
            elif command -v 7z >/dev/null 2>&1; then
                if [ -n "$password" ]; then
                    7z x "$file" -o"$target_dir" -p"$password" -y -bb0 >/dev/null 2>&1 || error_exit "Failed to extract RAR archive (wrong password?)"
                else
                    7z x "$file" -o"$target_dir" -y -bb0 >/dev/null 2>&1 || error_exit "Failed to extract RAR archive"
                fi
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        "7z")
            if command -v 7z >/dev/null 2>&1; then
                if [ -n "$password" ]; then
                    7z x "$file" -o"$target_dir" -p"$password" -y -bb0 >/dev/null 2>&1 || error_exit "Failed to extract 7z archive (wrong password?)"
                else
                    7z x "$file" -o"$target_dir" -y -bb0 >/dev/null 2>&1 || error_exit "Failed to extract 7z archive"
                fi
            else
                try_gui_extractor "$file" "$target_dir"
            fi ;;
        *)
            error_exit "Unsupported archive type: $archive_type" ;;
    esac
}

# Function to try GUI archive managers with CLI options
try_gui_extractor() {
    local file="$1"
    local target_dir="$2"
    
    print_color "$YELLOW" "Trying GUI archive managers with CLI options..."
    
    # Try file-roller (GNOME) - force batch mode
    if command -v file-roller >/dev/null 2>&1; then
        print_color "$BLUE" "Using file-roller"
        if file-roller --extract-to="$target_dir" "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Try ark (KDE) - batch mode should not show GUI
    if command -v ark >/dev/null 2>&1; then
        print_color "$BLUE" "Using ark"
        if ark --batch --autosubfolder --destination "$target_dir" "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Try engrampa (MATE)
    if command -v engrampa >/dev/null 2>&1; then
        print_color "$BLUE" "Using engrampa"
        if engrampa --extract-to="$target_dir" "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Try xarchiver
    if command -v xarchiver >/dev/null 2>&1; then
        print_color "$BLUE" "Using xarchiver"
        if xarchiver --extract-to="$target_dir" "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Try atool as universal CLI fallback (handles many archive types)
    if command -v atool >/dev/null 2>&1; then
        print_color "$BLUE" "Using atool"
        if (cd "$target_dir" && atool --extract --explain "$file") >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # If we're running from GUI (no terminal), show error dialog
    if ! is_terminal; then
        error_exit "No suitable extraction tool found for this archive type"
    else
        error_exit "No suitable extraction tool found for this archive type"
    fi
}

# Function to check if password is needed
needs_password() {
    local file="$1"
    local archive_type="$2"
    
    case "$archive_type" in
        "zip")
            if command -v unzip >/dev/null 2>&1; then
                unzip -t "$file" >/dev/null 2>&1 || return 0
            fi ;;
        "rar")
            if command -v unrar >/dev/null 2>&1; then
                unrar t "$file" >/dev/null 2>&1 || return 0
            fi ;;
        "7z")
            if command -v 7z >/dev/null 2>&1; then
                7z t "$file" >/dev/null 2>&1 || return 0
            fi ;;
    esac
    return 1
}

# Function to check if this is an installer version
is_installer() {
    local script_name
    script_name=$(basename "$0")
    [[ "$script_name" == *"installer"* ]]
}

# Function to get the target script name (removing "installer" from name)
get_target_script_name() {
    local script_name
    script_name=$(basename "$0")
    # Remove various installer patterns
    script_name="${script_name//-installer/}"
    script_name="${script_name//_installer/}"
    script_name="${script_name//installer-/}"
    script_name="${script_name//installer_/}"
    script_name="${script_name//installer/}"
    
    # If we ended up with just .sh, use the default name
    if [ "$script_name" = ".sh" ] || [ "$script_name" = "" ]; then
        script_name="extract-here-now.sh"
    fi
    
    # Ensure it ends with .sh
    if [[ "$script_name" != *.sh ]]; then
        script_name="${script_name}.sh"
    fi
    
    echo "$script_name"
}

# Function to prompt for installation
prompt_install() {
    print_color "$BLUE" "Extract Here Now v$VERSION - Universal Archive Extractor"
    echo
    print_color "$YELLOW" "This appears to be an installer version of the script."
    echo
    print_color "$GREEN" "The installer will:"
    echo "  • Install the script to ~/.local/lib/extract-here-now/"
    echo "  • Create a command alias 'extract-here-now'"
    echo "  • Add a desktop application for 'Open with' menus"
    echo "  • Configure PATH if needed"
    echo
    
    if command -v zenity >/dev/null 2>&1; then
        if zenity --question --title="Install Extract Here Now?" --text="Install Extract Here Now universal archive extractor?\n\nThis will create the command 'extract-here-now' and add it to archive context menus." 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif is_terminal; then
        echo -n "Install Extract Here Now? [Y/n]: "
        read -r response
        case "$response" in
            [nN]|[nN][oO])
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    else
        # Running from GUI but no zenity - default to install
        print_color "$YELLOW" "No GUI dialog available, proceeding with installation..."
        return 0
    fi
}
ensure_local_bin_in_path() {
    local path_entry='export PATH="$HOME/.local/bin:$PATH"'
    local path_check='# Add ~/.local/bin to PATH if not already there'
    local shell_files=("$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile")
    local updated=false
    
    print_color "$BLUE" "Checking PATH configuration..."
    
    # Create ~/.profile if it doesn't exist (standard file that should be present)
    if [ ! -f "$HOME/.profile" ]; then
        print_color "$YELLOW" "Creating ~/.profile"
        cat > "$HOME/.profile" << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists. See /usr/share/doc/bash/examples/startup-files for examples.

# Set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
        updated=true
    fi
    
    for shell_file in "${shell_files[@]}"; do
        # Only check existing files (don't create shell-specific RC files)
        if [ -f "$shell_file" ]; then
            # Check if PATH entry already exists (look for various common patterns)
            if ! grep -qE '(HOME/\.local/bin|\$HOME/\.local/bin|~/.local/bin)' "$shell_file" 2>/dev/null; then
                print_color "$YELLOW" "Adding ~/.local/bin to PATH in ~/$(basename "$shell_file")"
                {
                    echo
                    echo "$path_check"
                    echo 'if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then'
                    echo "    $path_entry"
                    echo 'fi'
                } >> "$shell_file"
                updated=true
            else
                print_color "$GREEN" "PATH already configured in ~/$(basename "$shell_file")"
            fi
        fi
    done
    
    if [ "$updated" = true ]; then
        print_color "$YELLOW" "PATH updated. You may need to restart your shell or run 'source ~/.profile'"
    else
        print_color "$GREEN" "PATH already properly configured"
    fi
    
    # Note: We only check PATH during installation to avoid performance impact
    # during regular archive extraction operations. If users install new shells
    # later, they can re-run --install to update their RC files.
}

# Function to uninstall the script
uninstall_extractor() {
    print_color "$BLUE" "Uninstalling Extract Here Now..."
    
    local removed_something=false
    
    # Remove symlink
    if [ -L "$SYMLINK_PATH" ]; then
        rm "$SYMLINK_PATH"
        print_color "$GREEN" "Removed symlink: $SYMLINK_PATH"
        removed_something=true
    elif [ -e "$SYMLINK_PATH" ]; then
        print_color "$YELLOW" "Warning: $SYMLINK_PATH exists but is not a symlink"
    fi
    
    # Remove desktop file
    if [ -f "$DESKTOP_DIR/$DESKTOP_FILE" ]; then
        rm "$DESKTOP_DIR/$DESKTOP_FILE"
        print_color "$GREEN" "Removed desktop file: $DESKTOP_DIR/$DESKTOP_FILE"
        removed_something=true
        
        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
        fi
    fi
    
    if [ ! "$removed_something" = true ]; then
        print_color "$YELLOW" "No installed components found to remove"
    fi
    
    # Ask about removing the script directory
    if [ -d "$SCRIPT_DIR" ]; then
        echo
        print_color "$YELLOW" "Script directory still exists: $SCRIPT_DIR"
        
        if command -v zenity >/dev/null 2>&1; then
            if zenity --question --text="Do you want to delete the script files?\n\nDirectory: $SCRIPT_DIR" 2>/dev/null; then
                rm -rf "$SCRIPT_DIR"
                print_color "$GREEN" "Removed script directory: $SCRIPT_DIR"
            else
                print_color "$BLUE" "Script directory preserved"
            fi
        elif is_terminal; then
            echo -n "Do you want to delete the script files? [y/N]: "
            read -r response
            case "$response" in
                [yY]|[yY][eE][sS])
                    rm -rf "$SCRIPT_DIR"
                    print_color "$GREEN" "Removed script directory: $SCRIPT_DIR"
                    ;;
                *)
                    print_color "$BLUE" "Script directory preserved"
                    ;;
            esac
        else
            print_color "$BLUE" "Script directory preserved (no user input available)"
        fi
    fi
    
    print_color "$GREEN" "Uninstallation completed!"
}

# Function to install the script and desktop file
install_extractor() {
    local auto_install=${1:-false}
    
    if [ "$auto_install" = true ]; then
        print_color "$BLUE" "Installing Extract Here Now v$VERSION..."
    else
        print_color "$BLUE" "Installing Extract Here Now v$VERSION..."
    fi
    
    # Get the target script name (removes "installer" from name)
    local target_script_name
    target_script_name=$(get_target_script_name)
    local target_script_path="$SCRIPT_DIR/$target_script_name"
    
    # Remove existing installations first (idempotent)
    print_color "$BLUE" "Cleaning up any existing installation..."
    [ -L "$SYMLINK_PATH" ] && rm "$SYMLINK_PATH"
    [ -e "$SYMLINK_PATH" ] && rm "$SYMLINK_PATH"  # Remove even if not a symlink
    [ -f "$DESKTOP_DIR/$DESKTOP_FILE" ] && rm "$DESKTOP_DIR/$DESKTOP_FILE"
    [ -f "$target_script_path" ] && rm "$target_script_path"  # Remove old script
    
    # Wait a moment for filesystem consistency
    sleep 2
    
    # Create directories
    mkdir -p "$SCRIPT_DIR" "$BIN_DIR" "$DESKTOP_DIR"
    
    # Copy script to lib directory with correct name
    print_color "$BLUE" "Installing script as: $target_script_path"
    cp "$0" "$target_script_path"
    
    # Make script executable
    chmod +x "$target_script_path"
    
    # Create symlink pointing to the installed script
    print_color "$BLUE" "Creating command alias: $SYMLINK_PATH -> $target_script_path"
    ln -sf "$target_script_path" "$SYMLINK_PATH"
    
    # Create desktop file pointing to the installed script
    print_color "$BLUE" "Creating desktop file: $DESKTOP_DIR/$DESKTOP_FILE"
    cat > "$DESKTOP_DIR/$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Extract Here Now (Universal)
Comment=Extract archives automatically without opening GUI applications
Exec=$target_script_path %f
Icon=application-x-archive
Terminal=false
MimeType=application/zip;application/x-zip-compressed;application/x-tar;application/gzip;application/x-gzip;application/x-bzip2;application/x-xz;application/x-rar;application/vnd.rar;application/x-7z-compressed;application/x-compressed-tar;application/x-bzip-compressed-tar;application/x-xz-compressed-tar;application/x-lzip;application/x-lzma;
Categories=Utility;Archiving;
StartupNotify=false
NoDisplay=false
EOF
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
    
    # Ensure ~/.local/bin is in PATH
    ensure_local_bin_in_path
    
    print_color "$GREEN" "Installation completed successfully!"
    print_color "$BLUE" "Script installed to: $target_script_path"
    print_color "$BLUE" "Command available as: $SCRIPT_NAME"
    print_color "$BLUE" "Desktop file created: $DESKTOP_DIR/$DESKTOP_FILE"
    echo
    print_color "$YELLOW" "To make this the default handler for all archive types, run:"
    print_color "$YELLOW" "$SCRIPT_NAME --set-default"
    echo
    print_color "$BLUE" "You can now use 'extract-here-now /path/to/archive.zip' from anywhere!"
}

# Function to set as default archive handler
set_default_handler() {
    print_color "$BLUE" "Setting Extract Here Now as default handler for archive types..."
    
    local desktop_file="$DESKTOP_FILE"
    local mime_types=(
        "application/zip"
        "application/x-zip-compressed"
        "application/x-tar"
        "application/gzip"
        "application/x-gzip"
        "application/x-bzip2"
        "application/x-xz"
        "application/x-rar"
        "application/vnd.rar"
        "application/x-7z-compressed"
        "application/x-compressed-tar"
        "application/x-bzip-compressed-tar"
        "application/x-xz-compressed-tar"
        "application/x-lzip"
        "application/x-lzma"
    )
    
    # Check if desktop file exists
    if [ ! -f "$DESKTOP_DIR/$DESKTOP_FILE" ]; then
        error_exit "Desktop file not found. Please run --install first."
    fi
    
    # Handle qtpaths variants for KDE compatibility
    local qtpaths_alias=""
    local use_alias=false
    
    if ! command -v qtpaths >/dev/null 2>&1; then
        for qt_variant in qtpaths6 qtpaths-qt6 qtpaths5 qtpaths-qt5; do
            if command -v "$qt_variant" >/dev/null 2>&1; then
                print_color "$BLUE" "Found $qt_variant, will use alias for xdg-mime calls"
                qtpaths_alias="alias qtpaths='$qt_variant';"
                use_alias=true
                break
            fi
        done
        
        if [ "$use_alias" = false ]; then
            print_color "$YELLOW" "Warning: No qtpaths variant found. KDE MIME associations may not work properly."
        fi
    fi
    
    # Set MIME type associations
    local success_count=0
    local total_count=${#mime_types[@]}
    
    for mime_type in "${mime_types[@]}"; do
        if command -v xdg-mime >/dev/null 2>&1; then
            # Use bash -c with qtpaths alias if needed, otherwise run directly
            if [ "$use_alias" = true ]; then
                if bash -c "$qtpaths_alias xdg-mime default '$desktop_file' '$mime_type'" 2>/dev/null; then
                    print_color "$GREEN" "Set default for: $mime_type"
                    success_count=$((success_count + 1))
                else
                    print_color "$YELLOW" "Warning: Failed to set default for: $mime_type"
                fi
            else
                if xdg-mime default "$desktop_file" "$mime_type" 2>/dev/null; then
                    print_color "$GREEN" "Set default for: $mime_type"
                    success_count=$((success_count + 1))
                else
                    print_color "$YELLOW" "Warning: Failed to set default for: $mime_type"
                fi
            fi
        else
            print_color "$RED" "xdg-mime not available. Cannot set default associations."
            return 1
        fi
    done
    
    print_color "$GREEN" "Default associations completed! ($success_count/$total_count successful)"
    if [ "$success_count" -eq "$total_count" ]; then
        print_color "$BLUE" "Extract Here Now is now the default handler for all archive types."
    else
        print_color "$YELLOW" "Some MIME types may not have been set properly. Check your desktop environment."
    fi
}

# Function to show usage
show_usage() {
    echo "Extract Here Now v$VERSION"
    echo "Usage: $SCRIPT_NAME [OPTIONS] [ARCHIVE_FILE]"
    echo
    echo "Options:"
    echo "  --install       Install the script and desktop file"
    echo "  --uninstall     Remove the script and desktop file"
    echo "  --set-default   Set as default handler for archive types"
    echo "  --version       Show version information"
    echo "  --help         Show this help message"
    echo
    echo "If no options are provided, extract the specified archive file."
    echo
    if is_installer; then
        echo "Note: This appears to be an installer version. Running without"
        echo "arguments will prompt to install the application."
        echo
    fi
    echo "Supported formats:"
    echo "  ZIP, JAR, WAR, EAR, TAR variants, RAR, 7Z, and compressed files"
}

# Main extraction function
main_extract() {
    local file="$1"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        error_exit "File not found: $file"
    fi
    
    # Get absolute path
    file=$(realpath "$file")
    local base_dir
    base_dir=$(dirname "$file")
    
    # Detect archive type
    local archive_type
    archive_type=$(detect_archive_type "$file")
    
    if [ "$archive_type" = "unknown" ]; then
        error_exit "File is not a recognized archive format: $(basename "$file")"
    fi
    
    print_color "$BLUE" "Detected archive type: $archive_type"
    
    # Check if password is needed
    local password=""
    if needs_password "$file" "$archive_type"; then
        password=$(prompt_password "$(basename "$file")")
    fi
    
    # Determine extraction directory
    local base_name
    base_name=$(get_base_name "$file")
    
    local target_dir
    if has_root_directory "$file" "$archive_type"; then
        # Archive has root directory - check if it already exists
        if [ -e "$base_dir/$base_name" ]; then
            # Root directory exists, create unique name and extract there
            target_dir=$(create_unique_dir "$base_dir" "$base_name")
            mkdir -p "$target_dir"
            print_color "$BLUE" "Archive contains root directory but '$base_name' already exists"
            print_color "$BLUE" "Creating extraction directory: $target_dir"
        else
            # Root directory doesn't exist, safe to extract directly to base directory
            target_dir="$base_dir"
            print_color "$BLUE" "Archive contains root directory, extracting to: $target_dir"
        fi
    else
        # No root directory, create subdirectory
        target_dir=$(create_unique_dir "$base_dir" "$base_name")
        mkdir -p "$target_dir"
        print_color "$BLUE" "Creating extraction directory: $target_dir"
    fi
    
    # Verify target directory is writable
    if [ ! -w "$target_dir" ]; then
        error_exit "Cannot write to target directory: $target_dir"
    fi
    
    # Extract the archive
    extract_archive "$file" "$archive_type" "$target_dir" "$password"
    
    # Verify extraction succeeded by checking if target directory has contents
    if [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
        print_color "$GREEN" "Extraction completed successfully!"
        show_info "Archive extracted to: $target_dir"
    else
        error_exit "Extraction appears to have failed - target directory is empty"
    fi
}

# Main script logic
main() {
    case "${1:-}" in
        "--install")
            install_extractor false
            ;;
        "--uninstall")
            uninstall_extractor
            ;;
        "--set-default")
            set_default_handler
            ;;
        "--version"|"-v")
            echo "Extract Here Now v$VERSION"
            echo "Universal archive extractor for Linux"
            ;;
        "--help"|"-h")
            show_usage
            ;;
        "")
            # No arguments provided - check if this is an installer version
            if is_installer; then
                if prompt_install; then
                    install_extractor true
                else
                    print_color "$BLUE" "Installation cancelled."
                    exit 0
                fi
            else
                show_usage
            fi
            ;;
        *)
            main_extract "$1"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
