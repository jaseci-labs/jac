#!/usr/bin/env bash
# Jac Programming Language Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
#
# Options:
#   --core        Install only jaclang (no plugins)
#   --standalone  Download a pre-built standalone binary from GitHub Releases
#   --version V   Install a specific version
#   --uninstall   Remove Jac
#   --help        Print usage
#
# Examples:
#   curl -fsSL ... | bash                          # Full ecosystem via uv
#   curl -fsSL ... | bash -s -- --core             # Core language only
#   curl -fsSL ... | bash -s -- --standalone       # Standalone binary (all plugins)
#   curl -fsSL ... | bash -s -- --standalone --core  # Standalone binary (core only)
#   curl -fsSL ... | bash -s -- --version 2.3.1    # Specific version

set -euo pipefail

REPO="jaseci-labs/jaseci"
GITHUB_API="https://api.github.com/repos/${REPO}"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
INSTALL_DIR="${HOME}/.local/bin"

# --- Defaults ---
CORE_ONLY=false
STANDALONE=false
VERSION=""
UNINSTALL=false

# --- Colors and output helpers ---

info() {
    printf "\033[0;34m[jac]\033[0m %s\n" "$*"
}

warn() {
    printf "\033[0;33m[jac]\033[0m %s\n" "$*" >&2
}

err() {
    printf "\033[0;31m[jac]\033[0m %s\n" "$*" >&2
}

has_cmd() {
    command -v "$1" &>/dev/null
}

need_cmd() {
    if ! has_cmd "$1"; then
        err "Required command not found: $1"
        err "Please install '$1' and try again."
        exit 1
    fi
}

# --- Usage ---

usage() {
    cat <<EOF
Jac Programming Language Installer

USAGE:
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
    curl -fsSL ... | bash -s -- [OPTIONS]

OPTIONS:
    --core        Install only jaclang (no plugins)
    --standalone  Download a pre-built standalone binary from GitHub Releases
    --version V   Install a specific version (e.g., 2.3.1)
    --uninstall   Remove Jac installation
    --help        Print this help message

EXAMPLES:
    # Full ecosystem (all plugins) via uv
    curl -fsSL ... | bash

    # Core language only via uv
    curl -fsSL ... | bash -s -- --core

    # Standalone binary with all plugins
    curl -fsSL ... | bash -s -- --standalone

    # Standalone binary, core only
    curl -fsSL ... | bash -s -- --standalone --core

    # Specific version
    curl -fsSL ... | bash -s -- --version 2.3.1
EOF
}

# --- Platform detection ---

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="macos" ;;
        MINGW* | MSYS* | CYGWIN*)
            err "Windows detected. Windows support via PowerShell is coming soon."
            err "For now, please use WSL2 or install manually: pip install jaseci"
            exit 1
            ;;
        *)
            err "Unsupported operating system: $os"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64 | amd64)  ARCH="x86_64" ;;
        aarch64 | arm64)  ARCH="aarch64" ;;
        *)
            err "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --core)
                CORE_ONLY=true
                shift
                ;;
            --standalone)
                STANDALONE=true
                shift
                ;;
            --version)
                if [[ $# -lt 2 ]]; then
                    err "--version requires a version argument (e.g., --version 2.3.1)"
                    exit 1
                fi
                VERSION="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --help | -h)
                usage
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# --- PATH helpers ---

ensure_on_path() {
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
        export PATH="${INSTALL_DIR}:${PATH}"
    fi

    # Check if the install dir is in the user's shell profile
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    local profile=""

    case "$shell_name" in
        zsh)  profile="$HOME/.zshrc" ;;
        bash)
            if [[ -f "$HOME/.bashrc" ]]; then
                profile="$HOME/.bashrc"
            elif [[ -f "$HOME/.bash_profile" ]]; then
                profile="$HOME/.bash_profile"
            fi
            ;;
        fish) profile="$HOME/.config/fish/config.fish" ;;
    esac

    if [[ -n "$profile" ]] && ! grep -q "${INSTALL_DIR}" "$profile" 2>/dev/null; then
        warn ""
        warn "Add ${INSTALL_DIR} to your PATH by running:"
        if [[ "$shell_name" == "fish" ]]; then
            warn "  fish_add_path ${INSTALL_DIR}"
        else
            warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $profile"
        fi
        warn ""
        warn "Then restart your shell or run: source $profile"
    fi
}

