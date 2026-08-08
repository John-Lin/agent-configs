# Migration: skills CLI → apm

Run once per machine. apm deploys real directories under `~/.agents/skills/` and
`~/.claude/skills/` and refuses to write onto a symlink (`Skill destination ...
is a symlink -- refusing to deploy`), so the links left by the skills CLI have to
go first. Two layouts exist, depending on how old the machine is: one link per
managed skill, or — older still — `~/.claude/skills` as a single link to
`~/.agents/skills`. The commands below cover both, and only touch links that
resolve back into `~/.agents/skills/`.

```bash
find ~/.agents/skills ~/.claude/skills -maxdepth 1 -type l \
  -lname '*/.agents/skills/*' -delete
[ "$(readlink ~/.claude/skills)" = "$HOME/.agents/skills" ] && rm -f ~/.claude/skills

rm -f ~/.agents/.skill-lock.json          # state file of the CLI being replaced

mkdir -p ~/.apm
cp ~/workspace/agent-configs/apm/apm.yml ~/.apm/apm.yml   # adjust to your clone
apm install --global
```

The old copies under `~/.agents/skills/` are overwritten in place by the install;
skills you added by hand are untouched because apm only reconciles what its
lockfile records.

Skills linked in from somewhere else survive in `~/.agents/skills/` but lose
their Claude Code side when the directory link goes. On Omarchy, restore it:

```bash
ln -sfn ~/.local/share/omarchy/default/omarchy-skill ~/.claude/skills/omarchy
```

From here on skills are managed with `apm` directly — see `docs/ai.md`.
