#!/usr/bin/env bash
# import-repo.sh — Clone a GitHub repo and import skills/commands into .library/
# Analyzes repo contents to classify items as skills, commands, or unknown.
#
# Usage:
#   bash scripts/import-repo.sh clone <github-url>
#   bash scripts/import-repo.sh analyze <tmp-dir>
#   bash scripts/import-repo.sh import-skill <tmp-dir> <item-name> <group>
#   bash scripts/import-repo.sh import-command <tmp-dir> <item-name> <group>
#   bash scripts/import-repo.sh suggest-group <github-url>
#   bash scripts/import-repo.sh cleanup <tmp-dir>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRARY_CMD_DIR="$REPO_ROOT/.library/commands"
LIBRARY_SKL_DIR="$REPO_ROOT/.library/skills"
CLAUDE_CMD_DIR="$REPO_ROOT/.claude/commands"
CLAUDE_SKL_DIR="$REPO_ROOT/.claude/skills"


# ─── URL Parsing ──────────────────────────────────────────────────────────────
# Parses GitHub URLs into repo, branch, and subpath components.
# Sets globals: GITHUB_REPO, GITHUB_BRANCH, GITHUB_SUBPATH
GITHUB_REPO=""
GITHUB_BRANCH=""
GITHUB_SUBPATH=""

