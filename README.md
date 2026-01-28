# Hugo Container Builder

A containerized Hugo website builder with flexible version management, external resource integration, and comprehensive CI/CD support. Built for GitHub Container Registry with Podman and Jenkins integration.

[![Build and Push Container](https://github.com/owner/hugo-builder/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/owner/hugo-builder/actions/workflows/build-and-push.yml)
[![Release](https://github.com/owner/hugo-builder/actions/workflows/release.yml/badge.svg)](https://github.com/owner/hugo-builder/actions/workflows/release.yml)

## Features

- 🐳 **Multi-platform containers** (linux/amd64, linux/arm64)
- 🏗️ **Configurable Hugo versions** via build arguments
- 📦 **External resource fetching** from Git repositories and APIs
- 🔄 **Automated CI/CD** with GitHub Actions
- 🐧 **Podman compatibility** with rootless execution
- 🚀 **Jenkins integration** with pipeline templates
- 🔒 **Security-focused** with non-root user and vulnerability scanning
- ⚡ **Performance optimized** with multi-stage builds and caching

## Quick Start

### Using Docker/Podman

```bash
# Pull the latest image
docker pull ghcr.io/owner/hugo-builder:latest

# Build a Hugo site
docker run --rm \
  -v ./my-site:/workspace/src:rw \
  -v ./output:/workspace/output:rw \
  -e HUGO_BASEURL=https://mysite.com \
  -e HUGO_ENVIRONMENT=production \
  ghcr.io/owner/hugo-builder:latest
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  hugo-builder:
    image: ghcr.io/owner/hugo-builder:latest
    environment:
      - HUGO_BASEURL=https://mysite.com
      - HUGO_ENVIRONMENT=production
    volumes:
      - ./site:/workspace/src:rw
      - ./output:/workspace/output:rw
    command: ["build-site.sh"]
```

### With External Content

```bash
docker run --rm \
  -v ./my-site:/workspace/src:rw \
  -v ./output:/workspace/output:rw \
  -e HUGO_BASEURL=https://mysite.com \
  -e EXTERNAL_CONTENT_REPOS='[{"url":"https://github.com/org/content.git","path":"blog","branch":"main"}]' \
  ghcr.io/owner/hugo-builder:latest
```

## Container Images

Images are available from GitHub Container Registry:

- `ghcr.io/owner/hugo-builder:latest` - Latest stable build
- `ghcr.io/owner/hugo-builder:hugo-{version}` - Specific Hugo version
- `ghcr.io/owner/hugo-builder:{tag}` - Release versions
- `ghcr.io/owner/hugo-builder:edge` - Development builds

### Supported Hugo Versions

- `latest` - Most recent Hugo version
- `0.120.4` - Hugo v0.120.4
- `0.119.0` - Hugo v0.119.0

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HUGO_VERSION` | Hugo version to use | `latest` |
| `HUGO_BASEURL` | Site base URL | `` |
| `HUGO_ENVIRONMENT` | Build environment | `production` |
| `BUILD_DRAFTS` | Include draft content | `false` |
| `MINIFY_OUTPUT` | Minify HTML/CSS/JS | `true` |
| `CREATE_ARCHIVE` | Create site archive | `false` |
| `EXTERNAL_CONTENT_REPOS` | Git repositories JSON array | `[]` |
| `CONTENT_API_ENDPOINTS` | API endpoints JSON array | `[]` |

### Volume Mounts

| Path | Purpose | Access |
|------|---------|---------|
| `/workspace/src` | Hugo source directory | read-write |
| `/workspace/output` | Built site output | read-write |
| `/workspace/cache` | External resource cache | read-write |
| `/workspace/config` | Configuration overrides | read-only |

## External Resource Integration

### Git Repositories

Fetch content from external Git repositories:

```bash
export EXTERNAL_CONTENT_REPOS='[
  {
    "url": "https://github.com/org/blog-content.git",
    "path": "blog",
    "branch": "main"
  },
  {
    "url": "https://github.com/org/documentation.git",
    "path": "docs",
    "branch": "v2.0"
  }
]'
```

### API Endpoints

Fetch dynamic content from APIs:

```bash
export CONTENT_API_ENDPOINTS='[
  {
    "url": "https://api.example.com/posts",
    "output": "data/posts.json",
    "type": "json"
  },
  {
    "url": "https://api.example.com/events",
    "output": "data/events.json",
    "type": "json-to-markdown"
  }
]'
```

## Build Process

The container executes the following build pipeline:

1. **External Resource Fetching** - Clone Git repos and fetch API content
2. **Content Preprocessing** - Validate and transform content
3. **Dependency Installation** - Install npm packages for themes
4. **Hugo Build** - Generate static site with specified configuration
5. **Post-processing** - Optimize output and create archives
6. **Custom Hooks** - Execute user-defined scripts

## Podman Integration

### Rootless Execution

```bash
# Pull image
podman pull ghcr.io/owner/hugo-builder:latest

# Run with proper SELinux context
podman run --rm \
  -v ./site:/workspace/src:rw,Z \
  -v ./output:/workspace/output:rw,Z \
  --userns keep-id \
  --security-opt label=type:container_runtime_t \
  ghcr.io/owner/hugo-builder:latest
```

### Podman Compose

```yaml
version: '3.8'
services:
  hugo-builder:
    image: ghcr.io/owner/hugo-builder:latest
    volumes:
      - ./site:/workspace/src:rw,Z
      - ./output:/workspace/output:rw,Z
    userns_mode: "keep-id"
    security_opt:
      - "label=type:container_runtime_t"
```

## Jenkins Integration

### Prerequisites

- Jenkins with Podman support
- Hugo Builder Jenkins Library (optional)

### Basic Pipeline

```groovy
pipeline {
    agent { label 'podman' }
    
    stages {
        stage('Build Site') {
            steps {
                sh """
                    podman run --rm \
                        -v \${PWD}/src:/workspace/src:rw,Z \
                        -v \${PWD}/output:/workspace/output:rw,Z \
                        -e HUGO_BASEURL=https://mysite.com \
                        ghcr.io/owner/hugo-builder:latest
                """
            }
        }
        
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'output/**/*'
            }
        }
    }
}
```

See [examples/Jenkinsfile](examples/Jenkinsfile) for a complete pipeline template.

## Development

### Building Locally

```bash
# Build with default Hugo version
docker build -t hugo-builder:local .

