#!/bin/bash

set -euo pipefail

REPO_ROOT=$(pwd)
TEST_OUTPUT=$(mktemp /tmp/makefile-safety.out.XXXXXX)

cleanup() {
	rm -f "$TEST_OUTPUT"
}

trap cleanup EXIT

assert_file_exists() {
	if [ ! -f "$1" ]; then
		printf 'Expected file to exist: %s\n' "$1" >&2
		exit 1
	fi
}

assert_dir_exists() {
	if [ ! -d "$1" ]; then
		printf 'Expected directory to exist: %s\n' "$1" >&2
		exit 1
	fi
}

assert_contains() {
	local file="$1"
	local expected="$2"

	if ! grep -Fq "$expected" "$file"; then
		printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
		exit 1
	fi
}

assert_not_contains() {
	local file="$1"
	local unexpected="$2"

	if grep -Fq "$unexpected" "$file"; then
		printf 'Did not expect %s to contain: %s\n' "$file" "$unexpected" >&2
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
		printf 'Expected %s to point to %s\n' "$path" "$expected" >&2
		exit 1
	fi
}

assert_make_fails() {
	local home_dir="$1"
	shift

	if HOME="$home_dir" make "$@" >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected make %s to fail\n' "$*" >&2
		cat "$TEST_OUTPUT" >&2
		exit 1
	fi
}

test_sync_opencode_preserves_existing_directory() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode/agents"
	printf 'keep me\n' >"$home_dir/.config/opencode/agents/local.txt"

	assert_make_fails "$home_dir" sync-opencode
	assert_dir_exists "$home_dir/.config/opencode/agents"
	assert_file_exists "$home_dir/.config/opencode/agents/local.txt"
	assert_contains "$home_dir/.config/opencode/agents/local.txt" 'keep me'
	# Verify no partial install: opencode.json must not be written
	if [ -e "$home_dir/.config/opencode/opencode.json" ]; then
		printf 'Partial install: opencode.json was written despite agents conflict\n' >&2
		exit 1
	fi
}

test_sync_opencode_preserves_existing_config_json() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode"
	printf '{"custom":true}\n' >"$home_dir/.config/opencode/opencode.json"

	assert_make_fails "$home_dir" sync-opencode
	assert_file_exists "$home_dir/.config/opencode/opencode.json"
	assert_contains "$home_dir/.config/opencode/opencode.json" '{"custom":true}'
}

test_sync_opencode_force_overwrites_existing_config_json() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode"
	printf '{"custom":true}\n' >"$home_dir/.config/opencode/opencode.json"

	HOME="$home_dir" make sync-opencode-force >"$TEST_OUTPUT" 2>&1
	assert_file_exists "$home_dir/.config/opencode/opencode.json"
	assert_not_contains "$home_dir/.config/opencode/opencode.json" '{"custom":true}'
}

test_sync_opencode_force_replaces_existing_directory() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode/agents"
	printf 'replace me\n' >"$home_dir/.config/opencode/agents/local.txt"

	HOME="$home_dir" make sync-opencode-force >"$TEST_OUTPUT" 2>&1
	assert_symlink_target "$home_dir/.config/opencode/agents" "$REPO_ROOT/opencode/agents"
}

test_clean_force_preserves_unmanaged_opencode_directory() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode/agents"
	printf 'keep me\n' >"$home_dir/.config/opencode/agents/local.txt"

	HOME="$home_dir" make clean-force >"$TEST_OUTPUT" 2>&1
	assert_dir_exists "$home_dir/.config/opencode/agents"
	assert_file_exists "$home_dir/.config/opencode/agents/local.txt"
	assert_contains "$home_dir/.config/opencode/agents/local.txt" 'keep me'
}

test_sync_claude_preserves_existing_generated_files() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.claude"
	printf 'custom claude\n' >"$home_dir/.claude/CLAUDE.md"

	assert_make_fails "$home_dir" sync-claude
	assert_file_exists "$home_dir/.claude/CLAUDE.md"
	assert_contains "$home_dir/.claude/CLAUDE.md" 'custom claude'
}

test_sync_claude_force_overwrites_generated_files() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.claude"
	printf 'custom claude\n' >"$home_dir/.claude/CLAUDE.md"
	printf '{"custom":true}\n' >"$home_dir/.claude/settings.json"

	HOME="$home_dir" make sync-claude-force >"$TEST_OUTPUT" 2>&1
	assert_symlink_target "$home_dir/.claude/agents" "$REPO_ROOT/claude/.claude/agents"
	assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$home_dir/.pi/agent/AGENTS.md"
	assert_contains "$home_dir/.claude/CLAUDE.md" "You are an experienced, pragmatic software engineer."
	assert_not_contains "$home_dir/.claude/CLAUDE.md" 'custom claude'
}

test_sync_pi_preserves_existing_canonical() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.pi/agent"
	printf 'custom agents\n' >"$home_dir/.pi/agent/AGENTS.md"

	assert_make_fails "$home_dir" sync-pi
	assert_file_exists "$home_dir/.pi/agent/AGENTS.md"
	assert_contains "$home_dir/.pi/agent/AGENTS.md" 'custom agents'
}

test_sync_pi_force_overwrites_canonical() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.pi/agent"
	printf 'custom agents\n' >"$home_dir/.pi/agent/AGENTS.md"

	HOME="$home_dir" make sync-pi-force >"$TEST_OUTPUT" 2>&1
	assert_contains "$home_dir/.pi/agent/AGENTS.md" "You are an experienced, pragmatic software engineer."
	assert_not_contains "$home_dir/.pi/agent/AGENTS.md" 'custom agents'
}

test_clean_claude_preserves_custom_files() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.claude"
	printf 'custom claude\n' >"$home_dir/.claude/CLAUDE.md"
	printf '{"custom":true}\n' >"$home_dir/.claude/settings.json"

	HOME="$home_dir" make clean-claude >"$TEST_OUTPUT" 2>&1
	assert_file_exists "$home_dir/.claude/CLAUDE.md"
	assert_file_exists "$home_dir/.claude/settings.json"
	assert_contains "$home_dir/.claude/CLAUDE.md" 'custom claude'
	assert_contains "$home_dir/.claude/settings.json" '{"custom":true}'
}

test_clean_opencode_preserves_unmanaged_directory() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.config/opencode/agents"
	printf 'keep me\n' >"$home_dir/.config/opencode/agents/local.txt"

	HOME="$home_dir" make clean-opencode >"$TEST_OUTPUT" 2>&1
	assert_dir_exists "$home_dir/.config/opencode/agents"
	assert_file_exists "$home_dir/.config/opencode/agents/local.txt"
	assert_contains "$home_dir/.config/opencode/agents/local.txt" 'keep me'
}

main() {
	cd "$REPO_ROOT"
	test_sync_opencode_preserves_existing_directory
	test_sync_opencode_preserves_existing_config_json
	test_sync_opencode_force_overwrites_existing_config_json
	test_sync_opencode_force_replaces_existing_directory
	test_clean_force_preserves_unmanaged_opencode_directory
	test_sync_claude_preserves_existing_generated_files
	test_sync_claude_force_overwrites_generated_files
	test_sync_pi_preserves_existing_canonical
	test_sync_pi_force_overwrites_canonical
	test_clean_claude_preserves_custom_files
	test_clean_opencode_preserves_unmanaged_directory
}

main "$@"
