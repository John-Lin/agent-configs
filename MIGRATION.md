Migrations are recorded newest first. Only the first section applies to a machine
on the current layout; everything below it is kept as a record of earlier moves
and still refers to `make sync-skills` and the skills CLI, both of which are
gone. Run an older section only to bring a machine forward to the layout that
section produced, then continue with the section above it.

---

# Migration: skills CLI → apm

Run once per machine. The skills CLI created one symlink per managed skill under
`~/.claude/skills/`; apm deploys real directories there and refuses to write onto
a symlink (`Skill destination ... is a symlink -- refusing to deploy`), so the
old links have to go first. Only links pointing back into `~/.agents/skills/` are
removed — anything else is left alone.

```bash
find ~/.claude/skills -maxdepth 1 -type l -lname '*/.agents/skills/*' -delete
rm -f ~/.agents/.skill-lock.json          # state file of the CLI being replaced

mkdir -p ~/.apm
cp ~/workspace/agent-configs/apm/apm.yml ~/.apm/apm.yml   # adjust to your clone
apm install --global
```

The old copies under `~/.agents/skills/` are overwritten in place by the install;
skills you added by hand are untouched because apm only reconciles what its
lockfile records.

From here on skills are managed with `apm` directly — see `docs/ai.md`. There is
no `make sync-skills`.

---

# Migration: Stow-managed skills → pinned skills CLI

Use this migration after PR #4 is merged. It removes only the known legacy skill
symlinks created by this repository, then lets `skills@1.5.19` install canonical
copies and Claude Code per-skill links. Other skills under `~/.agents/skills/` are
left untouched.

```bash
cd ~/workspace/agent-configs   # adjust to your clone path
git status --short             # stop and reconcile local changes before pulling
git switch main
git pull --ff-only

# Remove only legacy per-skill links created by the old Stow package.
for name in architecture-diagram find-docs gh-cli test-driven-development; do
  path="$HOME/.agents/skills/$name"
  if [ -L "$path" ]; then
    current=$(readlink "$path")
    case "$current" in
      */agent-configs/skills/.agents/skills/"$name"|*/dotfiles/claude/.claude/skills/"$name")
        rm -f "$path" ;;
      *) echo "Unknown legacy skill target: $path -> $current"; exit 1 ;;
    esac
  fi
done

# Remove only a known legacy whole-directory Claude skills link. The new CLI
# creates ~/.claude/skills as a directory containing one link per managed skill.
if [ -L ~/.claude/skills ]; then
  current=$(readlink ~/.claude/skills)
  case "$current" in
    "$HOME/.agents/skills"|*/dotfiles/claude/.claude/skills|*/agent-configs/claude/.claude/skills)
      rm -f ~/.claude/skills ;;
    *) echo "Unknown ~/.claude/skills target: $current"; exit 1 ;;
  esac
fi

make sync-skills
```

If PR #4 has not been merged and you intentionally want to test it first, replace
the `git switch main` / `git pull` commands with:

```bash
gh pr checkout 4
```

Verify the migrated layout:

```bash
npx --yes skills@1.5.19 ls -g --json
ls -ld ~/.agents/skills/{architecture-diagram,find-docs,test-driven-development,grill-me,grill-with-docs,handoff}
ls -ld ~/.claude/skills
ls -l ~/.claude/skills/{architecture-diagram,find-docs,test-driven-development,grill-me,grill-with-docs,handoff}
```

Expected layout:

- the six paths under `~/.agents/skills/` are canonical directories managed by
  the skills CLI;
- `~/.claude/skills/` is a real directory;
- its six managed entries are per-skill symlinks created by the skills CLI;
- `gh-cli` is intentionally no longer installed by this repository.

---

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
| `~/.config/opencode/agents` | `dotfiles/opencode/agents` | `agent-configs/opencode/agents` |
| `~/.config/ccstatusline/settings.json` | `dotfiles/ccstatusline/...` | `agent-configs/ccstatusline/...` |

The old `~/.claude/skills` symlink is not re-pointed into this repository. Remove
it and run `make sync-skills`; the skills CLI replaces it with one symlink per
managed skill.

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

Copy your untracked personal and work inputs onto the new machine if you use them:

- `agents-md/AGENTS.personal.md`
- `claude/claude_settings.personal.json`
- `opencode_work.libsonnet` in the external directory selected by
  `OPENCODE_WORK_CONFIG`

