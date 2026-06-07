# Default target
all: sync

# Recipes use bash-only features (process substitution, [[ ]], read -n).
SHELL := /bin/bash

REPO_ROOT := $(abspath $(CURDIR))

# Auto-detect work environment via OPENCODE_WORK_CONFIG env var (path to external config dir)
OPENCODE_ENV := $(if $(OPENCODE_WORK_CONFIG),work,personal)
OPENCODE_JPATH := $(if $(OPENCODE_WORK_CONFIG),-J $(OPENCODE_WORK_CONFIG) -J $(REPO_ROOT)/jsonnet,)

define ensure_safe_symlink
target="$(1)"; source="$(2)"; force_hint="$(3)"; \
if [ -L "$$target" ]; then \
	current="$$(readlink "$$target")"; \
	if [ "$$current" != "$$source" ]; then \
		echo "❌ $$target points to $$current"; \
		echo "   Expected: $$source"; \
		echo "   Remove it manually or run make $$force_hint"; \
		exit 1; \
	fi; \
elif [ -e "$$target" ]; then \
	echo "❌ $$target already exists and is not a symlink managed by this repo"; \
	echo "   Move it away manually or run make $$force_hint"; \
	exit 1; \
fi
endef

define remove_managed_path
target="$(1)"; source="$(2)"; \
if [ -L "$$target" ]; then \
	current="$$(readlink "$$target")"; \
	if [ "$$current" = "$$source" ]; then \
		rm -f "$$target"; \
	else \
		echo "⚠️  Skipping unmanaged symlink $$target -> $$current"; \
	fi; \
elif [ -e "$$target" ]; then \
	echo "⚠️  Skipping unmanaged path $$target"; \
fi
endef

# Merge base + optional personal instructions into the file at $(1).
# This is the canonical AGENTS.md content, owned by ~/.pi/agent/AGENTS.md.
define build_agents_md
if [ -f "$(REPO_ROOT)/claude/.claude/AGENTS.personal.md" ]; then \
	echo "  Merging base + personal → AGENTS.md"; \
	{ cat "$(REPO_ROOT)/claude/.claude/AGENTS.base.md"; echo ""; cat "$(REPO_ROOT)/claude/.claude/AGENTS.personal.md"; } > "$(1)"; \
else \
	echo "  No AGENTS.personal.md found, using base only"; \
	echo "  💡 Copy AGENTS.personal.md.example → AGENTS.personal.md to customize"; \
	cp "$(REPO_ROOT)/claude/.claude/AGENTS.base.md" "$(1)"; \
fi
endef

# Merge settings template + optional personal overrides into the file at $(1).
define build_settings
echo "  Generating settings.json..."; \
if [ -f "$(REPO_ROOT)/claude/claude_settings.personal.json" ]; then \
	echo "  Merging template + personal settings.json"; \
	jq -s '.[0] * .[1]' "$(REPO_ROOT)/claude/claude_settings.json.template" "$(REPO_ROOT)/claude/claude_settings.personal.json" > "$(1)"; \
else \
	cp "$(REPO_ROOT)/claude/claude_settings.json.template" "$(1)"; \
fi
endef

define remove_managed_file
target="$(1)"; expected="$(2)"; \
if [ -L "$$target" ]; then \
	echo "⚠️  Skipping unmanaged symlink $$target"; \
elif [ -e "$$target" ]; then \
	if cmp -s "$$target" "$$expected"; then \
		rm -f "$$target"; \
	else \
		echo "⚠️  Skipping unmanaged file $$target"; \
	fi; \
fi
endef

# Shared prerequisite
require-stow:
	@command -v stow >/dev/null 2>&1 || { echo "❌ stow is not installed. Please install it first."; exit 1; }

# Install all configurations (removed automatic installation)
sync:
	@echo "⚠️  Please specify which configuration to install:"
	@echo "  make sync-claude        - Install Claude Code configuration"
	@echo "  make sync-ccstatusline  - Install ccstatusline configuration"
	@echo "  make sync-opencode      - Install OpenCode configuration (agents + opencode.json)"
	@echo "  make sync-pi            - Install pi configuration (AGENTS.md + settings.json)"

