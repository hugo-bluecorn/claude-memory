#!/usr/bin/env bash
# setup_memory_management.sh
# Installs Claude Memory session management system into a project
#
# Usage: ./setup_memory_management.sh [target_directory]
#        target_directory defaults to current working directory
#
# This script fetches all files from GitHub when executed.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# === Configuration ===
GITHUB_RAW_BASE="https://raw.githubusercontent.com/hugo-bluecorn/claude-memory/master"

# Files to fetch
REMOTE_COMMANDS=(
  "cleanup-backups.md" "coalesce.md" "context-stats.md" "discard-backup.md"
  "document-and-save.md" "document-and-save-to.md" "fresh-start.md"
  "fresh-start-all.md" "resume-from.md" "resume-latest.md"
  "search-sessions.md" "sessions-list.md"
)
REMOTE_HOOKS=("on-session-start.sh" "on-session-end.sh" "on-pre-compact.sh")
REMOTE_SCRIPTS=("discard-backup.sh" "fresh-start.sh")
REMOTE_TEMPLATES=("active-context.md" "project-memory.md")

# HTTP client (detected at runtime)
HTTP_CLIENT=""

# === Help ===
show_help() {
  cat << EOF
Claude Memory Setup

Usage: ./setup_memory_management.sh [target_directory]

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

# === HTTP Client Detection ===
detect_http_client() {
  # Allow test override
  if [[ -n "${SETUP_FORCE_HTTP_CLIENT:-}" ]]; then
    echo "$SETUP_FORCE_HTTP_CLIENT"
    return
  fi

  if command -v curl &>/dev/null; then
    echo "curl"
  elif command -v wget &>/dev/null; then
    echo "wget"
  else
    echo "none"
  fi
}

validate_prerequisites() {
  HTTP_CLIENT=$(detect_http_client)
  if [[ "$HTTP_CLIENT" == "none" ]]; then
    echo -e "${RED}Error: curl or wget is required for installation${NC}" >&2
    echo "Please install curl or wget and try again" >&2
    exit 3
  fi
  echo "Using $HTTP_CLIENT for downloads"
}

# === Remote Fetch ===

# Get the directory where this script is located (for mock_local mode)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fetch_remote_file() {
  local remote_path="$1"
  local local_path="$2"
  local url="$GITHUB_RAW_BASE/$remote_path"

  # Test mode: use local files instead of network
  if [[ "${SETUP_TEST_MODE:-}" == "mock_local" ]]; then
    # Simulate network failure if requested
    if [[ "${MOCK_CURL_FAIL:-}" == "1" ]]; then
      echo -e "${RED}Error: Failed to download $remote_path${NC}" >&2
      return 1
    fi

    # Simulate empty response if requested
    if [[ "${MOCK_CURL_EMPTY:-}" == "1" ]]; then
      touch "$local_path"
      echo -e "${RED}Error: Downloaded file is empty: $local_path${NC}" >&2
      return 1
    fi

    # Copy from local source
    local local_source="$SCRIPT_DIR/$remote_path"
    if [[ -f "$local_source" ]]; then
      cp "$local_source" "$local_path"
      return 0
    else
      echo -e "${RED}Error: Local source not found: $local_source${NC}" >&2
      return 1
    fi
  fi

  # Real download using detected client
  local download_success=false
  if [[ "$HTTP_CLIENT" == "curl" ]]; then
    if curl -sSfL "$url" -o "$local_path" 2>/dev/null; then
      download_success=true
    fi
  else
    if wget -q "$url" -O "$local_path" 2>/dev/null; then
      download_success=true
    fi
  fi

  if [[ "$download_success" != "true" ]]; then
    echo -e "${RED}Error: Failed to download $remote_path${NC}" >&2
    return 1
  fi

  # Validate not empty
  if [[ ! -s "$local_path" ]]; then
    echo -e "${RED}Error: Downloaded file is empty: $local_path${NC}" >&2
    return 1
  fi
}

# === Install Functions ===

create_directories() {
  local target="$1"
  echo "Creating directory structure..."
  mkdir -p "$target/.claude/commands"
  mkdir -p "$target/.claude/hooks"
  mkdir -p "$target/.claude/scripts"
  mkdir -p "$target/.claude/memory/raw"
  mkdir -p "$target/.claude/memory/sessions"
}

fetch_commands() {
  local target="$1"
  echo "Fetching commands..."
  for cmd in "${REMOTE_COMMANDS[@]}"; do
    fetch_remote_file "src/commands/$cmd" "$target/.claude/commands/$cmd" || return 1
  done
}

fetch_hooks() {
  local target="$1"
  echo "Fetching hooks..."
  for hook in "${REMOTE_HOOKS[@]}"; do
    fetch_remote_file "src/hooks/$hook" "$target/.claude/hooks/$hook" || return 1
    chmod +x "$target/.claude/hooks/$hook"
  done
}

fetch_scripts() {
  local target="$1"
  echo "Fetching scripts..."
  for script in "${REMOTE_SCRIPTS[@]}"; do
    fetch_remote_file "src/scripts/$script" "$target/.claude/scripts/$script" || return 1
    chmod +x "$target/.claude/scripts/$script"
  done
}

fetch_templates() {
  local target="$1"
  echo "Setting up session files..."
  for template in "${REMOTE_TEMPLATES[@]}"; do
    if [[ ! -f "$target/.claude/memory/$template" ]]; then
      fetch_remote_file "src/templates/$template" "$target/.claude/memory/$template" || return 1
    else
      echo -e "${YELLOW}  Skipping $template (already exists)${NC}"
    fi
  done
}

show_success_message() {
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
}

# === Argument Parsing ===

parse_arguments() {
  case "${1:-}" in
    -h|--help)
      show_help
      ;;
  esac

  # Default to current directory if no target specified
  TARGET_DIR="${1:-.}"

  # Resolve to absolute path
  TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    echo -e "${RED}Error: Target directory does not exist: ${TARGET_DIR}${NC}" >&2
    exit 1
  }
}

# === Main ===

main() {
  parse_arguments "$@"

  validate_prerequisites

  echo "Installing Claude Memory to: $TARGET_DIR"
  echo "Fetching from: $GITHUB_RAW_BASE"

  create_directories "$TARGET_DIR"
  fetch_commands "$TARGET_DIR" || exit 2
  fetch_hooks "$TARGET_DIR" || exit 2
  fetch_scripts "$TARGET_DIR" || exit 2
  fetch_templates "$TARGET_DIR" || exit 2

  show_success_message
}

main "$@"
