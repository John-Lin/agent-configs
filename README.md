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
make sync-claude        # Claude Code config (CLAUDE.md, settings.json, agents, skills)
make sync-ccstatusline  # ccstatusline config
make sync-opencode      # OpenCode agents + generated opencode.json
make sync-pi            # pi AGENTS.md symlink + packages injection

make sync-claude-force
make sync-opencode-force

make test
make clean
```

- `make test` runs syntax checks, safety regression tests, and sync smoke tests.
- `make clean` removes repo-managed symlinks and generated files while preserving
  unmanaged local files.

## Repo Layout

- `claude/` - Claude Code config and local override templates
- `ccstatusline/` - Claude status line config
- `opencode/` - OpenCode agents
- `jsonnet/` - Jsonnet source for the generated OpenCode config
- `pi/` - pi shared packages
- `docs/ai.md` - agent overview, OpenCode, Claude settings, MCP setup

## Personal Overrides

Personal/machine-specific files stay gitignored:

- `claude/.claude/CLAUDE.personal.md` (merged into `~/.claude/CLAUDE.md`)
- `claude/claude_settings.personal.json` (merged into `~/.claude/settings.json`)
- `jsonnet/opencode_work.libsonnet` (work overlay, kept outside this repo)

`make sync-pi` links pi to the generated Claude instructions
(`~/.pi/agent/AGENTS.md -> ~/.claude/CLAUDE.md`), so run `make sync-claude`
first.

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