# Generate the canonical instructions file at ~/.pi/agent/AGENTS.md.
# pi owns this file; Claude Code and OpenCode symlink to it. Every sync target
# that needs the instructions depends on this so the canonical file always exists.
sync-agents-md:
	@echo "📝 Generating canonical AGENTS.md (~/.pi/agent/AGENTS.md)..."
	@set -e; \
	mkdir -p ~/.pi/agent; \
	tmp_agents="$$(mktemp /tmp/agents-md.XXXXXX)"; \
	cleanup() { rm -f "$$tmp_agents"; }; \
	trap cleanup EXIT; \
	$(call build_agents_md,$$tmp_agents); \
	if [ -e "$${HOME}/.pi/agent/AGENTS.md" ] && [ ! -L "$${HOME}/.pi/agent/AGENTS.md" ] && ! cmp -s "$$tmp_agents" "$${HOME}/.pi/agent/AGENTS.md"; then \
		echo "❌ $${HOME}/.pi/agent/AGENTS.md already exists with different contents"; \
		echo "   Move it away manually or run make sync-pi-force"; \
		exit 1; \
	fi; \
	mv "$$tmp_agents" "$${HOME}/.pi/agent/AGENTS.md"

# Install Claude Code configuration
# CLAUDE.md is a symlink to the canonical ~/.pi/agent/AGENTS.md.
sync-claude: sync-agents-md
	@echo "🤖 Installing Claude Code configuration..."
	@set -e; \
	mkdir -p ~/.claude; \
	command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Please install it first."; exit 1; }; \
	tmp_settings="$$(mktemp /tmp/claude-settings.XXXXXX)"; \
	cleanup() { rm -f "$$tmp_settings"; }; \
	trap cleanup EXIT; \
	$(call build_settings,$$tmp_settings); \
	if [ -e "$${HOME}/.claude/settings.json" ] && ! cmp -s "$$tmp_settings" "$${HOME}/.claude/settings.json"; then \
		echo "❌ $${HOME}/.claude/settings.json already exists with different contents"; \
		echo "   Move it away manually or run make sync-claude-force"; \
		exit 1; \
	fi; \
	$(call ensure_safe_symlink,$${HOME}/.claude/CLAUDE.md,$${HOME}/.pi/agent/AGENTS.md,sync-claude-force); \
	$(call ensure_safe_symlink,$${HOME}/.claude/agents,$(REPO_ROOT)/claude/.claude/agents,sync-claude-force); \
	$(call ensure_safe_symlink,$${HOME}/.claude/skills,$(REPO_ROOT)/claude/.claude/skills,sync-claude-force); \
	mv "$$tmp_settings" "$${HOME}/.claude/settings.json"; \
	ln -snf "$${HOME}/.pi/agent/AGENTS.md" "$${HOME}/.claude/CLAUDE.md"; \
	ln -snf "$(REPO_ROOT)/claude/.claude/agents" "$${HOME}/.claude/agents"; \
	ln -snf "$(REPO_ROOT)/claude/.claude/skills" "$${HOME}/.claude/skills"
	@echo "✅ Claude Code configuration installed"

sync-claude-force:
	@echo "🤖 Installing Claude Code configuration (force)..."
	@mkdir -p ~/.claude
	@rm -rf ~/.claude/agents ~/.claude/skills
	@rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
	@$(MAKE) sync-claude

# Install ccstatusline configuration
sync-ccstatusline: require-stow
	@echo "📊 Installing ccstatusline configuration..."
	@mkdir -p ~/.config/ccstatusline
	@if [ -f ~/.config/ccstatusline/settings.json ] && [ ! -L ~/.config/ccstatusline/settings.json ]; then \
		backup_file="$$HOME/.config/ccstatusline/settings.json.bak.$$(date +%Y%m%d%H%M%S)"; \
		echo "  Backing up existing settings.json → $$backup_file"; \
		mv ~/.config/ccstatusline/settings.json "$$backup_file"; \
	fi
	stow -t ~ ccstatusline
	@echo "✅ ccstatusline configuration installed"

