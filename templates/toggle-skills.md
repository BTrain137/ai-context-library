---
description: Toggle marketing skills on or off, or list current status.
---

# Toggle Skills

Enable or disable marketing skills independently.

## Instructions

Check the user's argument to determine the action:

**User input**: `$ARGUMENTS`

### If argument is "on":

```bash
bash scripts/toggle-skills.sh marketing on
```

Tell the user:
> Marketing skills enabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "off":

```bash
bash scripts/toggle-skills.sh marketing off
```

Tell the user:
> Marketing skills disabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "list" (or empty/missing):

```bash
bash scripts/toggle-skills.sh list
```
