#!/bin/bash

# Install the managed skills declared in the manifest file(s) into the universal
# ~/.agents/skills directory using the pinned skills CLI.
#
# Multiple manifests are merged (skill lists for a repo shared across files are
# combined), so a gitignored internal manifest can layer on top of the public
# one. At least one manifest file must be provided and exist.
#
# Usage:
#   SKILLS_CLI="npx --yes skills@1.5.19" sync-skills.sh <manifest.yaml>...

set -euo pipefail

if [ -z "${SKILLS_CLI:-}" ]; then
	echo "Error: SKILLS_CLI must be set (e.g. 'npx --yes skills@1.5.19')" >&2
	exit 1
fi

if [ "$#" -eq 0 ]; then
	echo "Error: no skills manifest files provided" >&2
	exit 1
fi

echo "Installing shared skills..."
mkdir -p ~/.agents/skills

# Migrate the old single-symlink layout (~/.claude/skills -> ~/.agents/skills)
# to the CLI-managed per-skill links.
if [ -L ~/.claude/skills ]; then
	current="$(readlink ~/.claude/skills)"
	if [ "$current" = "${HOME}/.agents/skills" ]; then
		rm -f ~/.claude/skills
		echo "  Migrated Claude Code skills to per-skill links"
	else
		echo "Error: ~/.claude/skills points to $current" >&2
		echo "   Remove it manually before installing CLI-managed per-skill links" >&2
		exit 1
	fi
fi

# Merge all manifests into lines of "<repo> <skill> [<skill>...]".
# The single-quoted argument is a yq expression, not a shell expansion.
# shellcheck disable=SC2016
entries="$(yq ea -r '. as $item ireduce ({}; . *+ $item) | to_entries[] | .key + " " + (.value | join(" "))' "$@")"

while read -r repo skills; do
	[ -n "$repo" ] || continue
	echo "  Installing from $repo: $skills"
	skill_args=()
	for skill in $skills; do skill_args+=(--skill "$skill"); done
	# SKILLS_CLI is intentionally word-split into "npx --yes skills@<ver>".
	# shellcheck disable=SC2086
	$SKILLS_CLI add "$repo" "${skill_args[@]}" --global --agent opencode --agent claude-code --yes </dev/null
done <<< "$entries"

echo "Skills installed to ~/.agents/skills/"