parse_github_url() {
  local url="$1"
  url="${url%/}"
  url="${url%.git}"

  GITHUB_REPO=""
  GITHUB_BRANCH=""
  GITHUB_SUBPATH=""

  # https://github.com/user/repo/tree/branch/optional/path
  if [[ "$url" =~ ^https://github\.com/([^/]+/[^/]+)/tree/([^/]+)(/(.+))?$ ]]; then
    GITHUB_REPO="${BASH_REMATCH[1]}"
    GITHUB_BRANCH="${BASH_REMATCH[2]}"
    GITHUB_SUBPATH="${BASH_REMATCH[4]:-}"
  # https://github.com/user/repo
  elif [[ "$url" =~ ^https://github\.com/([^/]+/[^/]+)$ ]]; then
    GITHUB_REPO="${BASH_REMATCH[1]}"
  else
    echo "Error: Could not parse GitHub URL: $url" >&2
    echo "Expected: https://github.com/<user>/<repo> or https://github.com/<user>/<repo>/tree/<branch>/<path>" >&2
    return 1
  fi
}


# ─── Skip List ────────────────────────────────────────────────────────────────
# Files and directories to skip during analysis (repo metadata, not importable)
should_skip() {
  local name="$1"
  case "$name" in
    .git|.github|.claude|.claude-plugin|node_modules|.specstory|.vscode|__pycache__)
      return 0 ;;
    README.md|CONTRIBUTING.md|LICENSE|LICENSE.md|CHANGELOG.md|VERSIONS.md)
      return 0 ;;
    AGENTS.md|CLAUDE.md|.gitignore|package.json|package-lock.json|yarn.lock|tsconfig.json)
      return 0 ;;
    ._*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}


# ─── Frontmatter Detection ───────────────────────────────────────────────────
# Checks if a .md file has YAML frontmatter with a description field
has_command_frontmatter() {
  local file="$1"
  local first_line
  first_line=$(head -1 "$file" 2>/dev/null) || return 1
  [[ "$first_line" == "---" ]] || return 1
  head -20 "$file" 2>/dev/null | grep -q 'description:' && return 0
  return 1
}


# ─── Clone ────────────────────────────────────────────────────────────────────
# Clones the repo to a temp directory and determines the content root.
# Outputs TMPDIR= and CONTENTDIR= lines for the caller to parse.
clone_repo() {
  local url="$1"
  parse_github_url "$url" || exit 1

  local tmp_dir
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/import-repo-XXXXXX")

  local clone_url="https://github.com/${GITHUB_REPO}.git"

  echo "Cloning $GITHUB_REPO..."

  if [[ -n "$GITHUB_BRANCH" ]]; then
    if ! git clone --depth 1 --branch "$GITHUB_BRANCH" --quiet "$clone_url" "$tmp_dir/repo" 2>&1; then
      echo "Error: Failed to clone repository" >&2
      rm -rf "$tmp_dir"
      exit 1
    fi
  else
    if ! git clone --depth 1 --quiet "$clone_url" "$tmp_dir/repo" 2>&1; then
      echo "Error: Failed to clone repository" >&2
      rm -rf "$tmp_dir"
      exit 1
    fi
  fi

  local content_dir="$tmp_dir/repo"
  if [[ -n "$GITHUB_SUBPATH" ]]; then
    content_dir="$tmp_dir/repo/$GITHUB_SUBPATH"
    if [[ ! -d "$content_dir" ]]; then
      echo "Error: Subpath not found in repo: $GITHUB_SUBPATH" >&2
      rm -rf "$tmp_dir"
      exit 1
    fi
  fi

  # Store content root for subsequent commands
  echo "$content_dir" > "$tmp_dir/.content-root"

  echo ""
  echo "TMPDIR=$tmp_dir"
  echo "CONTENTDIR=$content_dir"
}


# ─── Analyze ──────────────────────────────────────────────────────────────────
# Walks the content directory and classifies items as skill, command, or unknown.
# Detection heuristics:
#   [skill]   — directory containing SKILL.md
#   [command] — .md file with YAML frontmatter containing description:
#   [unknown] — anything else (needs user decision)
analyze() {
  local tmp_dir="$1"

  if [[ ! -f "$tmp_dir/.content-root" ]]; then
    echo "Error: No content root found. Run 'clone' first." >&2
    exit 1
  fi

  local content_dir
  content_dir="$(cat "$tmp_dir/.content-root")"

  local skill_count=0
  local command_count=0
  local unknown_count=0

  echo "Analyzing contents..."
  echo ""

  # Special case: content_dir itself is a single skill
  if [[ -f "$content_dir/SKILL.md" ]]; then
    local name
    name="$(basename "$content_dir")"
    echo "  [skill]   $name/"
    skill_count=1
    echo ""
    echo "Found: $skill_count skill(s), $command_count command(s), $unknown_count unknown(s)"
    return
  fi

  # Check for skills/ and commands/ subdirectories
  local has_skills_dir=false
  local has_commands_dir=false
  [[ -d "$content_dir/skills" ]] && has_skills_dir=true
  [[ -d "$content_dir/commands" ]] && has_commands_dir=true

  # ── Scan skills/ subdirectory ──
  if $has_skills_dir; then
    for item in "$content_dir/skills"/*/; do
      [[ -d "$item" ]] || continue
      local name
      name="$(basename "$item")"
      should_skip "$name" && continue

      if [[ -f "$item/SKILL.md" ]]; then
        echo "  [skill]   $name/"
        skill_count=$((skill_count + 1))
      else
        echo "  [unknown] $name/ (directory, no SKILL.md)"
        unknown_count=$((unknown_count + 1))
      fi
    done
  fi

  # ── Scan commands/ subdirectory ──
  if $has_commands_dir; then
    for item in "$content_dir/commands"/*.md; do
      [[ -f "$item" ]] || continue
      local name
      name="$(basename "$item")"
      should_skip "$name" && continue

      if has_command_frontmatter "$item"; then
        echo "  [command] $name"
        command_count=$((command_count + 1))
      else
        echo "  [unknown] $name (no description frontmatter)"
        unknown_count=$((unknown_count + 1))
      fi
    done
  fi

  # ── Scan root-level directories (skip skills/, commands/, and known skips) ──
  for item in "$content_dir"/*/; do
    [[ -d "$item" ]] || continue
    local name
    name="$(basename "$item")"
    should_skip "$name" && continue
    [[ "$name" == "skills" || "$name" == "commands" ]] && continue

    if [[ -f "$item/SKILL.md" ]]; then
      echo "  [skill]   $name/"
      skill_count=$((skill_count + 1))
    else
      echo "  [unknown] $name/ (directory, no SKILL.md)"
      unknown_count=$((unknown_count + 1))
    fi
  done

  # ── Scan root-level .md files ──
  for item in "$content_dir"/*.md; do
    [[ -f "$item" ]] || continue
    local name
    name="$(basename "$item")"
    should_skip "$name" && continue

    if has_command_frontmatter "$item"; then
      echo "  [command] $name"
      command_count=$((command_count + 1))
    else
      echo "  [unknown] $name (no description frontmatter)"
      unknown_count=$((unknown_count + 1))
    fi
  done

  echo ""
  echo "Found: $skill_count skill(s), $command_count command(s), $unknown_count unknown(s)"

  if [[ $unknown_count -gt 0 ]]; then
    echo ""
    echo "Items marked [unknown] need manual classification."
    echo "Ask the user if each should be imported as a skill or command, or skipped."
  fi
}


# ─── Import Skill ─────────────────────────────────────────────────────────────
# Copies a skill directory from the temp clone into .library/skills/<group>/
import_skill() {
  local tmp_dir="$1"
  local item_name="$2"
  local group="$3"
  local content_dir
  content_dir="$(cat "$tmp_dir/.content-root")"

  # Search for the skill in expected locations
  local src=""
  if [[ "$(basename "$content_dir")" == "$item_name" && -f "$content_dir/SKILL.md" ]]; then
    src="$content_dir"
  elif [[ -d "$content_dir/skills/$item_name" ]]; then
    src="$content_dir/skills/$item_name"
  elif [[ -d "$content_dir/$item_name" ]]; then
    src="$content_dir/$item_name"
  else
    echo "Error: Skill not found: $item_name" >&2
    exit 1
  fi

  local dest_dir="$LIBRARY_SKL_DIR/$group"
  local dest="$dest_dir/$item_name"

  mkdir -p "$dest_dir"

  if [[ -d "$dest" ]]; then
    echo "  Skipped $item_name (already exists in $group)"
    return
  fi

  cp -R "$src" "$dest"
  echo "  Imported $item_name/ -> .library/skills/$group/$item_name/"
}


# ─── Import Command ──────────────────────────────────────────────────────────
# Copies a command .md file from the temp clone into .library/commands/<group>/
import_command() {
  local tmp_dir="$1"
  local item_name="$2"
  local group="$3"
  local content_dir
  content_dir="$(cat "$tmp_dir/.content-root")"

  # Search for the command in expected locations
  local src=""
  if [[ -f "$content_dir/commands/$item_name" ]]; then
    src="$content_dir/commands/$item_name"
  elif [[ -f "$content_dir/$item_name" ]]; then
    src="$content_dir/$item_name"
  else
    echo "Error: Command not found: $item_name" >&2
    exit 1
  fi

  local dest_dir="$LIBRARY_CMD_DIR/$group"
  local dest="$dest_dir/$item_name"

  mkdir -p "$dest_dir"

  if [[ -f "$dest" ]]; then
    echo "  Skipped $item_name (already exists in $group)"
    return
  fi

  cp "$src" "$dest"
  echo "  Imported $item_name -> .library/commands/$group/$item_name"
}


# ─── Suggest Group ────────────────────────────────────────────────────────────
# Extracts a suggested group name from the GitHub URL.
# Uses the subdirectory name if present, otherwise the repo name.
suggest_group() {
  local url="$1"
  parse_github_url "$url" || exit 1

  if [[ -n "$GITHUB_SUBPATH" ]]; then
    basename "$GITHUB_SUBPATH"
  else
    echo "$GITHUB_REPO" | cut -d'/' -f2
  fi
}


# ─── Cleanup ──────────────────────────────────────────────────────────────────
# Removes the temporary clone directory
cleanup() {
  local tmp_dir="$1"

  if [[ ! -d "$tmp_dir" ]]; then
    echo "Warning: Directory not found: $tmp_dir"
    return
  fi

  # Safety: only delete if it matches our temp dir pattern
  if [[ "$tmp_dir" != *"/import-repo-"* ]]; then
    echo "Error: Refusing to delete directory that doesn't match import-repo pattern: $tmp_dir" >&2
    exit 1
  fi

  rm -rf "$tmp_dir"
  echo "Cleaned up temporary files"
}


# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  echo "import-repo.sh — Clone a GitHub repo and import skills/commands into .library/"
  echo ""
  echo "Usage:"
  echo "  bash scripts/import-repo.sh clone <github-url>"
  echo "  bash scripts/import-repo.sh analyze <tmp-dir>"
  echo "  bash scripts/import-repo.sh import-skill <tmp-dir> <item-name> <group>"
  echo "  bash scripts/import-repo.sh import-command <tmp-dir> <item-name> <group>"
  echo "  bash scripts/import-repo.sh suggest-group <github-url>"
  echo "  bash scripts/import-repo.sh cleanup <tmp-dir>"
}


# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
  clone)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    clone_repo "$2"
    ;;
  analyze)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    analyze "$2"
    ;;
  import-skill)
    [[ -z "${2:-}" || -z "${3:-}" || -z "${4:-}" ]] && { usage; exit 1; }
    import_skill "$2" "$3" "$4"
    ;;
  import-command)
    [[ -z "${2:-}" || -z "${3:-}" || -z "${4:-}" ]] && { usage; exit 1; }
    import_command "$2" "$3" "$4"
    ;;
  suggest-group)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    suggest_group "$2"
    ;;
  cleanup)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    cleanup "$2"
    ;;
  *)
    usage
    ;;
esac
