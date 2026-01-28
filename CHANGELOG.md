# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of Hugo Container Builder
- Multi-stage Dockerfile with Alpine base
- External resource fetching from Git repositories and APIs
- Content preprocessing and validation scripts
- GitHub Actions workflows for CI/CD
- Podman compatibility with rootless execution
- Jenkins pipeline integration
- Multi-platform container support (amd64, arm64)
- Security scanning with Trivy
- Comprehensive documentation and examples

### Security
- Non-root user execution
- Minimal attack surface with Alpine base
- Content validation and sanitization
- Automated vulnerability scanning

## [1.0.0] - 2024-01-01

### Added
- Initial release of Hugo Container Builder
- Core containerization functionality
- Basic Hugo site building capabilities
- GitHub Container Registry integration