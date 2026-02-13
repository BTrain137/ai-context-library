# Organize Library Skill

You have deep knowledge of the ai-context-library pattern used in this project. This skill provides context for organizing commands and skills into the `.library/` system.

## Pattern Overview

- **`.library/`** is the git-tracked source of truth for all AI context (commands and skills)
- **`.claude/commands/`** and **`.claude/skills/`** are gitignored runtime directories containing **only symlinks**
- **Toggle scripts** (`scripts/toggle-commands.sh`, `scripts/toggle-skills.sh`) manage which groups are active by creating/removing symlinks
- **`scripts/organize-library.sh`** detects real files in the runtime directories and moves them into `.library/`

## When This Skill Applies

Activate this skill when the user:
- Drops new command/skill files into `.claude/` directories
- Asks about organizing or managing their AI context library
- Wants to create new groups or reorganize existing ones
- Encounters issues with symlinks, toggle scripts, or the library structure

## Key Conventions

### Command Files
- Always `.md` format with YAML frontmatter containing a `description` field
- Live in `.library/commands/<group>/<name>.md`
- Symlinked as `.claude/commands/<name>.md` -> `../../.library/commands/<group>/<name>.md`

### Skill Directories
- Each skill is a directory with at least `SKILL.md`
- Live in `.library/skills/<group>/<skill-name>/`
- Symlinked as `.claude/skills/<skill-name>` -> `../../.library/skills/<group>/<skill-name>`
- May contain a `references/` subdirectory for supporting docs

### Group Registry
- Groups are registered in the `group_dir()` case statement within each toggle script
- May also be in an `ALL_GROUPS` array or hardcoded in `list_groups()`
- `organize-library.sh register-command-group` and `register-skill-group` handle the `group_dir()` update automatically
- After registering, manually verify the `list_groups()` loop includes the new group

## Edge Cases

- **Duplicate names**: If a file with the same name exists in `.library/`, the move will fail. Rename before moving.
- **Missing SKILL.md**: Skill directories without `SKILL.md` will still work as symlinks but won't be loaded by Claude Code as skills.
- **ExFAT `._*` files**: The toggle scripts clean these automatically. They're harmless macOS resource fork artifacts.
- **Broken symlinks**: If `.library/` content is moved/deleted without updating symlinks, run the toggle script again (`<group> on`) to recreate them.
- **`.skill` packages**: Zip-packaged skills (`.skill` files) should be extracted into a directory before organizing.
