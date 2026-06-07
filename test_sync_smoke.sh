#!/bin/bash

set -euo pipefail

REPO_ROOT=$(pwd)

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

	if [ "$(realpath "$path")" != "$expected" ]; then
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
		printf 'Expected a regular file (not a symlink): %s\n' "$1" >&2
		exit 1
	fi
}

assert_file_not_contains() {
	local path="$1"
	local needle="$2"

	if grep -Fq -- "$needle" "$path"; then
		printf 'Expected %s to not contain: %s\n' "$path" "$needle" >&2
		exit 1
	fi
}

assert_not_exists() {
	if [ -e "$1" ]; then
		printf 'Expected path to not exist: %s\n' "$1" >&2
		exit 1
	fi
}

main() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' EXIT

	cd "$REPO_ROOT"

	assert_not_exists "$REPO_ROOT/skills/.agents/skills/web-browser"
	assert_not_exists "$REPO_ROOT/skills/.agents/skills/uv-package-manager/SKILL.md"
	assert_file_not_contains "$REPO_ROOT/claude/README.md" "skills/web-browser"
	assert_file_not_contains "$REPO_ROOT/claude/README.md" "uv-package-manager"
	assert_file_contains "$REPO_ROOT/docs/ai.md" '- `typescript-pro` - TypeScript specialist'
	assert_file_not_contains "$REPO_ROOT/docs/ai.md" "/sc:analyze"
	assert_file_not_contains "$REPO_ROOT/docs/ai.md" "web-browser"
	assert_file_not_contains "$REPO_ROOT/docs/ai.md" "uv-package-manager"
	assert_file_contains "$REPO_ROOT/README.md" 'make sync-pi'
	assert_file_contains "$REPO_ROOT/jsonnet/README.md" '| `gpt-5.5` | GPT-5.5 | 5.00 | 30.00 |'

	HOME="$home_dir" make sync-ccstatusline
	assert_symlink_resolves_to "$home_dir/.config/ccstatusline/settings.json" "$REPO_ROOT/ccstatusline/.config/ccstatusline/settings.json"

	OPENCODE_WORK_CONFIG= HOME="$home_dir" make sync-opencode
	assert_exists "$home_dir/.config/opencode/opencode.json"
	assert_file_contains "$home_dir/.config/opencode/opencode.json" '"share": "disabled"'
	assert_symlink_resolves_to "$home_dir/.config/opencode/agents" "$REPO_ROOT/opencode/agents"
	# opencode reads instructions from a global AGENTS.md → canonical pi file
	assert_symlink_target "$home_dir/.config/opencode/AGENTS.md" "$home_dir/.pi/agent/AGENTS.md"

	HOME="$home_dir" make sync-skills
	# Shared skills land as one symlink per skill under ~/.agents/skills/
	assert_symlink_resolves_to "$home_dir/.agents/skills/find-docs" "$REPO_ROOT/skills/.agents/skills/find-docs"
	assert_exists "$home_dir/.agents/skills/find-docs/SKILL.md"

	HOME="$home_dir" make sync-claude
	# CLAUDE.md is now a symlink to the canonical pi AGENTS.md
	assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.claude/CLAUDE.md" 'You are an experienced, pragmatic software engineer.'
	assert_exists "$home_dir/.claude/settings.json"
	assert_symlink_resolves_to "$home_dir/.claude/agents" "$REPO_ROOT/claude/.claude/agents"
	# Claude reaches skills via ~/.claude/skills -> ~/.agents/skills
	assert_symlink_target "$home_dir/.claude/skills" "$home_dir/.agents/skills"
	assert_exists "$home_dir/.claude/skills/find-docs/SKILL.md"
	assert_not_exists "$home_dir/.claude/skills/web-browser"
	assert_not_exists "$home_dir/.claude/skills/uv-package-manager/SKILL.md"

	HOME="$home_dir" make sync-pi
	# pi owns the canonical instructions as a real generated file
	assert_regular_file "$home_dir/.pi/agent/AGENTS.md"
	assert_file_contains "$home_dir/.pi/agent/AGENTS.md" 'You are an experienced, pragmatic software engineer.'
	assert_exists "$home_dir/.pi/agent/settings.json"
	assert_file_contains "$home_dir/.pi/agent/settings.json" 'npm:pi-subagents'
}

main "$@"
