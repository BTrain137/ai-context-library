---
description: "Organize untracked files into the .library/ system"
---

# Organize Library

Detect real (non-symlink) files dropped into `.claude/commands/` or `.claude/skills/`, then move them into `.library/` and create proper symlinks.

## Instructions

When the user invokes this command:

### 1. Scan for unorganized items
```bash
bash scripts/organize-library.sh scan
```

### 2. If items are found, for each one:

**For command files (.md):**
- Show the filename and ask which group to file it under
- If the user wants a new group, register it first:
  ```bash
  bash scripts/organize-library.sh register-command-group <name>
  ```
- Move the file:
  ```bash
  bash scripts/organize-library.sh move-command <file.md> <group>
  ```

**For skill directories:**
- Show the directory name and ask which group to file it under
- If the user wants a new group, register it first:
  ```bash
  bash scripts/organize-library.sh register-skill-group <name>
  ```
- Move the skill:
  ```bash
  bash scripts/organize-library.sh move-skill <dir-name> <group>
  ```

### 3. Confirm with a final scan
```bash
bash scripts/organize-library.sh scan
```
Should report "0 unorganized items found".

> **Note:** Groups are auto-enabled when registered. The `register-command-group` and `register-skill-group` commands automatically create symlinks in `.claude/` after creating the group directory.

### 4. If no items found
Report that everything is already organized and suggest using `/toggle-commands` or `/toggle-skills` to manage active groups.
