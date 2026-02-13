# The `.library` System: Toggleable AI Commands & Skills via Symlinks

A pattern for organizing large collections of AI agent commands and skills into **grouped libraries** that can be toggled on/off instantly — without polluting git history or bloating the AI context window.

> **New here?** Start with the [README](README.md) for the concept overview and motivation behind this pattern.

---

## The Problem

When working with AI coding agents (Claude Code, Cursor, etc.), you accumulate a lot of commands and skills over time:

- **Commands** (slash commands) for workflows like sprint planning, code review, PR creation, brainstorming
- **Skills** (domain knowledge packages) for marketing, SEO, copywriting, analytics, etc.

These all live in directories the AI agent watches (e.g., `.claude/commands/` and `.claude/skills/`). The issues:

1. **Context window bloat** -- Every command/skill description is loaded into the AI's context. 40+ BMAD commands + 15 speckit commands + 25 marketing skills = massive token overhead, even when you only need a few
2. **Git noise** -- Toggling commands on/off by moving files creates constant diffs
3. **Disorganization** -- Flat directories with 80+ files become unmanageable
4. **No grouping** -- Can't enable "all marketing skills" or "all speckit commands" with one action

---

## The Solution: `.library/` + Symlinks

### Core Concept

```
.library/                    ← Committed to git (source of truth)
├── commands/
│   ├── bmad/        (41 commands)
│   ├── speckit/     (15 commands)
│   ├── project/     (toggle commands - always on)
│   └── other/       (PR commands, misc)
└── skills/
    └── marketing/   (25 skills)

.claude/commands/            ← Gitignored (symlinks only)
├── toggle-bmad.md → ../../.library/commands/project/toggle-bmad.md
├── toggle-speckit.md → ../../.library/commands/project/toggle-speckit.md
└── (other active symlinks)

.claude/skills/              ← Gitignored (symlinks only)
├── seo-audit → ../../.library/skills/marketing/seo-audit
├── copywriting → ../../.library/skills/marketing/copywriting
└── (other active symlinks)
```

**Key principles:**
- `.library/` is the **single source of truth**, version-controlled in git
- `.claude/commands/` and `.claude/skills/` are **gitignored** and contain only symlinks
- Toggle scripts create/remove symlinks -- **zero git noise** when enabling/disabling
- The AI only loads what's symlinked, **reducing context window usage**

---

## Directory Structure

### Commands: `.library/commands/`

Commands are organized into **groups**. Each group is a subdirectory containing `.md` files:

```
.library/commands/
├── bmad/                  # BMAD Method workflows (41 commands)
│   ├── bmad-agent-bmad-master.md
│   ├── bmad-bmm-create-prd.md
│   ├── bmad-bmm-sprint-planning.md
│   ├── bmad-brainstorming.md
│   └── ... (41 total)
│
├── speckit/               # SpecKit planning & implementation (15 commands)
│   ├── 00-speckit.constitution.md
│   ├── 01-speckit.ideate.md
│   ├── 02-speckit.specify.md
│   ├── 11-speckit.implement.md
│   └── ... (15 total)
│
├── project/               # Project-level toggles (always active)
│   ├── toggle-bmad.md
│   ├── toggle-speckit.md
│   └── toggle-skills.md
│
└── other/                 # Miscellaneous commands
    ├── 12-create-pr-description.md
    └── 14-create-pr.md
```

### Skills: `.library/skills/`

Skills are organized into **groups** (currently `marketing`). Each skill is a **directory** with a `SKILL.md` and optional `references/`:

```
.library/skills/
└── marketing/             # Marketing skill group (25 skills)
    ├── seo-audit/
    │   ├── SKILL.md
    │   └── references/
    │       ├── ai-writing-detection.md
    │       └── aeo-geo-patterns.md
    ├── copywriting/
    │   ├── SKILL.md
    │   └── references/
    │       ├── copy-frameworks.md
    │       └── natural-transitions.md
    ├── marketing-ideas/
    │   ├── SKILL.md
    │   └── references/
    │       └── ideas-by-category.md
    └── ... (25 total)
```

**Skill anatomy:**
- `SKILL.md` -- Required. YAML frontmatter (`name`, `description`) + markdown instructions. The frontmatter description determines when the AI activates the skill.
- `references/` -- Optional. Detailed reference material loaded on-demand (not into context upfront). Keeps SKILL.md lean while providing deep knowledge when needed.

