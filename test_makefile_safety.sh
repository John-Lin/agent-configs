#!/bin/bash

set -euo pipefail

REPO_ROOT=$(pwd)
TEST_OUTPUT=$(mktemp /tmp/makefile-safety.out.XXXXXX)
export AGENT_NAME="Test Partner"

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
		printf 'Expected %s not to contain: %s\n' "$file" "$unexpected" >&2
		exit 1
	fi
}

assert_occurrences() {
	local file="$1"
	local expected="$2"
	local expected_count="$3"
	local actual_count

	actual_count=$({ grep -Fo "$expected" "$file" || true; } | wc -l | tr -d ' ')
	if [ "$actual_count" != "$expected_count" ]; then
		printf 'Expected %s to contain %s occurrences of %s, got %s\n' \
			"$file" "$expected_count" "$expected" "$actual_count" >&2
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
	assert_contains "$home_dir/.config/opencode/opencode.json" '"share": "disabled"'
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

test_sync_skills_preserves_unmanaged_claude_skills_symlink() {
	local home_dir custom_skills
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN
	custom_skills="$home_dir/custom-skills"

	mkdir -p "$home_dir/.claude" "$custom_skills"
	printf 'keep me\n' >"$custom_skills/local.txt"
	ln -s "$custom_skills" "$home_dir/.claude/skills"

	assert_make_fails "$home_dir" sync-skills
	assert_symlink_target "$home_dir/.claude/skills" "$custom_skills"
	assert_file_exists "$custom_skills/local.txt"
	assert_contains "$custom_skills/local.txt" 'keep me'
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
	assert_symlink_resolves_to "$home_dir/.claude/skills/find-docs" "$home_dir/.agents/skills/find-docs"
	assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$home_dir/.pi/agent/AGENTS.md"
	assert_contains "$home_dir/.claude/CLAUDE.md" "You are an experienced, pragmatic software engineer."
}

test_sync_agents_md_preserves_existing_canonical() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.pi/agent"
	printf 'custom agents\n' >"$home_dir/.pi/agent/AGENTS.md"

	assert_make_fails "$home_dir" sync-agents-md
	assert_file_exists "$home_dir/.pi/agent/AGENTS.md"
	assert_contains "$home_dir/.pi/agent/AGENTS.md" 'custom agents'
}

test_sync_agents_md_force_overwrites_canonical() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	mkdir -p "$home_dir/.pi/agent"
	printf 'custom agents\n' >"$home_dir/.pi/agent/AGENTS.md"

	HOME="$home_dir" make sync-agents-md-force >"$TEST_OUTPUT" 2>&1
	assert_contains "$home_dir/.pi/agent/AGENTS.md" "You are an experienced, pragmatic software engineer."
}

test_agents_template_uses_personal_placeholders() {
	local template="$REPO_ROOT/agents-md/AGENTS.base.md"

	assert_occurrences "$template" '{{PARTNER_NAME}}' 5
	assert_occurrences "$template" '{{PERSONAL_INSTRUCTIONS}}' 1
	assert_not_contains "$template" 'John'
	assert_not_contains "$template" 'Jesse'
}

test_agents_renderer_rejects_example_name() {
	local template
	template=$(mktemp /tmp/agents-template.XXXXXX)
	trap 'rm -f "${template-}"' RETURN

	printf '{{PARTNER_NAME}}\n{{PERSONAL_INSTRUCTIONS}}\n' >"$template"
	if AGENT_NAME=YOUR_NAME "$REPO_ROOT/scripts/render-agents-md.sh" "$template" /dev/null >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected renderer to reject example AGENT_NAME\n' >&2
		exit 1
	fi
	assert_contains "$TEST_OUTPUT" 'AGENT_NAME must be set to your name'
}

test_agents_renderer_requires_one_personal_placeholder() {
	local template
	template=$(mktemp /tmp/agents-template.XXXXXX)
	trap 'rm -f "${template-}"' RETURN

	printf '{{PARTNER_NAME}}\n' >"$template"
	if "$REPO_ROOT/scripts/render-agents-md.sh" "$template" /dev/null >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected renderer to reject a template without {{PERSONAL_INSTRUCTIONS}}\n' >&2
		exit 1
	fi
	assert_contains "$TEST_OUTPUT" 'exactly one {{PERSONAL_INSTRUCTIONS}} line'

	printf '{{PARTNER_NAME}}\n{{PERSONAL_INSTRUCTIONS}}\n{{PERSONAL_INSTRUCTIONS}}\n' >"$template"
	if "$REPO_ROOT/scripts/render-agents-md.sh" "$template" /dev/null >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected renderer to reject duplicate {{PERSONAL_INSTRUCTIONS}} lines\n' >&2
		exit 1
	fi
	assert_contains "$TEST_OUTPUT" 'exactly one {{PERSONAL_INSTRUCTIONS}} line'
}

