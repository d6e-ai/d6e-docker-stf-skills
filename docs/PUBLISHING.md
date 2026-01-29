# Publishing D6E Docker STFs to Container Registries

This guide explains how to publish your D6E Docker STFs to container registries.

## 📋 Table of Contents

- [Overview](#overview)
- [GitHub Container Registry (ghcr.io)](#github-container-registry-ghcrio)
- [Docker Hub](#docker-hub)
- [Private Registries](#private-registries)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

Main reasons to publish D6E Docker STFs to container registries:

1. **Sharing**: Share STFs with team members and other users
2. **Version Management**: Manage multiple versions
3. **Production Deployment**: Make accessible from D6E production environment
4. **CI/CD Integration**: Build automated build and deploy pipelines

### Major Container Registries

| Registry | URL | Use Case | Free Tier |
|----------|-----|----------|-----------|
| **GitHub Container Registry** | ghcr.io | Open source, team development | Unlimited public |
| **Docker Hub** | docker.io | General distribution | Unlimited public |
| **AWS ECR** | xxx.dkr.ecr.region.amazonaws.com | AWS environment | 500MB/month |
| **GCP Artifact Registry** | region-docker.pkg.dev | GCP environment | 500MB/month |
| **Azure Container Registry** | xxx.azurecr.io | Azure environment | Basic: $5/month |

---

## GitHub Container Registry (ghcr.io)

Free container registry provided by GitHub. **Recommended**

### Benefits

- ✅ Public images are free and unlimited
- ✅ Integrated with GitHub repositories
- ✅ Automatic builds with GitHub Actions
- ✅ Fine-grained access control

### Prerequisites

1. GitHub account
2. Personal Access Token with `write:packages` permission

### Step 1: Create Personal Access Token

1. Log in to GitHub
2. Settings → Developer settings → Personal access tokens → Tokens (classic)
3. Click "Generate new token (classic)"
4. Select scopes:
   - ✅ `write:packages`
   - ✅ `read:packages`
   - ✅ `delete:packages` (optional)
5. Copy the token (save for later)

### Step 2: Login to GitHub Container Registry

```bash
# Set environment variables (recommended)
export GITHUB_TOKEN="your_personal_access_token"
export GITHUB_USERNAME="your_github_username"

# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Or enter manually
docker login ghcr.io -u your_github_username
# Password: <Personal Access Token>
```

### Step 3: Build Docker Image

```bash
# Navigate to project directory
cd /path/to/your-docker-stf

# Build image
docker build -t your-stf-name:latest .

# Multi-platform support (recommended)
docker buildx build --platform linux/amd64,linux/arm64 -t your-stf-name:latest .
```

### Step 4: Tag Image

```bash
# Tag for GitHub Container Registry
docker tag your-stf-name:latest ghcr.io/$GITHUB_USERNAME/your-stf-name:latest
docker tag your-stf-name:latest ghcr.io/$GITHUB_USERNAME/your-stf-name:v1.0.0

# Example
docker tag echo-stf:latest ghcr.io/yourusername/echo-stf:latest
docker tag echo-stf:latest ghcr.io/yourusername/echo-stf:v1.0.0
```

### Step 5: Push Image

```bash
# Push image
docker push ghcr.io/$GITHUB_USERNAME/your-stf-name:latest
docker push ghcr.io/$GITHUB_USERNAME/your-stf-name:v1.0.0
```

### Step 6: Make Image Public

By default, images are private. To make public:

1. Visit https://github.com/users/$GITHUB_USERNAME/packages
2. Click on package name (`your-stf-name`)
3. Click "Package settings"
4. Click "Change visibility" → Select "Public"
5. Enter package name to confirm

### Step 7: Verify Image

```bash
# Public images can be pulled without login
docker pull ghcr.io/$GITHUB_USERNAME/your-stf-name:latest

# Check image info
docker images | grep your-stf-name
```

### Step 8: Use in D6E

```javascript
// Specify GHCR image when creating STF version
d6e_create_stf_version({
  stf_id: "{stf_id}",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"ghcr.io/yourusername/your-stf-name:latest"}'
});
```

### Automation Script (Recommended)

Create `publish-ghcr.sh`:

```bash
#!/bin/bash
# GitHub Container Registry publishing script

set -e

# Configuration
IMAGE_NAME="your-stf-name"
GITHUB_USERNAME="${GITHUB_USERNAME:-yourusername}"
VERSION="${1:-latest}"

# Build
echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:${VERSION} .

# Tag
echo "Tagging image..."
docker tag ${IMAGE_NAME}:${VERSION} ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:${VERSION}
docker tag ${IMAGE_NAME}:${VERSION} ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:latest

# Push
echo "Pushing to GitHub Container Registry..."
docker push ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:${VERSION}
docker push ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:latest

echo "✅ Published: ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:${VERSION}"
echo "✅ Published: ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:latest"
```

Usage:

```bash
chmod +x publish-ghcr.sh
./publish-ghcr.sh v1.0.0
```

### Automatic Publishing with GitHub Actions

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Docker Image

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

Usage:

```bash
# Push version tag
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will automatically build and publish
```

---

## Docker Hub

Most widely used container registry.

### Step 1: Create Docker Hub Account

1. Visit https://hub.docker.com
2. Create an account (free)

### Step 2: Login to Docker Hub

```bash
docker login

# Username: your_dockerhub_username
# Password: your_dockerhub_password
```

### Step 3: Tag and Push Image

```bash
# Tag
docker tag your-stf-name:latest your_dockerhub_username/your-stf-name:latest
docker tag your-stf-name:latest your_dockerhub_username/your-stf-name:v1.0.0

# Push
docker push your_dockerhub_username/your-stf-name:latest
docker push your_dockerhub_username/your-stf-name:v1.0.0
```

### Step 4: Use in D6E

```javascript
d6e_create_stf_version({
  stf_id: "{stf_id}",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"your_dockerhub_username/your-stf-name:latest"}'
});
```

---

## Private Registries

For enterprise environments or strict security requirements.

### AWS ECR (Elastic Container Registry)

```bash
# Login with AWS CLI
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Push image
docker tag your-stf-name:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/your-stf-name:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/your-stf-name:latest
```

### GCP Artifact Registry

```bash
# Login with gcloud CLI
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push image
docker tag your-stf-name:latest \
  us-central1-docker.pkg.dev/project-id/repo-name/your-stf-name:latest
docker push us-central1-docker.pkg.dev/project-id/repo-name/your-stf-name:latest
```

### Azure Container Registry

```bash
# Login with Azure CLI
az acr login --name myregistry

# Push image
docker tag your-stf-name:latest myregistry.azurecr.io/your-stf-name:latest
docker push myregistry.azurecr.io/your-stf-name:latest
```

### Using Private Registries with D6E

To access private registries from D6E API server, configure authentication:

```yaml
# compose.withdb.yml or docker-compose.yml
services:
  api:
    image: d6e-api:latest
    environment:
      # Private registry authentication
      - DOCKER_REGISTRY_AUTH=base64_encoded_auth_config
```

Or login from D6E API server's Docker daemon:

```bash
docker exec -it d6e-api-1 docker login ghcr.io -u username
```

---

## Best Practices

### 1. Semantic Versioning

Use [semantic versioning](https://semver.org/) for version tags:

```bash
# Major.Minor.Patch
docker tag stf:latest ghcr.io/user/stf:v1.0.0
docker tag stf:latest ghcr.io/user/stf:v1.0
docker tag stf:latest ghcr.io/user/stf:v1
docker tag stf:latest ghcr.io/user/stf:latest
```

### 2. Multi-Platform Support

Publish images that work on different architectures:

```bash
# Using buildx
docker buildx create --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/user/stf:latest \
  --push \
  .
```

### 3. Optimize Image Size

```dockerfile
# Multi-stage build
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Lightweight production image
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY main.py .
ENV PATH=/root/.local/bin:$PATH
ENTRYPOINT ["python3", "main.py"]
```

### 4. Security Scanning

Scan images for vulnerabilities before publishing:

```bash
# Scan with Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image ghcr.io/user/stf:latest

# Scan with Docker Scout (built into Docker Desktop)
docker scout cves ghcr.io/user/stf:latest
```

### 5. Image Signing

Ensure image authenticity:

```bash
# Sign image with Cosign
cosign sign ghcr.io/user/stf:latest

# Verify signature
cosign verify ghcr.io/user/stf:latest
```

### 6. Comprehensive Documentation

Include in README:

- Image description
- Usage instructions
- Supported operations
- Environment variables
- Examples
- License

### 7. CI/CD Pipeline

Build automated build, test, and publish pipeline:

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build test image
        run: docker build -t test:latest .
      - name: Run tests
        run: |
          echo '{"input":{"operation":"test"},"sources":{}}' | \
            docker run --rm -i test:latest

  publish:
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
```

---

## Troubleshooting

### Issue: Cannot Login

```bash
# Clear cache
docker logout ghcr.io

# Login again
docker login ghcr.io -u username
```

### Issue: Push Denied

**Cause**: Insufficient permissions

**Solution**:
1. Check Personal Access Token permissions (`write:packages`)
2. Check repository permissions
3. If package exists, check existing permissions

### Issue: Cannot Pull Image from D6E

**Cause**: D6E API server cannot access registry

**Solution**:

1. **For public images**: Verify image is actually public
2. **For private images**: Configure authentication in D6E API server

```bash
# Login from D6E API server
docker exec -it d6e-api-1 docker login ghcr.io -u username
```

### Issue: Image Size Too Large

**Solution**:

1. Use multi-stage builds
2. Exclude unnecessary files with `.dockerignore`
3. Use lightweight base images (`alpine`, `slim`)

```dockerfile
# .dockerignore
.git
.gitignore
*.md
tests/
examples/
.github/
```

### Issue: Platform Compatibility Error

**Error**: `exec format error`

**Cause**: Image platform doesn't match host architecture

**Solution**:

```bash
# Build for correct platform
docker build --platform linux/amd64 -t stf:latest .

# Or build multi-platform image
docker buildx build --platform linux/amd64,linux/arm64 -t stf:latest --push .
```

---

## Template

### publish.sh Template

```bash
#!/bin/bash
# Docker STF publishing script

set -e

# Configuration
IMAGE_NAME="${IMAGE_NAME:-my-stf}"
REGISTRY="${REGISTRY:-ghcr.io}"
USERNAME="${USERNAME:-yourusername}"
VERSION="${1:-latest}"

# Colored logging
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Build
log_info "Building Docker image..."
docker build -t ${IMAGE_NAME}:${VERSION} . || {
  log_error "Build failed"
  exit 1
}

# Tag
log_info "Tagging image..."
docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${VERSION}
docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:latest

# Push
log_info "Pushing to ${REGISTRY}..."
docker push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${VERSION}
docker push ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:latest

log_info "✅ Successfully published:"
log_info "  - ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${VERSION}"
log_info "  - ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:latest"

# Display usage example
log_info ""
log_info "To use this image in D6E:"
echo "d6e_create_stf_version({"
echo "  stf_id: '{stf_id}',"
echo "  version: '${VERSION}',"
echo "  runtime: 'docker',"
echo "  code: '{\"image\":\"${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${VERSION}\"}'"
echo "})"
```

---

## Summary

Docker STF publishing steps:

1. ✅ Choose container registry (recommended: GitHub Container Registry)
2. ✅ Login to registry
3. ✅ Build Docker image
4. ✅ Tag image
5. ✅ Push image
6. ✅ Configure image visibility (if needed)
7. ✅ Specify image URL in D6E

### Recommended Workflow

- **Development**: Local build
- **Testing**: Local registry or private registry
- **Production**: GitHub Container Registry or Docker Hub

---

## Reference Resources

- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [GCP Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)

---

**Happy Publishing! 🚀**

Next, check [TESTING.md](./TESTING.md) to learn testing methods before publishing!
