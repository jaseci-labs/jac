#!/usr/bin/env bash
# Jac installer
#
# Installs the `jac` command from this repository's GitHub releases. There are
# two compilers, and a machine has one of them, since both are the command
# `jac`:
#
#   jac (the default)
#       The Jac compiler. A release is an archive,
#       jac-<version>-<platform>.tar.gz, unpacked under ~/.jac/<version>, with
#       ~/.local/bin/jac linked to its bin/jac. jac finds its runtime, its
#       standard library and its plugins beside its own executable.
#
#   the reference design (--reference)
#       The Jac language's reference design. A release is one self-contained
#       binary, jac-<version>-<platform>, installed as ~/.local/bin/jac. It
#       bundles its own runtime: no Python, pip or uv is needed.
#
# Installing one where the other is installed replaces it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash
#   curl -fsSL ... | bash -s -- --reference
#
# Options:
#   --reference   Install the reference design instead of jac
#   --version V   Install release V of the kind being installed (e.g. 0.70.0)
#   --uninstall   Remove whichever is installed
#   --help        Print usage
#
# Environment:
#   JAC_HOME               Where jac releases are unpacked (default ~/.jac)
#   JAC_BIN_DIR            Where the jac command goes (default ~/.local/bin)
#   JAC_RELEASES_API       The releases API's base, for tests and mirrors
#                          (default https://api.github.com/repos/jaseci-labs/jac)
#   JAC_RELEASES_DOWNLOAD  The release downloads' base, for tests and mirrors
#                          (default https://github.com/jaseci-labs/jac/releases/download)
#   GITHUB_TOKEN, GH_TOKEN Sent to api.github.com when set, for its rate limit

set -euo pipefail

REPO="jaseci-labs/jac"
DEFAULT_API="https://api.github.com/repos/${REPO}"
DEFAULT_DOWNLOAD="https://github.com/${REPO}/releases/download"
RELEASES_API="${JAC_RELEASES_API:-${DEFAULT_API}}"
RELEASES_DOWNLOAD="${JAC_RELEASES_DOWNLOAD:-${DEFAULT_DOWNLOAD}}"
RELEASES_API="${RELEASES_API%/}"
RELEASES_DOWNLOAD="${RELEASES_DOWNLOAD%/}"
INSTALL_URL="https://raw.githubusercontent.com/${REPO}/main/scripts/install.sh"

JAC_HOME="${JAC_HOME:-${HOME}/.jac}"
BIN_DIR="${JAC_BIN_DIR:-${HOME}/.local/bin}"
# Written beside a reference-design binary this script installed. `jac update
# --self` reads it to know the binary is this script's to replace.
INSTALL_MARKER=".jac-install"
INSTALL_MARKER_VALUE="installed-by-jaseci-labs-install-script"

# Both kinds publish to one repository, so GitHub's /releases/latest names
# whichever was published last, and this script never asks for it. It lists
# the releases instead, this many to a page and at most this many pages, and
# reads which kind each one is from the assets it holds.
PER_PAGE=30
MAX_PAGES=10

KIND="jac"
VERSION=""
UNINSTALL=false

# Filled in by resolve_release: the release to install, and what there is to
# say when there is none.
REL_TAG=""
REL_VERSION=""
OTHER_VERSION=""
NEWEST_VERSION=""

# Not local to a function: the EXIT trap runs after every function returned.
tmpdir=""
staging=""

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

cleanup() {
    if [[ -n "$tmpdir" ]]; then
        rm -rf "${tmpdir:?}"
    fi
    if [[ -n "$staging" ]]; then
        rm -rf "${staging:?}"
    fi
}

