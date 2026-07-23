#!/bin/bash

# Inject pi extension packages into settings.json.
#
# pi owns ~/.pi/agent/settings.json as the user's personal file, so we never
# clobber it wholesale: we only manage the .packages array. When it already
# matches the manifest we do nothing; when it differs we show a diff and ask
# before overwriting.
#
# Usage: sync-pi-packages.sh <settings.json> <packages.json>

set -euo pipefail

settings_file="$1"
packages_file="$2"

if [ ! -f "$settings_file" ]; then
	echo "  Creating $settings_file with packages..."
	jq -n '{packages: $pkgs[0]}' --slurpfile pkgs "$packages_file" > "$settings_file"
	exit 0
fi

existing_packages=$(jq '.packages' "$settings_file")
incoming_packages=$(jq '.' "$packages_file")

if [ "$existing_packages" = "$incoming_packages" ]; then
	echo "  ✅ Packages already up to date."
	exit 0
fi

echo ""
echo "  📦 Package diff (current → incoming):"
diff <(echo "$existing_packages" | jq -S '.' 2>/dev/null) \
     <(echo "$incoming_packages" | jq -S '.') \
     --label "current $settings_file" \
     --label "incoming $packages_file" || true
echo ""
read -p "  Overwrite packages? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo "  Injecting packages into $settings_file..."
	jq '.packages = $pkgs[0]' --slurpfile pkgs "$packages_file" "$settings_file" > "$settings_file.tmp"
	mv "$settings_file.tmp" "$settings_file"
else
	echo "  ⏭️  Skipped package injection."
fi
