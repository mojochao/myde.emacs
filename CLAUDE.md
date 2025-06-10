# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

MyDE (My Development Environment) is a personal Emacs configuration built on top of James Cherti's Minimal Emacs foundation. The configuration uses a modular approach with multiple initialization files:

- `pre-early-init.el` - Loaded before early-init.el
- `early-init.el` - Standard Emacs early initialization 
- `post-early-init.el` - Loaded after early-init.el
- `pre-init.el` - Loaded before init.el
- `post-init.el` - Main configuration file with all package setups
- `myde.el` - Custom utility functions and hooks
- `custom.el` - Emacs customization settings

The configuration leverages the `use-package` macro exclusively for package management and configuration in `post-init.el`.

## Development Commands

### Setup and Installation
```bash
make init     # Clone the minimal-emacs.d repo locally
make link     # Symlink custom elisp files into minimal-emacs.d
make install  # Symlink minimal-emacs.d to ~/.emacs.d
```

### Maintenance
```bash
make clean    # Remove minimal-emacs.d directory
make update   # Pull latest changes from minimal-emacs.d repo
make unlink   # Remove symlinks from minimal-emacs.d
make uninstall # Remove installation symlink
```

### Development Workflow
- Configuration changes should be made to the top-level `.el` files
- The `make link` command creates symlinks so changes are immediately reflected
- Restart Emacs to test configuration changes
- Use `make clean && make init && make link` to reset to clean state

## Key Configuration Features

### Package Management
- Uses MELPA, GNU, and NonGNU package archives
- All packages configured via `use-package` in `post-init.el`
- Tree-sitter support with automatic grammar installation

### Development Tools
- **Go Development**: go-mode with LSP via Eglot, automatic goimports on save
- **Terraform**: terraform-mode with format-on-save
- **Markdown**: GitHub Flavored Markdown mode
- **AI Integration**: Aider, Claude Code, and gptel clients

### Completion Stack
- **In-buffer**: Corfu for completion-at-point
- **Minibuffer**: Vertico + Orderless + Marginalia + Consult + Embark

### Custom Functions (myde.el)
- `myde/keyboard-quit`: Smarter keyboard-quit behavior
- `myde/go-ts-or-plain-mode`: Tree-sitter fallback for Go
- `myde/goimports-setup`: Automatic imports on save
- `myde/auto-create-missing-dirs`: Auto-create parent directories

## Platform-Specific Behavior

### macOS
- Uses GNU `ls` for dired (`/usr/local/bin/gls`)
- Integrates shell PATH via `exec-path-from-shell`
- Keeps menu bar (follows macOS conventions)

### Linux/Other
- Disables menu bar
- Standard `ls` command for dired