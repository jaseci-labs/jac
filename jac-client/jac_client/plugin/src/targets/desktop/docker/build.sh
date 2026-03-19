#!/bin/bash
# Helper script to build Jac desktop apps in Docker for production
#
# This script builds your app inside an Ubuntu 22.04 container to ensure
# GLIBC 2.35 compatibility with most modern Linux distributions.
#
# Requirements:
#   - Docker with at least 4GB memory (8GB recommended)
#   - ~5GB disk space for build
#
# Usage:
#   ./build.sh [project_dir] [--rebuild-image]
#
# Options:
#   project_dir      Path to your Jac project (default: current directory)
#   --rebuild-image  Force rebuild the Docker image
#
# Example:
#   ./build.sh ./my-app
#   ./build.sh . --rebuild-image
#
# Troubleshooting:
#   If build gets "Killed", increase Docker memory in Docker Desktop settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="jac-desktop-builder"
IMAGE_TAG="ubuntu22.04"

# Parse arguments
PROJECT_DIR="${1:-.}"
REBUILD_IMAGE=false

for arg in "$@"; do
    case $arg in
        --rebuild-image)
            REBUILD_IMAGE=true
            shift
            ;;
    esac
done

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "=== Jac Desktop Production Builder ==="
echo "Project: $PROJECT_DIR"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo ""
    echo "Install Docker:"
    echo "  Ubuntu/Debian: sudo apt-get install docker.io"
    echo "  macOS: brew install --cask docker"
    echo "  Or visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running"
    echo ""
    echo "Start Docker:"
    echo "  Linux: sudo systemctl start docker"
    echo "  macOS: Open Docker Desktop app"
    exit 1
fi

# Build or pull the Docker image
if [ "$REBUILD_IMAGE" = true ] || ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &> /dev/null; then
    echo "Building Docker image (this may take a few minutes on first run)..."
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" "$SCRIPT_DIR"
    echo ""
fi

# Find jac-client source directory (for installing latest version)
JAC_CLIENT_DIR=""
JASECI_ROOT=""

# Try to find jaseci root by looking for jac-client directory
SEARCH_DIR="$PROJECT_DIR"
for i in {1..5}; do
    if [ -d "$SEARCH_DIR/jac-client" ]; then
        JASECI_ROOT="$SEARCH_DIR"
        JAC_CLIENT_DIR="$SEARCH_DIR/jac-client"
        break
    fi
    SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

# Build volume mounts
VOLUME_MOUNTS="-v $PROJECT_DIR:/project"

if [ -n "$JASECI_ROOT" ]; then
    echo "Found jaseci root: $JASECI_ROOT"
    VOLUME_MOUNTS="$VOLUME_MOUNTS -v $JASECI_ROOT:/jaseci:ro"
fi

# Run the build in Docker
echo "Starting Docker build..."
echo ""

docker run --rm \
    $VOLUME_MOUNTS \
    -w /project \
    -e JAC_SIDECAR_STANDALONE=1 \
    -e JAC_PRODUCTION_BUILD=1 \
    -e CARGO_BUILD_JOBS=2 \
    "$IMAGE_NAME:$IMAGE_TAG" \
    bash -c '
        set -e

        echo "=== Installing Jac packages ==="

        # Install from local jaseci source if available
        # Copy to temp dir first since mounted volume may be read-only
        if [ -d /jaseci/jac ]; then
            echo "Installing jaclang from source..."
            cp -r /jaseci/jac /tmp/jac
            python3.12 -m pip install -q /tmp/jac
            rm -rf /tmp/jac
        else
            echo "Installing jaclang from PyPI..."
            python3.12 -m pip install -q jaclang
        fi

        if [ -d /jaseci/jac-client ]; then
            echo "Installing jac-client from source..."
            cp -r /jaseci/jac-client /tmp/jac-client
            python3.12 -m pip install -q /tmp/jac-client
            rm -rf /tmp/jac-client
        else
            echo "Installing jac-client from PyPI..."
            python3.12 -m pip install -q jac-client
        fi

        # Install jac-scale if available
        if [ -d /jaseci/jac-scale ]; then
            echo "Installing jac-scale from source..."
            cp -r /jaseci/jac-scale /tmp/jac-scale
            python3.12 -m pip install -q /tmp/jac-scale
            rm -rf /tmp/jac-scale
        else
            python3.12 -m pip install -q jac-scale 2>/dev/null || echo "jac-scale not available"
        fi

        # Clean up pip cache to free memory before Rust build
        python3.12 -m pip cache purge 2>/dev/null || true
        rm -rf /root/.cache/pip /tmp/*

        echo ""
        echo "=== Building desktop app ==="
        # Find the main entry file
        ENTRY_FILE=""
        if [ -f main.jac ]; then
            ENTRY_FILE="main.jac"
        elif [ -f app.jac ]; then
            ENTRY_FILE="app.jac"
        elif [ -f index.jac ]; then
            ENTRY_FILE="index.jac"
        else
            ENTRY_FILE=$(ls *.jac 2>/dev/null | head -1)
        fi

        if [ -z "$ENTRY_FILE" ]; then
            echo "ERROR: No .jac entry file found"
            exit 1
        fi

        echo "Entry file: $ENTRY_FILE"
        jac build "$ENTRY_FILE" --client desktop

        echo ""
        echo "=== Build complete! ==="
        echo ""

        # Find and list output files
        if [ -d src-tauri/target/release/bundle ]; then
            echo "Output files:"
            find src-tauri/target/release/bundle -type f \( -name "*.AppImage" -o -name "*.deb" -o -name "*.rpm" \) -exec ls -lh {} \;
        fi
    '

echo ""
echo "=== Docker build finished ==="
echo ""
echo "Your production-ready AppImage is in:"
echo "  $PROJECT_DIR/src-tauri/target/release/bundle/appimage/"
