#!/bin/bash

set -euo pipefail

REPO_ROOT=$(pwd)
# Derive the canonical marker from its source so assertions track wording
# changes to the shared instructions instead of duplicating the literal.
CANONICAL_MARKER=$(head -n1 "$REPO_ROOT/agents-md/AGENTS.base.md")
CLEANUP_HOME=
CLEANUP_OUTPUT=

cleanup() {
	[ -n "$CLEANUP_HOME" ] && rm -rf -- "$CLEANUP_HOME"
	[ -n "$CLEANUP_OUTPUT" ] && rm -f -- "$CLEANUP_OUTPUT"
}

trap cleanup EXIT

assert_exists() {
	if [ ! -e "$1" ]; then
		printf 'Expected path to exist: %s\n' "$1" >&2
		exit 1
	fi
}

assert_symlink_resolves_to() {
	local path="$1"
	local expected="$2"

	if [ ! -L "$path" ]; then
		printf 'Expected symlink: %s\n' "$path" >&2
		exit 1
	fi

	if [ "$(realpath "$path")" != "$(realpath "$expected")" ]; then
		printf 'Expected %s to resolve to %s\n' "$path" "$expected" >&2
		exit 1
	fi
}

assert_file_contains() {
	local path="$1"
	local needle="$2"

	if ! grep -Fq -- "$needle" "$path"; then
		printf 'Expected %s to contain: %s\n' "$path" "$needle" >&2
		exit 1
	fi
}

assert_symlink_target() {
	local path="$1"
	local expected="$2"

	if [ ! -L "$path" ]; then
		printf 'Expected symlink: %s\n' "$path" >&2
		exit 1
	fi

	if [ "$(readlink "$path")" != "$expected" ]; then
		printf 'Expected %s to point to %s (got %s)\n' "$path" "$expected" "$(readlink "$path")" >&2
		exit 1
	fi
}

assert_regular_file() {
	if [ -L "$1" ] || [ ! -f "$1" ]; then
		printf 'Expected a regular file: %s\n' "$1" >&2
		exit 1
	fi
}

run_make() {
	local home_dir="$1"
	shift

	if ! HOME="$home_dir" make "$@" >"$test_output" 2>&1; then
		cat "$test_output" >&2
		exit 1
	fi
}

# Print skills.yaml as lines of "<repo> <skill> [<skill>...]", mirroring the
# Makefile's SKILLS_MANIFEST_ENTRIES so assertions track the manifest.
manifest_entries() {
	yq -r 'to_entries[] | .key + " " + (.value | join(" "))' "$REPO_ROOT/skills.yaml"
}

main() {
	local home_dir test_output skill_entries repo skills skill first_pkg
	home_dir=$(mktemp -d)
	test_output=$(mktemp /tmp/sync-smoke.out.XXXXXX)
	CLEANUP_HOME="$home_dir"
	CLEANUP_OUTPUT="$test_output"

	cd "$REPO_ROOT"

	run_make "$home_dir" sync-ccstatusline
	assert_symlink_resolves_to "$home_dir/.config/ccstatusline/settings.json" "$REPO_ROOT/ccstatusline/.config/ccstatusline/settings.json"

	OPENCODE_WORK_CONFIG= run_make "$home_dir" sync-opencode
	assert_exists "$home_dir/.config/opencode/opencode.json"
	assert_file_contains "$home_dir/.config/opencode/opencode.json" '"share": "disabled"'
	assert_symlink_resolves_to "$home_dir/.config/opencode/agents" "$REPO_ROOT/opencode/agents"
	# opencode reads instructions from a global AGENTS.md → canonical pi file
	assert_symlink_target "$home_dir/.config/opencode/AGENTS.md" "$home_dir/.pi/agent/AGENTS.md"

	mkdir -p "$home_dir/.agents/skills" "$home_dir/.claude"
	ln -s "$home_dir/.agents/skills" "$home_dir/.claude/skills"
	# Force the public manifest only: internal sources (skills-int.yaml) may need
	# VPN/auth, and an empty SKILLS_MANIFEST_INT also exercises the
	# missing-internal-manifest path, which must not break sync-skills.
	run_make "$home_dir" sync-claude SKILLS_MANIFEST_INT=
	# Published skills are installed by the pinned skills CLI into the universal
	# directory. Every skill listed in skills.yaml must be present.
	skill_entries="$(manifest_entries)"
	if [ -z "$skill_entries" ]; then
		printf 'skills.yaml produced no entries\n' >&2
		exit 1
	fi
	while read -r repo skills; do
		assert_file_contains "$home_dir/.agents/.skill-lock.json" "$repo"
		for skill in $skills; do
			assert_exists "$home_dir/.agents/skills/$skill/SKILL.md"
		done
	done <<< "$skill_entries"

	# CLAUDE.md is now a symlink to the canonical pi AGENTS.md
	assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.claude/CLAUDE.md" "$CANONICAL_MARKER"
	assert_exists "$home_dir/.claude/settings.json"
	assert_symlink_resolves_to "$home_dir/.claude/agents" "$REPO_ROOT/claude/.claude/agents"
	# The skills CLI links each managed skill into Claude Code's skill directory.
	while read -r repo skills; do
		for skill in $skills; do
			assert_symlink_resolves_to "$home_dir/.claude/skills/$skill" "$home_dir/.agents/skills/$skill"
			assert_exists "$home_dir/.claude/skills/$skill/SKILL.md"
		done
	done <<< "$skill_entries"

	run_make "$home_dir" sync-pi
	# pi owns the canonical instructions as a real generated file
	assert_regular_file "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.pi/agent/AGENTS.md" "$CANONICAL_MARKER"
	assert_exists "$home_dir/.pi/agent/settings.json"
	# sync-pi must merge packages.json into settings.json. Derive an expected
	# package from the manifest so the assertion tracks changes automatically.
	first_pkg=$(jq -r '.. | strings | select(startswith("npm:"))' "$REPO_ROOT/pi/packages.json" | head -1)
	assert_file_contains "$home_dir/.pi/agent/settings.json" "$first_pkg"

	mkdir -p "$home_dir/.agents/skills/unmanaged-skill"
	printf '%s\n' 'keep me' >"$home_dir/.agents/skills/unmanaged-skill/SKILL.md"
	run_make "$home_dir" clean-skills
	assert_exists "$home_dir/.agents/skills/unmanaged-skill/SKILL.md"
}

main "$@"