# --- uv installation path ---

install_via_uv() {
    need_cmd "curl"

    # Ensure uv is installed
    if ! has_cmd uv; then
        info "Installing uv (Python package manager)..."
        curl -LsSf "$UV_INSTALL_URL" | sh
        export PATH="${INSTALL_DIR}:${PATH}"

        if ! has_cmd uv; then
            err "Failed to install uv. Please install it manually:"
            err "  curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
        info "uv installed successfully."
    else
        info "uv is already installed."
    fi

    # Always install jaclang as the tool (it provides the 'jac' entry point).
    # For full ecosystem, add all plugins via --with flags.
    local spec="jaclang"
    if [[ -n "$VERSION" ]]; then
        spec="jaclang==${VERSION}"
    fi

    local -a with_args=()
    if ! $CORE_ONLY; then
        with_args+=(--with byllm --with jac-client --with jac-scale --with jac-super --with jac-mcp)
    fi

    # Check if already installed and upgrade vs fresh install
    if uv tool list 2>/dev/null | grep -q "^jaclang "; then
        info "Upgrading jaclang..."
        if [[ -n "$VERSION" ]]; then
            uv tool install "$spec" "${with_args[@]}" --python ">=3.12" --force
        else
            uv tool upgrade jaclang "${with_args[@]}" --python ">=3.12"
        fi
    else
        info "Installing jaclang..."
        uv tool install "$spec" "${with_args[@]}" --python ">=3.12"
    fi

    ensure_on_path

    # Verify
    if has_cmd jac; then
        info ""
        info "Jac installed successfully!"
        jac --version 2>/dev/null || true
        info ""
        info "Get started:"
        info "  jac --help"
        info ""
    else
        warn "Installation completed but 'jac' is not on PATH."
        warn "Try restarting your shell or adding ~/.local/bin to PATH."
    fi
}

# --- Standalone binary installation path ---

get_latest_version() {
    local response
    response=$(curl -fsSL "${GITHUB_API}/releases/latest" 2>/dev/null) || {
        err "Failed to query GitHub API for latest release."
        err "Check your internet connection or specify a version with --version."
        exit 1
    }

    # Extract tag_name, strip leading 'v'
    local tag
    tag=$(echo "$response" | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -1 | grep -o '"v[^"]*"' | tr -d '"' | sed 's/^v//')

    if [[ -z "$tag" ]]; then
        err "Could not determine latest version from GitHub Releases."
        err "Please specify a version with --version."
        exit 1
    fi

    echo "$tag"
}

resolve_jaclang_version_from_release() {
    local release_tag="$1"
    local response
    response=$(curl -fsSL "${GITHUB_API}/releases/tags/v${release_tag}" 2>/dev/null) || {
        err "Failed to query GitHub API for release v${release_tag}."
        exit 1
    }

    # Find jac-*-linux-x86_64 or jac-*-macos-* asset to extract the jaclang version
    local jac_version
    jac_version=$(echo "$response" | grep -o '"name":[[:space:]]*"jac-[^"]*"' | head -1 | grep -oE 'jac-[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^jac-//')

    if [[ -z "$jac_version" ]]; then
        err "Could not determine jaclang version from release v${release_tag} assets."
        err "The jaclang standalone binary may not have been built yet for this release."
        exit 1
    fi

    echo "$jac_version"
}

