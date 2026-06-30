SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PYTHON      ?= python3.12
VENVDIR     ?= ./venv
ENV_FILE    ?= ./.env.sdk
WXO_VERSION ?= latest

OBSERVABILITY_TOOL ?= --with-langfuse
OPTIONAL_TOOLS     ?= --with-langflow

PIP  := $(VENVDIR)/bin/pip
PY   := $(VENVDIR)/bin/python
ORCH := $(VENVDIR)/bin/orchestrate

default: help

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Setup:"
	@echo "  install          Create venv and install Watsonx Orchestrate ADK"
	@echo "  upgrade          Upgrade Watsonx Orchestrate ADK"
	@echo "  bootstrap        Full local setup"
	@echo "  cleanup          Remove venv"
	@echo "  doctor           Run environment diagnostics"
	@echo ""
	@echo "Server:"
	@echo "  start            Start local Orchestrate server"
	@echo "  stop             Stop local Orchestrate server"
	@echo "  restart          Restart local server"
	@echo "  logs             Show server logs"
	@echo "  reset            Reset local server, requires CONFIRM=YES"
	@echo "  purge            Delete local VM/data, requires CONFIRM=YES"
	@echo ""
	@echo "Environment:"
	@echo "  register-saas    Register SaaS env"
	@echo "  activate-saas    Activate SaaS env"
	@echo "  activate-local   Activate local env"
	@echo ""
	@echo "Project:"
	@echo "  init             Create project folders"
	@echo "  deploy           Deploy tools and agents"
	@echo "  connections      Deploy connections"
	@echo "  list             List connections, tools, agents"
	@echo "  chat             Start chat"
	@echo "  copilot          Start copilot"

.PHONY: require-python
require-python:
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: $(PYTHON) not found"; exit 1; }
	@$(PYTHON) -c 'import sys; assert sys.version_info[:2] == (3,12), f"Expected Python 3.12, got {sys.version}"'

.PHONY: require-venv
require-venv:
	@test -x "$(PY)" || { echo "ERROR: venv missing. Run: make install"; exit 1; }

.PHONY: require-orch
require-orch:
	@test -x "$(ORCH)" || { echo "ERROR: orchestrate CLI missing. Run: make install"; exit 1; }

.PHONY: require-env
require-env:
	@test -f "$(ENV_FILE)" || { echo "ERROR: $(ENV_FILE) missing"; exit 1; }

.PHONY: install
install: require-python
	@if [ ! -d "$(VENVDIR)" ]; then \
		echo "Creating venv: $(VENVDIR)"; \
		$(PYTHON) -m venv "$(VENVDIR)"; \
	else \
		echo "Venv already exists: $(VENVDIR)"; \
	fi
	@$(PIP) install --upgrade pip setuptools wheel
	@if [ "$(WXO_VERSION)" = "latest" ]; then \
		echo "Installing latest ibm-watsonx-orchestrate"; \
		$(PIP) install --upgrade ibm-watsonx-orchestrate; \
	else \
		echo "Installing ibm-watsonx-orchestrate==$(WXO_VERSION)"; \
		$(PIP) install --upgrade "ibm-watsonx-orchestrate==$(WXO_VERSION)"; \
	fi
	@$(PIP) install -U pytest
	@if [ -f tools/requirements.txt ]; then \
		$(PIP) install -r tools/requirements.txt; \
	fi
	@$(ORCH) --install-completion || true
	@echo "✅ Install complete"

.PHONY: upgrade
upgrade: require-venv
	@$(PIP) install --upgrade "ibm-watsonx-orchestrate==$(WXO_VERSION)"
	@$(ORCH) --version || true

.PHONY: cleanup
cleanup:
	@if [ "$(VENVDIR)" = "/" ] || [ "$(VENVDIR)" = "." ] || [ -z "$(VENVDIR)" ]; then \
		echo "Refusing to delete VENVDIR=$(VENVDIR)"; \
		exit 1; \
	fi
	@rm -rf "$(VENVDIR)"
	@echo "✅ Removed $(VENVDIR)"

.PHONY: bootstrap
bootstrap: install init doctor
	@if [ -f "$(ENV_FILE)" ]; then \
		echo "Starting local server..."; \
		$(MAKE) start; \
	else \
		echo "⚠️  $(ENV_FILE) missing. Create it, then run: make start"; \
	fi

.PHONY: doctor
doctor:
	@bash scripts/doctor.sh "$(PYTHON)" "$(VENVDIR)" "$(ENV_FILE)"

.PHONY: init
init:
	@mkdir -p agents tools connections knowledge-bases toolkits models scripts tests assets sandbox bin
	@printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'ROOT="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")/.." && pwd)"' \
'exec "$$ROOT/venv/bin/orchestrate" "$$@"' \
> bin/orchestrate
	@chmod +x bin/orchestrate
	@echo "✅ Project structure initialized"

.PHONY: start
start: require-orch require-env
	@$(ORCH) server start -e "$(ENV_FILE)" $(OBSERVABILITY_TOOL) $(OPTIONAL_TOOLS)

.PHONY: stop
stop: require-orch
	@$(ORCH) server stop || true

.PHONY: restart
restart: stop start

.PHONY: logs
logs: require-orch
	@$(ORCH) server logs

.PHONY: reset
reset: require-orch
	@if [ "$${CONFIRM:-NO}" != "YES" ]; then \
		echo "Run: make reset CONFIRM=YES"; \
		exit 1; \
	fi
	@$(ORCH) server stop || true
	@$(ORCH) server reset

.PHONY: purge
purge: require-orch
	@if [ "$${CONFIRM:-NO}" != "YES" ]; then \
		echo "Run: make purge CONFIRM=YES"; \
		exit 1; \
	fi
	@$(ORCH) server stop || true
	@$(ORCH) server purge

.PHONY: chat
chat: require-orch require-env
	@$(ORCH) chat start --env-file "$(ENV_FILE)"

.PHONY: copilot
copilot: require-orch require-env
	@$(ORCH) copilot start --env-file "$(ENV_FILE)"

.PHONY: register-saas
register-saas: require-orch require-env
	@set -a; source "$(ENV_FILE)"; set +a; \
	ENV_NAME="$${WO_INSTANCE_ALIAS:-wxo-saas}"; \
	test -n "$${WO_INSTANCE:-}" || { echo "ERROR: WO_INSTANCE missing"; exit 1; }; \
	$(ORCH) env add --name "$$ENV_NAME" --url "$$WO_INSTANCE"

.PHONY: activate-saas
activate-saas: require-orch require-env
	@set -a; source "$(ENV_FILE)"; set +a; \
	ENV_NAME="$${WO_INSTANCE_ALIAS:-wxo-saas}"; \
	test -n "$${WO_API_KEY:-}" || { echo "ERROR: WO_API_KEY missing"; exit 1; }; \
	$(ORCH) env activate "$$ENV_NAME" --api-key "$$WO_API_KEY"

.PHONY: activate-local
activate-local: require-orch
	@$(ORCH) env activate local

.PHONY: deploy
deploy: require-orch
	@bash scripts/deploy.sh

.PHONY: connections
connections: require-orch
	@bash scripts/create_connections.sh

.PHONY: list
list: require-orch
	@$(ORCH) connections list || true
	@sleep 1
	@$(ORCH) tools list || true
	@sleep 1
	@$(ORCH) agents list || true

.PHONY: test
test: require-venv
	@$(PY) -m pytest