#!/usr/bin/env bash
# Jac Programming Language Installer
#
# Installs the self-contained `jac` binary -- a Zig launcher that bundles its own
# private CPython, so it needs NO system Python, uv, or pip at install or runtime.
# Plugins (byllm, jac-scale, jac-mcp) are installed on top of the binary with
# `jac install`, which pulls them from PyPI into the binary's bundled interpreter.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
#
# Options:
#   --core        Install just the `jac` binary (no plugins)
#   --version V   Install the binary from a specific release tag (default: latest)
#   --uninstall   Remove the `jac` binary
#   --help        Print usage
#
# Examples:
#   curl -fsSL ... | bash                       # binary + plugins
#   curl -fsSL ... | bash -s -- --core          # binary only
#   curl -fsSL ... | bash -s -- --version jaclang-0.16.7

set -euo pipefail

REPO="jaseci-labs/jaseci"
GITHUB_API="https://api.github.com/repos/${REPO}"
INSTALL_DIR="${HOME}/.local/bin"

# --- Defaults ---
CORE_ONLY=false
VERSION=""
UNINSTALL=false
PLUGINS=(byllm jac-scale jac-mcp)

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
    --core        Install just the 'jac' binary (no plugins)
    --version V   Install the binary from a specific release tag (e.g., jaclang-0.16.7)
    --uninstall   Remove the 'jac' binary
    --help        Print this help message

EXAMPLES:
    # The 'jac' binary plus all plugins
    curl -fsSL ... | bash

    # Just the 'jac' binary
    curl -fsSL ... | bash -s -- --core

    # A specific release
    curl -fsSL ... | bash -s -- --version jaclang-0.16.7
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
            err "Windows detected. Windows binaries are not built yet."
            err "Please use WSL2 for now."
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
            --version)
                if [[ $# -lt 2 ]]; then
                    err "--version requires a release tag argument (e.g., --version jaclang-0.16.7)"
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

# --- Binary installation ---

# Fetch the release JSON for "latest" or "tags/<tag>".
release_json() {
    local ref="$1"
    curl -fsSL "${GITHUB_API}/releases/${ref}" 2>/dev/null || {
        err "Failed to query GitHub API for release: ${ref}"
        err "Check your internet connection or specify a tag with --version."
        exit 1
    }
}

install_binary() {
    need_cmd "curl"

    local ref json
    if [[ -n "$VERSION" ]]; then
        ref="tags/${VERSION}"
        info "Resolving release ${VERSION}..."
    else
        ref="latest"
        info "Fetching latest release..."
    fi
    json="$(release_json "$ref")"

    # The jac binary asset for this platform, e.g. jac-0.16.7-linux-x86_64
    # (exclude the .sha256 sidecar).
    local asset
    asset="$(echo "$json" \
        | grep -oE "\"name\":[[:space:]]*\"jac-[0-9]+\.[0-9]+\.[0-9]+-${OS}-${ARCH}\"" \
        | head -1 \
        | grep -oE "jac-[0-9]+\.[0-9]+\.[0-9]+-${OS}-${ARCH}")"
    if [[ -z "$asset" ]]; then
        err "No jac binary asset found for ${OS}-${ARCH} in the target release."
        err "Standalone binaries may not be built yet for this platform/release."
        exit 1
    fi
    info "Binary: ${asset}"

    local download_url checksum_url
    download_url="$(echo "$json" \
        | grep -oE "\"browser_download_url\":[[:space:]]*\"[^\"]*${asset}\"" \
        | head -1 \
        | grep -oE "https://[^\"]*${asset}")"
    checksum_url="${download_url}.sha256"

    mkdir -p "$INSTALL_DIR"

    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    info "Downloading ${asset}..."
    if ! curl -fsSL -o "${tmpdir}/${asset}" "$download_url"; then
        err "Failed to download: ${download_url}"
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

    if has_cmd jac; then
        info ""
        info "Jac installed successfully!"
        jac --version 2>/dev/null || true
    else
        warn "Binary installed to ${INSTALL_DIR}/jac but 'jac' is not on PATH."
        warn "Try restarting your shell or adding ~/.local/bin to PATH."
    fi
}

# --- Plugin installation (on top of the binary) ---

install_plugins() {
    if ! has_cmd jac; then
        warn "'jac' is not on PATH yet; skipping plugin install."
        warn "After fixing your PATH, run: jac install ${PLUGINS[*]}"
        return
    fi
    info ""
    info "Installing plugins: ${PLUGINS[*]}..."
    if ! jac install "${PLUGINS[@]}"; then
        warn "Plugin install failed. Install them later with: jac install ${PLUGINS[*]}"
    fi
}

# --- Uninstall ---

do_uninstall() {
    if [[ -f "${INSTALL_DIR}/jac" ]]; then
        info "Removing ${INSTALL_DIR}/jac..."
        rm -f "${INSTALL_DIR}/jac"
        info "Jac has been uninstalled."
    else
        warn "No 'jac' binary found at ${INSTALL_DIR}/jac."
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

    install_binary
    if ! $CORE_ONLY; then
        install_plugins
    fi

    info ""
    info "Get started:"
    info "  jac --help"
    info ""
}

main "$@"