# Install OpenCode configuration (agents + opencode.json from jsonnet)
# Global instructions come from ~/.config/opencode/AGENTS.md → canonical pi file.
sync-opencode: sync-agents-md
	@echo "🤖 Installing OpenCode configuration..."
	@mkdir -p ~/.config/opencode
	@command -v jsonnet >/dev/null 2>&1 || { echo "❌ jsonnet is not installed. Please install it first."; exit 1; }
	@set -e; \
	echo "  Building opencode.json (env=$(OPENCODE_ENV))..."; \
	tmp_opencode="$$(mktemp /tmp/opencode-json.XXXXXX)"; \
	cleanup() { rm -f "$$tmp_opencode"; }; \
	trap cleanup EXIT; \
	jsonnet $(OPENCODE_JPATH) --tla-str env=$(OPENCODE_ENV) "$(REPO_ROOT)/jsonnet/opencode.jsonnet" > "$$tmp_opencode"; \
	if [ -e "$${HOME}/.config/opencode/opencode.json" ] && ! cmp -s "$$tmp_opencode" "$${HOME}/.config/opencode/opencode.json"; then \
		echo "❌ ~/.config/opencode/opencode.json already exists with different contents"; \
		echo "   Move it away manually or run make sync-opencode-force"; \
		exit 1; \
	fi; \
	$(call ensure_safe_symlink,$${HOME}/.config/opencode/agents,$(REPO_ROOT)/opencode/agents,sync-opencode-force); \
	$(call ensure_safe_symlink,$${HOME}/.config/opencode/AGENTS.md,$${HOME}/.pi/agent/AGENTS.md,sync-opencode-force); \
	mv "$$tmp_opencode" "$${HOME}/.config/opencode/opencode.json"; \
	ln -snf "$(REPO_ROOT)/opencode/agents" "$${HOME}/.config/opencode/agents"; \
	ln -snf "$${HOME}/.pi/agent/AGENTS.md" "$${HOME}/.config/opencode/AGENTS.md"
	@echo "✅ OpenCode configuration installed (env=$(OPENCODE_ENV))"

sync-opencode-force:
	@echo "🤖 Installing OpenCode configuration (force)..."
	@mkdir -p ~/.config/opencode
	@rm -f ~/.config/opencode/opencode.json ~/.config/opencode/AGENTS.md
	@rm -rf ~/.config/opencode/agents
	@$(MAKE) sync-opencode

# Install pi configuration (owns canonical AGENTS.md; packages injected into settings.json)
sync-pi: sync-agents-md
	@echo "🤖 Installing pi configuration..."
	@mkdir -p ~/.pi/agent
	@command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Please install it first."; exit 1; }
	@if [ -f ~/.pi/agent/settings.json ]; then \
		existing_packages=$$(jq '.packages' ~/.pi/agent/settings.json); \
		incoming_packages=$$(jq '.' "$(REPO_ROOT)/pi/packages.json"); \
		if [ "$$existing_packages" != "$$incoming_packages" ]; then \
			echo ""; \
			echo "  📦 Package diff (current → incoming):"; \
			diff <(echo "$$existing_packages" | jq -S '.' 2>/dev/null) \
			     <(echo "$$incoming_packages" | jq -S '.') \
			     --label "current ~/.pi/agent/settings.json" \
			     --label "incoming pi/packages.json" || true; \
			echo ""; \
			read -p "  Overwrite packages? [y/N] " -n 1 -r; \
			echo ""; \
			if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
				echo "  Injecting packages into ~/.pi/agent/settings.json..."; \
				jq '.packages = $$pkgs[0]' --slurpfile pkgs "$(REPO_ROOT)/pi/packages.json" ~/.pi/agent/settings.json > ~/.pi/agent/settings.json.tmp && \
				mv ~/.pi/agent/settings.json.tmp ~/.pi/agent/settings.json; \
			else \
				echo "  ⏭️  Skipped package injection."; \
			fi; \
		else \
			echo "  ✅ Packages already up to date."; \
		fi; \
	else \
		echo "  Creating ~/.pi/agent/settings.json with packages..."; \
		jq -n '{packages: $$pkgs[0]}' --slurpfile pkgs "$(REPO_ROOT)/pi/packages.json" > ~/.pi/agent/settings.json; \
	fi
	@echo "✅ pi configuration installed"
	@echo "  ~/.pi/agent/AGENTS.md (canonical instructions)"
	@echo "  ~/.pi/agent/settings.json (packages injected)"

sync-pi-force:
	@echo "🤖 Installing pi configuration (force)..."
	@mkdir -p ~/.pi/agent
	@rm -f ~/.pi/agent/AGENTS.md
	@$(MAKE) sync-pi

# Remove all symlinks and generated files (with confirmation)
clean:
	@echo "⚠️  WARNING: This will remove all agent-config configurations!"
	@echo "  - ~/.claude/ (CLAUDE.md, settings.json, agents, skills)"
	@echo "  - ~/.pi/agent/AGENTS.md (canonical instructions)"
	@echo "  - ~/.config/opencode/opencode.json"
	@echo "  - ~/.config/opencode/agents"
	@echo "  - ~/.config/opencode/AGENTS.md"
	@echo ""
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean-force; \
	else \
		echo "❌ Clean cancelled"; \
	fi

