#!/bin/bash

# Install the managed skills declared in the manifest file(s) with apm.
#
# Multiple manifests are merged (their dependency lists are concatenated), so a
# gitignored internal manifest can layer on top of the public one. At least one
# manifest file must be provided and exist.
#
# The merged result is written to ~/.apm/apm.yml because that is the only
# manifest `apm install --global` reads; its location is fixed and cannot be
# redirected. `apm install` then deploys every declared skill to
# ~/.agents/skills/ (read natively by OpenCode and pi) and to ~/.claude/skills/,
# and prunes skills the manifest no longer declares.
#
# Usage:
#   sync-skills.sh <manifest.yml>...

set -euo pipefail

if [ "$#" -eq 0 ]; then
	echo "Error: no skills manifest files provided" >&2
	exit 1
fi

echo "Installing shared skills..."

# Migrate the old single-symlink layout (~/.claude/skills -> ~/.agents/skills)
# to the per-skill directories apm deploys.
if [ -L ~/.claude/skills ]; then
	current="$(readlink ~/.claude/skills)"
	if [ "$current" = "${HOME}/.agents/skills" ]; then
		rm -f ~/.claude/skills
		echo "  Migrated Claude Code skills to per-skill directories"
	else
		echo "Error: ~/.claude/skills points to $current" >&2
		echo "   Remove it manually before installing apm-managed skills" >&2
		exit 1
	fi
fi

mkdir -p ~/.apm

tmp_manifest="$(mktemp /tmp/apm-manifest.XXXXXX)"
trap 'rm -f "$tmp_manifest"' EXIT

# Merge every manifest, concatenating the dependency lists.
# The single-quoted argument is a yq expression, not a shell expansion.
# shellcheck disable=SC2016
yq ea '. as $item ireduce ({}; . *+ $item)' "$@" >"$tmp_manifest"

# apm rewrites this file whenever packages are added or removed, so a difference
# means either a hand-edited manifest or an `apm uninstall --global` the repo
# manifest does not know about. Refuse to clobber either silently.
if [ -e "${HOME}/.apm/apm.yml" ] && ! cmp -s "$tmp_manifest" "${HOME}/.apm/apm.yml"; then
	echo "Error: ${HOME}/.apm/apm.yml already exists with different contents" >&2
	echo "   Move it away manually or run make sync-skills-force" >&2
	exit 1
fi

mv "$tmp_manifest" "${HOME}/.apm/apm.yml"

# Run from $HOME so a stray project manifest in the current directory cannot
# shadow the user-scope install.
cd "$HOME" && apm install --global

echo "Skills installed to ~/.agents/skills/ and ~/.claude/skills/"
