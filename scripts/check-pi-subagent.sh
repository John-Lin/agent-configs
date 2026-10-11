#!/bin/bash

# Verify the installed subagent command and skill; optionally exercise a real
# model-backed child on an isolated tmux server without touching daily sessions.
set -euo pipefail

live=false
case "${1:-}" in
	"") ;;
	--live) live=true ;;
	-h|--help)
		printf 'Usage: bash scripts/check-pi-subagent.sh [--live]\n'
		printf 'Check Pi registration. --live also runs a real model request and requires authentication.\n'
		exit 0
		;;
	*) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
	printf 'Expected at most one argument; use --help for usage.\n' >&2
	exit 1
fi

for command in pi subagent jq tmux; do
	command -v "$command" >/dev/null || { printf 'Required command not found: %s\n' "$command" >&2; exit 1; }
done

logs=$(mktemp -d /tmp/pi-subagent-check.XXXXXX)
handle=
cleanup() {
	if [ -n "$handle" ]; then
		subagent stop "$handle" >>"$logs/cleanup.log" 2>&1 || printf 'Cleanup failed; see %s/cleanup.log\n' "$logs" >&2
	fi
}
trap cleanup EXIT
printf 'Verification logs: %s\n' "$logs"

printf '{"id":"commands","type":"get_commands"}\n' |
	pi --offline --no-mcp --mode rpc --no-session >"$logs/commands.jsonl" 2>"$logs/stderr.log"
if [ -s "$logs/stderr.log" ]; then
	printf 'Pi emitted diagnostics; inspect %s/stderr.log\n' "$logs" >&2
	exit 1
fi
if ! jq -se '
	any(.[]; .id == "commands" and .success == true and
		([.data.commands[]? | select(.name == "subagent" and .source == "extension" and
			.sourceInfo.source == "git:github.com/badlogic/pi-subagent")] | length == 1) and
		([.data.commands[]? | select(.name == "skill:subagent" and .source == "skill")] | length == 1))
' "$logs/commands.jsonl" >/dev/null; then
	printf 'Expected badlogic subagent command and skill; inspect %s/commands.jsonl\n' "$logs" >&2
	exit 1
fi
printf 'PASS: badlogic subagent command and skill registered\n'

if [ "$live" = false ]; then
	exit 0
fi

# TMUX_TMPDIR gives the CLI its own default socket; clear any inherited server.
unset TMUX TMUX_PANE
export TMUX_TMPDIR="$logs"
settings="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/settings.json"
provider="${PI_PROVIDER:-$(jq -r '.defaultProvider // empty' "$settings")}"
model="${PI_MODEL:-$(jq -r '.defaultModel // empty' "$settings")}"
subagent spawn --name installation-check --cwd "$logs" --provider "$provider" --model "$model" \
	--thinking off --tools read,grep,find,ls --no-extensions --no-skills \
	--no-prompt-templates --no-context-files \
	--prompt 'Reply with exactly SUBAGENT_INSTALL_OK. Do not use any tools.' >"$logs/spawn.log"
handle=$(grep -Eo '\([a-f0-9]{6}\)' "$logs/spawn.log" | tr -d '()')
if [ -z "$handle" ]; then
	printf 'Could not read child handle; inspect %s/spawn.log\n' "$logs" >&2
	exit 1
fi
subagent status "$handle" >"$logs/status.log"
subagent wait "$handle" --timeout 120 >"$logs/result.log"
if ! grep -Fxq 'SUBAGENT_INSTALL_OK' "$logs/result.log"; then
	printf 'Unexpected model response; inspect %s/result.log\n' "$logs" >&2
	exit 1
fi
subagent stop "$handle" >"$logs/stop.log"
handle=
printf 'PASS: real child spawned, returned a response, and stopped on an isolated tmux server\n'
