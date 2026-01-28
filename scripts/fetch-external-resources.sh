#!/bin/bash
set -euo pipefail

# Fetch external resources script
# This script handles fetching content from external sources

LOG_PREFIX="[FETCH-EXTERNAL]"

log() {
    echo "$LOG_PREFIX $1" >&2
}

error() {
    echo "$LOG_PREFIX ERROR: $1" >&2
    exit 1
}

# Parse external content repositories from environment variable
EXTERNAL_REPOS=${EXTERNAL_CONTENT_REPOS:-"[]"}
CONTENT_APIS=${CONTENT_API_ENDPOINTS:-"[]"}
CACHE_DIR="/workspace/cache"
SRC_DIR="/workspace/src"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR" "$SRC_DIR"

# Function to clone or update git repository
fetch_git_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-main}"
    
    log "Fetching git repository: $repo_url"
    
    if [ -d "$target_dir/.git" ]; then
        log "Repository exists, updating..."
        cd "$target_dir"
        git fetch origin
        git reset --hard "origin/$branch"
    else
        log "Cloning repository..."
        git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"
    fi
}

# Function to fetch content from API endpoint
fetch_api_content() {
    local api_url="$1"
    local output_file="$2"
    
    log "Fetching content from API: $api_url"
    
    if curl -s -f "$api_url" > "$output_file"; then
        log "Successfully fetched content from $api_url"
    else
        error "Failed to fetch content from $api_url"
    fi
}

# Function to download file via HTTP
fetch_http_resource() {
    local url="$1"
    local output_file="$2"
    
    log "Downloading file: $url"
    
    if curl -s -L -f "$url" -o "$output_file"; then
        log "Successfully downloaded $url"
    else
        error "Failed to download $url"
    fi
}

# Process external repositories
if [ "$EXTERNAL_REPOS" != "[]" ]; then
    log "Processing external repositories..."
    
    echo "$EXTERNAL_REPOS" | jq -r '.[] | @base64' | while read -r repo_data; do
        repo_info=$(echo "$repo_data" | base64 -d)
        
        if echo "$repo_info" | jq -e . >/dev/null 2>&1; then
            # JSON format with metadata
            repo_url=$(echo "$repo_info" | jq -r '.url')
            target_path=$(echo "$repo_info" | jq -r '.path // "external"')
            branch=$(echo "$repo_info" | jq -r '.branch // "main"')
        else
            # Simple string format
            repo_url="$repo_info"
            target_path="external/$(basename "$repo_url" .git)"
            branch="main"
        fi
        
        target_dir="$CACHE_DIR/$target_path"
        fetch_git_repo "$repo_url" "$target_dir" "$branch"
        
        # Copy content to source directory
        if [ -d "$target_dir/content" ]; then
            rsync -av "$target_dir/content/" "$SRC_DIR/content/"
            log "Copied content from $target_path"
        fi
        
        if [ -d "$target_dir/static" ]; then
            rsync -av "$target_dir/static/" "$SRC_DIR/static/"
            log "Copied static assets from $target_path"
        fi
    done
fi

# Process API endpoints
if [ "$CONTENT_APIS" != "[]" ]; then
    log "Processing API endpoints..."
    
    echo "$CONTENT_APIS" | jq -r '.[] | @base64' | while read -r api_data; do
        api_info=$(echo "$api_data" | base64 -d)
        
        if echo "$api_info" | jq -e . >/dev/null 2>&1; then
            api_url=$(echo "$api_info" | jq -r '.url')
            output_path=$(echo "$api_info" | jq -r '.output')
            content_type=$(echo "$api_info" | jq -r '.type // "json"')
        else
            error "Invalid API endpoint configuration: $api_info"
        fi
        
        output_file="$SRC_DIR/$output_path"
        mkdir -p "$(dirname "$output_file")"
        
        fetch_api_content "$api_url" "$output_file"
        
        # Convert JSON to markdown if needed
        if [ "$content_type" = "json-to-markdown" ] && command -v jq >/dev/null; then
            log "Converting JSON to markdown format"
            # Custom JSON to markdown conversion logic can be added here
        fi
    done
fi

log "External resource fetching completed successfully"