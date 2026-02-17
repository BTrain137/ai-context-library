#!/usr/bin/env bash
# Toggle skill groups on/off by creating/removing symlinks.
# Source of truth: .library/skills/<group>/<skill>/
# Symlinks:       .claude/skills/<skill> → ../../.library/skills/<group>/<skill>
#
# Usage:
#   bash scripts/toggle-skills.sh my-group on
#   bash scripts/toggle-skills.sh my-group off
#   bash scripts/toggle-skills.sh list

set -uo pipefail

# ─── Resolve paths from repo root ─────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills"
LIBRARY_DIR="$REPO_ROOT/.library/skills"
GITIGNORE="$REPO_ROOT/.gitignore"

mkdir -p "$SKILLS_DIR"

# ─── Group Discovery ─────────────────────────────────────────────────────────
# Groups are auto-discovered from subdirectories of .library/skills/
discover_groups() {
  local groups=()
  for d in "$LIBRARY_DIR"/*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"
    [[ "$name" == "._"* ]] && continue
    groups+=("$name")
  done
  echo "${groups[@]+"${groups[@]}"}"
}

group_dir() {
  local name="$1"
  # Reject path traversal: slashes, ".." sequences, or names starting with "."
  if [[ "$name" == */* || "$name" == *..* || "$name" == .* ]]; then
    echo "Invalid group name: $name" >&2
    return 1
  fi
  local dir="$LIBRARY_DIR/$name"
  if [[ -d "$dir" ]]; then
    echo "$dir"
  else
    echo "Unknown group: $name" >&2
    return 1
  fi
}

# ─── Gitignore ─────────────────────────────────────────────────────────────────
# Ensure .claude/skills is in .gitignore (permanently ignored)
ensure_gitignore() {
  for entry in ".claude/commands/" ".claude/skills/"; do
    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
      echo "$entry" >> "$GITIGNORE"
    fi
  done
}

# ─── Enable ────────────────────────────────────────────────────────────────────
# Create symlinks for all skill directories in a library group
enable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group") || exit 1
  local count=0

  for d in "$src_dir"/*/; do
    [ -d "$d" ] || continue
    local skill_name
    skill_name=$(basename "$d")
    local link="$SKILLS_DIR/$skill_name"
    local target="../../.library/skills/$group/$skill_name"

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

# ─── Disable ───────────────────────────────────────────────────────────────────
# Remove symlinks that point into a library group
disable_group() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group") || exit 1
  local count=0

  for link in "$SKILLS_DIR"/*/; do
    [ -L "${link%/}" ] || continue
    local target
    target=$(readlink "${link%/}")
    if [[ "$target" == *".library/skills/$group/"* ]]; then
      rm "${link%/}"
      count=$((count + 1))
    fi
  done
  echo "Disabled $count $group skills (symlinks removed)"
}

# ─── Count helpers ─────────────────────────────────────────────────────────────
# Count active symlinks for a group
count_active() {
  local group="$1"
  local count=0

  for link in "$SKILLS_DIR"/*/; do
    [ -L "${link%/}" ] || continue
    local target
    target=$(readlink "${link%/}")
    if [[ "$target" == *".library/skills/$group/"* ]]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Count total skill directories in a library group
count_total() {
  local group="$1"
  local src_dir
  src_dir=$(group_dir "$group") || { echo "0"; return; }
  local count=0
  for d in "$src_dir"/*/; do
    [ -d "$d" ] && count=$((count + 1))
  done
  echo "$count"
}

# ─── List ──────────────────────────────────────────────────────────────────────
# List what's active vs available
list_groups() {
  echo ""
  echo "=== Skill Library ==="
  local groups
  groups=$(discover_groups)
  if [ -z "$groups" ]; then
    echo "  (no skill groups found — create directories under .library/skills/)"
  else
    for group in $groups; do
      local active total
      active=$(count_active "$group")
      total=$(count_total "$group")
      local status="off"
      if [ "$active" -gt 0 ]; then
        status="ON"
      fi
      printf "  %-12s %s active / %s total  [%s]\n" "$group:" "$active" "$total" "$status"
    done
  fi
  echo ""
}

# ─── Main ──────────────────────────────────────────────────────────────────────
GROUP="${1:-}"
ACTION="${2:-}"

if [ "$GROUP" = "list" ] || [ -z "$GROUP" ]; then
  list_groups
  exit 0
fi

if [ -z "$ACTION" ]; then
  echo "Usage: bash scripts/toggle-skills.sh <group|list> <on|off>"
  echo ""
  echo "Available groups: $(discover_groups)"
  exit 1
fi

if ! group_dir "$GROUP" > /dev/null 2>&1; then
  echo "Unknown group: $GROUP"
  echo "Available groups: $(discover_groups)"
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
