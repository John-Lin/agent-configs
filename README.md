# agent-configs

Personal configuration for AI coding agents (Claude Code, OpenCode, pi) and the
Claude status line, managed with `make` and `GNU Stow`. Split out of my
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
make sync-skills        # shared skills → ~/.agents/skills/<name>

make sync-agents-md-force  # regenerate canonical AGENTS.md only (after editing AGENTS.personal.md)
make sync-claude-force
make sync-opencode-force
make sync-pi-force
make sync-skills-force

make test
make clean
```

- `make test` runs syntax checks, safety regression tests, and sync smoke tests.
- `make clean` removes repo-managed symlinks and generated files while preserving
  unmanaged local files.

## Repo Layout

- `agents-md/` - shared, tool-neutral instruction source (canonical `AGENTS.md`)
- `skills/` - shared, tool-neutral skills, stowed to `~/.agents/skills/<name>`
- `claude/` - Claude Code config and local override templates
- `ccstatusline/` - Claude status line config
- `opencode/` - OpenCode agents
- `jsonnet/` - Jsonnet source for the generated OpenCode config
- `pi/` - pi shared packages
- `docs/ai.md` - agent overview, OpenCode, Claude settings, MCP setup

## Personal Overrides

Personal/machine-specific files stay gitignored:

- `agents-md/AGENTS.personal.md` (merged into the canonical `~/.pi/agent/AGENTS.md`)
- `claude/claude_settings.personal.json` (merged into `~/.claude/settings.json`)
- `jsonnet/opencode_work.libsonnet` (work overlay, kept outside this repo)

Because these are gitignored, they live on one machine only. Copy them to each
new machine yourself before running the sync targets — otherwise the sync
falls back to base-only output and your personal overrides are silently dropped.

The shared instructions are generated once as the canonical
`~/.pi/agent/AGENTS.md` (pi owns it). Claude Code and OpenCode point at it via
symlinks: `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md`. Any of
`make sync-claude` / `sync-opencode` / `sync-pi` regenerates the canonical file
as needed.

Shared skills follow the same tool-neutral idea: `make sync-skills` stows them to
`~/.agents/skills/<name>`. OpenCode and pi read that path natively; Claude Code
reaches them through `~/.claude/skills → ~/.agents/skills` (set up by
`make sync-claude`). See `docs/ai.md`.

Migrating a machine that already had the old dotfiles installed? See
`MIGRATION.md`.

Detailed setup:
- `claude/README.md`
- `jsonnet/README.md`
- `docs/ai.md`

## Requirements

- macOS or Linux
- Git, Make, GNU Stow
- `jq`
- `jsonnet` (for `make sync-opencode`)
- Node.js / `bun` (Claude Code, OpenCode, pi runtimes)
- Python 3 (used by `make check-syntax`)

## License

MIT