---

## Toggle Scripts

Two bash scripts manage the symlink lifecycle:

### `scripts/toggle-commands.sh`

Toggles command groups on/off.

```bash
# Enable a group
bash scripts/toggle-commands.sh bmad on
bash scripts/toggle-commands.sh speckit on

# Disable a group
bash scripts/toggle-commands.sh bmad off
bash scripts/toggle-commands.sh speckit off

# List all groups and their status
bash scripts/toggle-commands.sh list
```

**Output example:**
```
=== Command Library ===
  bmad:      0 active / 41 total  [off]
  speckit:   15 active / 15 total [ON]
  project:   3 active / 3 total   [ON]
  other:     2 active / 2 total   [ON]
```

### `scripts/toggle-skills.sh`

Toggles skill groups on/off.

```bash
# Enable marketing skills
bash scripts/toggle-skills.sh marketing on

# Disable marketing skills
bash scripts/toggle-skills.sh marketing off

# List status
bash scripts/toggle-skills.sh list
```

**Output example:**
```
=== Skill Library ===
  marketing:   25 active / 25 total  [ON]
```

### `scripts/organize-library.sh`

Detects real (non-symlink) files dropped into `.claude/` and organizes them into `.library/`.

```bash
# Scan for unorganized items
bash scripts/organize-library.sh scan

# Move a command into a group
bash scripts/organize-library.sh move-command new-tool.md other

# Move a skill into a group
bash scripts/organize-library.sh move-skill my-skill marketing

# Register a brand new group
bash scripts/organize-library.sh register-command-group my-group
bash scripts/organize-library.sh register-skill-group my-group
```

### How the toggle scripts work internally

1. **Enable**: Iterates over files/directories in `.library/commands/<group>/` (or `.library/skills/<group>/`), creates symlinks in `.claude/commands/` (or `.claude/skills/`) pointing back to the library
2. **Disable**: Finds symlinks in `.claude/commands/` (or `.claude/skills/`) that point into the group's library directory and removes them
3. **List**: Counts active symlinks vs total available for each group and displays status
4. **Gitignore**: Ensures `.claude/commands` and `.claude/skills` are in `.gitignore`
5. **Cleanup**: Removes macOS `._*` resource fork files (useful on ExFAT drives)

### How the organize script works internally

1. **Scan**: Tests each file/directory in `.claude/` with `-L` (is symlink?) — reports anything that's a real file
2. **Move**: `mv` the item to `.library/<type>/<group>/`, then `ln -s` a relative symlink in its place
3. **Register**: `mkdir` the group directory, then `sed` a new case into `group_dir()` in the toggle script

---

## Toggle Commands (Slash Commands)

For convenience, toggle commands are exposed as slash commands in the AI agent. These live in `.library/commands/project/` and are always active:

### `/toggle-bmad [on|off|list]`

```markdown
---
description: Toggle bmad commands on or off, or list current status.
---

# Toggle BMAD Commands

Check the user's argument to determine the action:
- "on": runs `bash scripts/toggle-commands.sh bmad on`
- "off": runs `bash scripts/toggle-commands.sh bmad off`
- "list" or empty: runs `bash scripts/toggle-commands.sh list`
```

### `/toggle-speckit [on|off|list]`

Same pattern for speckit commands.

### `/toggle-skills [on|off|list]`

Same pattern for skill groups.

### `/organize-library`

Detects real (non-symlink) files dropped into `.claude/commands/` or `.claude/skills/`, then interactively moves them into `.library/` with proper symlinks. See the Organize Script section below.

---

## Organize Script

### The problem it solves

When you download, create, or receive a new command or skill file, it lands as a **real file** in `.claude/commands/` or `.claude/skills/`. That breaks the symlink pattern:

- It's not stored in `.library/` (so it's not in git)
- It won't survive a toggle off/on cycle (real files get deleted when `disable_group` removes by symlink check)
- It creates git noise if `.claude/` directories aren't fully gitignored

### `scripts/organize-library.sh`

Five subcommands:

```bash
# Scan — find unorganized real files
bash scripts/organize-library.sh scan

# Move a command file into a group
bash scripts/organize-library.sh move-command new-workflow.md my-workflows

# Move a skill directory into a group
bash scripts/organize-library.sh move-skill seo-audit marketing

# Register a new command group (creates dir + updates toggle-commands.sh)
bash scripts/organize-library.sh register-command-group my-workflows

# Register a new skill group (creates dir + updates toggle-skills.sh)
bash scripts/organize-library.sh register-skill-group devops
```