# Force clean without confirmation (used by clean target)
clean-force:
	@echo "🧹 Removing all configurations..."
	@$(MAKE) clean-claude
	@$(MAKE) clean-opencode
	@$(MAKE) clean-pi
	@echo "✅ All configurations removed"

clean-claude:
	@echo "🧹 Removing Claude Code configuration..."
	@set -e; \
	mkdir -p ~/.claude; \
	command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Please install it first."; exit 1; }; \
	tmp_settings="$$(mktemp /tmp/claude-settings.XXXXXX)"; \
	cleanup() { rm -f "$$tmp_settings"; }; \
	trap cleanup EXIT; \
	$(call build_settings,$$tmp_settings); \
	$(call remove_managed_file,$${HOME}/.claude/settings.json,$$tmp_settings)
	@$(call remove_managed_path,$${HOME}/.claude/CLAUDE.md,$${HOME}/.pi/agent/AGENTS.md)
	@$(call remove_managed_path,$${HOME}/.claude/agents,$(REPO_ROOT)/claude/.claude/agents)
	@$(call remove_managed_path,$${HOME}/.claude/skills,$(REPO_ROOT)/claude/.claude/skills)
	@echo "✅ Claude Code configuration removed"

clean-opencode:
	@echo "🧹 Removing OpenCode configuration..."
	@set -e; \
	if command -v jsonnet >/dev/null 2>&1; then \
		tmp_opencode="$$(mktemp /tmp/opencode-json.XXXXXX)"; \
		cleanup() { rm -f "$$tmp_opencode"; }; \
		trap cleanup EXIT; \
		jsonnet $(OPENCODE_JPATH) --tla-str env=$(OPENCODE_ENV) "$(REPO_ROOT)/jsonnet/opencode.jsonnet" > "$$tmp_opencode"; \
		$(call remove_managed_file,$${HOME}/.config/opencode/opencode.json,$$tmp_opencode); \
	else \
		echo "  ⚠️  jsonnet not found, skipping opencode.json cleanup"; \
	fi
	@$(call remove_managed_path,$${HOME}/.config/opencode/agents,$(REPO_ROOT)/opencode/agents)
	@$(call remove_managed_path,$${HOME}/.config/opencode/AGENTS.md,$${HOME}/.pi/agent/AGENTS.md)
	@echo "✅ OpenCode configuration removed"

clean-pi:
	@echo "🧹 Removing pi configuration..."
	@set -e; \
	tmp_agents="$$(mktemp /tmp/agents-md.XXXXXX)"; \
	cleanup() { rm -f "$$tmp_agents"; }; \
	trap cleanup EXIT; \
	$(call build_agents_md,$$tmp_agents); \
	$(call remove_managed_file,$${HOME}/.pi/agent/AGENTS.md,$$tmp_agents)
	@echo "  (settings.json left untouched — it is your personal file)"
	@echo "✅ pi configuration removed"

# Test commands
test: check-syntax test-safety test-sync-smoke
	@echo "✅ All checks passed!"

test-safety:
	@bash "./test_makefile_safety.sh"

test-sync-smoke:
	@bash "./test_sync_smoke.sh"

# Check syntax of configuration files
check-syntax:
	@echo "🔍 Checking syntax..."
	@echo "Checking Jsonnet files..."
	@if command -v jsonnet >/dev/null 2>&1; then \
		for file in $$(find ./jsonnet -name "*.jsonnet" -o -name "*.libsonnet" 2>/dev/null | grep -v '_work'); do \
			echo "  Checking $$file"; \
			jsonnet --tla-str env=personal "$$file" >/dev/null 2>&1 || jsonnet "$$file" >/dev/null 2>&1 || { echo "❌ Syntax error in $$file"; exit 1; }; \
		done; \
	else \
		echo "  ⚠️  jsonnet not found, skipping Jsonnet checks"; \
	fi
	@echo "Checking JSON files..."
	@for file in claude/claude_settings.json.template pi/packages.json ccstatusline/.config/ccstatusline/settings.json; do \
		if [ -f "$$file" ]; then \
			echo "  Checking $$file"; \
			python3 -m json.tool "$$file" >/dev/null || { echo "❌ Invalid JSON in $$file"; exit 1; }; \
		fi; \
	done
	@echo "✅ Syntax check passed"

.PHONY: all require-stow clean clean-force clean-claude clean-opencode clean-pi sync sync-agents-md sync-claude sync-claude-force sync-ccstatusline sync-opencode sync-opencode-force sync-pi sync-pi-force test test-safety test-sync-smoke check-syntax
