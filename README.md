# subagents

> Personal collection of AI coding subagents for Claude Code, Cursor, Gemini CLI, and Codex.

## About

Subagents are specialised AI assistants that a parent agent delegates
scoped tasks to. Each one runs in its own context window with a focused
system prompt, returns a result, and leaves the main session free to think
about the work that actually matters.

This repo collects the subagents I use day to day. The format is portable —
a single Markdown file with YAML frontmatter — so each one drops into any
of the four major harnesses without modification.

## Quick start

```bash
git clone https://github.com/newtonmunene/subagents.git ~/code/subagents
cd ~/code/subagents
chmod +x install.sh
./install.sh
```

That symlinks every subagent into the agent directories of all four
supported harnesses. To pick a subset, pass harness names:
`./install.sh claude cursor`.

Then invoke from inside the harness — natural language works everywhere:

```
Have the docs-specialist subagent audit the comments and docs in this PR.
```

Or use the harness-specific shortcut (`@docs-specialist` in Claude Code,
`/docs-specialist` in Cursor) if you prefer.

## Subagents

| Name              | What it does                                                         | When to use                                           |
| ----------------- | -------------------------------------------------------------------- | ----------------------------------------------------- |
| `docs-specialist` | Writes, audits, and improves comments, API/symbol docs, and READMEs. | After writing or modifying code; before a docs sweep. |

More to come.

## Installation

`install.sh` symlinks every `*.md` file in the repo root (excluding the
top-level docs listed in its `EXCLUDE` array) into each selected harness's
agent directory:

| Harness     | Install location    |
| ----------- | ------------------- |
| Cursor      | `~/.cursor/agents/` |
| Claude Code | `~/.claude/agents/` |
| Gemini CLI  | `~/.gemini/agents/` |
| Codex       | `~/.codex/agents/`  |

Symlinks (not copies), so a `git pull` in this repo immediately takes
effect everywhere the subagent is installed. The script refuses to
overwrite real files at the target paths — anything you authored by
hand outside this repo is left alone with a warning.

### Common invocations

```bash
./install.sh                       # install to all four harnesses
./install.sh claude cursor         # install to a subset
./install.sh all                   # explicit "all" (same as bare)
./install.sh --dry-run             # preview without changing anything
./install.sh --uninstall           # remove from every harness
./install.sh --uninstall codex     # remove from one harness
./install.sh --help                # full usage
```

Uninstall only removes symlinks that point back into this repo, so it
will never delete subagents you installed from somewhere else.

## Adding a new subagent

1. Create `<name>.md` at the repo root.
2. Add YAML frontmatter with at least `name` and `description`. The
   description is what each harness reads to decide when to delegate,
   so make it specific.
3. Write the system prompt in the body.
4. Re-run `./install.sh` (or the subset variant).

Minimal skeleton:

```markdown
---
name: example
description: One-line summary of what this does and when to invoke it.
model: inherit
---

You are a [role]. Your job is to [scope]...
```

All four harnesses share `name`, `description`, and `model`. Each adds
platform-specific fields — Claude Code and Gemini CLI support `tools`
for fine-grained tool restriction; Cursor supports `readonly` and
`is_background`. The subagents in this repo stick to the shared subset
by default and add platform-specific fields only when they unlock
something materially useful.

## License

[MIT](./LICENSE)
