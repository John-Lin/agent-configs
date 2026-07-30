# Default target
all: sync

# Recipes use bash-only features (process substitution, [[ ]], read -n).
SHELL := /bin/bash

REPO_ROOT := $(abspath $(CURDIR))

# apm/apm.yml is the single source of truth for managed public skills; the tests
# derive their assertions from the same file. apm/apm-int.yml holds internal
# (non-public) sources, is gitignored, and is merged in when present.
SKILLS_MANIFEST := $(REPO_ROOT)/apm/apm.yml
SKILLS_MANIFEST_INT := $(REPO_ROOT)/apm/apm-int.yml
SKILLS_MANIFEST_FILES := $(SKILLS_MANIFEST) $(wildcard $(SKILLS_MANIFEST_INT))
# Merge every manifest (concatenating the dependency lists).
SKILLS_MANIFEST_MERGE := . as $$item ireduce ({}; . *+ $$item)
# Print every managed package reference, one per line (used by clean-skills).
# A dependency with a `path:` is uninstalled by its full "<repo>/<path>" form.
SKILLS_MANIFEST_PACKAGES := yq ea -r '$(SKILLS_MANIFEST_MERGE) | .dependencies.apm[] | [(.git // .), .path] | filter(. != null) | join("/")' $(SKILLS_MANIFEST_FILES)

# Auto-detect work environment via OPENCODE_WORK_CONFIG env var (path to external config dir)
OPENCODE_ENV := $(if $(OPENCODE_WORK_CONFIG),work,personal)
OPENCODE_JPATH := $(if $(OPENCODE_WORK_CONFIG),-J $(OPENCODE_WORK_CONFIG) -J $(REPO_ROOT)/jsonnet,)

define ensure_safe_symlink
target="$(1)"; source="$(2)"; force_hint="$(3)"; \
if [ -L "$$target" ]; then \
	current="$$(readlink "$$target")"; \
	if [ "$$current" != "$$source" ]; then \
		echo "Error: $$target points to $$current"; \
		echo "   Expected: $$source"; \
		echo "   Remove it manually or run make $$force_hint"; \
		exit 1; \
	fi; \
elif [ -e "$$target" ]; then \
	echo "Error: $$target already exists and is not a symlink managed by this repo"; \
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
		echo "Warning: Skipping unmanaged symlink $$target -> $$current"; \
	fi; \
elif [ -e "$$target" ]; then \
	echo "Warning: Skipping unmanaged path $$target"; \
fi
endef

# Merge base + optional personal instructions into the file at $(1).
# This is the canonical AGENTS.md content, owned by ~/.pi/agent/AGENTS.md.
define build_agents_md
if [ -f "$(REPO_ROOT)/agents-md/AGENTS.personal.md" ]; then \
	echo "  Merging base + personal → AGENTS.md"; \
	{ cat "$(REPO_ROOT)/agents-md/AGENTS.base.md"; echo ""; cat "$(REPO_ROOT)/agents-md/AGENTS.personal.md"; } > "$(1)"; \
else \
	echo "  No AGENTS.personal.md found, using base only"; \
	echo "  Copy AGENTS.personal.md.example → AGENTS.personal.md to customize"; \
	cp "$(REPO_ROOT)/agents-md/AGENTS.base.md" "$(1)"; \
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

# Refuse to clobber a customised file: fail if $(1) already exists and differs
# from the freshly built $(2), pointing the user at the force target $(3).
define assert_no_conflict
if [ -e "$(1)" ] && ! cmp -s "$(2)" "$(1)"; then \
	echo "Error: $(1) already exists with different contents"; \
	echo "   Move it away manually or run make $(3)"; \
	exit 1; \
fi
endef

define remove_managed_file
target="$(1)"; expected="$(2)"; \
if [ -L "$$target" ]; then \
	echo "Warning: Skipping unmanaged symlink $$target"; \
elif [ -e "$$target" ]; then \
	if cmp -s "$$target" "$$expected"; then \
		rm -f "$$target"; \
	else \
		echo "Warning: Skipping unmanaged file $$target"; \
	fi; \