usage() {
    cat <<EOF
Jac installer

Installs the 'jac' command. There are two compilers, and a machine has one of
them; installing one where the other is installed replaces it.

  jac (the default)     The Jac compiler, unpacked under
                        ${JAC_HOME}/<version>, with
                        ${BIN_DIR}/jac linked to it.
  the reference design  The Jac language's reference design (--reference): one
                        self-contained binary at ${BIN_DIR}/jac.

USAGE:
    curl -fsSL ${INSTALL_URL} | bash
    curl -fsSL ... | bash -s -- [OPTIONS]

OPTIONS:
    --reference   Install the reference design instead of jac
    --version V   Install release V of the kind being installed (e.g. 0.70.0)
    --uninstall   Remove whichever is installed
    --help        Print this help message

ENVIRONMENT:
    JAC_HOME               Where jac releases are unpacked (default ~/.jac)
    JAC_BIN_DIR            Where the jac command goes (default ~/.local/bin)
    JAC_RELEASES_API       The releases API's base, for tests and mirrors
                           (default ${DEFAULT_API})
    JAC_RELEASES_DOWNLOAD  The release downloads' base, for tests and mirrors
                           (default ${DEFAULT_DOWNLOAD})
    GITHUB_TOKEN, GH_TOKEN Sent to api.github.com when set, for its rate limit

EXAMPLES:
    # The newest jac
    curl -fsSL ... | bash

    # The newest reference design
    curl -fsSL ... | bash -s -- --reference

    # A specific release
    curl -fsSL ... | bash -s -- --version 0.70.0
    curl -fsSL ... | bash -s -- --reference --version 0.40.1
EOF
}

# --- What the two kinds are called, and how each is asked for ---

kind_name() {
    if [[ "$1" == "reference" ]]; then
        echo "the Jac reference design"
    else
        echo "jac"
    fi
}

other_kind() {
    if [[ "$1" == "reference" ]]; then
        echo "jac"
    else
        echo "reference"
    fi
}

# The command that installs kind $1, release $2 when given.
install_command() {
    local args=""
    if [[ "$1" == "reference" ]]; then
        args=" --reference"
    fi
    if [[ -n "${2:-}" ]]; then
        args="${args} --version $2"
    fi
    if [[ -n "$args" ]]; then
        echo "curl -fsSL ${INSTALL_URL} | bash -s --${args}"
    else
        echo "curl -fsSL ${INSTALL_URL} | bash"
    fi
}

# --- Platform detection ---

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux*) OS="linux" ;;
        Darwin*) OS="macos" ;;
        MINGW* | MSYS* | CYGWIN*)
            err "This installer is for Linux and macOS. Each jac release has a Windows"
            err "zip, jac-<version>-windows-x86_64.zip, to unpack by hand; or use WSL2"
            err "and re-run this installer inside it."
            exit 1
            ;;
        *)
            err "Unsupported operating system: $os"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64 | amd64) ARCH="x86_64" ;;
        aarch64 | arm64) ARCH="aarch64" ;;
        *)
            err "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    PLATFORM="${OS}-${ARCH}"
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reference)
                KIND="reference"
                shift
                ;;
            --version)
                if [[ $# -lt 2 ]]; then
                    err "--version requires a version (e.g. --version 0.70.0)"
                    exit 1
                fi
                VERSION="${2#v}"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            # The reference design was once one of several distributions these
            # chose between. Its binary is the only one now, so they do nothing.
            --standalone | --core)
                warn "Note: '$1' is no longer needed; the reference design is one binary (--reference)."
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

# --- The releases API ---

# GET the API URL $1 into the file $2 and print the HTTP status, "000" when
# the server could not be reached. The token goes to GitHub's own API only,
# never to a base named by JAC_RELEASES_API.
api_get() {
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}" code
    if [[ -n "$token" && "$RELEASES_API" == "$DEFAULT_API" ]]; then
        code="$(curl -sSL -o "$2" -w '%{http_code}' -H "Authorization: Bearer ${token}" "$1" 2>/dev/null)" || code="000"
    else
        code="$(curl -sSL -o "$2" -w '%{http_code}' "$1" 2>/dev/null)" || code="000"
    fi
    echo "$code"
}

api_failed() {
    err "Could not read the releases from ${RELEASES_API} (HTTP $1)."
    if [[ "$1" == "403" || "$1" == "429" ]]; then
        err "GitHub limits requests made without a token. Set GITHUB_TOKEN and try"
        err "again, or wait for the limit to reset."
    else
        err "Check your connection and try again."
    fi
    exit 1
}

