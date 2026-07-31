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

From here on skills are managed with `apm` directly — see `docs/ai.md`.
