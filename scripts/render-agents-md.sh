#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
	printf 'Usage: %s TEMPLATE PERSONAL_INSTRUCTIONS\n' "$0" >&2
	exit 2
fi

if [ -z "${AGENT_NAME:-}" ]; then
	printf 'AGENT_NAME is required\n' >&2
	exit 1
fi
if [ "$AGENT_NAME" = "YOUR_NAME" ]; then
	printf 'AGENT_NAME must be set to your name\n' >&2
	exit 1
fi

template="$1"
personal_instructions="$2"
partner_token='{{PARTNER_NAME}}'
personal_token='{{PERSONAL_INSTRUCTIONS}}'

if [ ! -f "$template" ]; then
	printf 'Template does not exist: %s\n' "$template" >&2
	exit 1
fi
if [ ! -r "$personal_instructions" ] || [ -d "$personal_instructions" ]; then
	printf 'Personal instructions are not readable: %s\n' "$personal_instructions" >&2
	exit 1
fi

partner_count=$({ grep -Fo "$partner_token" "$template" || true; } | wc -l | tr -d ' ')
personal_count=$(grep -Fxc "$personal_token" "$template" || true)
if [ "$partner_count" -eq 0 ]; then
	printf 'Template must contain %s\n' "$partner_token" >&2
	exit 1
fi
if [ "$personal_count" -ne 1 ]; then
	printf 'Template must contain exactly one %s line\n' "$personal_token" >&2
	exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
	if [ "$line" = "$personal_token" ]; then
		if [ -s "$personal_instructions" ]; then
			cat "$personal_instructions"
			last_byte=$(tail -c 1 "$personal_instructions" | od -An -t u1 | tr -d ' ')
			[ "$last_byte" = "10" ] || printf '\n'
		fi
		continue
	fi

	rendered=${line//$partner_token/$AGENT_NAME}
	printf '%s\n' "$rendered"
done <"$template"