# Build with specific Hugo version
docker build --build-arg HUGO_VERSION=0.120.4 -t hugo-builder:hugo-0.120.4 .

# Build with additional packages
docker build --build-arg ADDITIONAL_PACKAGES="imagemagick git-lfs" -t hugo-builder:extended .
```

### Testing

```bash
# Run container tests
docker run --rm hugo-builder:local health-check.sh

# Test with sample site
mkdir -p test-site/content
echo '---\ntitle: Test\n---\n# Hello World' > test-site/content/_index.md
echo 'baseURL: "https://test.com"' > test-site/hugo.yaml

docker run --rm \
  -v ./test-site:/workspace/src:rw \
  -v ./test-output:/workspace/output:rw \
  hugo-builder:local
```

## Troubleshooting

### Common Issues

**Permission Denied Errors**
```bash
# Ensure proper ownership of volumes
sudo chown -R $(id -u):$(id -g) ./site ./output

# For Podman with SELinux, use :Z suffix
podman run -v ./site:/workspace/src:rw,Z ...
```

**External Resource Fetching Fails**
```bash
# Check network connectivity
docker run --rm ghcr.io/owner/hugo-builder:latest curl -I https://github.com

# Verify JSON format
echo '[{"url":"https://github.com/user/repo.git"}]' | jq .
```

**Hugo Build Fails**
```bash
# Enable debug output
docker run --rm -e DEBUG=true ...

# Check Hugo configuration
docker run --rm -v ./site:/workspace/src:rw ghcr.io/owner/hugo-builder:latest \
  bash -c "cd /workspace/src && hugo config"
```

### Logs and Debugging

```bash
# View build logs
docker logs <container_id>

# Interactive debugging
docker run -it --entrypoint /bin/bash ghcr.io/owner/hugo-builder:latest

# Health check
docker run --rm ghcr.io/owner/hugo-builder:latest health-check.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/owner/hugo-builder.git
cd hugo-builder

# Build and test locally
make build
make test

# Run example
make run-example
```

## Security

- Containers run as non-root user (`hugo`)
- Regular security scanning with Trivy
- Minimal base image (Alpine Linux)
- Content validation and sanitization
- Secret management support

Report security vulnerabilities to: security@example.com

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/owner/hugo-builder/issues)
- 💬 [Discussions](https://github.com/owner/hugo-builder/discussions)
- 📧 Email: support@example.com