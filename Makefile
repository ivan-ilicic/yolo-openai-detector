# Common developer commands. See AGENTS.md §6.
.DEFAULT_GOAL := help
PY ?= python3
VENV ?= .venv

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

.PHONY: install
install: ## Create venv and install dev dependencies
	$(PY) -m venv $(VENV)
	$(VENV)/bin/pip install -U pip
	$(VENV)/bin/pip install -e ".[dev]"

.PHONY: export-model
export-model: ## Export YOLO26 weights to ONNX into ./models (needs the 'export' extra)
	$(VENV)/bin/pip install -e ".[export]"
	$(VENV)/bin/python scripts/export_model.py --models yolo26-n yolo26-s --out models

.PHONY: run
run: ## Run the API locally (requires YOLO_DETECT_API_KEY)
	$(VENV)/bin/uvicorn yolo_detect_api.main:app --reload --host 0.0.0.0 --port 8000

.PHONY: test
test: ## Run the full test suite
	$(VENV)/bin/pytest

.PHONY: lint
lint: ## Lint with ruff
	$(VENV)/bin/ruff check src tests

.PHONY: typecheck
typecheck: ## Static type check with mypy
	$(VENV)/bin/mypy

.PHONY: docker
docker: ## Build the runtime Docker image
	docker build -t yolo-detect-api:latest .
