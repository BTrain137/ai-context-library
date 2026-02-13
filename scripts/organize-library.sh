#!/usr/bin/env bash
# organize-library.sh — Detect and organize real files dropped into .claude/
# Moves them into .library/ and creates symlinks in their place.
#
# Usage:
#   bash scripts/organize-library.sh scan
#   bash scripts/organize-library.sh move-command <file.md> <group>
#   bash scripts/organize-library.sh move-skill <dir-name> <group>
#   bash scripts/organize-library.sh register-command-group <name>
#   bash scripts/organize-library.sh register-skill-group <name>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRARY_CMD_DIR=".library/commands"
LIBRARY_SKL_DIR=".library/skills"
CLAUDE_CMD_DIR=".claude/commands"
CLAUDE_SKL_DIR=".claude/skills"


# ─── Scan ────────────────────────────────────────────────────────────────────
# Finds real (non-symlink) files/dirs in .claude/commands/ and .claude/skills/
scan() {
  local found=0

  echo "Scanning for unorganized items..."
  echo ""

  # Scan commands — real .md files (not symlinks)
  if [[ -d "$CLAUDE_CMD_DIR" ]]; then
    for file in "$CLAUDE_CMD_DIR"/*.md; do
      [[ -f "$file" ]] || continue
      [[ -L "$file" ]] && continue
      local name
      name="$(basename "$file")"
      [[ "$name" == "._"* ]] && continue
      echo "  [command] $name (real file)"
      found=$((found + 1))
    done
  fi

  # Scan skills — real directories (not symlinks)
  if [[ -d "$CLAUDE_SKL_DIR" ]]; then
    for dir in "$CLAUDE_SKL_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      [[ -L "${dir%/}" ]] && continue
      local name
      name="$(basename "$dir")"
      [[ "$name" == "._"* ]] && continue
      echo "  [skill]   $name/ (real directory)"
      found=$((found + 1))
    done
  fi

  echo ""
  echo "$found unorganized item(s) found"

  if [[ $found -gt 0 ]]; then
    echo ""
    echo "Available command groups:"
    for d in "$LIBRARY_CMD_DIR"/*/; do
      [[ -d "$d" ]] || continue
      local name
      name="$(basename "$d")"
      [[ "$name" == "._"* ]] && continue
      echo "  - $name"
    done
    echo ""
    echo "Available skill groups:"
    for d in "$LIBRARY_SKL_DIR"/*/; do
      [[ -d "$d" ]] || continue
      local name
      name="$(basename "$d")"
      [[ "$name" == "._"* ]] && continue
      echo "  - $name"
    done
    echo ""
    echo "Use:"
    echo "  bash scripts/organize-library.sh move-command <file.md> <group>"
    echo "  bash scripts/organize-library.sh move-skill <dir-name> <group>"
    echo "  bash scripts/organize-library.sh register-command-group <name>"
    echo "  bash scripts/organize-library.sh register-skill-group <name>"
  fi
}

# ─── Move Command ────────────────────────────────────────────────────────────
# Moves a real .md file from .claude/commands/ into .library/commands/<group>/
# and creates a symlink in its place.
move_command() {
  local file="$1"
  local group="$2"
  local src="$CLAUDE_CMD_DIR/$file"
  local dest_dir="$LIBRARY_CMD_DIR/$group"
  local dest="$dest_dir/$file"

  if [[ ! -f "$src" ]]; then
    echo "Error: File not found: $src"
    exit 1
  fi

  if [[ -L "$src" ]]; then
    echo "Error: $file is already a symlink — nothing to move"
    exit 1
  fi

  if [[ ! -d "$dest_dir" ]]; then
    echo "Error: Group directory not found: $dest_dir"
    echo "Create it first: bash scripts/organize-library.sh register-command-group $group"
    exit 1
  fi

  if [[ -f "$dest" ]]; then
    echo "Error: $file already exists in $group"
    exit 1
  fi

  mv "$src" "$dest"
  ln -s "../../.library/commands/$group/$file" "$src"

  echo "Moved $file -> .library/commands/$group/$file"
  echo "Created symlink: .claude/commands/$file -> ../../.library/commands/$group/$file"
}

# ─── Move Skill ──────────────────────────────────────────────────────────────
# Moves a real skill directory from .claude/skills/ into .library/skills/<group>/
# and creates a symlink in its place.
move_skill() {
  local name="$1"
  local group="$2"
  local src="$CLAUDE_SKL_DIR/$name"
  local dest_dir="$LIBRARY_SKL_DIR/$group"
  local dest="$dest_dir/$name"

  if [[ ! -d "$src" ]]; then
    echo "Error: Skill directory not found: $src"
    exit 1
  fi

  if [[ -L "$src" ]]; then
    echo "Error: $name is already a symlink — nothing to move"
    exit 1
  fi

  if [[ ! -d "$dest_dir" ]]; then
    echo "Error: Group directory not found: $dest_dir"
    echo "Create it first: bash scripts/organize-library.sh register-skill-group $group"
    exit 1
  fi

  if [[ -d "$dest" ]]; then
    echo "Error: $name already exists in $group"
    exit 1
  fi

  mv "$src" "$dest"
  ln -s "../../.library/skills/$group/$name" "$src"

  echo "Moved $name/ -> .library/skills/$group/$name/"
  echo "Created symlink: .claude/skills/$name -> ../../.library/skills/$group/$name"
}

# ─── Register Command Group ─────────────────────────────────────────────────
# Creates the .library/commands/<name>/ directory and auto-enables the group.
register_command_group() {
  local name="$1"
  local dir="$LIBRARY_CMD_DIR/$name"

  if [[ -d "$dir" ]]; then
    echo "Group '$name' already exists"
  else
    mkdir -p "$dir"
    echo "Created group '$name' at $dir"
  fi

  # Auto-enable: symlink any files in the group into .claude/commands/
  bash "$REPO_ROOT/scripts/toggle-commands.sh" "$name" on
}

# ─── Register Skill Group ───────────────────────────────────────────────────
# Creates the .library/skills/<name>/ directory and auto-enables the group.
register_skill_group() {
  local name="$1"
  local dir="$LIBRARY_SKL_DIR/$name"

  if [[ -d "$dir" ]]; then
    echo "Group '$name' already exists"
  else
    mkdir -p "$dir"
    echo "Created group '$name' at $dir"
  fi

  # Auto-enable: symlink any skills in the group into .claude/skills/
  bash "$REPO_ROOT/scripts/toggle-skills.sh" "$name" on
}

# ─── Usage ───────────────────────────────────────────────────────────────────
usage() {
  echo "organize-library.sh — Detect and organize real files into .library/"
  echo ""
  echo "Usage:"
  echo "  bash scripts/organize-library.sh scan"
  echo "  bash scripts/organize-library.sh move-command <file.md> <group>"
  echo "  bash scripts/organize-library.sh move-skill <dir-name> <group>"
  echo "  bash scripts/organize-library.sh register-command-group <name>"
  echo "  bash scripts/organize-library.sh register-skill-group <name>"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-}" in
  scan)
    scan
    ;;
  move-command)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { usage; exit 1; }
    move_command "$2" "$3"
    ;;
  move-skill)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { usage; exit 1; }
    move_skill "$2" "$3"
    ;;
  register-command-group)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    register_command_group "$2"
    ;;
  register-skill-group)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    register_skill_group "$2"
    ;;
  *)
    usage
    ;;
esac
