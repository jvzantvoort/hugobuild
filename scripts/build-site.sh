#!/bin/bash
set -euo pipefail

# Main Hugo build orchestration script
# This script coordinates the entire build process

LOG_PREFIX="[BUILD-SITE]"

log() {
    echo "$LOG_PREFIX $1" >&2
}

error() {
    echo "$LOG_PREFIX ERROR: $1" >&2
    exit 1
}

# Environment variables with defaults
HUGO_BASEURL=${HUGO_BASEURL:-""}
HUGO_ENVIRONMENT=${HUGO_ENVIRONMENT:-"production"}
BUILD_DRAFTS=${BUILD_DRAFTS:-"false"}
MINIFY_OUTPUT=${MINIFY_OUTPUT:-"true"}
SRC_DIR="/workspace/src"
OUTPUT_DIR="/workspace/output"
CACHE_DIR="/workspace/cache"

# Validate environment
if [ ! -d "$SRC_DIR" ]; then
    error "Source directory does not exist: $SRC_DIR"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

cd "$SRC_DIR"

log "Starting Hugo build process..."
log "Environment: $HUGO_ENVIRONMENT"
log "Base URL: ${HUGO_BASEURL:-"(not set)"}"

# Step 1: Fetch external resources
log "Step 1: Fetching external resources..."
if ! fetch-external-resources.sh; then
    error "Failed to fetch external resources"
fi

# Step 2: Preprocess content
log "Step 2: Preprocessing content..."
if ! preprocess-content.sh; then
    error "Failed to preprocess content"
fi

# Step 3: Install theme dependencies
log "Step 3: Installing theme dependencies..."
if [ -f "package.json" ]; then
    log "Found package.json, installing npm dependencies..."
    npm ci --silent || npm install --silent
    
    # Run build script if it exists
    if npm list --json 2>/dev/null | jq -e '.scripts.build' >/dev/null 2>&1; then
        log "Running npm build script..."
        npm run build
    fi
elif [ -f "themes/*/package.json" ]; then
    log "Found theme package.json files..."
    for theme_pkg in themes/*/package.json; do
        theme_dir=$(dirname "$theme_pkg")
        log "Installing dependencies for theme: $(basename "$theme_dir")"
        cd "$theme_dir"
        npm ci --silent || npm install --silent
        cd "$SRC_DIR"
    done
fi

# Step 4: Build Hugo site
log "Step 4: Building Hugo site..."

# Prepare Hugo command
HUGO_CMD="hugo"

# Add base URL if provided
if [ -n "$HUGO_BASEURL" ]; then
    HUGO_CMD="$HUGO_CMD --baseURL=$HUGO_BASEURL"
fi

# Add environment
HUGO_CMD="$HUGO_CMD --environment=$HUGO_ENVIRONMENT"

# Add destination
HUGO_CMD="$HUGO_CMD --destination=$OUTPUT_DIR"

# Add minification
if [ "$MINIFY_OUTPUT" = "true" ]; then
    HUGO_CMD="$HUGO_CMD --minify"
fi

# Add drafts if enabled
if [ "$BUILD_DRAFTS" = "true" ]; then
    HUGO_CMD="$HUGO_CMD --buildDrafts"
fi

# Add verbose output for debugging
if [ "${DEBUG:-false}" = "true" ]; then
    HUGO_CMD="$HUGO_CMD --verbose"
fi

log "Executing: $HUGO_CMD"

# Execute Hugo build
if ! $HUGO_CMD; then
    error "Hugo build failed"
fi

# Step 5: Post-processing
log "Step 5: Post-processing output..."

# Generate build metadata
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_INFO="{
    \"buildTime\": \"$BUILD_TIME\",
    \"hugoVersion\": \"$(hugo version --quiet || echo 'unknown')\",
    \"environment\": \"$HUGO_ENVIRONMENT\",
    \"baseURL\": \"${HUGO_BASEURL:-""}\",
    \"minified\": $MINIFY_OUTPUT,
    \"includeDrafts\": $BUILD_DRAFTS
}"

echo "$BUILD_INFO" > "$OUTPUT_DIR/build-info.json"
log "Build metadata written to build-info.json"

# Create build summary
CONTENT_COUNT=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
ASSET_COUNT=$(find "$OUTPUT_DIR" -type f ! -name "*.html" | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)

log "Build completed successfully!"
log "Generated $CONTENT_COUNT HTML pages"
log "Generated $ASSET_COUNT asset files"
log "Total output size: $TOTAL_SIZE"

# Step 6: Create archive if requested
if [ "${CREATE_ARCHIVE:-false}" = "true" ]; then
    log "Creating site archive..."
    ARCHIVE_NAME="site-$(date +%Y%m%d-%H%M%S).tar.gz"
    cd "$OUTPUT_DIR"
    tar -czf "../$ARCHIVE_NAME" .
    cd ..
    log "Archive created: $ARCHIVE_NAME"
fi

# Step 7: Custom post-build hook
if [ -f "/workspace/config/post-build-hook.sh" ]; then
    log "Running custom post-build hook..."
    bash "/workspace/config/post-build-hook.sh" "$OUTPUT_DIR"
fi

log "Hugo build process completed successfully!"