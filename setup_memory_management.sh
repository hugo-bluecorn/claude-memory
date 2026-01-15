#!/usr/bin/env bash
# setup_memory_management.sh
# Installs Claude Memory session management system into a project
#
# Usage: ./setup_memory_management.sh [target_directory]
#        target_directory defaults to current working directory

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Show help
show_help() {
  cat << EOF
Claude Memory Setup

Usage: ./setup_memory_management.sh [options] [target_directory]

Options:
  -h, --help    Show this help message

Arguments:
  target_directory    The project directory to install into (default: current directory)

This script installs:
  - Session management commands (document-and-save, resume-latest, etc.)
  - Automatic backup hooks (session end, pre-compact, session start)
  - Helper scripts for session management
  - Template files for active-context.md and project-memory.md

After installation, merge settings-hooks.json into your .claude/settings.json
and add CLAUDE.md.snippet to your .claude/CLAUDE.md.
EOF
  exit 0
}

# Parse arguments
case "${1:-}" in
  -h|--help)
    show_help
    ;;
esac

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory (default to first argument or current directory)
TARGET_DIR="${1:-.}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  echo -e "${RED}Error: Target directory does not exist: $1${NC}"
  exit 1
}

echo "Installing Claude Memory to: $TARGET_DIR"

# === Create Directory Structure ===
echo "Creating directory structure..."
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/scripts"
mkdir -p "$TARGET_DIR/planning/sessions/raw"

# === Copy Commands ===
echo "Copying commands..."
for cmd in "$SCRIPT_DIR/src/commands/"*.md; do
  if [[ -f "$cmd" ]]; then
    filename=$(basename "$cmd")
    cp "$cmd" "$TARGET_DIR/.claude/commands/$filename"
  fi
done

# === Copy Hooks ===
echo "Copying hooks..."
for hook in "$SCRIPT_DIR/src/hooks/"*.sh; do
  if [[ -f "$hook" ]]; then
    filename=$(basename "$hook")
    cp "$hook" "$TARGET_DIR/.claude/hooks/$filename"
    chmod +x "$TARGET_DIR/.claude/hooks/$filename"
  fi
done

# === Copy Scripts ===
echo "Copying scripts..."
for script in "$SCRIPT_DIR/src/scripts/"*.sh; do
  if [[ -f "$script" ]]; then
    filename=$(basename "$script")
    cp "$script" "$TARGET_DIR/.claude/scripts/$filename"
    chmod +x "$TARGET_DIR/.claude/scripts/$filename"
  fi
done

# === Copy Templates (only if not existing) ===
echo "Setting up session files..."
if [[ ! -f "$TARGET_DIR/planning/sessions/active-context.md" ]]; then
  cp "$SCRIPT_DIR/src/templates/active-context.md" "$TARGET_DIR/planning/sessions/active-context.md"
else
  echo -e "${YELLOW}  Skipping active-context.md (already exists)${NC}"
fi

if [[ ! -f "$TARGET_DIR/planning/sessions/project-memory.md" ]]; then
  cp "$SCRIPT_DIR/src/templates/project-memory.md" "$TARGET_DIR/planning/sessions/project-memory.md"
else
  echo -e "${YELLOW}  Skipping project-memory.md (already exists)${NC}"
fi

# === Final Instructions ===
echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Merge hooks from settings-hooks.json into your .claude/settings.json"
echo "2. Add session management section from CLAUDE.md.snippet to your .claude/CLAUDE.md"
echo ""
echo "Available commands:"
echo "  /document-and-save     - Save session to default path"
echo "  /document-and-save-to  - Save session to custom path"
echo "  /resume-latest         - Resume from most recent session"
echo "  /resume-from           - Resume from specific session"
echo "  /sessions-list         - Browse available sessions"
echo "  /discard-backup        - Discard pending backup"