# Read the releases JSON in the file $1 and print one line for each release:
#
#   tag <TAB> published_at <TAB> draft <TAB> prerelease <TAB> jac <TAB> jac-any <TAB> ref <TAB> ref-any
#
# `jac` is the version of the release's jac archive for this platform
# (jac-<version>-<platform>.tar.gz) and `ref` that of its reference-design
# binary (jac-<version>-<platform>). The -any columns are the version of an
# archive or a binary for any platform. Each is "-" where the release holds
# none. $2 is how deep a release object sits: 2 in a listing, 1 for one
# release.
#
# This reads the JSON's structure, not its layout, with sed and awk alone. sed
# rewrites the two escapes that can hide a quote, so that every quote left
# opens or closes a string. awk then takes the quote as its record separator:
# odd records are what lies between strings (braces, brackets, colons,
# literals) and even records are the strings. A string is a key when a colon
# follows it, and the nesting depth says whose key it is, so release notes
# that quote "tag_name", or an uploader named like an asset, are not taken
# for either.
scan_releases() {
    LC_ALL=C sed -e 's/\\\\/\\u005c/g' -e 's/\\"/\\u0022/g' "$1" \
        | LC_ALL=C awk -v RS='"' -v plat="$PLATFORM" -v base="$2" '
        function reset() {
            tag = ""; pub = "-"; draft = "false"; pre = "false"
            jv = "-"; jany = "-"; rv = "-"; rany = "-"
        }
        function flush() {
            if (tag != "")
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", tag, pub, draft, pre, jv, jany, rv, rany
            reset()
        }
        # The version in the asset name n when it is "jac-<version><tail>".
        function version_of(n, tail,    v) {
            if (length(n) <= 4 + length(tail)) return ""
            if (substr(n, length(n) - length(tail) + 1) != tail) return ""
            v = substr(n, 5, length(n) - 4 - length(tail))
            if (v !~ /^[0-9][0-9A-Za-z.+_]*(-[0-9A-Za-z.+_]+)*$/) return ""
            return v
        }
        function asset(n,    v, rest) {
            if (substr(n, 1, 4) != "jac-") return
            v = version_of(n, "-" plat ".tar.gz")
            if (v != "") { jv = v; jany = v; return }
            v = version_of(n, "-" plat)
            if (v != "") { rv = v; rany = v; return }
            # An asset of either kind for another platform.
            rest = n
            if (sub(/-(linux|macos|windows)-(x86_64|aarch64)\.(tar\.gz|zip)$/, "", rest)) {
                v = substr(rest, 5)
                if (v ~ /^[0-9]/ && jany == "-") jany = v
            } else if (sub(/-(linux|macos)-(x86_64|aarch64)$/, "", rest)) {
                v = substr(rest, 5)
                if (v ~ /^[0-9]/ && rany == "-") rany = v
            }
        }
        function value(v) {
            if (keydepth == base) {
                if (key == "tag_name") tag = v
                else if (key == "draft") draft = v
                else if (key == "prerelease") pre = v
                else if (key == "published_at" && v != "null") pub = v
            } else if (inassets && keydepth == base + 2 && key == "name") {
                asset(v)
            }
        }
        BEGIN { depth = 0; expect = 0; inassets = 0; wantassets = 0; reset() }
        NR % 2 == 0 {
            if (expect) { value($0); expect = 0 }
            last = $0
            next
        }
        {
            t = $0
            gsub(/[ \t\r\n]/, "", t)
            expect = 0
            if (substr(t, 1, 1) == ":") {
                key = last; keydepth = depth
                t = substr(t, 2)
                if (t == "") expect = 1
                else if (match(t, /^(true|false|null)/)) value(substr(t, 1, RLENGTH))
                wantassets = (key == "assets" && keydepth == base)
            }
            n = length(t)
            for (i = 1; i <= n; i++) {
                c = substr(t, i, 1)
                if (c == "{" || c == "[") {
                    depth++
                    if (c == "[" && wantassets) inassets = 1
                    wantassets = 0
                } else if (c == "}" || c == "]") {
                    if (c == "}" && depth == base) flush()
                    depth--
                    if (c == "]" && depth == base) inassets = 0
                }
            }
        }
    '
}

