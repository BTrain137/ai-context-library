# Library Structure Reference

## Directory Layout

```
.library/                          # Git-tracked source of truth
├── commands/
│   └── <group>/                   # e.g., project, workflows, debugging
│       ├── <command-name>.md      # Slash command file
│       └── ...
└── skills/
    └── <group>/                   # e.g., development, marketing, devops
        └── <skill-name>/          # Skill directory
            ├── SKILL.md           # Required — skill definition
            └── references/        # Optional — supporting documents
                └── *.md

.claude/
├── commands/                      # Gitignored — symlinks only at runtime
│   ├── <command>.md -> ../../.library/commands/<group>/<command>.md
│   └── ...
└── skills/                        # Gitignored — symlinks only at runtime
    ├── <skill> -> ../../.library/skills/<group>/<skill>
    └── ...

scripts/
├── toggle-commands.sh             # Enable/disable command groups
├── toggle-skills.sh               # Enable/disable skill groups
└── organize-library.sh            # Detect + move real files into .library/
```

## Symlink Conventions

All symlinks use **relative paths** from their location in `.claude/`:

| Type | Symlink location | Target |
|------|-----------------|--------|
| Command | `.claude/commands/<name>.md` | `../../.library/commands/<group>/<name>.md` |
| Skill | `.claude/skills/<name>` | `../../.library/skills/<group>/<name>` |

The `../../` prefix navigates from `.claude/commands/` (or `.claude/skills/`) up to the repo root, then into `.library/`.

## Toggle Script Registry Format

Each toggle script contains a `group_dir()` case statement that maps group names to library paths:

```bash
group_dir() {
  case "$1" in
    group-a)  echo "$LIBRARY_DIR/group-a" ;;
    group-b)  echo "$LIBRARY_DIR/group-b" ;;
    *)        echo "" ;;
  esac
}
```

Some implementations also use an `ALL_GROUPS` array for the listing function. Both must be updated when adding a new group.

The `organize-library.sh register-*-group` commands update `group_dir()` automatically via `sed`.

## Command File Format

```markdown
---
description: "Short description shown in /help"
---

# Command Title

Instructions for Claude when the command is invoked.
```

The YAML frontmatter `description` field is required for the command to appear in Claude Code's help listing.

## Skill Directory Format

```
<skill-name>/
├── SKILL.md           # Required — loaded when skill is active
└── references/        # Optional
    └── *.md           # Supporting context documents
```

`SKILL.md` should describe when the skill applies and what knowledge it provides. Reference documents provide deeper context that Claude can consult as needed.

## Organize Workflow

When a real (non-symlink) file appears in `.claude/commands/` or `.claude/skills/`:

1. `scan` detects it as unorganized
2. User picks a target group (or creates one with `register-*-group`)
3. `move-command` or `move-skill` moves it to `.library/` and creates a symlink
4. Toggle script enables the group if not already active
5. Final `scan` confirms 0 unorganized items remain