fi
endef

# Shared prerequisites
require-stow:
	@command -v stow >/dev/null 2>&1 || { echo "Error: stow is not installed. Please install it first."; exit 1; }

require-apm:
	@command -v apm >/dev/null 2>&1 || { echo "Error: apm is not installed (brew install microsoft/apm/apm). Required to install skills."; exit 1; }

# mikefarah yq v4 (brew install yq); Ubuntu's apt "yq" is an incompatible tool.
require-yq:
	@command -v yq >/dev/null 2>&1 || { echo "Error: yq is not installed (brew install yq). Required to read apm/apm.yml."; exit 1; }

require-jq:
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq is not installed. Please install it first."; exit 1; }

require-jsonnet:
	@command -v jsonnet >/dev/null 2>&1 || { echo "Error: jsonnet is not installed. Please install it first."; exit 1; }

# Install all configurations (removed automatic installation)
sync:
	@echo "Warning: Please specify which configuration to install:"
	@echo "  make sync-claude        - Install Claude Code configuration"
	@echo "  make sync-ccstatusline  - Install ccstatusline configuration"
	@echo "  make sync-opencode      - Install OpenCode configuration (agents + opencode.json)"
	@echo "  make sync-pi            - Install pi configuration (AGENTS.md + settings.json)"
	@echo "  make sync-skills        - Install published skills to ~/.agents/skills/"

# Generate the canonical instructions file at ~/.pi/agent/AGENTS.md.
# pi owns this file; Claude Code and OpenCode symlink to it. Every sync target
# that needs the instructions depends on this so the canonical file always exists.
sync-agents-md:
	@echo "Generating canonical AGENTS.md (~/.pi/agent/AGENTS.md)..."
	@set -e; \
	mkdir -p ~/.pi/agent; \
	tmp_agents="$$(mktemp /tmp/agents-md.XXXXXX)"; \
	trap 'rm -f "$$tmp_agents"' EXIT; \
	$(call build_agents_md,$$tmp_agents); \
	if [ -e "$${HOME}/.pi/agent/AGENTS.md" ] && [ ! -L "$${HOME}/.pi/agent/AGENTS.md" ] && ! cmp -s "$$tmp_agents" "$${HOME}/.pi/agent/AGENTS.md"; then \
		echo "Error: $${HOME}/.pi/agent/AGENTS.md already exists with different contents"; \
		echo "   Move it away manually or run make sync-agents-md-force"; \
		exit 1; \
	fi; \
	mv "$$tmp_agents" "$${HOME}/.pi/agent/AGENTS.md"

# Regenerate the canonical AGENTS.md, replacing an existing real file. Use after
# editing AGENTS.personal.md when ~/.pi/agent/AGENTS.md is already a real file.
# Unlike sync-pi-force, this touches only the instructions, not settings.json.
sync-agents-md-force:
	@echo "Regenerating canonical AGENTS.md (force)..."
	@mkdir -p ~/.pi/agent
	@rm -f ~/.pi/agent/AGENTS.md
	@$(MAKE) sync-agents-md

# Install Claude Code configuration
# CLAUDE.md is a symlink to the canonical ~/.pi/agent/AGENTS.md.
sync-claude: sync-agents-md sync-skills require-jq
	@echo "Installing Claude Code configuration..."
	@set -e; \
	mkdir -p ~/.claude; \
	tmp_settings="$$(mktemp /tmp/claude-settings.XXXXXX)"; \
	trap 'rm -f "$$tmp_settings"' EXIT; \
	$(call build_settings,$$tmp_settings); \
	$(call assert_no_conflict,$${HOME}/.claude/settings.json,$$tmp_settings,sync-claude-force); \
	$(call ensure_safe_symlink,$${HOME}/.claude/CLAUDE.md,$${HOME}/.pi/agent/AGENTS.md,sync-claude-force); \
	$(call ensure_safe_symlink,$${HOME}/.claude/agents,$(REPO_ROOT)/claude/.claude/agents,sync-claude-force); \
	mv "$$tmp_settings" "$${HOME}/.claude/settings.json"; \
	ln -snf "$${HOME}/.pi/agent/AGENTS.md" "$${HOME}/.claude/CLAUDE.md"; \
	ln -snf "$(REPO_ROOT)/claude/.claude/agents" "$${HOME}/.claude/agents"
	@echo "Claude Code configuration installed"

