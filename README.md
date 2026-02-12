# Stop Feeding Your AI Agent a Buffet When It Only Needs a Snack

**The `.library` Pattern: How to cut 60-75% of wasted AI context tokens with a single Unix trick**

---

> You installed 40 commands, 15 workflow tools, and 25 domain skills into your AI coding agent. Congrats -- you just burned 24,000 tokens before writing a single line of code.

If you use Claude Code, Cursor, or any AI coding agent with custom commands and skills, you've probably hit this wall: your context window fills up faster than it should, your agent starts losing track of things, and you're paying for tokens that do nothing.

The problem isn't the AI. It's that you're loading **everything** into **every** session.

---

## The Real Cost of "Always On"

Let's do the math.

A typical power-user setup for Claude Code or Cursor might look like this:

| What's loaded | Count | Tokens (approx.) |
|---------------|-------|-------------------|
| BMAD workflow commands | 41 | ~12,000 |
| SpecKit planning commands | 15 | ~4,500 |
| Marketing skills | 25 | ~7,500 |
| **Total overhead** | **81 items** | **~24,000 tokens** |

That's **12% of your usable context window** gone before you type "hello."

With Claude Code Pro at $20/month giving you 10-40 real prompts per 5-hour window, and Cursor Pro giving 500 fast requests per month -- every wasted token counts. Context bloat means:

- Hitting the 80% threshold faster (where performance degrades)
- More `/compact` runs and session restarts
- The AI "forgetting" important project details because command descriptions are eating the space
- Higher costs on pay-per-token plans ($3-15 per million tokens)

One developer on Reddit put it bluntly: the context limit should be _"three times larger to consider coding with it truly comfortable."_ But you don't need a bigger window. You need to stop wasting the one you have.

---

## The Pattern: `.library/` + Symlinks

The fix borrows from a decades-old Unix pattern: **symlink farms** -- the same approach tools like GNU Stow use for dotfile management.

Instead of dumping every command and skill into the AI's watched directories, you:

1. **Store everything** in a `.library/` directory, organized by group
2. **Gitignore** the AI's runtime directories (`.claude/commands/`, `.claude/skills/`)
3. **Symlink only what you need** into those directories with toggle scripts

```
.library/                    <-- git-tracked source of truth
├── commands/
│   ├── bmad/        (41 commands)
│   ├── speckit/     (15 commands)
│   ├── project/     (toggles -- always on)
│   └── other/       (misc utilities)
└── skills/
    └── marketing/   (25 skills)

.claude/commands/            <-- gitignored, symlinks only
.claude/skills/              <-- gitignored, symlinks only
```

Toggle a group on? Symlinks appear. Toggle it off? Symlinks vanish. Zero files move. Zero git diffs. The AI only loads what's linked.

---

## Before vs. After

### Marketing Monday

You're writing landing page copy. You need marketing skills, not sprint planning tools.

**Before**: 24,000 tokens of overhead. AI context cluttered with `bmad-bmm-sprint-planning` and `speckit.implement` descriptions it will never use today.

**After**:

```bash
bash scripts/toggle-skills.sh marketing on    # 25 skills activated
bash scripts/toggle-commands.sh bmad off       # 41 commands deactivated
bash scripts/toggle-commands.sh speckit off    # 15 commands deactivated
```

**Result**: ~8,700 tokens of overhead. **64% reduction.**

### Dev Sprint Wednesday

You're implementing features. You need SpecKit, not SEO audit skills.

```bash
bash scripts/toggle-commands.sh speckit on     # 15 commands activated
bash scripts/toggle-skills.sh marketing off    # 25 skills deactivated
```

**Result**: ~5,700 tokens of overhead. **76% reduction.**

### Brainstorming Friday

You're in product planning mode. You need BMAD, nothing else.

```bash
bash scripts/toggle-commands.sh bmad on
bash scripts/toggle-commands.sh speckit off
bash scripts/toggle-skills.sh marketing off
```

**Result**: ~13,200 tokens. Still 45% less than loading everything.

---

## How It Actually Works (5-Minute Setup)

### 1. Organize your library

```bash
mkdir -p .library/commands/{my-workflows,my-tools,project}
mkdir -p .library/skills/{marketing,devops}
```

Move your command `.md` files and skill directories into their groups.

### 2. Create the toggle script

The core logic is ~30 lines of bash. Here's the gist:

