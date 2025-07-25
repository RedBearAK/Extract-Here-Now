# Extract Here Now

**Universal Linux archive extractor that just works.** Extract archives directly where they are, without opening GUI applications or choosing destinations. Like the default archive behavior on macOS, but for Linux.

![Archive extraction demo](https://img.shields.io/badge/Supports-ZIP%20%7C%20TAR%20%7C%20RAR%20%7C%207Z%20%7C%20More-blue)
![Desktop Integration](https://img.shields.io/badge/Integration-Desktop%20%7C%20Terminal%20%7C%20Context%20Menu-green)
![Cross Platform](https://img.shields.io/badge/Distros-Fedora%20%7C%20Ubuntu%20%7C%20Arch%20%7C%20openSUSE%20%7C%20More-orange)

## ⚡ Quick Install

```bash
# One-line installer with automatic fallbacks
wget -O extract-here-now-installer.sh https://raw.githubusercontent.com/RedBearAK/Extract-Here-Now/main/extract-here-now-installer.sh && chmod +x extract-here-now-installer.sh && ./extract-here-now-installer.sh || curl -o extract-here-now-installer.sh https://raw.githubusercontent.com/RedBearAK/Extract-Here-Now/main/extract-here-now-installer.sh && chmod +x extract-here-now-installer.sh && ./extract-here-now-installer.sh || echo "❌ Please install wget or curl first, then try again."
```

That's it! The installer will:
- ✅ Install the script to `~/.local/lib/extract-here-now/`
- ✅ Create the `extract-here-now` command 
- ✅ Add desktop integration for "Open with" menus
- ✅ Configure your PATH automatically

## What It Does

Extract Here Now solves the **most annoying thing** about Linux archive handling in GUI file managers: having to open archives in GUI applications just to extract them, or constantly using the "Extract Here" that hides in different places in different Linux file manager context menus. Instead, it:

- **Extracts immediately** - No GUI windows, no destination prompts
- **Handles conflicts** - Creates `Archive_copy_01` folders automatically
- **Detects root folders** - Extracts intelligently based on archive structure
- **Works everywhere** - Terminal, file manager, context menus
- **Supports everything** - ZIP, TAR variants, RAR, 7Z, and more ^

^ _Using the relevant native commands/apps._

## Features

### Smart Extraction Logic
- **Root directory detection** - Extracts directly if archive contains a single root folder
- **Conflict resolution** - Creates numbered copies (`_copy_01`, `_copy_02`) when destinations exist
- **Clean extraction** - Never overwrites files, always creates contained folders

### Multi-Environment Support  
- **Desktop integration** - Appears in "Open with" menus across all major desktop environments
- **Terminal command** - Use `extract-here-now archive.zip` from anywhere
- **File manager** - Right-click any archive and select "Extract Here Now"

### Advanced Features
- **Password support** - GUI and terminal prompts for encrypted archives
- **Format detection** - Uses both MIME types and file extensions for accuracy
- **Tool fallbacks** - Tries multiple extraction tools automatically
- **Cross-distro** - Works on Fedora, Ubuntu, Arch, openSUSE, and more

## Supported Formats

| Format               | Extensions                                                            | Tools Used                                                 |
| -------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------- |
| **ZIP Archives**     | `.zip`, `.jar`, `.war`, `.ear`                                        | `unzip`, `7z`                                              |
| **TAR Archives**     | `.tar`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, <br>`.tgz`, `.tbz2`, `.txz` | `tar`                                                      |
| **RAR Archives**     | `.rar`                                                                | `unrar`, `7z`                                              |
| **7-Zip Archives**   | `.7z`                                                                 | `7z`                                                       |
| **Compressed Files** | `.gz`, `.bz2`, `.xz`, `.lzma`                                         | `gunzip`, `bunzip2`, `unxz`, `unlzma`                      |
| **GUI Fallbacks**    | *All of the above*                                                    | `file-roller`, `ark`, `engrampa`, <br>`xarchiver`, `atool` |

## Requirements

### Essential
- **Linux** (any distribution)
- **Bash** 4.0+ (standard on all modern distros)

### Archive Tools (install as needed)
Most distros include basic tools, but for full format support:

```bash
# Fedora/RHEL/CentOS
sudo dnf install unzip tar p7zip unrar

# Ubuntu/Debian
sudo apt install unzip tar p7zip-full unrar

# Arch Linux  
sudo pacman -S unzip tar p7zip unrar

# openSUSE
sudo zypper install unzip tar p7zip unrar
```

### Optional (for enhanced experience)
- **zenity** - GUI dialogs and password prompts
- **file-roller/ark/engrampa** - Fallback extraction for unusual formats

## Usage Examples

### Terminal Usage
```bash
# Extract any archive
extract-here-now document.zip
extract-here-now backup.tar.gz  
extract-here-now photos.rar

# Check version
extract-here-now --version

# Set as default for all archive types
extract-here-now --set-default
```

### File Manager Usage
1. Right-click any archive file
2. Select **"Open with" → "Extract Here Now (Universal)"**
3. Done! Archive extracts immediately

### What You Get
```
Before:                          After:
📁 ~/Downloads/                  📁 ~/Downloads/
  📄 photos.zip                    📄 photos.zip
                            →      📁 photos/
                                     📸 IMG_001.jpg
                                     📸 IMG_002.jpg
```

## Configuration

### Set as Default Archive Handler
Make Extract Here Now the default for all archive types:
```bash
extract-here-now --set-default
```

This sets it as the default application for ZIP, TAR, RAR, 7Z, and other archive formats in your desktop environment.

### Uninstall
```bash
extract-here-now --uninstall
```

Removes the command, desktop integration, and optionally the script files.

## How It Works

### Smart Directory Creation
```bash
# Archive with root directory (most archives)
archive.zip
├── MyProject/           # ← Root directory detected  
│   ├── file1.txt
│   └── file2.txt
# Result: Extracts directly to current directory (MyProject/ folder appears)

# Archive without root directory  
messy.zip
├── file1.txt            # ← No root directory
├── file2.txt  
# Result: Creates messy/ folder, extracts files inside
```

### Conflict Resolution
```bash
# If target already exists:
📁 MyProject/           # ← Already exists
📄 MyProject.zip        
# Result: Creates MyProject_copy_01/ automatically
```

### Password Handling
- **GUI Mode**: Zenity password dialog
- **Terminal Mode**: Secure terminal input
- **Encrypted formats**: ZIP, RAR, 7Z password support

## Troubleshooting

### "Command not found" 
```bash
# Reload your shell profile
source ~/.profile
# Or restart your terminal
```

### "qtpaths: command not found" errors
The script automatically handles Qt versioning issues on KDE/Plasma systems. These warnings are harmless and suppressed.

### Archive won't extract
1. Check if you have the required tool: `which unzip` / `which unrar` / etc.
2. Install missing tools for your distro (see Requirements section)
3. Try with `--verbose` flag for debugging: `extract-here-now --verbose archive.zip`

### GUI dialogs not appearing
Install zenity for better GUI integration:
```bash
# Most distros
sudo [package-manager] install zenity
```

## Desktop Environment Compatibility

Should work on many Linux distros and desktops:
- **GNOME** (Fedora, Ubuntu)
- **KDE Plasma** (Fedora, openSUSE, Arch)  
- **XFCE** (Xubuntu, Fedora Spins)
- **MATE** (Ubuntu MATE)
- **Cinnamon** (Linux Mint)
- **Budgie** (Solus)
- **Window managers** (i3, Sway, Hyprland)

## Contributing

Contributions welcome! This project aims to be the **universal** Linux archive extractor.

### Areas for improvement:
- Additional archive format support
- More GUI archive manager integrations  
- Better error handling for edge cases
- Translations for different languages

### How to contribute:
1. Fork the repository
2. Create a feature branch
3. Test on multiple distros/desktop environments
4. Submit a pull request

## License

GNU General Public License 3.0 - see [LICENSE](LICENSE) for details.

## Why This Exists

On macOS, archives just extract when you double-click them. It's simple and predictable.

On Linux, archives opened from a file manager tend to open in GUI applications that ask where to extract, show progress bars, and generally get in your way when you just wanted the files to be extracted **right here, right now**.

Extract Here Now brings that macOS simplicity to Linux. Because sometimes the best UX is no UX at all.

---

*Have issues or suggestions? [Open an issue](https://github.com/RedBearAK/Extract-Here-Now/issues).