## Option A — Re-point the symlinks (minimal, no regeneration)

This is the lowest-risk path: it re-points the remaining repo-owned symlinks and
installs skills through the pinned CLI without regenerating Claude instructions,
Claude settings, or OpenCode configuration. The ccstatusline target separately
backs up a hand-edited regular settings file before installing its managed link.

```bash
AGENT_CONFIGS=~/workspace/agent-configs   # adjust to where you cloned it

ln -snf "$AGENT_CONFIGS/claude/.claude/agents"  ~/.claude/agents
ln -snf "$AGENT_CONFIGS/opencode/agents"        ~/.config/opencode/agents

# Replace only a known legacy whole-directory skills link. Preserve an
# already-migrated directory and refuse unknown symlinks.
if [ -L ~/.claude/skills ]; then
  current=$(readlink ~/.claude/skills)
  case "$current" in
    "$HOME/.agents/skills"|*/dotfiles/claude/.claude/skills|*/agent-configs/claude/.claude/skills)
      rm -f ~/.claude/skills ;;
    *) echo "Unknown ~/.claude/skills target: $current"; exit 1 ;;
  esac
fi
( cd "$AGENT_CONFIGS" && make sync-skills )

# Remove only the known stale dotfiles link. The make target backs up a regular,
# hand-edited settings file before Stow installs the managed link.
if [ -L ~/.config/ccstatusline/settings.json ]; then
  current=$(readlink ~/.config/ccstatusline/settings.json)
  case "$current" in
    */dotfiles/ccstatusline/*) rm -f ~/.config/ccstatusline/settings.json ;;
    */agent-configs/ccstatusline/*) : ;;
    *) echo "Unknown ccstatusline symlink target: $current"; exit 1 ;;
  esac
fi
( cd "$AGENT_CONFIGS" && make sync-ccstatusline )
```

## Option B — Full re-install via make

Re-manages everything from this repo, regenerating the merged files too. Cleaner
provenance, but it will refuse (or with `-force`, overwrite) any generated file
that has drifted from the repo — see the warning below.

```bash
cd ~/workspace/agent-configs

# Remove the stale repo-owned agent symlinks first. The sync targets handle
# ccstatusline regular-file backups and refuse unrelated symlinks.
rm -f ~/.claude/agents ~/.config/opencode/agents

# Replace only a known legacy whole-directory skills link.
if [ -L ~/.claude/skills ]; then
  current=$(readlink ~/.claude/skills)
  case "$current" in
    "$HOME/.agents/skills"|*/dotfiles/claude/.claude/skills|*/agent-configs/claude/.claude/skills)
      rm -f ~/.claude/skills ;;
    *) echo "Unknown ~/.claude/skills target: $current"; exit 1 ;;
  esac
fi

# Remove only the known stale dotfiles ccstatusline link. Preserve a current
# agent-configs link and let the make target back up regular files.
if [ -L ~/.config/ccstatusline/settings.json ]; then
  current=$(readlink ~/.config/ccstatusline/settings.json)
  case "$current" in
    */dotfiles/ccstatusline/*) rm -f ~/.config/ccstatusline/settings.json ;;
    */agent-configs/ccstatusline/*) : ;;
    *) echo "Unknown ccstatusline symlink target: $current"; exit 1 ;;
  esac
fi

make sync-claude         # install Claude agents/settings, create the CLAUDE.md symlink, and install shared skills
make sync-ccstatusline   # ~/.config/ccstatusline/settings.json
make sync-opencode       # ~/.config/opencode/agents + regenerate opencode.json
make sync-pi             # regenerate canonical ~/.pi/agent/AGENTS.md + inject packages
```

> **If a sync stops with "already exists with different contents":** identify
> which managed file drifted before forcing anything. If canonical
> `~/.pi/agent/AGENTS.md` differs from the repository-generated instructions, run
> `make sync-agents-md-force`. Use `make sync-claude-force` for Claude settings or
> symlink conflicts, and `make sync-opencode-force` for OpenCode files or symlink
> conflicts. These force targets discard local edits to the files they manage.

## Verify