### How `scan` works

1. Iterates over `.claude/commands/*.md` — skips symlinks (`-L` test), reports real files
2. Iterates over `.claude/skills/*/` — skips symlink directories, reports real directories
3. Ignores `._*` macOS resource fork files
4. Lists available groups from `.library/commands/` and `.library/skills/`

### How `move-command` works

1. Validates the file exists and is not already a symlink
2. Validates the target group directory exists in `.library/commands/`
3. Checks for name collisions in the destination
4. `mv` the file to `.library/commands/<group>/`
5. `ln -s` a relative symlink in `.claude/commands/` pointing back to `.library/`

### How `register-*-group` works

1. Creates the `.library/commands/<name>/` (or `.library/skills/<name>/`) directory
2. Uses `sed` to insert a new case into the `group_dir()` function in the toggle script
3. Warns that you may need to manually add the group to `list_groups()` if it uses a hardcoded loop

### The `/organize-library` slash command

The template (`templates/organize-library.md`) instructs the AI to:

1. Run `scan` to detect unorganized items
2. For each item, ask the user which group to file it under
3. Register new groups if needed
4. Move items and create symlinks
5. Enable the group with the toggle script
6. Run a final `scan` to confirm everything is organized

### Organize Library skill

The template (`templates/organize-library-skill/`) provides an optional skill that gives the AI deep context about the library pattern. Place it in `.library/skills/<group>/organize-library/` and symlink it when you want the AI to understand the library system at a deeper level.

---

## Setup Guide

### Step 1: Create the directory structure

```bash
mkdir -p .library/commands/{bmad,speckit,project,other}
mkdir -p .library/skills/marketing
```

### Step 2: Move your commands into groups

Move command files from `.claude/commands/` into the appropriate `.library/commands/<group>/` directory:

```bash
# Example: move all bmad-* commands
mv .claude/commands/bmad-*.md .library/commands/bmad/

# Example: move speckit commands
mv .claude/commands/*speckit*.md .library/commands/speckit/
```

### Step 3: Move your skills into groups

Move skill directories from `.claude/skills/` into `.library/skills/<group>/`:

```bash
# Example: move all marketing skills
mv .claude/skills/seo-audit .library/skills/marketing/
mv .claude/skills/copywriting .library/skills/marketing/
# ... etc
```

### Step 4: Create the toggle scripts

Create `scripts/toggle-commands.sh` and `scripts/toggle-skills.sh`. The scripts should:

1. Accept a group name and action (`on`/`off`/`list`)
2. Map group names to `.library/` subdirectories
3. Create symlinks (enable) or remove symlinks (disable) in `.claude/` directories
4. Ensure `.claude/commands` and `.claude/skills` are in `.gitignore`

See the reference implementations below for the full scripts.

### Step 5: Create toggle slash commands

Create files in `.library/commands/project/` for each toggle:
- `toggle-bmad.md`
- `toggle-speckit.md`
- `toggle-skills.md`

Each one instructs the AI to run the appropriate toggle script based on the user's argument.

### Step 6: Update `.gitignore`

```gitignore
# AI agent runtime directories (symlinks only, managed by toggle scripts)
.claude/commands
.claude/skills
.claude/commands-disabled
```

### Step 7: Remove old files from git tracking

If commands/skills were previously tracked by git:

```bash
git rm -r --cached .claude/commands/ .claude/commands-disabled/ .claude/skills/ 2>/dev/null
```

### Step 8: Bootstrap the symlinks

Enable the groups you want active:

```bash
# Always-on project toggles
bash scripts/toggle-commands.sh project on
bash scripts/toggle-commands.sh other on

# Optional: enable what you need right now
bash scripts/toggle-commands.sh speckit on
bash scripts/toggle-skills.sh marketing on
```

### Step 9: Restart your AI agent

Run `/clear` or restart the AI agent session for changes to take effect.

---

## How It Reduces AI Context

### Before (everything loaded)

```
Context window usage:
  41 BMAD commands        ~12,000 tokens (descriptions)
  15 SpecKit commands     ~4,500 tokens
  25 Marketing skills     ~7,500 tokens (descriptions only)
  ─────────────────────
  Total overhead:         ~24,000 tokens ALWAYS loaded
```

