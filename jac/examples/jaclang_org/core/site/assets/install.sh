#!/usr/bin/env bash
# Jac Programming Language Installer
#
# Downloads the self-contained native `jac` binary from GitHub Releases and
# puts it on your PATH. No system Python, pip, or uv is required -- the binary
# bundles its own runtime.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
#
# Options:
#   --version V   Install a specific release version (e.g., 2.3.1)
#   --uninstall   Remove Jac
#   --help        Print usage
#
# Examples:
#   curl -fsSL ... | bash                          # Latest jac binary
#   curl -fsSL ... | bash -s -- --version 2.3.1    # Specific version
#   curl -fsSL ... | bash -s -- --uninstall        # Remove Jac

set -euo pipefail

REPO="jaseci-labs/jaseci"
GITHUB_API="https://api.github.com/repos/${REPO}"
INSTALL_DIR="${HOME}/.local/bin"

# --- Defaults ---
VERSION=""
UNINSTALL=false
# Filled in by resolve_release_metadata once the release is known: the jac
# binary version its assets are named with, and every asset name it carries.
ASSET_VERSION=""
RELEASE_ASSETS=""

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

# GitHub API requests: authenticate when GITHUB_TOKEN/GH_TOKEN is set, since
# unauthenticated calls share a per-IP rate limit that CI runners exhaust.
api_curl() {
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    if [[ -n "$token" ]]; then
        curl -fsSL -H "Authorization: Bearer ${token}" "$@"
    else
        curl -fsSL "$@"
    fi
}

# --- Usage ---

usage() {
    cat <<EOF
Jac Programming Language Installer

Downloads the self-contained native 'jac' binary (bundled runtime; no Python,
pip, or uv needed) and puts it on your PATH.

USAGE:
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
    curl -fsSL ... | bash -s -- [OPTIONS]

OPTIONS:
    --version V   Install a specific release version (e.g., 2.3.1)
    --uninstall   Remove Jac installation
    --help        Print this help message

EXAMPLES:
    # Latest jac binary
    curl -fsSL ... | bash

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
            err "For now, please use WSL2 and re-run this installer inside it."
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
            # Accepted for backward compatibility -- the binary is now the only
            # distribution, so these are no-ops.
            --standalone | --core)
                warn "Note: '$1' is no longer needed; the native binary is the default install."
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

# --- Version resolution ---

