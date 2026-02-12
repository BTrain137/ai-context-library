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

### How the scripts work internally

1. **Enable**: Iterates over files/directories in `.library/commands/<group>/` (or `.library/skills/<group>/`), creates symlinks in `.claude/commands/` (or `.claude/skills/`) pointing back to the library
2. **Disable**: Finds symlinks in `.claude/commands/` (or `.claude/skills/`) that point into the group's library directory and removes them
3. **List**: Counts active symlinks vs total available for each group and displays status
4. **Gitignore**: Ensures `.claude/commands` and `.claude/skills` are in `.gitignore`
5. **Cleanup**: Removes macOS `._*` resource fork files (useful on ExFAT drives)

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

---

## Adding New Groups

### New command group

1. Create the directory: `mkdir -p .library/commands/my-group/`
2. Add your `.md` command files there
3. Add a case to `group_dir()` in `toggle-commands.sh`:
   ```bash
   my-group) echo "$LIBRARY_DIR/my-group" ;;
   ```
4. Add `my-group` to the `list_groups()` loop
5. Optionally create a `/toggle-my-group` slash command in `.library/commands/project/`

### New skill group

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
| Via slash commands | `/toggle-bmad on`, `/toggle-speckit off`, `/toggle-skills on` |