```bash
for p in ~/.claude/agents ~/.config/opencode/agents \
         ~/.config/ccstatusline/settings.json; do
  printf '%-42s -> %s  [%s]\n' "$p" "$(readlink "$p")" \
    "$([ -e "$p" ] && echo OK || echo DANGLING)"
done
find ~/.claude/skills -mindepth 1 -maxdepth 1 -type l -print
```

The repo-owned symlinks should read `OK` and point into `agent-configs/`. Claude's
skill directory should contain one CLI-managed link per installed skill.

## Optional cleanup

Old backup files left behind by earlier installs are safe to remove once you've
confirmed the migration:

```bash
rm -f ~/.config/ccstatusline/settings.json.bak.* \
      ~/.config/opencode/opencode.json.bak.* \
      ~/.claude/settings.json.bak ~/.claude/settings.json.orig
```

---

# Migration: CLAUDE.md → canonical AGENTS.md (pi-owned) + shared skills

This is a **separate** migration from the dotfiles split above. It applies to a
machine that was set up while `~/.claude/CLAUDE.md` was the canonical instruction
file and skills lived under `claude/`. The model is now inverted, and skills moved
to a tool-neutral home:

| | Old layout | New layout |
|---|---|---|
| Canonical instructions (real file) | `~/.claude/CLAUDE.md` | `~/.pi/agent/AGENTS.md` |
| `~/.claude/CLAUDE.md` | real generated file | symlink → `~/.pi/agent/AGENTS.md` |
| `~/.pi/agent/AGENTS.md` | symlink → `~/.claude/CLAUDE.md` | the canonical real file |
| `~/.config/opencode/AGENTS.md` | absent (used the `~/.claude/CLAUDE.md` fallback) | symlink → `~/.pi/agent/AGENTS.md` |
| `~/.claude/skills/<name>` | reached through one repo-owned directory symlink | per-skill symlink → `~/.agents/skills/<name>` |
| `~/.agents/skills/<name>` | absent | skills installed from upstream by `skills` (read natively by OpenCode + pi) |

The **sources** also moved in the repo: instructions from `claude/.claude/CLAUDE.base.md`
(later `AGENTS.base.md`) to `agents-md/AGENTS.base.md`. Skills now come from their
upstream repositories through the pinned skills CLI.

These steps update the canonical instructions, instruction symlinks, and managed
skills. They deliberately **do not** touch `~/.claude/settings.json` or
`~/.config/opencode/opencode.json` — those are unrelated and may be hand-tuned,
so do not use the `-force` targets here. The
`~/.claude/agents` and `~/.config/opencode/agents` symlinks are unaffected (their
source paths did not move), so leave them as-is.

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

# 5. Replace only a known legacy whole-directory Claude skills link. Preserve an
#    already-migrated directory and refuse unknown symlinks. OpenCode and pi read
#    ~/.agents/skills natively.
if [ -L ~/.claude/skills ]; then
  current=$(readlink ~/.claude/skills)
  case "$current" in
    "$HOME/.agents/skills"|*/dotfiles/claude/.claude/skills|*/agent-configs/claude/.claude/skills)
      rm -f ~/.claude/skills ;;
    *) echo "Unknown ~/.claude/skills target: $current"; exit 1 ;;
  esac
fi
make sync-skills                  # install upstream skills and Claude per-skill links
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
ls ~/.agents/skills
find ~/.claude/skills -mindepth 1 -maxdepth 1 -type l -print
```

The instruction symlinks should read `OK` and point at the real
`~/.pi/agent/AGENTS.md`. Each managed skill should have a corresponding symlink
under `~/.claude/skills/`.

## Updating personal instructions afterward

Once `~/.pi/agent/AGENTS.md` is a real file, editing `agents-md/AGENTS.personal.md`
(or creating it for the first time, on a machine that finished the migration
base-only) and re-running `make sync-agents-md` is **refused** — the conservative
guard won't overwrite the existing real canonical:

```
❌ ~/.pi/agent/AGENTS.md already exists with different contents
   Move it away manually or run make sync-agents-md-force
```

Use the force target to regenerate just the instructions. It rebuilds the
canonical from base + personal and leaves `~/.pi/agent/settings.json`,
`~/.claude/settings.json`, and `~/.config/opencode/opencode.json` untouched
(unlike `make sync-pi-force`, which also re-injects pi packages):

```bash
make sync-agents-md-force
```

The CLAUDE.md / OpenCode symlinks already point at the canonical, so they pick up
the new content with no further steps.
