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
`~/.config/opencode/AGENTS.md` symlink to it. A machine set up before that change
(its `~/.claude/CLAUDE.md` is a real file, with `~/.pi/agent/AGENTS.md` pointing
back at it) needs the separate steps in
[Migration: CLAUDE.md → canonical AGENTS.md](#migration-claudemd--canonical-agentsmd-pi-owned)
below.

## Prerequisites

```bash
# Clone this repo (anywhere; examples below assume ~/workspace/agent-configs)
git clone git@github.com:John-Lin/agent-configs.git ~/workspace/agent-configs

# Pull the dotfiles change that drops the AI directories
cd ~/dotfiles && git pull
```

Copy your gitignored personal files onto the new machine if you use them:

- `agents-md/AGENTS.personal.md`
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

---

# Migration: CLAUDE.md → canonical AGENTS.md (pi-owned)

This is a **separate** migration from the dotfiles split above. It applies to a
machine that was set up while `~/.claude/CLAUDE.md` was the canonical instruction
file. The model is now inverted:

| | Old layout | New layout |
|---|---|---|
| Canonical (real file) | `~/.claude/CLAUDE.md` | `~/.pi/agent/AGENTS.md` |
| `~/.claude/CLAUDE.md` | real generated file | symlink → `~/.pi/agent/AGENTS.md` |
| `~/.pi/agent/AGENTS.md` | symlink → `~/.claude/CLAUDE.md` | the canonical real file |
| `~/.config/opencode/AGENTS.md` | absent (used the `~/.claude/CLAUDE.md` fallback) | symlink → `~/.pi/agent/AGENTS.md` |

The instruction **source** also moved in the repo: from `claude/.claude/CLAUDE.base.md`
(later `AGENTS.base.md`) to `agents-md/AGENTS.base.md`.

These steps only touch the instruction files. They deliberately **do not** touch
`~/.claude/settings.json` or `~/.config/opencode/opencode.json` — those are
unrelated and may be hand-tuned, so do not use the `-force` targets here. The
`~/.claude/{agents,skills}` and `~/.config/opencode/agents` symlinks are also
unaffected (their source paths did not move), so leave them as-is.

**Which layout am I on?** `~/.pi/agent/AGENTS.md` is a **symlink** (or missing) on
the old layout, and a **real file** once migrated:

```bash
[ -L ~/.pi/agent/AGENTS.md ] && echo "old layout — migrate below" \
  || { [ -e ~/.pi/agent/AGENTS.md ] && echo "already migrated (steps below are a safe no-op)" \
       || echo "pi file missing — steps below will create it"; }
```

Re-running the steps on an already-migrated machine is a safe no-op.

```bash
# Adjust the path if you cloned the repo elsewhere (e.g. ~/agent-configs).
cd ~/workspace/agent-configs && git pull

# 1. Put your personal instructions at the new path, agents-md/AGENTS.personal.md.
#    Relocate one from an older path only if the new path doesn't already have it
#    (never clobber an existing agents-md/AGENTS.personal.md):
mkdir -p agents-md
if [ ! -e agents-md/AGENTS.personal.md ]; then
  for old in claude/.claude/CLAUDE.personal.md claude/.claude/AGENTS.personal.md; do
    [ -f "$old" ] && { mv "$old" agents-md/AGENTS.personal.md; break; }
  done
else
  echo "agents-md/AGENTS.personal.md already exists — keeping it; remove any stale old-path file yourself."
fi
#    (No personal file on disk but ~/.claude/CLAUDE.md has custom content beyond
#     the shared base? See "Recovering personal content" below first.)

# 2. Generate the canonical real file ~/.pi/agent/AGENTS.md (base + personal).
#    This replaces the old ~/.pi/agent/AGENTS.md -> ~/.claude/CLAUDE.md symlink.
make sync-agents-md

# 3. Confirm the canonical matches your live instructions, then re-point CLAUDE.md.
#    (make won't convert a real CLAUDE.md into a symlink for you — it stops instead.)
if cmp -s ~/.pi/agent/AGENTS.md ~/.claude/CLAUDE.md; then
  ln -snf ~/.pi/agent/AGENTS.md ~/.claude/CLAUDE.md
else
  echo "Content differs — do NOT re-point yet; see 'Reconciling a mismatch' below."
fi

# 4. Give OpenCode an explicit global AGENTS.md.
mkdir -p ~/.config/opencode
ln -snf ~/.pi/agent/AGENTS.md ~/.config/opencode/AGENTS.md
```

## Recovering personal content

If step 1 found no personal file on disk but your live `~/.claude/CLAUDE.md` has
custom content appended after the shared base (it was baked in at generation time
and the source file is gone), recover it from the live file:

```bash
base_lines=$(wc -l < agents-md/AGENTS.base.md)
tail -n +$((base_lines + 2)) ~/.claude/CLAUDE.md > agents-md/AGENTS.personal.md

# Verify the split reproduces your current file byte-for-byte:
{ cat agents-md/AGENTS.base.md; echo ""; cat agents-md/AGENTS.personal.md; } \
  | cmp - ~/.claude/CLAUDE.md && echo "faithful ✅"
```

- Prints `faithful ✅` → re-run from step 2.
- `agents-md/AGENTS.personal.md` came out empty → your `~/.claude/CLAUDE.md` was
  base-only; delete the empty file and continue.
- **No `faithful ✅` (cmp reports a difference)** → the shared base changed since
  this machine's `CLAUDE.md` was generated, so the line-count split is unreliable.
  Don't trust the auto-extracted file: open `~/.claude/CLAUDE.md`, copy only your
  personal additions (everything below the shared base) into
  `agents-md/AGENTS.personal.md` by hand, then continue. The new canonical will
  intentionally pick up the base updates, so it won't byte-match the old
  `CLAUDE.md` — see *Reconciling a mismatch* for re-pointing in that case.

## Reconciling a mismatch

Step 3 only re-points `~/.claude/CLAUDE.md` when the freshly generated canonical
matches your current live file. A mismatch has two causes:

- **You lost personal content** — the canonical is missing custom instructions
  your live `CLAUDE.md` had. Recover them (above) before re-pointing.
- **Intentional base update** — you edited `AGENTS.base.md` since this machine was
  set up, so the canonical is *newer* than the live `CLAUDE.md`. This is expected.
  Eyeball the diff, then re-point manually:

  ```bash
  diff ~/.claude/CLAUDE.md ~/.pi/agent/AGENTS.md   # review what changed
  ln -snf ~/.pi/agent/AGENTS.md ~/.claude/CLAUDE.md
  ```

## Verify

```bash
printf '%-30s ' '~/.pi/agent/AGENTS.md'
[ -L ~/.pi/agent/AGENTS.md ] && echo 'symlink ❌ (want real file)' || echo 'real file ✅'
for p in ~/.claude/CLAUDE.md ~/.config/opencode/AGENTS.md; do
  printf '%-30s -> %s  [%s]\n' "$p" "$(readlink "$p")" \
    "$([ -e "$p" ] && echo OK || echo DANGLING)"
done
```

Both symlinks should read `OK` and point at the real `~/.pi/agent/AGENTS.md`.