# From scan_releases lines on stdin, print the line of the release to take:
# among the published releases (no drafts and no prereleases, unless $2 is
# "any") that hold a version in column $1, the one with the highest version,
# and of two with one version the one published later.
#
# The highest version, not the latest date: a line that is still maintained
# publishes after a newer one (0.34.28 came out three days after 0.38.0), and
# a bare install is not for that line's users. Versions are only ever compared
# within one kind, which the assets decide, so the two kinds' numbers are free
# to drift apart or to overlap.
pick_release() {
    LC_ALL=C awk -F '\t' -v col="$1" -v all="${2:-}" '
        function vcmp(a, b,    x, y, n, m, i, p, q) {
            n = split(a, x, /[.+_-]/); m = split(b, y, /[.+_-]/)
            for (i = 1; i <= n || i <= m; i++) {
                p = (i <= n) ? x[i] : "0"; q = (i <= m) ? y[i] : "0"
                if (p ~ /^[0-9]+$/ && q ~ /^[0-9]+$/) {
                    if (p + 0 != q + 0) return (p + 0 > q + 0) ? 1 : -1
                } else if (p != q) {
                    return (p > q) ? 1 : -1
                }
            }
            return 0
        }
        $col == "-" || $col == "" { next }
        all != "any" && ($3 != "false" || $4 != "false") { next }
        {
            c = (best == "") ? 1 : vcmp($col, bestv)
            if (c > 0 || (c == 0 && $2 > bestd)) { best = $0; bestv = $col; bestd = $2 }
        }
        END { if (best != "") print best }
    '
}

# Columns of a scan_releases line, by kind.
kind_col() {
    if [[ "$1" == "reference" ]]; then echo 7; else echo 5; fi
}

kind_any_col() {
    if [[ "$1" == "reference" ]]; then echo 8; else echo 6; fi
}

# Print column $3 of the line pick_release takes from the lines $1 for column
# $2 (and $4, "any" to take drafts and prereleases too), or nothing.
picked() {
    printf '%s\n' "$1" | pick_release "$2" "${4:-}" | cut -f "$3"
}

# Find the release to install: REL_TAG and REL_VERSION, left empty when no
# release holds this kind for this platform. OTHER_VERSION is the other kind's
# newest version for this platform and NEWEST_VERSION this kind's newest
# version for any platform, each empty when there is none.
resolve_release() {
    local col anycol othercol body code rows page
    col="$(kind_col "$KIND")"
    anycol="$(kind_any_col "$KIND")"
    othercol="$(kind_col "$(other_kind "$KIND")")"
    body="${tmpdir}/releases.json"

    if [[ -n "$VERSION" ]]; then
        code="$(api_get "${RELEASES_API}/releases/tags/v${VERSION}" "$body")"
        if [[ "$code" == "404" ]]; then
            err "There is no release v${VERSION}. See https://github.com/${REPO}/releases"
            exit 1
        elif [[ "$code" != "200" ]]; then
            api_failed "$code"
        fi
        rows="$(scan_releases "$body" 1)"
        REL_TAG="$(picked "$rows" "$col" 1 any)"
        REL_VERSION="$(picked "$rows" "$col" "$col" any)"
        OTHER_VERSION="$(picked "$rows" "$othercol" "$othercol" any)"
        NEWEST_VERSION="$(picked "$rows" "$anycol" "$anycol" any)"
        return 0
    fi

    # Page by page, newest first. The first page that holds this kind for this
    # platform decides.
    page=1
    while [[ $page -le $MAX_PAGES ]]; do
        code="$(api_get "${RELEASES_API}/releases?per_page=${PER_PAGE}&page=${page}" "$body")"
        if [[ "$code" != "200" ]]; then
            api_failed "$code"
        fi
        rows="$(scan_releases "$body" 2)"
        if [[ -z "$rows" ]]; then
            break
        fi
        if [[ -z "$NEWEST_VERSION" ]]; then
            NEWEST_VERSION="$(picked "$rows" "$anycol" "$anycol")"
        fi
        if [[ -z "$OTHER_VERSION" ]]; then
            OTHER_VERSION="$(picked "$rows" "$othercol" "$othercol")"
        fi
        REL_TAG="$(picked "$rows" "$col" 1)"
        if [[ -n "$REL_TAG" ]]; then
            REL_VERSION="$(picked "$rows" "$col" "$col")"
            return 0
        fi
        page=$((page + 1))
    done
}