```bash
# Enable: create symlinks from .claude/commands/ → .library/commands/<group>/
enable_group() {
  for f in ".library/commands/$1"/*.md; do
    ln -s "../../.library/commands/$1/$(basename $f)" ".claude/commands/$(basename $f)"
  done
}

# Disable: remove symlinks that point into the group
disable_group() {
  for link in .claude/commands/*.md; do
    [ -L "$link" ] && [[ "$(readlink $link)" == *"$1"* ]] && rm "$link"
  done
}
```

### 3. Gitignore the runtime directories

```gitignore
.claude/commands
.claude/skills
```

### 4. Create slash commands for toggling

Make a file `.library/commands/project/toggle-my-workflows.md`:

```markdown
---
description: Toggle my-workflows commands on or off.
---
# Toggle My Workflows
Run: `bash scripts/toggle-commands.sh my-workflows $ARGUMENTS`
```

Now you can type `/toggle-my-workflows on` or `/toggle-my-workflows off` right inside your AI agent.

### 5. Restart and go

Run `/clear` or restart your session. Only the symlinked commands/skills load.

> **Want the full details?** See [GUIDE.md](GUIDE.md) for the complete directory structure, reference implementations of both toggle scripts, troubleshooting, and instructions for adding new groups.

---

## Why Symlinks and Not Just Deleting Files?

| Approach | Git noise | Speed | Reversible | Tracks changes |
|----------|-----------|-------|------------|----------------|
| Move files between dirs | Diff on every toggle | Fast | Yes | Messy history |
| Delete & recreate | Diff on every toggle | Slow | Risky | Lost history |
| **Symlinks to `.library/`** | **None** | **Instant** | **Yes** | **Clean history** |

The `.library/` directory is your single source of truth. It's committed to git. You can edit commands, review changes in PRs, share them across machines -- all the normal git things. The symlinks are ephemeral runtime wiring.

This is the same pattern the Unix world has used for decades with GNU Stow, `dotbot`, and similar tools. It works because symlinks are cheap, instant, and invisible to git when the target directory is ignored.

---

## The Skill Architecture

Skills are more than just a markdown file. Each skill is a self-contained package:

```
seo-audit/
├── SKILL.md              # Instructions + YAML frontmatter (triggers activation)
└── references/           # Deep knowledge, loaded on-demand
    ├── ai-writing-detection.md
    └── aeo-geo-patterns.md
```

The `SKILL.md` frontmatter is what the AI reads to decide _when_ to activate the skill. The references are only loaded _after_ activation. This two-tier design keeps the upfront token cost minimal -- the AI sees a short description, not the entire SEO playbook.

With 25 marketing skills, the descriptions might cost ~7,500 tokens total when enabled. But each individual skill's deep reference material (often 2,000-5,000 tokens per reference) only loads when relevant. That's a massive difference from putting everything in `CLAUDE.md`.

---

## When You Should Use This Pattern

You probably need this if:

- You have **10+ commands or skills** installed in your AI agent
- You notice **context filling up faster** than expected on complex tasks
- You use **different tool sets** on different days (dev vs. marketing vs. planning)
- You work on a **team** and want to share commands/skills via git without everyone loading everything
- You're on a **metered plan** and want to stretch your token budget

You probably don't need this if:

- You have fewer than 10 commands and they're all relevant to every session
- You only use one workflow tool set

---

## Take It Further

Some ideas if you want to build on this:

- **Per-project profiles**: A `.library-profile` file that auto-enables the right groups when you `cd` into a project
- **Team libraries**: A shared `.library/` in a monorepo where each team has their own group
- **Cross-repo skills**: A separate git repo of skills, cloned into `.library/skills/` as a submodule
- **Automatic context budgeting**: A script that checks your current context usage and suggests which groups to disable

---

## TL;DR

1. Your AI agent loads every command and skill description into its context window -- even the ones you don't need right now
2. This wastes 12-25% of your usable context on overhead
3. The `.library/` pattern stores everything in a git-tracked directory and uses symlinks to activate only what you need
4. Toggle scripts let you switch tool sets in seconds -- via slash commands inside the AI itself
5. Result: 60-76% reduction in wasted context tokens, cleaner git history, and an AI that stays focused on what matters

---

_Built during late-night sessions with Claude Code. The irony of using an AI agent to build a system that makes AI agents work better is not lost on me._