get_latest_version() {
    local response
    response=$(api_curl "${GITHUB_API}/releases/latest" 2>/dev/null) || {
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

# Reads the release once and leaves both answers in globals: ASSET_VERSION and
# RELEASE_ASSETS. Globals rather than a printed value on purpose -- a caller
# would have to run this in a command substitution to capture what it echoes,
# and a subshell's assignments are gone the moment it exits, so the asset list
# would silently arrive empty at every caller.
resolve_release_metadata() {
    local release_tag="$1"
    local response
    response=$(api_curl "${GITHUB_API}/releases/tags/v${release_tag}" 2>/dev/null) || {
        err "Failed to query GitHub API for release v${release_tag}."
        exit 1
    }

    # Every asset name on that release, one per line. A platform's binary is
    # either in here or the release genuinely has none, and the second case
    # deserves a straight answer rather than a download that 404s.
    RELEASE_ASSETS=$(echo "$response" | grep -o '"name":[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')

    # Find a jac-<version>-<os>-<arch> asset to extract the jac binary version
    # (the jaclang version, which can differ from the jaseci release tag).
    ASSET_VERSION=$(echo "$response" | grep -o '"name":[[:space:]]*"jac-[^"]*"' | head -1 | grep -oE 'jac-[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^jac-//')

    if [[ -z "$ASSET_VERSION" ]]; then
        err "Could not determine the jac binary version from release v${release_tag} assets."
        err "The native binary may not have been built yet for this release."
        exit 1
    fi
}

# Walks back through recent releases for the newest one that carries a binary
# for this platform, so the message below can name a version instead of waving
# at the releases page. Bounded: this only ever runs on an error path, and each
# probe is one API call. Prints the version, or nothing if it finds none.
#
# The asset match insists on a jac-<major>.<minor>.<patch>-<platform> name, so
# the rolling `dev` prerelease's jac-dev-* assets never answer for a release.
find_last_release_with_platform() {
    local list tags tag body probed=0

    list=$(api_curl "${GITHUB_API}/releases?per_page=20" 2>/dev/null) || return 0
    tags=$(echo "$list" | grep -o '"tag_name":[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')

    while read -r tag; do
        [[ -n "$tag" ]] || continue
        [[ "$tag" == v* ]] || continue
        [[ "$tag" != "v${VERSION}" ]] || continue
        if [[ $probed -ge 8 ]]; then
            break
        fi
        probed=$((probed + 1))
        body=$(api_curl "${GITHUB_API}/releases/tags/${tag}" 2>/dev/null) || continue
        if echo "$body" | grep -qE "\"name\":[[:space:]]*\"jac-[0-9]+\.[0-9]+\.[0-9]+-${OS}-${ARCH}\""; then
            echo "${tag#v}"
            return 0
        fi
    done <<< "$tags"
}

# A release either carries this platform's binary or it does not, and the only
# useful thing to do about "it does not" is say so. There is no fallback build
# to hand an Intel Mac: the Apple Silicon binary is arm64 code that Intel
# hardware cannot execute, and Rosetta translates x86_64 onto Apple Silicon,
# not the other way round.
require_platform_asset() {
    local asset="$1"

    if printf '%s\n' "$RELEASE_ASSETS" | grep -qxF "$asset"; then
        return 0
    fi

    err "Release v${VERSION} ships no jac binary for ${OS}-${ARCH}."
    err ""
    if [[ "$OS" == "macos" && "$ARCH" == "x86_64" ]]; then
        err "This release has no Intel macOS build, and there is nothing else here"
        err "that will run on this machine: the macOS binary that did build is"
        err "arm64 (Apple Silicon) code, and Rosetta translates in the opposite"
        err "direction. So there is no way to install v${VERSION} on an Intel Mac."
        err ""
        info "Looking for the most recent release that does have one..."
        local last
        last=$(find_last_release_with_platform)
        if [[ -n "$last" ]]; then
            err "Install v${last} instead, the newest release with an Intel macOS build:"
            err ""
            err "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/scripts/install.sh | bash -s -- --version ${last}"
            err ""
            err "Stay on it until an Intel build ships again."
        else
            err "No recent release carries one either. See the release list for"
            err "the last version that did:"
            err ""
            err "  https://github.com/${REPO}/releases"
        fi
    else
        err "Pick a release that has one: https://github.com/${REPO}/releases"
    fi
    exit 1
}

# --- Binary installation ---

install_binary() {
    need_cmd "curl"

    # Resolve the release tag (the jaseci/release version).
    if [[ -z "$VERSION" ]]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version)
        info "Latest release: ${VERSION}"
    fi

    # The jac binary asset is named with the jaclang version, which can differ
    # from the jaseci release tag.
    info "Resolving jac binary version for release v${VERSION}..."
    resolve_release_metadata "$VERSION"
    info "jac binary version: ${ASSET_VERSION}"

    local asset="jac-${ASSET_VERSION}-${OS}-${ARCH}"

    # Checked against the release's own asset list before downloading, so a
    # platform this release did not build gets an explanation rather than a
    # 404 and a list of guesses.
    require_platform_asset "$asset"

    local download_url="https://github.com/${REPO}/releases/download/v${VERSION}/${asset}"
    local checksum_url="${download_url}.sha256"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download to temp location. `tmpdir` is intentionally NOT `local`: the EXIT
    # trap below fires after install_binary returns, so a function-local would be
    # out of scope and trip `set -u` ("unbound variable") during cleanup. The
    # `${tmpdir:-}` guard keeps the trap safe if we exit before it is assigned.
    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir:-}"' EXIT

    info "Downloading ${asset}..."
    if ! curl -fsSL -o "${tmpdir}/${asset}" "$download_url"; then
        err "Failed to download: ${download_url}"
        err ""
        # Not a missing-asset guess any more: require_platform_asset already
        # confirmed the release lists this exact file.
        err "Release v${VERSION} does list this asset, so this is most likely a"
        err "network problem or a transient GitHub outage. Try again in a moment."
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
        info "Jac installed successfully!"
        info ""
        info "Performing initial setup, this may take a moment..."
        # No stderr redirect: the launcher narrates its one-time extract
        # (payload read, sha256, live percent) on stderr -- show it.
        jac || true
        info ""
    else
        warn "Binary installed to ${INSTALL_DIR}/jac but 'jac' is not on PATH."
        warn "Try restarting your shell or adding ~/.local/bin to PATH."
    fi
}

# --- Uninstall ---

do_uninstall() {
    local removed=false

    # Remove standalone binary
    if [[ -f "${INSTALL_DIR}/jac" ]]; then
        info "Removing ${INSTALL_DIR}/jac..."
        rm -f "${INSTALL_DIR}/jac"
        removed=true
    fi

    # Clean up any legacy uv-managed installs from older installer versions.
    if has_cmd uv; then
        if uv tool list 2>/dev/null | grep -q "^jaseci "; then
            info "Removing legacy jaseci (uv tool)..."
            uv tool uninstall jaseci
            removed=true
        fi
        if uv tool list 2>/dev/null | grep -q "^jaclang "; then
            info "Removing legacy jaclang (uv tool)..."
            uv tool uninstall jaclang
            removed=true
        fi
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

    install_binary
}

main "$@"
