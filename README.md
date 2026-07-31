# agent-configs

Personal configuration for AI coding agents (Claude Code, OpenCode, pi) and the
Claude status line, managed with `make` and a pinned skills CLI. Split out of my
[dotfiles](https://github.com/John-Lin/dotfiles) so editor/shell/desktop config
and agent config can evolve independently.

## Quick Start

```bash
git clone https://github.com/John-Lin/agent-configs ~/agent-configs
cd ~/agent-configs

# Show available install targets
make sync

# Common installs
make sync-claude
make sync-opencode
make sync-pi
```

Most sync targets fail fast if the destination already contains unmanaged files
or symlinks. Use the corresponding `*-force` target only when you explicitly
want to replace local contents.

## Common Commands

```bash
make sync-claude        # Claude Code config (CLAUDE.md→AGENTS.md, settings.json, agents)
make sync-ccstatusline  # ccstatusline config
make sync-opencode      # OpenCode agents + generated opencode.json + AGENTS.md
make sync-pi            # pi canonical AGENTS.md + packages injection

make sync-agents-md-force  # regenerate canonical AGENTS.md only (after editing AGENTS.personal.md)
make sync-claude-force
make sync-opencode-force
make sync-pi-force

make test
make clean
```

- `make test` runs syntax checks, safety regression tests, and sync smoke tests.
- `make clean` removes configuration managed by this project while preserving
  unrelated local files.

## Repo Layout

- `agents-md/` - shared, tool-neutral instruction source (canonical `AGENTS.md`)
- `claude/` - Claude Code config and local override templates
- `ccstatusline/` - Claude status line config
- `opencode/` - OpenCode agents
- `jsonnet/` - Jsonnet source for the generated OpenCode config
- `pi/` - pi shared packages
- `docs/ai.md` - agent overview, OpenCode, Claude settings, MCP setup

## Personal Overrides

Personal and work-specific inputs are not tracked by this repository:

- `agents-md/AGENTS.personal.md` (merged into the canonical `~/.pi/agent/AGENTS.md`)
- `claude/claude_settings.personal.json` (merged into `~/.claude/settings.json`)
- `opencode_work.libsonnet` in the external directory selected by
  `OPENCODE_WORK_CONFIG`

The first two files are gitignored and must be copied to each new machine before
running sync targets; without them, sync uses only the tracked base/template.
Keep the OpenCode work overlay outside this repository and pass its directory via
`OPENCODE_WORK_CONFIG` when running `make sync-opencode`.

The shared instructions are generated once as the canonical
`~/.pi/agent/AGENTS.md` (pi owns it). Claude Code and OpenCode point at it via
symlinks: `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md`. Any of
`make sync-claude` / `sync-opencode` / `sync-pi` regenerates the canonical file
as needed.

Shared skills are **not** managed by make. They are installed with
[apm](https://github.com/microsoft/apm) directly, into `~/.agents/skills/<name>`
(read natively by OpenCode and pi) and `~/.claude/skills/<name>` (the only skill
directory Claude Code discovers):

```bash
mkdir -p ~/.apm && cp apm/apm.yml ~/.apm/apm.yml   # new machine
apm install --global
```

`apm/apm.yml` here is a tracked reference copy of `~/.apm/apm.yml`, which is
where apm actually reads from. Copy it in either direction by hand; nothing
syncs it. Machines diverge on purpose — a work machine's manifest can name
internal repositories that must not be committed. See `docs/ai.md`.

Migrating a machine that already had the old dotfiles installed? See
`MIGRATION.md`.

Detailed setup:
- `claude/README.md`
- `jsonnet/README.md`
- `docs/ai.md`

## Requirements

- macOS or Linux
- Git, Make, GNU Stow (for ccstatusline)
- `jq`
- `jsonnet` (for `make sync-opencode`)
- `yq` (mikefarah v4, `brew install yq` — used by `make check-syntax`)
- `apm` (`brew install microsoft/apm/apm` — installs skills, outside make)
- `bun` if required by the locally installed agent runtimes
- Python 3 (used by `make check-syntax`)

## License

MIT