# Nothing to install: say what there is instead, and stop.
no_release() {
    local other
    other="$(other_kind "$KIND")"
    if [[ -n "$VERSION" ]]; then
        if [[ "$KIND" == "reference" ]]; then
            err "Release v${VERSION} holds no reference-design binary for ${PLATFORM}."
        else
            err "Release v${VERSION} holds no jac archive for ${PLATFORM}."
        fi
        if [[ -n "$OTHER_VERSION" ]]; then
            err "It is a release of $(kind_name "$other"). To install that:"
            err ""
            err "  $(install_command "$other" "$VERSION")"
        elif [[ -n "$NEWEST_VERSION" ]]; then
            err "It was not built for this platform. Its assets:"
            err ""
            err "  https://github.com/${REPO}/releases/tag/v${VERSION}"
        else
            err "Its assets: https://github.com/${REPO}/releases/tag/v${VERSION}"
        fi
        exit 1
    fi

    if [[ "$KIND" == "reference" ]]; then
        err "No release of the Jac reference design has a binary for ${PLATFORM}."
    else
        err "No release of jac has a build for ${PLATFORM}."
    fi
    if [[ "$PLATFORM" == "macos-x86_64" ]]; then
        err "An Apple Silicon (arm64) build does not run on an Intel Mac, and Rosetta"
        err "translates in the other direction, so there is nothing to substitute."
    fi
    if [[ -n "$OTHER_VERSION" ]]; then
        err ""
        if [[ "$other" == "reference" ]]; then
            err "The Jac reference design has one (${OTHER_VERSION}). It is the language's"
            err "reference design, and installs as the command jac too:"
        else
            err "jac has one (${OTHER_VERSION}). It is the Jac compiler, and installs as"
            err "the command jac too:"
        fi
        err ""
        err "  $(install_command "$other")"
    else
        err "The releases: https://github.com/${REPO}/releases"
    fi
    exit 1
}

# --- Downloading ---

sha256_of() {
    if has_cmd sha256sum; then
        sha256sum "$1" | awk '{print $1}'
    elif has_cmd shasum; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif has_cmd openssl; then
        openssl dgst -sha256 "$1" | awk '{print $NF}'
    else
        err "None of sha256sum, shasum and openssl is here to verify the download."
        exit 1
    fi
}

# Download the asset $1 of release REL_TAG into tmpdir and check it against
# the .sha256 published beside it. An asset is large (a jac archive is
# hundreds of megabytes), so on a terminal curl draws its progress bar: on
# stderr, which is still the terminal when this script is piped to bash.
download_verified() {
    local asset="$1" url expected actual fetched=true
    url="${RELEASES_DOWNLOAD}/${REL_TAG}/${asset}"

    info "Downloading ${asset}..."
    if [[ -t 2 ]]; then
        curl -fL --progress-bar -o "${tmpdir}/${asset}" "$url" || fetched=false
    else
        curl -fsSL -o "${tmpdir}/${asset}" "$url" || fetched=false
    fi
    if ! $fetched; then
        err "Failed to download ${url}"
        err "Release ${REL_TAG} lists this asset, so this is most likely a network"
        err "problem or a transient GitHub outage. Try again in a moment."
        exit 1
    fi
    if ! curl -fsSL -o "${tmpdir}/${asset}.sha256" "${url}.sha256"; then
        err "Failed to download the checksum of ${asset}; refusing to install it unverified."
        exit 1
    fi
    expected="$(awk '{print $1; exit}' "${tmpdir}/${asset}.sha256")"
    actual="$(sha256_of "${tmpdir}/${asset}")"
    if [[ -z "$expected" || "$expected" != "$actual" ]]; then
        err "Checksum verification failed for ${asset}."
        err "  expected: ${expected}"
        err "  got:      ${actual}"
        exit 1
    fi
    info "Checksum verified."
}