### After (toggle what you need)

```
Context window usage (marketing day):
  3 Project toggles       ~900 tokens
  25 Marketing skills     ~7,500 tokens
  ─────────────────────
  Total overhead:         ~8,400 tokens (65% reduction)

Context window usage (dev sprint):
  3 Project toggles       ~900 tokens
  15 SpecKit commands     ~4,500 tokens
  ─────────────────────
  Total overhead:         ~5,400 tokens (77% reduction)
```

The AI agent only sees what's symlinked. Disabled groups consume **zero tokens**.

---

## Reference Implementation: `toggle-commands.sh`

```bash
#!/usr/bin/env bash
# Toggle command groups on/off by creating/removing symlinks.
# Source of truth: .library/commands/<group>/<file>.md
# Symlinks:       .claude/commands/<file>.md → ../../.library/commands/<group>/<file>.md

set -uo pipefail

COMMANDS_DIR=".claude/commands"
LIBRARY_DIR=".library/commands"

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

    [ -L "$link" ] && continue          # skip existing symlinks
    [ -e "$link" ] && rm "$link"        # remove conflicting files

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
    if [[ "$target" == *"$src_dir"* ]]; then
      rm "$link"
      count=$((count + 1))
    fi
  done
  echo "Disabled $count $group commands (symlinks removed)"
}
```

## Reference Implementation: `toggle-skills.sh`

```bash
#!/usr/bin/env bash
# Toggle skill groups on/off by creating/removing symlinks.
# Source of truth: .library/skills/<group>/<skill>/
# Symlinks:       .claude/skills/<skill> → ../../.library/skills/<group>/<skill>

set -uo pipefail

SKILLS_DIR=".claude/skills"
LIBRARY_DIR=".library/skills"

mkdir -p "$SKILLS_DIR"

# Map group name to library subdirectory
group_dir() {
  case "$1" in
    marketing) echo "$LIBRARY_DIR/marketing" ;;
    *)         echo "" ;;
  esac
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

    [ -L "$link" ] && continue
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
```

## Reference Implementation: `organize-library.sh`

```bash
#!/usr/bin/env bash
# Detect and organize real files dropped into .claude/
# Moves them into .library/ and creates symlinks in their place.

set -euo pipefail

LIBRARY_CMD_DIR=".library/commands"
LIBRARY_SKL_DIR=".library/skills"
CLAUDE_CMD_DIR=".claude/commands"
CLAUDE_SKL_DIR=".claude/skills"

# Scan for real (non-symlink) files in .claude/ directories
scan() {
  local found=0
  echo "Scanning for unorganized items..."

  if [[ -d "$CLAUDE_CMD_DIR" ]]; then
    for file in "$CLAUDE_CMD_DIR"/*.md; do
      [[ -f "$file" ]] || continue
      [[ -L "$file" ]] && continue
      local name=$(basename "$file")
      [[ "$name" == "._"* ]] && continue
      echo "  [command] $name (real file)"
      found=$((found + 1))
    done
  fi

  if [[ -d "$CLAUDE_SKL_DIR" ]]; then
    for dir in "$CLAUDE_SKL_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      [[ -L "${dir%/}" ]] && continue
      local name=$(basename "$dir")
      [[ "$name" == "._"* ]] && continue
      echo "  [skill]   $name/ (real directory)"
      found=$((found + 1))
    done
  fi

  echo "$found unorganized item(s) found"
}

# Move a command file into .library/ and create symlink
move_command() {
  local file="$1" group="$2"
  mv "$CLAUDE_CMD_DIR/$file" "$LIBRARY_CMD_DIR/$group/$file"
  ln -s "../../.library/commands/$group/$file" "$CLAUDE_CMD_DIR/$file"
}

# Move a skill directory into .library/ and create symlink
move_skill() {
  local name="$1" group="$2"
  mv "$CLAUDE_SKL_DIR/$name" "$LIBRARY_SKL_DIR/$group/$name"
  ln -s "../../.library/skills/$group/$name" "$CLAUDE_SKL_DIR/$name"
}

# Register a new group in a toggle script's group_dir() function
register_command_group() {
  local name="$1"
  mkdir -p "$LIBRARY_CMD_DIR/$name"
  # Insert case entry before the wildcard in toggle-commands.sh
  sed -i '' "s|^\(    \*) .*echo.*\)|    $name) echo \"\$LIBRARY_DIR/$name\" ;;\n\1|" \
    scripts/toggle-commands.sh
}
```

