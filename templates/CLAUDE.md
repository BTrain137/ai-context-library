# {{PROJECT_NAME}}

{{Brief description of your project.}}

## AI Context Library

This project uses the **ai-context-library** pattern: `.library/` is the git-tracked source of truth, and `.claude/commands/` + `.claude/skills/` contain only symlinks managed by toggle scripts.

### Key Commands

- `/toggle-commands` — Enable/disable command groups
- `/toggle-skills` — Enable/disable skill groups
- `/organize-library` — Detect and organize files dropped into `.claude/`

### Quick Reference

```bash
bash scripts/toggle-commands.sh list        # Show command group status
bash scripts/toggle-skills.sh list          # Show skill group status
bash scripts/organize-library.sh scan       # Find unorganized files
```

## Notes

{{Add project-specific notes here, e.g.:}}
{{- ExFAT drive: macOS creates `._*` resource fork files — the toggle scripts clean these automatically.}}
{{- Monorepo: scripts assume they're run from the repo root.}}
