#!/bin/bash
set -euo pipefail

# Content preprocessing script
# This script handles content transformation and validation

LOG_PREFIX="[PREPROCESS]"

log() {
    echo "$LOG_PREFIX $1" >&2
}

error() {
    echo "$LOG_PREFIX ERROR: $1" >&2
    exit 1
}

SRC_DIR="/workspace/src"
CONFIG_DIR="/workspace/config"

# Ensure source directory exists
if [ ! -d "$SRC_DIR" ]; then
    error "Source directory does not exist: $SRC_DIR"
fi

cd "$SRC_DIR"

log "Starting content preprocessing..."

# Function to validate markdown files
validate_markdown() {
    local file="$1"
    
    # Check for basic markdown structure
    if ! head -10 "$file" | grep -q "^---$"; then
        log "Warning: $file missing front matter"
    fi
}

# Function to process markdown files
process_markdown() {
    local file="$1"
    
    log "Processing markdown file: $file"
    
    # Add any custom markdown processing here
    # For example, converting custom shortcodes, fixing links, etc.
    
    # Validate the file
    validate_markdown "$file"
}

# Function to optimize images
optimize_images() {
    if command -v mogrify >/dev/null; then
        log "Optimizing images..."
        find static/ -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" 2>/dev/null | while read -r img; do
            if [ -f "$img" ]; then
                # Basic image optimization (requires ImageMagick)
                mogrify -strip -interlace Plane -quality 85% "$img" 2>/dev/null || true
                log "Optimized image: $img"
            fi
        done
    else
        log "ImageMagick not available, skipping image optimization"
    fi
}

# Function to validate Hugo configuration
validate_config() {
    local config_file=""
    
    # Find configuration file
    for ext in yaml yml toml json; do
        if [ -f "config.$ext" ]; then
            config_file="config.$ext"
            break
        elif [ -f "hugo.$ext" ]; then
            config_file="hugo.$ext"
            break
        fi
    done
    
    if [ -n "$config_file" ]; then
        log "Found configuration file: $config_file"
        
        # Basic validation using Hugo
        if ! hugo config --quiet > /dev/null 2>&1; then
            error "Invalid Hugo configuration in $config_file"
        fi
        
        log "Configuration validated successfully"
    else
        log "Warning: No Hugo configuration file found"
    fi
}

# Function to merge external configuration
merge_external_config() {
    if [ -d "$CONFIG_DIR" ]; then
        log "Merging external configuration files..."
        
        # Copy configuration overrides
        find "$CONFIG_DIR" -type f -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.json" | while read -r config; do
            target="$(basename "$config")"
            log "Copying configuration override: $target"
            cp "$config" "./$target"
        done
    fi
}

# Main preprocessing workflow
main() {
    log "Validating source directory structure..."
    
    # Ensure basic Hugo directory structure
    mkdir -p content static themes layouts data
    
    log "Merging external configuration..."
    merge_external_config
    
    log "Validating configuration..."
    validate_config
    
    log "Processing content files..."
    # Process all markdown files
    find content/ -name "*.md" -type f 2>/dev/null | while read -r file; do
        process_markdown "$file"
    done
    
    log "Optimizing static assets..."
    optimize_images
    
    # Custom preprocessing hooks
    if [ -f "$CONFIG_DIR/preprocess-hook.sh" ]; then
        log "Running custom preprocessing hook..."
        bash "$CONFIG_DIR/preprocess-hook.sh"
    fi
    
    log "Content preprocessing completed successfully"
}

# Run main function
main "$@"