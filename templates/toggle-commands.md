---
description: Toggle command groups on or off, or list current status.
---

# Toggle Commands

Enable or disable command groups independently.

## Instructions

Check the user's argument to determine the action:

**User input**: `$ARGUMENTS`

### If argument is "on" followed by a group name (e.g., "on my-group"):

```bash
bash scripts/toggle-commands.sh <group> on
```

Tell the user:
> <group> commands enabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "off" followed by a group name (e.g., "off my-group"):

```bash
bash scripts/toggle-commands.sh <group> off
```

Tell the user:
> <group> commands disabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "list" (or empty/missing):

```bash
bash scripts/toggle-commands.sh list
```
