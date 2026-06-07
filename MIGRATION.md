# Migration: dotfiles → agent-configs

The Claude Code, OpenCode, ccstatusline, and pi configuration used to live in
[dotfiles](https://github.com/John-Lin/dotfiles). It now lives in this repo.

On a machine that already installed the old dotfiles, the home-directory
symlinks still point into `dotfiles/` and will dangle once you pull the dotfiles
change that removes those directories. This guide re-points them at this repo.

## What actually moved

Only **symlinks** break — they pointed into the old `dotfiles/` tree:

| Path | Old target | New target |
|------|------------|------------|
| `~/.claude/agents` | `dotfiles/claude/.claude/agents` | `agent-configs/claude/.claude/agents` |
| `~/.claude/skills` | `dotfiles/claude/.claude/skills` | `agent-configs/claude/.claude/skills` |
| `~/.config/opencode/agents` | `dotfiles/opencode/agents` | `agent-configs/opencode/agents` |
| `~/.config/ccstatusline/settings.json` | `dotfiles/ccstatusline/...` | `agent-configs/ccstatusline/...` |

These are **not** affected by the repo split and need no migration:

- `~/.claude/settings.json` and `~/.config/opencode/opencode.json` are generated
  regular files, not symlinks. They contain no repo paths, so they keep working as-is.

Note: the shared instructions now use the AGENTS.md model — the canonical file is
the real `~/.pi/agent/AGENTS.md`, and `~/.claude/CLAUDE.md` /
`~/.config/opencode/AGENTS.md` symlink to it. Running `make sync-claude` /
`sync-opencode` / `sync-pi` sets this up; see `docs/ai.md`.

## Prerequisites

```bash
# Clone this repo (anywhere; examples below assume ~/workspace/agent-configs)
git clone git@github.com:John-Lin/agent-configs.git ~/workspace/agent-configs

# Pull the dotfiles change that drops the AI directories
cd ~/dotfiles && git pull
```

Copy your gitignored personal files onto the new machine if you use them:

- `claude/.claude/AGENTS.personal.md`
- `claude/claude_settings.personal.json`
- `jsonnet/opencode_work.libsonnet` (work overlay, kept outside the repo)

## Option A — Re-point the symlinks (minimal, no regeneration)

This is the lowest-risk path: it only swaps the four symlinks and never touches
your generated `CLAUDE.md` / `settings.json` / `opencode.json`. Use it if you've
hand-tuned any of those files.

```bash
AGENT_CONFIGS=~/workspace/agent-configs   # adjust to where you cloned it

ln -snf "$AGENT_CONFIGS/claude/.claude/agents"  ~/.claude/agents
ln -snf "$AGENT_CONFIGS/claude/.claude/skills"  ~/.claude/skills
ln -snf "$AGENT_CONFIGS/opencode/agents"        ~/.config/opencode/agents

# ccstatusline is stow-managed; re-create via stow so the link matches the repo
rm -f ~/.config/ccstatusline/settings.json
( cd "$AGENT_CONFIGS" && stow -t ~ ccstatusline )
```

## Option B — Full re-install via make

Re-manages everything from this repo, regenerating the merged files too. Cleaner
provenance, but it will refuse (or with `-force`, overwrite) any generated file
that has drifted from the repo — see the warning below.

```bash
cd ~/workspace/agent-configs

# Remove the stale symlinks first (make refuses to clobber unmanaged symlinks)
rm -f ~/.claude/agents ~/.claude/skills ~/.config/opencode/agents ~/.config/ccstatusline/settings.json

make sync-claude         # ~/.claude/{agents,skills} + regenerate CLAUDE.md, settings.json
make sync-ccstatusline   # ~/.config/ccstatusline/settings.json
make sync-opencode       # ~/.config/opencode/agents + regenerate opencode.json
make sync-pi             # regenerate canonical ~/.pi/agent/AGENTS.md + inject packages
```

> **If `sync-claude` or `sync-opencode` stops with "already exists with different
> contents":** your live `~/.claude/CLAUDE.md` / `settings.json` /
> `~/.config/opencode/opencode.json` has drifted from what the repo generates
> (e.g. settings you changed by hand). That's the conservative guard working.
> Reconcile the difference, or run the matching `-force` target
> (`make sync-claude-force` / `make sync-opencode-force`) to replace the live
> file with the repo's version. `-force` discards your local edits to those
> generated files.

## Verify

```bash
for p in ~/.claude/agents ~/.claude/skills \
         ~/.config/opencode/agents ~/.config/ccstatusline/settings.json; do
  printf '%-42s -> %s  [%s]\n' "$p" "$(readlink "$p")" \
    "$([ -e "$p" ] && echo OK || echo DANGLING)"
done
```

Every line should read `OK` and point into `agent-configs/`.

## Optional cleanup

Old backup files left behind by earlier installs are safe to remove once you've
confirmed the migration:

```bash
rm -f ~/.config/ccstatusline/settings.json.bak.* \
      ~/.config/opencode/opencode.json.bak.* \
      ~/.claude/settings.json.bak ~/.claude/settings.json.orig
```
