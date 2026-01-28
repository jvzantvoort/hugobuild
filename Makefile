# Makefile for Hugo Container Builder

# Variables
REGISTRY := ghcr.io
OWNER := owner
IMAGE_NAME := hugo-builder
TAG := latest
HUGO_VERSION := latest
PLATFORM := linux/amd64,linux/arm64

# Docker/Podman command (auto-detect)
CONTAINER_CMD := $(shell which podman 2>/dev/null || echo docker)

# Build targets
.PHONY: help build build-multi test run-example clean push dev shell

help: ## Show this help message
	@echo "Hugo Container Builder - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build container image locally
	$(CONTAINER_CMD) build \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--tag $(IMAGE_NAME):$(TAG) \
		--tag $(IMAGE_NAME):hugo-$(HUGO_VERSION) \
		.

build-multi: ## Build multi-platform container image
	$(CONTAINER_CMD) buildx build \
		--platform $(PLATFORM) \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--tag $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):$(TAG) \
		--tag $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):hugo-$(HUGO_VERSION) \
		--push \
		.

test: build ## Run container tests
	@echo "Running container health check..."
	$(CONTAINER_CMD) run --rm $(IMAGE_NAME):$(TAG) health-check.sh
	
	@echo "Creating test site..."
	mkdir -p test-site/content test-output
	echo '---\ntitle: "Test Page"\ndate: 2024-01-01T00:00:00Z\n---\n\n# Test Hugo Site\n\nThis is a test page.' > test-site/content/_index.md
	echo 'baseURL: "https://test.example.com"\nlanguageCode: "en-us"\ntitle: "Test Site"' > test-site/hugo.yaml
	
	@echo "Testing container build..."
	$(CONTAINER_CMD) run --rm \
		-v $(PWD)/test-site:/workspace/src:rw \
		-v $(PWD)/test-output:/workspace/output:rw \
		-e HUGO_BASEURL=https://test.example.com \
		-e HUGO_ENVIRONMENT=production \
		$(IMAGE_NAME):$(TAG)
	
	@echo "Validating output..."
	test -f test-output/index.html || (echo "ERROR: Expected output file not found"; exit 1)
	test -f test-output/build-info.json || (echo "ERROR: Build info not found"; exit 1)
	
	@echo "Test completed successfully!"

run-example: build ## Run example Hugo build
	@echo "Setting up example site..."
	mkdir -p example-site/{content,static,themes} example-output
	
	# Create example content
	cat > example-site/content/_index.md << 'EOF'
---
title: "Welcome"
date: 2024-01-01T00:00:00Z
---

# Welcome to Hugo Container Builder

This is an example site built with the Hugo Container Builder.

## Features

- Containerized Hugo builds
- External resource integration  
- Multi-platform support
- CI/CD ready
EOF
	
	# Create Hugo config
	cat > example-site/hugo.yaml << 'EOF'
baseURL: 'https://example.com'
languageCode: 'en-us'
title: 'Hugo Container Builder Example'

params:
  version: '1.0.0'
  description: 'Example site built with Hugo Container Builder'

markup:
  goldmark:
    renderer:
      unsafe: true
EOF
	
	@echo "Building example site..."
	$(CONTAINER_CMD) run --rm \
		-v $(PWD)/example-site:/workspace/src:rw \
		-v $(PWD)/example-output:/workspace/output:rw \
		-e HUGO_BASEURL=https://example.com \
		-e HUGO_ENVIRONMENT=production \
		-e MINIFY_OUTPUT=true \
		$(IMAGE_NAME):$(TAG)
	
	@echo "Example build completed! Check example-output/ directory"

dev: ## Run development server with auto-rebuild
	$(CONTAINER_CMD) run --rm -it \
		-v $(PWD)/example-site:/workspace/src:rw \
		-p 1313:1313 \
		-e HUGO_ENVIRONMENT=development \
		-e BUILD_DRAFTS=true \
		$(IMAGE_NAME):$(TAG) \
		bash -c "cd /workspace/src && hugo server --bind 0.0.0.0 --port 1313 --buildDrafts"

shell: build ## Open interactive shell in container
	$(CONTAINER_CMD) run --rm -it \
		-v $(PWD):/workspace/host:ro \
		--entrypoint /bin/bash \
		$(IMAGE_NAME):$(TAG)

push: build ## Push image to registry
	$(CONTAINER_CMD) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):$(TAG)
	$(CONTAINER_CMD) tag $(IMAGE_NAME):hugo-$(HUGO_VERSION) $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):hugo-$(HUGO_VERSION)
	$(CONTAINER_CMD) push $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):$(TAG)
	$(CONTAINER_CMD) push $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):hugo-$(HUGO_VERSION)

clean: ## Clean up test files and containers
	rm -rf test-site test-output example-site example-output
	$(CONTAINER_CMD) image prune -f
	$(CONTAINER_CMD) container prune -f

validate: ## Validate configuration files
	@echo "Validating Dockerfile..."
	$(CONTAINER_CMD) build --no-cache --tag validate-test . >/dev/null
	$(CONTAINER_CMD) rmi validate-test
	
	@echo "Validating scripts..."
	shellcheck scripts/*.sh || echo "shellcheck not available, skipping shell script validation"
	
	@echo "Validating YAML files..."
	find . -name "*.yml" -o -name "*.yaml" | while read -r file; do \
		python3 -c "import yaml; yaml.safe_load(open('$$file'))" || echo "Failed to validate $$file"; \
	done
	
	@echo "Validation completed!"

# CI/CD targets
ci-build: ## Build for CI environment
	$(CONTAINER_CMD) build \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--tag $(REGISTRY)/$(OWNER)/$(IMAGE_NAME):ci-$(shell git rev-parse --short HEAD) \
		.

ci-test: ci-build ## Run tests in CI environment
	$(CONTAINER_CMD) run --rm \
		$(REGISTRY)/$(OWNER)/$(IMAGE_NAME):ci-$(shell git rev-parse --short HEAD) \
		health-check.sh

# Documentation targets
docs: ## Generate documentation
	@echo "Documentation is available in README.md"
	@echo "Additional documentation can be generated here"

# Version management
version: ## Show version information
	@echo "Hugo Container Builder"
	@echo "Container Command: $(CONTAINER_CMD)"
	@echo "Registry: $(REGISTRY)"
	@echo "Image: $(REGISTRY)/$(OWNER)/$(IMAGE_NAME)"
	@echo "Hugo Version: $(HUGO_VERSION)"
	@echo "Platform: $(PLATFORM)"

# Default target
.DEFAULT_GOAL := help