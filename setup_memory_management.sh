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
  - Hook configuration in .claude/settings.json
  - Session management section in .claude/CLAUDE.md
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

configure_settings() {
  local target="$1"
  local settings_file="$target/.claude/settings.json"
  local temp_file
  temp_file=$(mktemp)

  echo "Configuring settings.json..."

  # Fetch hooks config to temp file
  fetch_remote_file "settings-hooks.json" "$temp_file" || return 1

  if [[ ! -f "$settings_file" ]]; then
    # No existing settings - just use the hooks file
    cp "$temp_file" "$settings_file"
  else
    # Check if hooks already configured
    if grep -q "PreCompact" "$settings_file" 2>/dev/null; then
      echo -e "${YELLOW}  Skipping settings.json (hooks already configured)${NC}"
      rm -f "$temp_file"
      return 0
    fi

    # Merge hooks into existing settings using jq if available
    if command -v jq &>/dev/null; then
      local merged
      merged=$(jq -s '.[0] * .[1]' "$settings_file" "$temp_file" 2>/dev/null)
      if [[ -n "$merged" ]]; then
        echo "$merged" > "$settings_file"
      else
        # jq merge failed, append hooks manually
        echo -e "${YELLOW}  Warning: Could not merge settings, creating new file${NC}"
        cp "$temp_file" "$settings_file"
      fi
    else
      # No jq - just overwrite with hooks (user can merge manually if needed)
      echo -e "${YELLOW}  Warning: jq not found, replacing settings.json${NC}"
      cp "$temp_file" "$settings_file"
    fi
  fi

  rm -f "$temp_file"
}

configure_claude_md() {
  local target="$1"
  local claude_md="$target/.claude/CLAUDE.md"
  local temp_file
  temp_file=$(mktemp)

  echo "Configuring CLAUDE.md..."

  # Fetch snippet to temp file
  fetch_remote_file "CLAUDE.md.snippet" "$temp_file" || return 1

  if [[ ! -f "$claude_md" ]]; then
    # No existing CLAUDE.md - just use the snippet
    cp "$temp_file" "$claude_md"
  else
    # Check if snippet already added
    if grep -q "# Session Management" "$claude_md" 2>/dev/null; then
      echo -e "${YELLOW}  Skipping CLAUDE.md (session management already configured)${NC}"
      rm -f "$temp_file"
      return 0
    fi

    # Append snippet to existing file
    echo "" >> "$claude_md"
    echo "---" >> "$claude_md"
    echo "" >> "$claude_md"
    cat "$temp_file" >> "$claude_md"
  fi

  rm -f "$temp_file"
}

check_legacy_files() {
  local target="$1"
  local has_legacy=false

  # Check for old session format (without Z suffix)
  if ls "$target/.claude/memory/sessions/"session-????-??-??-????.md 2>/dev/null | grep -qv 'Z\.md$'; then
    has_legacy=true
  fi

  # Check for old backup format (without Z suffix)
  if ls "$target/.claude/memory/raw/"*.jsonl 2>/dev/null | grep -qvE '[0-9]{8}_[0-9]{6}Z_'; then
    has_legacy=true
  fi

  echo "$has_legacy"
}

show_success_message() {
  local target="$1"
  echo ""
  echo -e "${GREEN}Installation complete!${NC}"
  echo ""
  echo "Available commands:"
  echo "  /document-and-save     - Save session to default path"
  echo "  /document-and-save-to  - Save session to custom path"
  echo "  /resume-latest         - Resume from most recent session"
  echo "  /resume-from           - Resume from specific session"
  echo "  /sessions-list         - Browse available sessions"
  echo "  /discard-backup        - Discard pending backup"
  echo ""

  # Check for legacy files and warn
  if [[ "$(check_legacy_files "$target")" == "true" ]]; then
    echo -e "${YELLOW}Warning: Legacy session files detected.${NC}"
    echo "Timestamps now use UTC with Z suffix. To clear old data:"
    echo "  Run /fresh-start in your next Claude Code session"
    echo ""
  fi

  echo "Start a new Claude Code session to activate the hooks."
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
  configure_settings "$TARGET_DIR" || exit 2
  configure_claude_md "$TARGET_DIR" || exit 2

  show_success_message "$TARGET_DIR"
}

main "$@"
