#!/usr/bin/env bash
# Toggle skill groups on/off by creating/removing symlinks.
# Source of truth: .library/skills/<group>/<skill>/
# Symlinks:       .claude/skills/<skill> → ../../.library/skills/<group>/<skill>
#
# Usage:
#   bash scripts/toggle-skills.sh marketing on
#   bash scripts/toggle-skills.sh marketing off
#   bash scripts/toggle-skills.sh list

set -uo pipefail

SKILLS_DIR=".claude/skills"
LIBRARY_DIR=".library/skills"
GITIGNORE=".gitignore"

mkdir -p "$SKILLS_DIR"

# Map group name to library subdirectory
group_dir() {
  case "$1" in
    marketing) echo "$LIBRARY_DIR/marketing" ;;
    *)         echo "" ;;
  esac
}

# Ensure .claude/skills is in .gitignore (permanently ignored)
ensure_gitignore() {
  if ! grep -qxF ".claude/skills" "$GITIGNORE" 2>/dev/null; then
    echo ".claude/skills" >> "$GITIGNORE"
  fi
}

# Create symlinks for all skill directories in a library group
enable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for d in "$src_dir"/*/; do
    [ -d "$d" ] || continue
    local skill_name
    skill_name=$(basename "$d")
    local link="$SKILLS_DIR/$skill_name"
    local target="../../$src_dir/$skill_name"

    # Skip if symlink already exists
    if [ -L "$link" ]; then
      continue
    fi
    # Remove any non-symlink dir that conflicts
    [ -e "$link" ] && rm -rf "$link"

    ln -s "$target" "$link"
    count=$((count + 1))
  done
  echo "Enabled $count $group skills (symlinked)"
}

# Remove symlinks that point into a library group
disable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for link in "$SKILLS_DIR"/*/; do
    [ -L "${link%/}" ] || continue
    local target
    target=$(readlink "${link%/}")
    if [[ "$target" == *"$src_dir"* ]]; then
      rm "${link%/}"
      count=$((count + 1))
    fi
  done
  echo "Disabled $count $group skills (symlinks removed)"
}

# Count active symlinks for a group
count_active() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0

  for link in "$SKILLS_DIR"/*/; do
    [ -L "${link%/}" ] || continue
    local target
    target=$(readlink "${link%/}")
    if [[ "$target" == *"$src_dir"* ]]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Count total skill directories in a library group
count_total() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group")
  local count=0
  for d in "$src_dir"/*/; do
    [ -d "$d" ] && count=$((count + 1))
  done
  echo "$count"
}

# List what's active vs available
list_groups() {
  echo ""
  echo "=== Skill Library ==="
  for group in marketing; do
    local active total
    active=$(count_active "$group")
    total=$(count_total "$group")
    local status="off"
    if [ "$active" -gt 0 ]; then
      status="ON"
    fi
    printf "  %-12s %s active / %s total  [%s]\n" "$group:" "$active" "$total" "$status"
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
  echo "Usage: bash scripts/toggle-skills.sh <marketing|list> <on|off>"
  exit 1
fi

src_dir=$(group_dir "$GROUP")
if [ -z "$src_dir" ] || [ ! -d "$src_dir" ]; then
  echo "Unknown group: $GROUP (use marketing or list)"
  exit 1
fi

case "$ACTION" in
  on)  enable_group "$GROUP" ;;
  off) disable_group "$GROUP" ;;
  *)   echo "Unknown action: $ACTION (use on or off)"; exit 1 ;;
esac

# Ensure .claude/skills is gitignored
ensure_gitignore

# Clean up macOS resource fork files (._*) created on ExFAT drives
dot_clean "$SKILLS_DIR" 2>/dev/null
find "$SKILLS_DIR" -name '._*' -delete 2>/dev/null

echo ""
list_groups
echo "Restart Claude Code or run /clear for changes to take effect."