sync-claude-force:
	@echo "Installing Claude Code configuration (force)..."
	@mkdir -p ~/.claude
	@rm -rf ~/.claude/agents
	@rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
	@$(MAKE) sync-claude

# Install ccstatusline configuration
sync-ccstatusline: require-stow
	@echo "Installing ccstatusline configuration..."
	@mkdir -p ~/.config/ccstatusline
	@if [ -f ~/.config/ccstatusline/settings.json ] && [ ! -L ~/.config/ccstatusline/settings.json ]; then \
		backup_file="$$HOME/.config/ccstatusline/settings.json.bak.$$(date +%Y%m%d%H%M%S)"; \
		echo "  Backing up existing settings.json → $$backup_file"; \
		mv ~/.config/ccstatusline/settings.json "$$backup_file"; \
	fi
	stow -t ~ ccstatusline
	@echo "ccstatusline configuration installed"

# Install the declared skills with apm. They land in the universal
# ~/.agents/skills directory, which OpenCode and pi read natively, and in
# ~/.claude/skills, the only skill directory Claude Code discovers.
sync-skills: require-apm require-yq
	@bash "$(REPO_ROOT)/scripts/sync-skills.sh" $(SKILLS_MANIFEST_FILES)

# Reinstall skills, replacing a drifted user-scope manifest. Use after an
# `apm uninstall --global` or a hand edit left ~/.apm/apm.yml out of sync with
# the repo manifest. Installed skills are reconciled from the manifest, so
# anything it no longer declares is pruned.
sync-skills-force:
	@echo "Installing shared skills (force)..."
	@rm -f ~/.apm/apm.yml
	@$(MAKE) sync-skills

# Install OpenCode configuration (agents + opencode.json from jsonnet)
# Global instructions come from ~/.config/opencode/AGENTS.md → canonical pi file.
sync-opencode: sync-agents-md require-jsonnet
	@echo "Installing OpenCode configuration..."
	@mkdir -p ~/.config/opencode
	@set -e; \
	echo "  Building opencode.json (env=$(OPENCODE_ENV))..."; \
	tmp_opencode="$$(mktemp /tmp/opencode-json.XXXXXX)"; \
	trap 'rm -f "$$tmp_opencode"' EXIT; \
	jsonnet $(OPENCODE_JPATH) --tla-str env=$(OPENCODE_ENV) "$(REPO_ROOT)/jsonnet/opencode.jsonnet" > "$$tmp_opencode"; \
	$(call assert_no_conflict,$${HOME}/.config/opencode/opencode.json,$$tmp_opencode,sync-opencode-force); \
	$(call ensure_safe_symlink,$${HOME}/.config/opencode/agents,$(REPO_ROOT)/opencode/agents,sync-opencode-force); \
	$(call ensure_safe_symlink,$${HOME}/.config/opencode/AGENTS.md,$${HOME}/.pi/agent/AGENTS.md,sync-opencode-force); \
	mv "$$tmp_opencode" "$${HOME}/.config/opencode/opencode.json"; \
	ln -snf "$(REPO_ROOT)/opencode/agents" "$${HOME}/.config/opencode/agents"; \
	ln -snf "$${HOME}/.pi/agent/AGENTS.md" "$${HOME}/.config/opencode/AGENTS.md"
	@echo "OpenCode configuration installed (env=$(OPENCODE_ENV))"

sync-opencode-force:
	@echo "Installing OpenCode configuration (force)..."
	@mkdir -p ~/.config/opencode
	@rm -f ~/.config/opencode/opencode.json ~/.config/opencode/AGENTS.md
	@rm -rf ~/.config/opencode/agents
	@$(MAKE) sync-opencode

