#!/bin/bash
set -euo pipefail

# Container health check script

LOG_PREFIX="[HEALTH-CHECK]"

log() {
    echo "$LOG_PREFIX $1" >&2
}

error() {
    echo "$LOG_PREFIX ERROR: $1" >&2
    exit 1
}

# Check if Hugo is available and working
if ! command -v hugo >/dev/null 2>&1; then
    error "Hugo binary not found"
fi

# Check Hugo version
HUGO_VERSION=$(hugo version 2>/dev/null || echo "unknown")
log "Hugo version: $HUGO_VERSION"

# Check if required directories exist
for dir in /workspace/src /workspace/output /workspace/cache; do
    if [ ! -d "$dir" ]; then
        error "Required directory missing: $dir"
    fi
done

# Check if workspace is writable
if [ ! -w "/workspace" ]; then
    error "Workspace directory not writable"
fi

# Check Node.js if available
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    log "Node.js version: $NODE_VERSION"
fi

# Check git
if ! command -v git >/dev/null 2>&1; then
    error "Git binary not found"
fi

# Check curl
if ! command -v curl >/dev/null 2>&1; then
    error "Curl binary not found"
fi

# Check jq
if ! command -v jq >/dev/null 2>&1; then
    error "jq binary not found"
fi

# All checks passed
log "Health check passed - container is healthy"
exit 0