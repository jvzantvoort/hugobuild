# Multi-stage Dockerfile for Hugo Container Builder
ARG HUGO_VERSION=latest
ARG NODE_VERSION=18-alpine
ARG ADDITIONAL_PACKAGES=""

# Build stage
FROM node:${NODE_VERSION} AS builder

# Install Hugo
ARG HUGO_VERSION
RUN apk add --no-cache \
    git \
    curl \
    bash \
    ca-certificates \
    wget \
    gcompat \
    && if [ "$HUGO_VERSION" = "latest" ]; then \
        HUGO_VERSION=$(wget -qO- https://api.github.com/repos/gohugoio/hugo/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p'); \
    fi \
    && wget -O hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/').tar.gz \
    && tar -xzf hugo.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/hugo \
    && rm hugo.tar.gz \
    && hugo version

# Add additional packages if specified
ARG ADDITIONAL_PACKAGES
RUN if [ -n "$ADDITIONAL_PACKAGES" ]; then \
        apk add --no-cache $ADDITIONAL_PACKAGES; \
    fi

# Runtime stage
FROM node:${NODE_VERSION}

# Install runtime dependencies
RUN apk add --no-cache \
    git \
    curl \
    bash \
    ca-certificates \
    jq \
    rsync \
    gcompat \
    && adduser -D -s /bin/bash hugo

# Copy Hugo binary from builder stage
COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo

# Copy scripts
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Set working directory
WORKDIR /workspace

# Create necessary directories
RUN mkdir -p /workspace/src /workspace/output /workspace/cache /workspace/config \
    && chown -R hugo:hugo /workspace

# Switch to non-root user
USER hugo

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Default command
CMD ["build-site.sh"]