# --- What is installed ---

# What ${BIN_DIR}/jac is: "jac" (this script's link into JAC_HOME),
# "reference" (a binary: the reference design's), "link" (some other link) or
# "none".
installed_kind() {
    local target="${BIN_DIR}/jac"
    if [[ -L "$target" ]]; then
        case "$(readlink "$target")" in
            "${JAC_HOME}"/*) echo "jac" ;;
            *) echo "link" ;;
        esac
    elif [[ -e "$target" ]]; then
        echo "reference"
    else
        echo "none"
    fi
}

# The version JAC_HOME's `current` link names, or nothing.
current_version() {
    if [[ -L "${JAC_HOME}/current" ]]; then
        basename "$(readlink "${JAC_HOME}/current")"
    fi
}

# Remove the jac releases unpacked under JAC_HOME, and JAC_HOME with them when
# nothing else is in it. What else is there is not this script's to remove:
# the reference design keeps shell completions and settings in ~/.jac. Fails
# when there was nothing to remove.
remove_unpacked() {
    local dir found=false
    if [[ -L "${JAC_HOME}/current" ]]; then
        rm -f "${JAC_HOME:?}/current"
        found=true
    fi
    for dir in "${JAC_HOME}"/*/; do
        if [[ -f "${dir}bin/jac" ]]; then
            rm -rf "${dir:?}"
            found=true
        fi
    done
    rmdir "$JAC_HOME" 2>/dev/null || true
    $found
}

warn_path() {
    if echo "$PATH" | tr ':' '\n' | grep -qxF "$BIN_DIR"; then
        return 0
    fi
    local shell_name profile=""
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    case "$shell_name" in
        zsh) profile="$HOME/.zshrc" ;;
        bash)
            if [[ -f "$HOME/.bashrc" ]]; then
                profile="$HOME/.bashrc"
            else
                profile="$HOME/.bash_profile"
            fi
            ;;
        fish) profile="$HOME/.config/fish/config.fish" ;;
    esac
    warn ""
    warn "${BIN_DIR} is not on your PATH. Add it:"
    if [[ "$shell_name" == "fish" ]]; then
        warn "  fish_add_path ${BIN_DIR}"
    elif [[ -n "$profile" ]]; then
        warn "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ${profile}"
    else
        warn "  export PATH=\"${BIN_DIR}:\$PATH\""
    fi
    warn "Then restart your shell."
    warn ""
}

# --- Installing jac ---

# Compile and run a one-line program with the installed compiler, started as
# it will be from now on: by its name, found on PATH in BIN_DIR. Proof that it
# runs from there and finds its runtime and toolchain.
smoke_test() {
    local work out
    work="$(mktemp -d)"
    printf '%s\n' 'with entry { print("jac is ready"); }' > "${work}/hello.jac"
    if PATH="${BIN_DIR}:${PATH}" jac build "${work}/hello.jac" -o "${work}/hello" \
        && out="$("${work}/hello")" && [[ "$out" == "jac is ready" ]]; then
        rm -rf "${work:?}"
        return 0
    fi
    rm -rf "${work:?}"
    return 1
}

