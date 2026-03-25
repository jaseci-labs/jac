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
PREFER_PYPI=false

for arg in "$@"; do
    case $arg in
        --rebuild-image)
            REBUILD_IMAGE=true
            shift
            ;;
        --prefer-pypi)
            PREFER_PYPI=true
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

    # Look for jac-code in common locations (it's often outside jaseci monorepo)
    PARENT_DIR="$(dirname "$JASECI_ROOT")"
    for JAC_CODE_NAME in "jac-code" "jac-code-main" "jac_code"; do
        if [ -d "$PARENT_DIR/$JAC_CODE_NAME" ]; then
            echo "Found jac-code: $PARENT_DIR/$JAC_CODE_NAME"
            VOLUME_MOUNTS="$VOLUME_MOUNTS -v $PARENT_DIR/$JAC_CODE_NAME:/jac-code:ro"
            break
        fi
        if [ -d "$JASECI_ROOT/$JAC_CODE_NAME" ]; then
            echo "Found jac-code: $JASECI_ROOT/$JAC_CODE_NAME"
            VOLUME_MOUNTS="$VOLUME_MOUNTS -v $JASECI_ROOT/$JAC_CODE_NAME:/jac-code:ro"
            break
        fi
    done

    # Look for jac-byllm in common locations
    for BYLLM_NAME in "jac-byllm" "byllm"; do
        if [ -d "$PARENT_DIR/$BYLLM_NAME" ]; then
            echo "Found jac-byllm: $PARENT_DIR/$BYLLM_NAME"
            VOLUME_MOUNTS="$VOLUME_MOUNTS -v $PARENT_DIR/$BYLLM_NAME:/jac-byllm:ro"
            break
        fi
        if [ -d "$JASECI_ROOT/$BYLLM_NAME" ]; then
            echo "Found jac-byllm: $JASECI_ROOT/$BYLLM_NAME"
            VOLUME_MOUNTS="$VOLUME_MOUNTS -v $JASECI_ROOT/$BYLLM_NAME:/jac-byllm:ro"
            break
        fi
    done
fi

# Run the build in Docker
echo "Starting Docker build..."
echo ""

docker run --rm \
    $VOLUME_MOUNTS \
    -v jac-pip-cache:/root/.cache/pip \
    -v jac-cargo-cache:/root/.cargo/registry \
    -w /project \
    -e JAC_SIDECAR_STANDALONE=1 \
    -e JAC_PRODUCTION_BUILD=1 \
    -e CARGO_BUILD_JOBS=2 \
    -e PREFER_PYPI=$PREFER_PYPI \
    "$IMAGE_NAME:$IMAGE_TAG" \
    bash -c '
        set -e

        echo "=== Installing Jac packages ==="

        # Configure pip for slow/unstable connections
        export PIP_DEFAULT_TIMEOUT=300
        export PIP_RETRIES=10

        if [ "$PREFER_PYPI" = "true" ]; then
            echo "(Using PyPI for faster installs)"
        fi

        # Install jaclang
        if [ "$PREFER_PYPI" != "true" ] && [ -d /jaseci/jac ]; then
            echo "Installing jaclang from source..."
            cp -r /jaseci/jac /tmp/jac
            python3.12 -m pip install --progress-bar on /tmp/jac
            rm -rf /tmp/jac
        else
            echo "Installing jaclang from PyPI..."
            python3.12 -m pip install --progress-bar on jaclang
        fi

        # Install jac-client
        if [ "$PREFER_PYPI" != "true" ] && [ -d /jaseci/jac-client ]; then
            echo "Installing jac-client from source..."
            cp -r /jaseci/jac-client /tmp/jac-client
            python3.12 -m pip install --progress-bar on /tmp/jac-client
            rm -rf /tmp/jac-client
        else
            echo "Installing jac-client from PyPI..."
            python3.12 -m pip install --progress-bar on jac-client
        fi

        # Install jac-scale
        if [ "$PREFER_PYPI" != "true" ] && [ -d /jaseci/jac-scale ]; then
            echo "Installing jac-scale from source..."
            cp -r /jaseci/jac-scale /tmp/jac-scale
            python3.12 -m pip install --progress-bar on /tmp/jac-scale
            rm -rf /tmp/jac-scale
        else
            python3.12 -m pip install --progress-bar on jac-scale 2>/dev/null || echo "jac-scale not available"
        fi

        # Install byllm (jac-byllm) if available
        if [ "$PREFER_PYPI" != "true" ] && [ -d /jac-byllm ]; then
            echo "Installing byllm from source (/jac-byllm)..."
            cp -r /jac-byllm /tmp/jac-byllm
            python3.12 -m pip install --progress-bar on /tmp/jac-byllm
            rm -rf /tmp/jac-byllm
        elif [ "$PREFER_PYPI" != "true" ] && [ -d /jaseci/jac-byllm ]; then
            echo "Installing byllm from source (/jaseci/jac-byllm)..."
            cp -r /jaseci/jac-byllm /tmp/jac-byllm
            python3.12 -m pip install --progress-bar on /tmp/jac-byllm
            rm -rf /tmp/jac-byllm
        else
            echo "Installing byllm from PyPI..."
            python3.12 -m pip install --progress-bar on byllm 2>/dev/null || echo "byllm not available on PyPI"
        fi

        # Install jac-coder if available (check mounted paths)
        # Note: jac-coder is NOT on PyPI yet, so source is required
        if [ -d /jac-code ]; then
            echo "Installing jac-coder from source (/jac-code)..."
            cp -r /jac-code /tmp/jac-code
            python3.12 -m pip install --progress-bar on /tmp/jac-code
            rm -rf /tmp/jac-code
        elif [ -d /jaseci/jac-code ]; then
            echo "Installing jac-coder from source (/jaseci/jac-code)..."
            cp -r /jaseci/jac-code /tmp/jac-code
            python3.12 -m pip install --progress-bar on /tmp/jac-code
            rm -rf /tmp/jac-code
        else
            echo "jac-coder not available (not on PyPI, source required)"
        fi

        # Install Python dependencies from jac.toml if present
        if [ -f jac.toml ]; then
            echo "Installing dependencies from jac.toml..."
            python3.12 -c "
import tomllib
with open(\"jac.toml\", \"rb\") as f:
    data = tomllib.load(f)
deps = data.get(\"dependencies\", {})
for name, version in deps.items():
    if isinstance(version, str):
        spec = f\"{name}{version}\" if version and not version.startswith(\"*\") else name
        print(spec)
" | while read dep; do
                python3.12 -m pip install --progress-bar on "$dep" 2>/dev/null || echo "  Could not install: $dep"
            done
        fi

        # Upgrade PyInstaller to latest (Python 3.12 compatibility fixes)
        echo "Upgrading PyInstaller..."
        python3.12 -m pip install --upgrade pyinstaller

        # Ensure PyInstaller runtime dependencies are installed
        # setuptools>=70.0.0 required for Python 3.12 (pkgutil.ImpImporter removed)
        # importlib-metadata for package discovery in frozen apps
        # certifi for SSL certificates
        echo "Installing PyInstaller runtime dependencies..."
        python3.12 -m pip install --progress-bar on --upgrade \
            appdirs \
            "setuptools>=70.0.0" \
            packaging \
            importlib-metadata \
            certifi \
            zipp \
            jaraco.functools \
            jaraco.context \
            jaraco.text

        # Clean up temp files (but keep pip cache for faster rebuilds)
        rm -rf /tmp/*

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