install_standalone() {
    need_cmd "curl"

    # Resolve version (this is the jaseci/release version)
    if [[ -z "$VERSION" ]]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version)
        info "Latest release: ${VERSION}"
    fi

    # Determine asset name
    # The jaclang (slim) binary uses the jaclang version in its filename,
    # which differs from the jaseci release version.
    local asset_prefix asset_version
    if $CORE_ONLY; then
        asset_prefix="jac"
        info "Resolving jaclang version for release v${VERSION}..."
        asset_version=$(resolve_jaclang_version_from_release "$VERSION")
        info "jaclang version: ${asset_version}"
    else
        asset_prefix="jaseci"
        asset_version="$VERSION"
    fi

    local asset="${asset_prefix}-${asset_version}-${OS}-${ARCH}"
    local download_url="https://github.com/${REPO}/releases/download/v${VERSION}/${asset}"
    local checksum_url="${download_url}.sha256"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download to temp location
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    info "Downloading ${asset}..."
    if ! curl -fsSL -o "${tmpdir}/${asset}" "$download_url"; then
        err "Failed to download: ${download_url}"
        err ""
        err "This could mean:"
        err "  - The version '${VERSION}' does not exist"
        err "  - Standalone binaries are not available for ${OS}-${ARCH}"
        err "  - Network issue"
        err ""
        err "Try installing via uv instead (remove --standalone flag)."
        exit 1
    fi

    # Verify checksum if available
    if curl -fsSL -o "${tmpdir}/${asset}.sha256" "$checksum_url" 2>/dev/null; then
        info "Verifying checksum..."
        local expected actual
        expected=$(awk '{print $1}' "${tmpdir}/${asset}.sha256")

        if has_cmd sha256sum; then
            actual=$(sha256sum "${tmpdir}/${asset}" | awk '{print $1}')
        elif has_cmd shasum; then
            actual=$(shasum -a 256 "${tmpdir}/${asset}" | awk '{print $1}')
        else
            warn "Neither sha256sum nor shasum found, skipping checksum verification."
            actual="$expected"
        fi

        if [[ "$expected" != "$actual" ]]; then
            err "Checksum verification failed!"
            err "  Expected: ${expected}"
            err "  Got:      ${actual}"
            exit 1
        fi
        info "Checksum verified."
    else
        warn "Checksum file not available, skipping verification."
    fi

    # Install binary
    mv "${tmpdir}/${asset}" "${INSTALL_DIR}/jac"
    chmod +x "${INSTALL_DIR}/jac"

    ensure_on_path

    # Verify
    if has_cmd jac; then
        info ""
        info "Jac installed successfully! (standalone binary)"
        jac --version 2>/dev/null || true
        info ""
        info "Get started:"
        info "  jac --help"
        info ""
    else
        warn "Binary installed to ${INSTALL_DIR}/jac but 'jac' is not on PATH."
        warn "Try restarting your shell or adding ~/.local/bin to PATH."
    fi
}

# --- Uninstall ---

do_uninstall() {
    local removed=false

    # Remove uv-managed installations
    if has_cmd uv; then
        if uv tool list 2>/dev/null | grep -q "^jaseci "; then
            info "Removing jaseci (uv tool)..."
            uv tool uninstall jaseci
            removed=true
        fi
        if uv tool list 2>/dev/null | grep -q "^jaclang "; then
            info "Removing jaclang (uv tool)..."
            uv tool uninstall jaclang
            removed=true
        fi
    fi

    # Remove standalone binary
    if [[ -f "${INSTALL_DIR}/jac" ]]; then
        info "Removing ${INSTALL_DIR}/jac..."
        rm -f "${INSTALL_DIR}/jac"
        removed=true
    fi

    if $removed; then
        info "Jac has been uninstalled."
    else
        warn "No Jac installation found."
    fi
}

# --- Main ---

main() {
    parse_args "$@"

    if $UNINSTALL; then
        do_uninstall
        exit 0
    fi

    detect_platform

    info "Detected platform: ${OS}-${ARCH}"

    if $STANDALONE; then
        install_standalone
    else
        install_via_uv
    fi
}

main "$@"