install_jac() {
    need_cmd tar
    local name="jac-${REL_VERSION}-${PLATFORM}"
    download_verified "${name}.tar.gz"

    # Unpacked inside JAC_HOME and renamed into place, so that a file the
    # archive holds under two names (a hard link) stays one file.
    mkdir -p "$JAC_HOME" "$BIN_DIR"
    staging="${JAC_HOME}/.unpack.$$"
    rm -rf "${staging:?}"
    mkdir "$staging"
    tar xzf "${tmpdir}/${name}.tar.gz" -C "$staging"
    if [[ ! -f "${staging}/${name}/bin/jac" ]]; then
        err "${name}.tar.gz does not hold ${name}/bin/jac; nothing was installed."
        exit 1
    fi

    if [[ "$(installed_kind)" == "reference" ]]; then
        info "Replacing the Jac reference design at ${BIN_DIR}/jac with jac ${REL_VERSION}."
        rm -f "${BIN_DIR:?}/jac"
    fi
    rm -f "${BIN_DIR:?}/${INSTALL_MARKER:?}"

    rm -rf "${JAC_HOME:?}/${REL_VERSION:?}"
    mv "${staging}/${name}" "${JAC_HOME}/${REL_VERSION}"
    rmdir "$staging"
    ln -sfn "${JAC_HOME}/${REL_VERSION}" "${JAC_HOME}/current"
    ln -sfn "${JAC_HOME}/current/bin/jac" "${BIN_DIR}/jac"

    if smoke_test; then
        info "jac ${REL_VERSION} installed: ${BIN_DIR}/jac -> ${JAC_HOME}/${REL_VERSION}"
        info "Try it:  jac build hello.jac -o hello && ./hello"
    else
        err "jac ${REL_VERSION} was unpacked to ${JAC_HOME}/${REL_VERSION}, but it could"
        err "not compile and run a test program on this machine."
        exit 1
    fi
    warn_path
}

# --- Installing the reference design ---

install_reference() {
    local asset="jac-${REL_VERSION}-${PLATFORM}" was had
    download_verified "$asset"

    was="$(installed_kind)"
    if [[ "$was" == "jac" ]]; then
        had="$(current_version)"
        info "Replacing jac${had:+ ${had}} (${JAC_HOME}) with the Jac reference design ${REL_VERSION}."
        rm -f "${BIN_DIR:?}/jac"
        remove_unpacked || true
    elif [[ "$was" == "link" ]]; then
        rm -f "${BIN_DIR:?}/jac"
    fi

    mkdir -p "$BIN_DIR"
    chmod +x "${tmpdir}/${asset}"
    mv "${tmpdir}/${asset}" "${BIN_DIR}/jac"
    printf '%s\n' "$INSTALL_MARKER_VALUE" > "${BIN_DIR}/${INSTALL_MARKER}"

    info ""
    info "The Jac reference design ${REL_VERSION} is installed: ${BIN_DIR}/jac"
    info ""
    info "Performing initial setup, this may take a moment..."
    # No stderr redirect: the launcher narrates its one-time extract (payload
    # read, sha256, live percent) on stderr -- show it.
    "${BIN_DIR}/jac" || true
    info ""
    warn_path
}

install() {
    need_cmd curl
    tmpdir="$(mktemp -d)"

    if [[ -n "$VERSION" ]]; then
        info "Looking up release v${VERSION}..."
    else
        info "Finding the newest release of $(kind_name "$KIND")..."
    fi
    resolve_release
    if [[ -z "$REL_TAG" ]]; then
        no_release
    fi
    if [[ -z "$VERSION" && -n "$NEWEST_VERSION" && "$NEWEST_VERSION" != "$REL_VERSION" ]]; then
        warn "The newest release, ${NEWEST_VERSION}, has no build for ${PLATFORM}."
        warn "Installing ${REL_VERSION}, the newest that has one."
    fi

    if [[ "$KIND" == "reference" ]]; then
        install_reference
    else
        install_jac
    fi
}

# --- Uninstall ---

do_uninstall() {
    local removed=false

    if [[ "$(installed_kind)" != "none" ]]; then
        info "Removing ${BIN_DIR}/jac..."
        rm -f "${BIN_DIR:?}/jac"
        removed=true
    fi
    rm -f "${BIN_DIR:?}/${INSTALL_MARKER:?}"
    if remove_unpacked; then
        info "Removed the jac releases under ${JAC_HOME}."
        removed=true
    fi

    # Installs that older versions of this script made with uv.
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
    trap cleanup EXIT

    if $UNINSTALL; then
        do_uninstall
        exit 0
    fi

    detect_platform
    info "Detected platform: ${PLATFORM}"
    install
}

main "$@"
