#!/usr/bin/env bash
# Jac Programming Language -- Build & Install (local source)
#
# Local counterpart to scripts/install.sh. Instead of downloading a prebuilt
# `jac` binary from GitHub Releases, this builds the self-contained native
# binary from THIS checkout with `zig build` and installs it onto your PATH --
# exactly where and how the official installer puts the downloaded one
# (~/.local/bin/jac). Use it to install the version you have locally (your
# edits, a branch, an unreleased commit).
#
# Requires Zig 0.16.0 and network access for the one-time build prerequisites
# (pinned LLVM + python-build-standalone + typeshed stubs, fetched by the build
# itself). No system Python, pip, or uv is needed -- the binary bundles its own
# runtime, same as the released one.
#
# Usage (from anywhere in the repo):
#   ./scripts/build_install.sh
#
# Options:
#   --dev         Build the fast editable dev binary (`zig build -Ddev`): links
#                 the in-repo jac/ compiler source instead of bundling it, so
#                 jac/jaclang edits take effect with no rebuild. Much faster to
#                 build, but the installed binary depends on this checkout
#                 staying in place. Default is a full self-contained release build.
#   --uninstall   Remove the installed jac binary
#   --help        Print usage
#
# scale and the MCP server ship built into jac (jaclang.scale /
# jaclang.cli.mcp). Other plugins (byllm) are installed separately once `jac`
# is on PATH:
#   jac install byllm

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"

# --- Defaults ---
DEV_BUILD=false
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
Jac Programming Language -- Build & Install (local source)

Builds the self-contained native 'jac' binary from this checkout with
'zig build' and installs it to ${INSTALL_DIR}, the same place the official
installer (scripts/install.sh) puts the downloaded binary.

Requires Zig 0.16.0 and network access for the one-time build prerequisites.

USAGE:
    ./scripts/build_install.sh [OPTIONS]

OPTIONS:
    --dev         Build the fast editable dev binary (zig build -Ddev). Links
                  the in-repo compiler source instead of bundling it, so the
                  installed binary depends on this checkout staying in place.
    --uninstall   Remove the installed jac binary
    --help        Print this help message

PLUGINS:
    Once 'jac' is on PATH, install plugins with the binary's own installer:
        jac install byllm
EOF
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dev)
                DEV_BUILD=true
                shift
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

# --- Build + install ---

build_and_install() {
    need_cmd "git"
    need_cmd "zig"

    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"
    local jac_dir="${repo_root}/jac"

    if [[ ! -f "${jac_dir}/build.zig" ]]; then
        err "Could not find the jac build tree at ${jac_dir}."
        err "Run this script from inside the jaseci repository checkout."
        exit 1
    fi

    # The native (na) backend statically links a pinned LLVM into the LLVMPY_*
    # shim, which `zig build` needs placed in-tree before it can link. Fetching
    # it is idempotent (a no-op once present), same prerequisite the dev and
    # release builds share.
    info "Fetching pinned LLVM for the jacllvm shim (one-time; idempotent)..."
    ( cd "$jac_dir" && zig build fetch-llvm --summary all )

    if $DEV_BUILD; then
        info "Building the dev binary (zig build -Ddev; compiler linked from this checkout)..."
        ( cd "$jac_dir" && zig build -Ddev -Dpayload-progress )
    else
        info "Building the self-contained release binary (zig build)..."
        ( cd "$jac_dir" && zig build -Dpayload-progress --summary all )
    fi

    local built_bin="${jac_dir}/zig-out/bin/jac"
    if [[ ! -x "$built_bin" ]]; then
        err "Build finished but no binary was produced at ${built_bin}."
        exit 1
    fi

    # Install binary -- same destination as scripts/install.sh.
    mkdir -p "$INSTALL_DIR"

    if $DEV_BUILD; then
        # The dev binary links the in-repo compiler source, so it must keep
        # pointing back at this checkout. Symlink rather than copy.
        info "Linking dev binary into ${INSTALL_DIR}/jac (points at this checkout)..."
        ln -sf "$built_bin" "${INSTALL_DIR}/jac"
    else
        info "Installing binary to ${INSTALL_DIR}/jac..."
        cp "$built_bin" "${INSTALL_DIR}/jac"
        chmod +x "${INSTALL_DIR}/jac"
    fi

    ensure_on_path

    # Verify
    if has_cmd jac; then
        info ""
        info "Jac built and installed successfully!"
        jac --version 2>/dev/null || true
        info ""
        info "Get started:"
        info "  jac --help"
        info ""
        info "Add plugins (AI, deployment, MCP) when you need them:"
        info "  jac install byllm"
        info ""
    else
        warn "Binary installed to ${INSTALL_DIR}/jac but 'jac' is not on PATH."
        warn "Try restarting your shell or adding ~/.local/bin to PATH."
    fi
}

# --- Uninstall ---

do_uninstall() {
    local removed=false

    if [[ -e "${INSTALL_DIR}/jac" || -L "${INSTALL_DIR}/jac" ]]; then
        info "Removing ${INSTALL_DIR}/jac..."
        rm -f "${INSTALL_DIR}/jac"
        removed=true
    fi

    if $removed; then
        info "Jac has been uninstalled."
        info "Note: this leaves the build tree (jac/zig-out, jac/.llvm-build) intact."
    else
        warn "No Jac installation found at ${INSTALL_DIR}/jac."
    fi
}

# --- Main ---

main() {
    parse_args "$@"

    if $UNINSTALL; then
        do_uninstall
        exit 0
    fi

    build_and_install
}

main "$@"
