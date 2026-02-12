#!/usr/bin/env bash
# Toggle command groups on/off by creating/removing symlinks.
# Source of truth: .library/commands/<group>/<file>.md
# Symlinks:       .claude/commands/<file>.md → ../../.library/commands/<group>/<file>.md
#
# Usage:
#   bash scripts/toggle-commands.sh bmad on
#   bash scripts/toggle-commands.sh bmad off
#   bash scripts/toggle-commands.sh speckit on
#   bash scripts/toggle-commands.sh speckit off
#   bash scripts/toggle-commands.sh other on
#   bash scripts/toggle-commands.sh other off
#   bash scripts/toggle-commands.sh list

set -uo pipefail

COMMANDS_DIR=".claude/commands"
LIBRARY_DIR=".library/commands"
GITIGNORE=".gitignore"

mkdir -p "$COMMANDS_DIR"

# Map group name to library subdirectory
group_dir() {
  case "$1" in
    bmad)    echo "$LIBRARY_DIR/bmad" ;;
    speckit) echo "$LIBRARY_DIR/speckit" ;;
    project) echo "$LIBRARY_DIR/project" ;;
    other)   echo "$LIBRARY_DIR/other" ;;
    *)       echo "" ;;
  esac
}

# Ensure .claude/commands is in .gitignore (permanently ignored)
ensure_gitignore() {
  for entry in ".claude/commands" ".claude/commands-disabled"; do
    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
      echo "$entry" >> "$GITIGNORE"
    fi
  done
}

# Create symlinks for all files in a library group
enable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for f in "$src_dir"/*.md; do
    [ -f "$f" ] || continue
    local basename
    basename=$(basename "$f")
    local link="$COMMANDS_DIR/$basename"
    local target="../../$src_dir/$basename"

    # Skip if symlink already exists and points to the right place
    if [ -L "$link" ]; then
      continue
    fi
    # Remove any non-symlink file that conflicts
    [ -e "$link" ] && rm "$link"

    ln -s "$target" "$link"
    count=$((count + 1))
  done
  echo "Enabled $count $group commands (symlinked)"
}

# Remove symlinks that point into a library group
disable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for link in "$COMMANDS_DIR"/*.md; do
    [ -L "$link" ] || continue
    local target
    target=$(readlink "$link")
    # Check if this symlink points into the group's library dir
    if [[ "$target" == *"$src_dir"* ]]; then
      rm "$link"
      count=$((count + 1))
    fi
  done
  echo "Disabled $count $group commands (symlinks removed)"
}

# Count active symlinks for a group
count_active() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for link in "$COMMANDS_DIR"/*.md; do
    [ -L "$link" ] || continue
    local target
    target=$(readlink "$link")
    if [[ "$target" == *"$src_dir"* ]]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Count total files in a library group
count_total() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  ls "$src_dir"/*.md 2>/dev/null | wc -l | tr -d ' '
}

# List what's active vs available
list_groups() {
  echo ""
  echo "=== Command Library ==="
  for group in bmad speckit project other; do
    local active total
    active=$(count_active "$group")
    total=$(count_total "$group")
    local status="off"
    if [ "$active" -gt 0 ]; then
      status="ON"
    fi
    printf "  %-10s %s active / %s total  [%s]\n" "$group:" "$active" "$total" "$status"
  done
  echo ""
}

GROUP="${1:-}"
ACTION="${2:-}"

if [ "$GROUP" = "list" ] || [ -z "$GROUP" ]; then
  list_groups
  exit 0
fi

if [ -z "$ACTION" ]; then
  echo "Usage: bash scripts/toggle-commands.sh <bmad|speckit|other|list> <on|off>"
  exit 1
fi

src_dir=$(group_dir "$GROUP")
if [ -z "$src_dir" ] || [ ! -d "$src_dir" ]; then
  echo "Unknown group: $GROUP (use bmad, speckit, other, or list)"
  exit 1
fi

case "$ACTION" in
  on)  enable_group "$GROUP" ;;
  off) disable_group "$GROUP" ;;
  *)   echo "Unknown action: $ACTION (use on or off)"; exit 1 ;;
esac

# Ensure .claude/commands is gitignored
ensure_gitignore

# Clean up macOS resource fork files (._*) created on ExFAT drives
dot_clean "$COMMANDS_DIR" 2>/dev/null
find "$COMMANDS_DIR" -name '._*' -delete 2>/dev/null

echo ""
list_groups
echo "Restart Claude Code or run /clear for changes to take effect."
