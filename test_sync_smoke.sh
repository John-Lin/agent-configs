#!/bin/bash

set -euo pipefail

REPO_ROOT=$(pwd)
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

main() {
	local home_dir test_output
	home_dir=$(mktemp -d)
	test_output=$(mktemp /tmp/sync-smoke.out.XXXXXX)
	CLEANUP_HOME="$home_dir"
	CLEANUP_OUTPUT="$test_output"

	cd "$REPO_ROOT"

	assert_file_contains "$REPO_ROOT/docs/ai.md" '- `typescript-pro` - TypeScript specialist'
	assert_file_contains "$REPO_ROOT/README.md" 'make sync-pi'
	assert_file_contains "$REPO_ROOT/jsonnet/README.md" '| `gpt-5.5` | GPT-5.5 | 5.00 | 30.00 |'

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
	run_make "$home_dir" sync-claude
	# Published skills are installed by the pinned skills CLI into the universal directory.
	assert_exists "$home_dir/.agents/skills/architecture-diagram/SKILL.md"
	assert_exists "$home_dir/.agents/skills/find-docs/SKILL.md"
	assert_exists "$home_dir/.agents/skills/test-driven-development/SKILL.md"
	assert_exists "$home_dir/.agents/skills/grill-me/SKILL.md"
	assert_exists "$home_dir/.agents/skills/grill-with-docs/SKILL.md"
	assert_exists "$home_dir/.agents/skills/handoff/SKILL.md"
	assert_exists "$home_dir/.agents/skills/writing-great-skills/SKILL.md"
	assert_file_contains "$home_dir/.agents/.skill-lock.json" 'cocoon-ai/architecture-diagram-generator'
	assert_file_contains "$home_dir/.agents/.skill-lock.json" 'upstash/context7'
	assert_file_contains "$home_dir/.agents/.skill-lock.json" 'obra/superpowers'
	assert_file_contains "$home_dir/.agents/.skill-lock.json" 'mattpocock/skills'

	# CLAUDE.md is now a symlink to the canonical pi AGENTS.md
	assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.claude/CLAUDE.md" 'You are an experienced, pragmatic software engineer.'
	assert_exists "$home_dir/.claude/settings.json"
	assert_symlink_resolves_to "$home_dir/.claude/agents" "$REPO_ROOT/claude/.claude/agents"
	# The skills CLI links each managed skill into Claude Code's skill directory.
	assert_symlink_resolves_to "$home_dir/.claude/skills/find-docs" "$home_dir/.agents/skills/find-docs"
	assert_symlink_resolves_to "$home_dir/.claude/skills/grill-me" "$home_dir/.agents/skills/grill-me"
	assert_symlink_resolves_to "$home_dir/.claude/skills/grill-with-docs" "$home_dir/.agents/skills/grill-with-docs"
	assert_symlink_resolves_to "$home_dir/.claude/skills/handoff" "$home_dir/.agents/skills/handoff"
	assert_symlink_resolves_to "$home_dir/.claude/skills/writing-great-skills" "$home_dir/.agents/skills/writing-great-skills"
	assert_exists "$home_dir/.claude/skills/find-docs/SKILL.md"

	run_make "$home_dir" sync-pi
	# pi owns the canonical instructions as a real generated file
	assert_regular_file "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.pi/agent/AGENTS.md" 'You are an experienced, pragmatic software engineer.'
	assert_exists "$home_dir/.pi/agent/settings.json"
	assert_file_contains "$home_dir/.pi/agent/settings.json" 'npm:pi-subagents'

	mkdir -p "$home_dir/.agents/skills/unmanaged-skill"
	printf '%s\n' 'keep me' >"$home_dir/.agents/skills/unmanaged-skill/SKILL.md"
	run_make "$home_dir" clean-skills
	assert_exists "$home_dir/.agents/skills/unmanaged-skill/SKILL.md"
}

main "$@"