test_agents_renderer_interpolates_name_and_personal_instructions() {
	local template personal output expected
	template=$(mktemp /tmp/agents-template.XXXXXX)
	personal=$(mktemp /tmp/agents-personal.XXXXXX)
	output=$(mktemp /tmp/agents-output.XXXXXX)
	expected=$(mktemp /tmp/agents-expected.XXXXXX)
	trap 'rm -f "${template-}" "${personal-}" "${output-}" "${expected-}"' RETURN

	printf 'Hello, {{PARTNER_NAME}}.\n{{PERSONAL_INSTRUCTIONS}}\nGoodbye, {{PARTNER_NAME}}.\n' >"$template"
	printf 'Personal instruction.\n' >"$personal"
	printf 'Hello, Test Partner.\nPersonal instruction.\nGoodbye, Test Partner.\n' >"$expected"

	"$REPO_ROOT/scripts/render-agents-md.sh" "$template" "$personal" >"$output"
	if ! cmp -s "$output" "$expected"; then
		printf 'Rendered AGENTS.md did not match expected output\n' >&2
		diff -u "$expected" "$output" >&2 || true
		exit 1
	fi
}

test_agents_renderer_accepts_no_personal_instructions() {
	local template output expected
	template=$(mktemp /tmp/agents-template.XXXXXX)
	output=$(mktemp /tmp/agents-output.XXXXXX)
	expected=$(mktemp /tmp/agents-expected.XXXXXX)
	trap 'rm -f "${template-}" "${output-}" "${expected-}"' RETURN

	printf 'Hello, {{PARTNER_NAME}}.\n{{PERSONAL_INSTRUCTIONS}}\n' >"$template"
	printf 'Hello, Test Partner.\n' >"$expected"

	"$REPO_ROOT/scripts/render-agents-md.sh" "$template" /dev/null >"$output"
	if ! cmp -s "$output" "$expected"; then
		printf 'Name-only AGENTS.md did not match expected output\n' >&2
		diff -u "$expected" "$output" >&2 || true
		exit 1
	fi
}

test_sync_agents_md_renders_personal_name() {
	local home_dir output
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN
	output="$home_dir/.pi/agent/AGENTS.md"

	HOME="$home_dir" make sync-agents-md-force >"$TEST_OUTPUT" 2>&1
	assert_contains "$output" 'address your human partner as "Test Partner"'
	assert_contains "$output" 'working together as "Test Partner" and "Bot"'
	assert_not_contains "$output" '{{PARTNER_NAME}}'
	assert_not_contains "$output" '{{PERSONAL_INSTRUCTIONS}}'
}

test_sync_agents_md_rejects_example_name() {
	local home_dir
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	if HOME="$home_dir" make sync-agents-md-force AGENT_NAME=YOUR_NAME >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected sync-agents-md-force to reject example AGENT_NAME\n' >&2
		exit 1
	fi
	assert_contains "$TEST_OUTPUT" 'AGENT_NAME must be set to your name'
}

test_sync_agents_md_requires_personal_name() {
	local home_dir canonical expected
	home_dir=$(mktemp -d)
	trap '[ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN
	canonical="$home_dir/.pi/agent/AGENTS.md"
	mkdir -p "$(dirname "$canonical")"
	printf 'keep me\n' >"$canonical"
	expected=$(mktemp /tmp/agents-canonical.XXXXXX)
	cp "$canonical" "$expected"
	trap 'rm -f "${expected-}"; [ -n "${home_dir-}" ] && rm -rf "$home_dir"' RETURN

	if HOME="$home_dir" make sync-agents-md-force AGENT_NAME= >"$TEST_OUTPUT" 2>&1; then
		printf 'Expected sync-agents-md-force to fail without AGENT_NAME\n' >&2
		exit 1
	fi
	assert_contains "$TEST_OUTPUT" 'AGENT_NAME is required'
	assert_file_exists "$canonical"
	if ! cmp -s "$canonical" "$expected"; then
		printf 'Expected failed force sync to preserve canonical AGENTS.md byte-for-byte\n' >&2
		exit 1
	fi
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
	test_sync_skills_preserves_unmanaged_claude_skills_symlink
	test_sync_claude_preserves_existing_generated_files
	test_sync_claude_force_overwrites_generated_files
	test_sync_agents_md_preserves_existing_canonical
	test_sync_agents_md_force_overwrites_canonical
	test_agents_template_uses_personal_placeholders
	test_agents_renderer_rejects_example_name
	test_agents_renderer_requires_one_personal_placeholder
	test_agents_renderer_interpolates_name_and_personal_instructions
	test_agents_renderer_accepts_no_personal_instructions
	test_sync_agents_md_renders_personal_name
	test_sync_agents_md_rejects_example_name
	test_sync_agents_md_requires_personal_name
	test_sync_pi_preserves_existing_canonical
	test_sync_pi_force_overwrites_canonical
	test_clean_claude_preserves_custom_files
	test_clean_opencode_preserves_unmanaged_directory
}

main "$@"
