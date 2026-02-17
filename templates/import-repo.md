---
description: "Import skills and commands from a GitHub repository into .library/"
---

# Import Repo

Clone a GitHub repository and import its skills and commands into the `.library/` system, ready for toggling.

## Instructions

**User input**: `$ARGUMENTS`

The argument should be a GitHub URL. Supported formats:
- `https://github.com/<user>/<repo>` — imports from the repo root
- `https://github.com/<user>/<repo>/tree/<branch>/<path>` — imports from a specific subdirectory

### 1. Clone the repository

```bash
bash scripts/import-repo.sh clone <url>
```

Note the `TMPDIR=` line in the output — you'll need this path for subsequent commands.

### 2. Analyze the contents

```bash
bash scripts/import-repo.sh analyze <tmp-dir>
```

This classifies each item:
- `[skill]` — directory containing a `SKILL.md` file
- `[command]` — `.md` file with YAML frontmatter containing `description:`
- `[unknown]` — needs user input to classify

### 3. Suggest a group name

```bash
bash scripts/import-repo.sh suggest-group <url>
```

Present the suggested group name to the user and ask if they'd like to use it or choose a different one. **Wait for the user's response before proceeding.**

### 4. Handle unknown items

For any items marked `[unknown]`, ask the user:

> I found **\<item-name\>** but couldn't automatically determine if it's a skill or a command.
> Should I import it as a **skill**, a **command**, or **skip** it?

**Wait for the user's response** for each unknown item before proceeding.

### 5. Import items

For each skill:
```bash
bash scripts/import-repo.sh import-skill <tmp-dir> <item-name> <group>
```

For each command:
```bash
bash scripts/import-repo.sh import-command <tmp-dir> <item-name> <group>
```

### 6. Register and enable the group

If skills were imported:
```bash
bash scripts/organize-library.sh register-skill-group <group>
```

If commands were imported:
```bash
bash scripts/organize-library.sh register-command-group <group>
```

> **Note:** The register commands automatically enable the group by creating symlinks in `.claude/`.

### 7. Clean up

```bash
bash scripts/import-repo.sh cleanup <tmp-dir>
```

### 8. Report results

Tell the user:
> Imported **X skill(s)** and **Y command(s)** into the **\<group\>** group.
> Restart Claude Code or run `/clear` for changes to take effect.
> Use `/toggle-skills list` or `/toggle-commands list` to see the updated library.

### If no URL is provided

Tell the user:
> Please provide a GitHub URL. Examples:
> - `/import-repo https://github.com/user/repo`
> - `/import-repo https://github.com/user/repo/tree/main/subdirectory`