# Install pi configuration (owns canonical AGENTS.md; packages injected into settings.json)
sync-pi: sync-agents-md require-jq
	@echo "Installing pi configuration..."
	@mkdir -p ~/.pi/agent
	@bash "$(REPO_ROOT)/scripts/sync-pi-packages.sh" "$${HOME}/.pi/agent/settings.json" "$(REPO_ROOT)/pi/packages.json"
	@echo "pi configuration installed"
	@echo "  ~/.pi/agent/AGENTS.md (canonical instructions)"
	@echo "  ~/.pi/agent/settings.json (packages injected)"

sync-pi-force:
	@echo "Installing pi configuration (force)..."
	@mkdir -p ~/.pi/agent
	@rm -f ~/.pi/agent/AGENTS.md
	@$(MAKE) sync-pi

# Remove all symlinks and generated files (with confirmation)
clean:
	@echo "WARNING: This will remove all agent-config configurations!"
	@echo "  - ~/.claude/ (CLAUDE.md, settings.json, agents)"
	@echo "  - ~/.pi/agent/AGENTS.md (canonical instructions)"
	@echo "  - ~/.config/opencode/opencode.json"
	@echo "  - ~/.config/opencode/agents"
	@echo "  - ~/.config/opencode/AGENTS.md"
	@echo "  - ~/.agents/skills/<managed-skill> (canonical copies)"
	@echo "  - ~/.claude/skills/<managed-skill> (Claude Code copies)"
	@echo "  - ~/.apm/apm.yml (generated skills manifest)"
	@echo ""
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean-force; \
	else \
		echo "Clean cancelled"; \
	fi

# Force clean without confirmation (used by clean target)
clean-force:
	@echo "Removing all configurations..."
	@$(MAKE) clean-claude
	@$(MAKE) clean-skills
	@$(MAKE) clean-opencode
	@$(MAKE) clean-pi
	@echo "All configurations removed"

clean-claude: require-jq
	@echo "Removing Claude Code configuration..."
	@set -e; \
	mkdir -p ~/.claude; \
	tmp_settings="$$(mktemp /tmp/claude-settings.XXXXXX)"; \
	trap 'rm -f "$$tmp_settings"' EXIT; \
	$(call build_settings,$$tmp_settings); \
	$(call remove_managed_file,$${HOME}/.claude/settings.json,$$tmp_settings)
	@$(call remove_managed_path,$${HOME}/.claude/CLAUDE.md,$${HOME}/.pi/agent/AGENTS.md)
	@$(call remove_managed_path,$${HOME}/.claude/agents,$(REPO_ROOT)/claude/.claude/agents)
	@echo "Claude Code configuration removed"

clean-opencode:
	@echo "Removing OpenCode configuration..."
	@set -e; \
	if command -v jsonnet >/dev/null 2>&1; then \
		tmp_opencode="$$(mktemp /tmp/opencode-json.XXXXXX)"; \
		trap 'rm -f "$$tmp_opencode"' EXIT; \
		jsonnet $(OPENCODE_JPATH) --tla-str env=$(OPENCODE_ENV) "$(REPO_ROOT)/jsonnet/opencode.jsonnet" > "$$tmp_opencode"; \
		$(call remove_managed_file,$${HOME}/.config/opencode/opencode.json,$$tmp_opencode); \
	else \
		echo "  Warning: jsonnet not found, skipping opencode.json cleanup"; \
	fi
	@$(call remove_managed_path,$${HOME}/.config/opencode/agents,$(REPO_ROOT)/opencode/agents)
	@$(call remove_managed_path,$${HOME}/.config/opencode/AGENTS.md,$${HOME}/.pi/agent/AGENTS.md)
	@echo "OpenCode configuration removed"