The full version (in `scripts/organize-library.sh`) adds error handling, duplicate detection, and a `register-skill-group` subcommand.

---

## Adding New Groups

### Automated (via organize script)

```bash
# Register a new command group — creates dir + updates toggle-commands.sh
bash scripts/organize-library.sh register-command-group my-group

# Register a new skill group — creates dir + updates toggle-skills.sh
bash scripts/organize-library.sh register-skill-group my-group
```

**Note**: The `register` commands update `group_dir()` automatically. You may still need to add the group to `list_groups()` manually if it uses a hardcoded loop.

### Manual

#### New command group

1. Create the directory: `mkdir -p .library/commands/my-group/`
2. Add your `.md` command files there
3. Add a case to `group_dir()` in `toggle-commands.sh`:
   ```bash
   my-group) echo "$LIBRARY_DIR/my-group" ;;
   ```
4. Add `my-group` to the `list_groups()` loop
5. Optionally create a `/toggle-my-group` slash command in `.library/commands/project/`

#### New skill group

1. Create the directory: `mkdir -p .library/skills/my-group/`
2. Add your skill directories (each with a `SKILL.md`)
3. Add a case to `group_dir()` in `toggle-skills.sh`:
   ```bash
   my-group) echo "$LIBRARY_DIR/my-group" ;;
   ```
4. Add `my-group` to the `list_groups()` loop

---

## Troubleshooting

### Symlinks not working after toggle

Run `/clear` or restart the AI agent session. The agent reads commands/skills at session start.

### macOS resource fork files (`._*`)

On ExFAT/FAT32 drives, macOS creates `._*` resource fork files. The toggle scripts clean these up automatically with:
```bash
dot_clean "$DIR" 2>/dev/null
find "$DIR" -name '._*' -delete 2>/dev/null
```

### Previously tracked files still showing in `git status`

If `.claude/commands/` or `.claude/skills/` were tracked before being gitignored:
```bash
git rm -r --cached .claude/commands/ .claude/skills/ 2>/dev/null
```

### Symlink path is wrong

Symlinks use relative paths. From `.claude/commands/`, the path to `.library/commands/` is:
```
../../.library/commands/<group>/<file>.md
```
This works because: `.claude/commands/` → go up to `.claude/` → go up to project root → `.library/...`

---

## Evolution History

This system evolved through several iterations:

1. **V1 -- Flat files**: All commands lived directly in `.claude/commands/`. No grouping, no toggling. Every command loaded into every session.

2. **V2 -- Disabled directory**: Commands moved between `.claude/commands/` and `.claude/commands-disabled/` to toggle. Skills moved between `.claude/skills/` and `.claude/skills/_disabled/`. Problem: constant git diffs from file moves.

3. **V3 -- Symlink library (current)**: Source of truth moved to `.library/`. Runtime directories gitignored. Symlinks for toggling. Zero git noise, instant enable/disable, clean organization by group.

---

## Quick Reference

| Action | Command |
|--------|---------|
| Enable BMAD commands | `bash scripts/toggle-commands.sh bmad on` |
| Disable BMAD commands | `bash scripts/toggle-commands.sh bmad off` |
| Enable SpecKit commands | `bash scripts/toggle-commands.sh speckit on` |
| Disable SpecKit commands | `bash scripts/toggle-commands.sh speckit off` |
| Enable marketing skills | `bash scripts/toggle-skills.sh marketing on` |
| Disable marketing skills | `bash scripts/toggle-skills.sh marketing off` |
| List all statuses | `bash scripts/toggle-commands.sh list && bash scripts/toggle-skills.sh list` |
| Scan for unorganized files | `bash scripts/organize-library.sh scan` |
| Move command to group | `bash scripts/organize-library.sh move-command file.md group` |
| Move skill to group | `bash scripts/organize-library.sh move-skill skill-name group` |
| Register new command group | `bash scripts/organize-library.sh register-command-group name` |
| Register new skill group | `bash scripts/organize-library.sh register-skill-group name` |
| Via slash commands | `/toggle-bmad on`, `/toggle-speckit off`, `/toggle-skills on`, `/organize-library` |