clean-pi:
	@echo "Removing pi configuration..."
	@set -e; \
	tmp_agents="$$(mktemp /tmp/agents-md.XXXXXX)"; \
	trap 'rm -f "$$tmp_agents"' EXIT; \
	$(call build_agents_md,$$tmp_agents); \
	$(call remove_managed_file,$${HOME}/.pi/agent/AGENTS.md,$$tmp_agents)
	@echo "  (settings.json left untouched — it is your personal file)"
	@echo "pi configuration removed"

# apm removes only the files its lockfile records as deployed, so skills that
# were installed by hand survive. The user-scope manifest is deleted only when
# it still matches the repo manifest, i.e. when this repo is what installed it.
clean-skills: require-yq
	@echo "Removing shared skills..."
	@set -e; \
	tmp_manifest="$$(mktemp /tmp/apm-manifest.XXXXXX)"; \
	trap 'rm -f "$$tmp_manifest"' EXIT; \
	yq ea '$(SKILLS_MANIFEST_MERGE)' $(SKILLS_MANIFEST_FILES) >"$$tmp_manifest"; \
	if ! command -v apm >/dev/null 2>&1; then \
		echo "  Warning: apm not found, skipping skill removal"; \
	elif [ ! -e "$${HOME}/.apm/apm.yml" ]; then \
		echo "  No manifest at $${HOME}/.apm/apm.yml, nothing to remove"; \
	elif ! cmp -s "$$tmp_manifest" "$${HOME}/.apm/apm.yml"; then \
		echo "  Warning: Skipping unmanaged file $${HOME}/.apm/apm.yml"; \
	else \
		packages="$$($(SKILLS_MANIFEST_PACKAGES))"; \
		(cd "$${HOME}" && apm uninstall --global $$packages); \
		rm -f "$${HOME}/.apm/apm.yml"; \
	fi
	@rmdir ~/.agents/skills ~/.agents ~/.apm/apm_modules ~/.apm 2>/dev/null || true
	@echo "Shared skills removed"

# Test commands
test: check-syntax test-safety test-sync-smoke
	@echo "All checks passed!"

test-safety:
	@bash "./test_makefile_safety.sh"

test-sync-smoke:
	@bash "./test_sync_smoke.sh"

# Check syntax of configuration files
check-syntax:
	@echo "Checking syntax..."
	@echo "Checking Jsonnet files..."
	@if command -v jsonnet >/dev/null 2>&1; then \
		for file in $$(find ./jsonnet -name "*.jsonnet" -o -name "*.libsonnet" 2>/dev/null | grep -v '_work'); do \
			echo "  Checking $$file"; \
			jsonnet --tla-str env=personal "$$file" >/dev/null 2>&1 || jsonnet "$$file" >/dev/null 2>&1 || { echo "Error: Syntax error in $$file"; exit 1; }; \
		done; \
	else \
		echo "  Warning: jsonnet not found, skipping Jsonnet checks"; \
	fi
	@echo "Checking JSON files..."
	@for file in claude/claude_settings.json.template pi/packages.json ccstatusline/.config/ccstatusline/settings.json; do \
		if [ -f "$$file" ]; then \
			echo "  Checking $$file"; \
			python3 -m json.tool "$$file" >/dev/null || { echo "Error: Invalid JSON in $$file"; exit 1; }; \
		fi; \
	done
	@echo "Checking YAML files..."
	@if command -v yq >/dev/null 2>&1; then \
		for file in $(SKILLS_MANIFEST_FILES); do \
			echo "  Checking $$file"; \
			yq '.' "$$file" >/dev/null || { echo "Error: Invalid YAML in $$file"; exit 1; }; \
		done; \
	else \
		echo "  Warning: yq not found, skipping YAML checks"; \
	fi
	@echo "Syntax check passed"

.PHONY: all require-stow require-apm require-yq require-jq require-jsonnet clean clean-force clean-claude clean-skills clean-opencode clean-pi sync sync-agents-md sync-agents-md-force sync-claude sync-claude-force sync-ccstatusline sync-skills sync-skills-force sync-opencode sync-opencode-force sync-pi sync-pi-force test test-safety test-sync-smoke check-syntax
