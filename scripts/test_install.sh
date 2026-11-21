#!/usr/bin/env bash
# Tests of scripts/install.sh that need no network.
#
# A local server stands in for GitHub: it answers the releases API from a
# fixture list and serves fixture assets, both kinds of release in one
# repository as on GitHub (jac's tagged jac-v<version>, the reference
# design's v<version>). The installer is pointed at it with
# JAC_RELEASES_API and JAC_RELEASES_DOWNLOAD, and runs in a HOME of its own
# for each case. `uname` is stubbed, so the platform is the fixture's and not
# the machine's. The installed "compilers" are shell scripts that answer
# `--version` and, for jac, the one build the installer's smoke test asks for.
#
# Needs bash, curl, tar and python3 (for the server). Run it from anywhere:
#
#     bash scripts/test_install.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${HERE}/install.sh"
WORK="$(mktemp -d)"
FIX="${WORK}/fixture"
STUBS="${WORK}/stubs"
SERVER_PID=""
BASE=""
H=""
OUT=""
RC=0
AWK_DIR=""
LOG_MARK=0
PASSED=0
FAILED=0

cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "${WORK:?}"
}
trap cleanup EXIT

sha256_of() {
    if command -v sha256sum > /dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# --- Fixture assets ---

# A reference-design release asset: one "binary", with its checksum beside it.
reference_asset() {
    local tag="$1" version="$2" platform="$3" dir file
    dir="${FIX}/assets/${tag}"
    file="${dir}/jac-${version}-${platform}"
    mkdir -p "$dir"
    cat > "$file" <<EOF
#!/bin/sh
if [ "\${1:-}" = "--version" ]; then
    echo "jac ${version} (reference design, ${platform})"
else
    echo "reference design ${version}: first-run setup"
fi
EOF
    echo "$(sha256_of "$file")  jac-${version}-${platform}" > "${file}.sha256"
}

# A jac release asset: an archive of one directory holding bin/jac and the
# trees jac finds beside it, with its checksum beside it.
jac_asset() {
    local tag="$1" version="$2" platform="$3" dir name stage
    dir="${FIX}/assets/${tag}"
    name="jac-${version}-${platform}"
    stage="${WORK}/stage"
    mkdir -p "$dir"
    rm -rf "${stage:?}"
    mkdir -p "${stage}/${name}/bin" "${stage}/${name}/lib" "${stage}/${name}/rt" \
        "${stage}/${name}/abstractions" "${stage}/${name}/libraries" "${stage}/${name}/docs"
    cat > "${stage}/${name}/bin/jac" <<EOF
#!/bin/sh
if [ "\${1:-}" = "--version" ]; then
    echo "jac ${version} (${platform})"
elif [ "\${1:-}" = "build" ]; then
    out=""
    while [ \$# -gt 0 ]; do
        if [ "\$1" = "-o" ]; then out="\$2"; fi
        shift
    done
    printf '#!/bin/sh\necho "jac is ready"\n' > "\$out"
    chmod +x "\$out"
fi
EOF
    chmod +x "${stage}/${name}/bin/jac"
    echo "$version" > "${stage}/${name}/VERSION"
    (cd "$stage" && tar czf "${dir}/${name}.tar.gz" "$name")
    echo "$(sha256_of "${dir}/${name}.tar.gz")  ${name}.tar.gz" > "${dir}/${name}.tar.gz.sha256"
}

# --- The fixture releases ---
#
# releases.spec lists them newest first, as GitHub does, one to a line:
#
#   tag|published_at|draft|prerelease|asset,asset,...
#
# mkreleases.py writes the releases API's JSON from it, shaped as GitHub's is
# and with every trap for a reader of text in it: release notes that quote
# keys and hold escaped quotes, a title and an uploader named like an asset,
# an author with a tag_name of its own.

write_tools() {
    mkdir -p "$FIX" "$STUBS"
    cat > "${WORK}/mkreleases.py" <<'EOF'
import json
import sys

spec, out = sys.argv[1], sys.argv[2]
releases = []
for number, line in enumerate(open(spec).read().split("\n")):
    if not line.strip() or line.startswith("#"):
        continue
    tag, published, draft, prerelease, assets = line.split("|")
    releases.append(
        {
            "url": "https://api.example/repos/o/r/releases/%d" % number,
            "id": number,
            "author": {"login": "bot", "tag_name": "v96.0.0", "draft": True, "name": "jac-96.0.0-linux-x86_64"},
            "tag_name": tag,
            "target_commitish": "main",
            "name": "jac-97.0.0-linux-x86_64.tar.gz",
            "draft": draft == "true",
            "prerelease": prerelease == "true",
            "created_at": published or "2026-01-01T00:00:00Z",
            "published_at": published or None,
            "assets": [
                {
                    "url": "https://api.example/assets/%d" % index,
                    "name": name,
                    "label": "",
                    "uploader": {"login": "bot", "name": "jac-98.0.0-linux-x86_64"},
                    "state": "uploaded",
                    "size": 1,
                    "browser_download_url": "https://example/%s/%s" % (tag, name),
                }
                for index, name in enumerate(a for a in assets.split(",") if a)
            ],
            "body": 'Notes with "quotes", a brace { and a bracket [, a key '
            '"tag_name": "v99.0.0", "assets": [{"name": "jac-99.0.0-linux-x86_64"}], '
            "a tab\t, a newline\n and a backslash at the end\\",
        }
    )
json.dump(releases, open(out, "w"))
EOF
    cat > "${WORK}/server.py" <<'EOF'
import http.server
import json
import os
import sys
import urllib.parse

root = sys.argv[1]


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        with open(os.path.join(root, "requests.log"), "a") as log:
            log.write(self.path + "\n")
        url = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qs(url.query)
        releases = json.load(open(os.path.join(root, "releases.json")))
        # GitHub prints its JSON over many lines; a mirror may not.
        compact = os.path.exists(os.path.join(root, "compact"))

        def dump(value):
            if compact:
                return json.dumps(value, separators=(",", ":")).encode()
            return json.dumps(value, indent=2).encode()

        if url.path == "/api/releases":
            per = int(query.get("per_page", ["30"])[0])
            page = int(query.get("page", ["1"])[0])
            return self.reply(200, dump(releases[(page - 1) * per : page * per]))
        if url.path.startswith("/api/releases/tags/"):
            tag = url.path[len("/api/releases/tags/") :]
            for release in releases:
                if release["tag_name"] == tag and not release["draft"]:
                    return self.reply(200, dump(release))
            return self.reply(404, b'{"message": "Not Found"}')
        if url.path.startswith("/download/"):
            parts = url.path[len("/download/") :].split("/")
            path = os.path.join(root, "assets", *parts)
            if ".." not in parts and os.path.isfile(path):
                return self.reply(200, open(path, "rb").read())
        return self.reply(404, b'{"message": "Not Found"}')


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(root, "port.tmp"), "w") as port:
    port.write(str(server.server_address[1]))
os.rename(os.path.join(root, "port.tmp"), os.path.join(root, "port"))
server.serve_forever()
EOF
    # The platform is the case's, not the machine's.
    cat > "${STUBS}/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -m) echo "${FAKE_ARCH:-x86_64}" ;;
    *) echo "${FAKE_OS:-Linux}" ;;
esac
EOF
    # No uv: the installer's sweep of installs older versions made with it
    # must not reach the machine's own.
    printf '#!/bin/sh\nexit 0\n' > "${STUBS}/uv"
    chmod +x "${STUBS}/uname" "${STUBS}/uv"
}

REF_PLATFORMS="linux-x86_64 linux-aarch64 macos-aarch64"

# The assets a release's line names, for the platforms given.
ref_names() {
    local version="$1" p names=""
    shift
    for p in "$@"; do
        names="${names}jac-${version}-${p},jac-${version}-${p}.sha256,jac-${version}-${p}-jacpython,"
    done
    echo "${names}jac-${version}-admin-dist.tar.gz,jac-${version}-admin-dist.tar.gz.sha256"
}

jac_names() {
    local version="$1" p names=""
    shift
    for p in "$@"; do
        names="${names}jac-${version}-${p}.tar.gz,jac-${version}-${p}.tar.gz.sha256,"
    done
    echo "${names}jac-${version}-windows-x86_64.zip,jac-${version}-windows-x86_64.zip.sha256"
}

build_assets() {
    local p
    for p in $REF_PLATFORMS macos-x86_64; do
        reference_asset v0.40.1 0.40.1 "$p"
    done
    for p in $REF_PLATFORMS; do
        reference_asset v0.40.2 0.40.2 "$p"
        reference_asset v0.34.9 0.34.9 "$p"
        jac_asset jac-v0.70.0 0.70.0 "$p"
        jac_asset jac-v0.70.1 0.70.1 "$p"
    done
    jac_asset jac-v0.71.0-rc1 0.71.0-rc1 linux-x86_64
    jac_asset jac-v0.72.0 0.72.0 linux-x86_64
    # One version number under both kinds' tags.
    reference_asset v1.0.0 1.0.0 linux-x86_64
    jac_asset jac-v1.0.0 1.0.0 linux-x86_64
}

# The usual releases. Newest first: a draft and a prerelease of jac, then a
# reference-design release of an older line published last of all, then the
# newest reference design, published after the newest jac. What GitHub would
# call "latest" here is the reference design's, whichever way it is counted.
usual_releases() {
    # shellcheck disable=SC2086
    cat > "${FIX}/releases.spec" <<EOF
jac-v0.72.0||true|false|$(jac_names 0.72.0 linux-x86_64)
jac-v0.71.0-rc1|2026-03-10T00:00:00Z|false|true|$(jac_names 0.71.0-rc1 linux-x86_64)
v0.34.9|2026-03-05T00:00:00Z|false|false|$(ref_names 0.34.9 $REF_PLATFORMS)
v0.40.2|2026-03-01T00:00:00Z|false|false|$(ref_names 0.40.2 $REF_PLATFORMS)
jac-v0.70.1|2026-02-20T00:00:00Z|false|false|$(jac_names 0.70.1 $REF_PLATFORMS)
jac-v0.70.0|2026-02-01T00:00:00Z|false|false|$(jac_names 0.70.0 $REF_PLATFORMS)
v0.40.1|2026-01-10T00:00:00Z|false|false|$(ref_names 0.40.1 $REF_PLATFORMS macos-x86_64)
dev|2025-07-02T00:00:00Z|false|true|jac-dev-linux-x86_64,jac-dev-linux-x86_64.sha256,jac-dev-admin-dist.tar.gz
EOF
    python3 "${WORK}/mkreleases.py" "${FIX}/releases.spec" "${FIX}/releases.json"
}

start_server() {
    python3 "${WORK}/server.py" "$FIX" &
    SERVER_PID=$!
    local tries=0
    while [[ ! -f "${FIX}/port" ]]; do
        tries=$((tries + 1))
        if [[ $tries -gt 100 ]] || ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "the fixture server did not start" >&2
            exit 1
        fi
        sleep 0.1
    done
    BASE="http://127.0.0.1:$(cat "${FIX}/port")"
}

# --- Running the installer ---

new_home() {
    H="$(mktemp -d "${WORK}/home.XXXXXX")"
}

# Run the installer in the home $H. Its output lands in OUT, its status in RC.
run() {
    RC=0
    OUT="$(env -u GITHUB_TOKEN -u GH_TOKEN -u JAC_HOME -u JAC_BIN_DIR \
        HOME="$H" PATH="${AWK_DIR:+${AWK_DIR}:}${STUBS}:${PATH}" SHELL=/bin/bash \
        JAC_RELEASES_API="${BASE}/api" JAC_RELEASES_DOWNLOAD="${BASE}/download" \
        FAKE_OS="${FAKE_OS:-Linux}" FAKE_ARCH="${FAKE_ARCH:-x86_64}" \
        ${EXTRA_ENV:-} bash "$INSTALLER" "$@" 2>&1)" || RC=$?
}

ok() {
    PASSED=$((PASSED + 1))
}

fail() {
    FAILED=$((FAILED + 1))
    echo "FAIL: $1" >&2
    echo "--- installer output ---" >&2
    echo "${OUT:-}" >&2
    echo "------------------------" >&2
}

check() {
    local what="$1"
    shift
    if "$@"; then ok; else fail "$what"; fi
}

succeeded() { [[ $RC -eq 0 ]]; }
refused() { [[ $RC -ne 0 ]]; }
says() { [[ "$OUT" == *"$1"* ]]; }
says_once() { [[ "$(grep -c -- "$1" <<< "$OUT")" -eq 1 ]]; }
silent_on() { [[ "$OUT" != *"$1"* ]]; }
is_link() { [[ -L "$1" ]]; }
is_binary() { [[ -f "$1" && ! -L "$1" ]]; }
missing() { [[ ! -e "$1" && ! -L "$1" ]]; }
present() { [[ -e "$1" ]]; }
reports() { [[ "$("${H}/.local/bin/jac" --version 2>&1)" == *"$1"* ]]; }
marked() { [[ "$(cat "${H}/.local/bin/.jac-install" 2>/dev/null)" == "installed-by-jaseci-labs-install-script" ]]; }
nothing_installed() { missing "${H}/.local/bin/jac" && missing "${H}/.local/bin/.jac-install" && [[ -z "$(ls -A "${H}/.jac" 2>/dev/null)" ]]; }
# What the server was asked: mark_requests, then asked "<text>" for a request
# made since.
mark_requests() { LOG_MARK="$(wc -l < "${FIX}/requests.log")"; }
asked() { tail -n "+$((LOG_MARK + 1))" "${FIX}/requests.log" | grep -q -- "$1"; }

jac_is_installed() {
    local version="$1"
    is_link "${H}/.local/bin/jac" \
        && [[ "$(readlink "${H}/.local/bin/jac")" == "${H}/.jac/current/bin/jac" ]] \
        && [[ "$(readlink "${H}/.jac/current")" == "${H}/.jac/${version}" ]] \
        && [[ -d "${H}/.jac/${version}/abstractions" && -d "${H}/.jac/${version}/libraries" ]] \
        && missing "${H}/.local/bin/.jac-install" \
        && reports "jac ${version} ("
}

reference_is_installed() {
    local version="$1"
    is_binary "${H}/.local/bin/jac" && marked && reports "jac ${version} (reference design"
}

# --- The cases ---

case_default_install() {
    new_home
    run
    check "a bare install succeeds" succeeded
    check "a bare install is jac 0.70.1: not the draft, the prerelease, or the reference design published after it" jac_is_installed 0.70.1
    check "a bare install says what it installed" says "jac 0.70.1 installed"
    check "a first install replaces nothing" silent_on "Replacing"
}

case_reference_install() {
    new_home
    run --reference
    check "--reference succeeds" succeeded
    check "--reference is the reference design 0.40.2: not jac, and not the older line published after it" reference_is_installed 0.40.2
    check "--reference runs the binary's first-run setup" says "reference design 0.40.2: first-run setup"
    check "the reference design unpacks nothing under ~/.jac" missing "${H}/.jac"
}

case_switching() {
    new_home
    run
    mkdir -p "${H}/.jac"
    echo "complete -F _jac jac" > "${H}/.jac/completions.bash"
    run --reference
    check "the reference design installs over jac" succeeded
    check "the reference design replaced jac" reference_is_installed 0.40.2
    check "replacing jac is said in one line" says_once "Replacing jac 0.70.1"
    check "the unpacked jac release is gone" missing "${H}/.jac/0.70.1"
    check "the current link is gone" missing "${H}/.jac/current"
    check "what else is in ~/.jac stays" present "${H}/.jac/completions.bash"

    run
    check "jac installs over the reference design" succeeded
    check "jac replaced the reference design" jac_is_installed 0.70.1
    check "replacing the reference design is said in one line" says_once "Replacing the Jac reference design"

    run
    check "installing jac again succeeds" succeeded
    check "installing the same kind again replaces nothing" silent_on "Replacing"
}

case_version() {
    new_home
    run --version 0.70.0
    check "--version installs that jac release" jac_is_installed 0.70.0
    run --version v0.70.1
    check "--version takes a leading v" jac_is_installed 0.70.1
    check "an earlier jac release stays unpacked beside the new one" present "${H}/.jac/0.70.0/bin/jac"

    new_home
    run --reference --version 0.40.1
    check "--reference --version installs that reference-design release" reference_is_installed 0.40.1

    new_home
    run --version 0.71.0-rc1
    check "--version installs a prerelease when it is named" jac_is_installed 0.71.0-rc1

    new_home
    mark_requests
    run --version 0.40.1
    check "--version of a reference-design release is refused without --reference" refused
    check "--version of jac asks for the tag jac-v<version>" asked "/releases/tags/jac-v0.40.1"
    check "the refusal says jac has no such release" says "There is no release 0.40.1 of jac (no tag jac-v0.40.1)"
    check "the refusal names the reference design and how to get that release" says "bash -s -- --reference --version 0.40.1"
    check "a refused --version installs nothing" nothing_installed

    mark_requests
    run --reference --version 0.70.0
    check "--reference --version of a jac release is refused" refused
    check "--version of the reference design asks for the tag v<version>" asked "/releases/tags/v0.70.0"
    check "the refusal says the reference design has no such release" says "There is no release 0.70.0 of the Jac reference design (no tag v0.70.0)"
    check "the refusal names jac and how to get that release" says "bash -s -- --version 0.70.0"
    check "a refused --reference --version installs nothing" nothing_installed

    run --version 9.9.9
    check "a release that does not exist is refused" refused
    check "the refusal says there is no such release" says "There is no release 9.9.9 of jac"
    check "a release neither kind has names no other kind" silent_on "To install that"

    FAKE_OS=Darwin FAKE_ARCH=aarch64 run --version 0.71.0-rc1
    check "a jac release without this platform's archive is refused" refused
    check "the refusal says it holds no archive for the platform" says "Release jac-v0.71.0-rc1 holds no jac archive for macos-aarch64"

    FAKE_OS=Darwin FAKE_ARCH=x86_64 run --reference --version 0.40.2
    check "a release without this platform's binary is refused" refused
    check "the refusal says it was not built for the platform" says "Release v0.40.2 holds no reference-design binary for macos-x86_64"
}

case_uninstall() {
    new_home
    run --version 0.70.0
    run
    mkdir -p "${H}/.jac"
    echo "[hack]" > "${H}/.jac/hack.toml"
    run --uninstall
    check "--uninstall of jac succeeds" succeeded
    check "--uninstall removes the jac link" missing "${H}/.local/bin/jac"
    check "--uninstall removes every unpacked release" missing "${H}/.jac/0.70.0"
    check "--uninstall removes the newest unpacked release" missing "${H}/.jac/0.70.1"
    check "--uninstall removes the current link" missing "${H}/.jac/current"
    check "--uninstall leaves what else is in ~/.jac" present "${H}/.jac/hack.toml"
    check "--uninstall says so" says "Jac has been uninstalled"
    run --uninstall
    check "--uninstall with nothing installed says so" says "No Jac installation found"

    new_home
    run --reference
    run --uninstall
    check "--uninstall of the reference design succeeds" succeeded
    check "--uninstall removes the binary and its marker" nothing_installed
    check "--uninstall of the reference design says so" says "Jac has been uninstalled"

    new_home
    run
    run --uninstall
    check "--uninstall removes ~/.jac when nothing else is in it" missing "${H}/.jac"
}

case_missing_platform() {
    # An Intel Mac: jac has no build for it, the reference design had one.
    new_home
    FAKE_OS=Darwin FAKE_ARCH=x86_64 run
    check "jac on a platform it has no build for is refused" refused
    check "the refusal names the platform" says "No release of jac has a build for macos-x86_64"
    check "the refusal names the other kind" says "The Jac reference design has one (0.40.1)"
    check "the refusal says how to get the other kind" says "| bash -s -- --reference"
    check "nothing is installed for a platform without a build" nothing_installed

    FAKE_OS=Darwin FAKE_ARCH=x86_64 run --reference
    check "the reference design installs the newest release that has the platform" reference_is_installed 0.40.1
    check "it says the newest release has no build for the platform" says "The newest release, 0.40.2, has no build for macos-x86_64"

    # The other way round: no reference design for a platform jac has.
    grep -v -E '^v0\.(40|34)\.' "${FIX}/releases.spec" > "${FIX}/releases.spec.new"
    echo "v0.40.2|2026-03-01T00:00:00Z|false|false|$(ref_names 0.40.2 linux-x86_64 macos-aarch64)" >> "${FIX}/releases.spec.new"
    python3 "${WORK}/mkreleases.py" "${FIX}/releases.spec.new" "${FIX}/releases.json"
    new_home
    FAKE_ARCH=aarch64 run --reference
    check "the reference design on a platform it has no binary for is refused" refused
    check "the refusal names the platform (reference design)" says "No release of the Jac reference design has a binary for linux-aarch64"
    check "the refusal names jac" says "jac has one (0.70.1)"
    check "the refusal gives the plain command" says "main/scripts/install.sh | bash"
    check "the plain command carries no --reference" silent_on "bash -s -- --reference"
    check "nothing is installed (reference design)" nothing_installed
    FAKE_ARCH=aarch64 run
    check "jac installs on that platform" jac_is_installed 0.70.1
    usual_releases

    new_home
    FAKE_ARCH=riscv64 run
    check "an architecture nothing is built for is refused" says "Unsupported architecture: riscv64"
}

case_checksums() {
    local archive="${FIX}/assets/jac-v0.70.1/jac-0.70.1-linux-x86_64.tar.gz"
    local binary="${FIX}/assets/v0.40.2/jac-0.40.2-linux-x86_64"

    cp "${archive}.sha256" "${WORK}/saved.sha256"
    echo "0000000000000000000000000000000000000000000000000000000000000000  x" > "${archive}.sha256"
    new_home
    run
    check "a jac archive that fails its checksum is refused" refused
    check "the refusal says the checksum failed" says "Checksum verification failed"
    check "a failed checksum installs nothing" nothing_installed
    rm -f "${archive:?}.sha256"
    run
    check "a jac archive without a checksum is refused" says "refusing to install it unverified"
    check "a missing checksum installs nothing" nothing_installed
    cp "${WORK}/saved.sha256" "${archive}.sha256"

    cp "${binary}.sha256" "${WORK}/saved.sha256"
    echo "0000000000000000000000000000000000000000000000000000000000000000  x" > "${binary}.sha256"
    new_home
    run --reference
    check "a reference-design binary that fails its checksum is refused" refused
    check "the refusal says the checksum failed (reference design)" says "Checksum verification failed"
    check "a failed checksum installs nothing (reference design)" nothing_installed
    rm -f "${binary:?}.sha256"
    run --reference
    check "a reference-design binary without a checksum is refused" says "refusing to install it unverified"
    cp "${WORK}/saved.sha256" "${binary}.sha256"

    # A failed replacement leaves what was installed.
    new_home
    run --reference
    echo "0000000000000000000000000000000000000000000000000000000000000000  x" > "${archive}.sha256"
    run
    check "a failed install of the other kind is refused" refused
    check "a failed install of the other kind leaves the installed one" reference_is_installed 0.40.2
    cp "${WORK}/saved.sha256" "${binary}.sha256"
    echo "$(sha256_of "$archive")  jac-0.70.1-linux-x86_64.tar.gz" > "${archive}.sha256"
}

case_paging() {
    # More reference-design releases than a page holds, all newer than jac's.
    local i
    : > "${FIX}/releases.spec.new"
    for i in 35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1; do
        echo "v0.50.${i}|2026-04-01T00:00:00Z|false|false|$(ref_names "0.50.${i}" macos-aarch64)" >> "${FIX}/releases.spec.new"
    done
    cat "${FIX}/releases.spec" >> "${FIX}/releases.spec.new"
    python3 "${WORK}/mkreleases.py" "${FIX}/releases.spec.new" "${FIX}/releases.json"
    mark_requests
    new_home
    run
    check "jac is found on a later page of the listing" jac_is_installed 0.70.1
    check "the installer asked for the second page" asked "page=2"
    run --reference
    check "the reference design is found past releases without this platform" reference_is_installed 0.40.2
    check "it says newer releases have no build for the platform" says "The newest release, 0.50.35, has no build for linux-x86_64"
    usual_releases
}

case_tags() {
    # One version number released by both kinds: the tag says which is which.
    {
        echo "jac-v1.0.0|2026-05-02T00:00:00Z|false|false|$(jac_names 1.0.0 linux-x86_64)"
        echo "v1.0.0|2026-05-01T00:00:00Z|false|false|$(ref_names 1.0.0 linux-x86_64)"
        cat "${FIX}/releases.spec"
    } > "${FIX}/releases.spec.new"
    python3 "${WORK}/mkreleases.py" "${FIX}/releases.spec.new" "${FIX}/releases.json"
    new_home
    mark_requests
    run
    check "with one version under both tags, a bare install is jac" jac_is_installed 1.0.0
    check "jac is downloaded from its jac-v tag" asked "/download/jac-v1.0.0/jac-1.0.0-linux-x86_64.tar.gz"
    mark_requests
    run --reference
    check "with one version under both tags, --reference is the reference design" reference_is_installed 1.0.0
    check "the reference design is downloaded from its v tag" asked "/download/v1.0.0/jac-1.0.0-linux-x86_64"
    run --version 1.0.0
    check "--version takes jac from the jac-v tag" jac_is_installed 1.0.0
    run --reference --version 1.0.0
    check "--reference --version takes the reference design from the v tag" reference_is_installed 1.0.0

    # An asset under the other kind's tag is not that kind's release: an
    # archive under a v tag, a binary under a jac-v tag, both newer than all.
    {
        echo "v3.0.0|2026-06-02T00:00:00Z|false|false|$(jac_names 3.0.0 linux-x86_64)"
        echo "jac-v2.0.0|2026-06-01T00:00:00Z|false|false|$(ref_names 2.0.0 linux-x86_64)"
        cat "${FIX}/releases.spec"
    } > "${FIX}/releases.spec.new"
    python3 "${WORK}/mkreleases.py" "${FIX}/releases.spec.new" "${FIX}/releases.json"
    new_home
    run
    check "an archive under a v tag is not a jac release" jac_is_installed 0.70.1
    run --reference
    check "a binary under a jac-v tag is not a reference-design release" reference_is_installed 0.40.2
    usual_releases
}

case_compact_json() {
    touch "${FIX}/compact"
    new_home
    run
    check "jac installs from JSON on one line" jac_is_installed 0.70.1
    run --reference
    check "the reference design installs from JSON on one line" reference_is_installed 0.40.2
    run --version 0.70.0
    check "--version installs from JSON on one line" jac_is_installed 0.70.0
    rm -f "${FIX:?}/compact"
}

case_other_awks() {
    # Whichever awks this machine has besides the one `awk` names.
    local impl found
    for impl in gawk mawk nawk original-awk busybox; do
        found="$(command -v "$impl" || true)"
        if [[ -z "$found" ]]; then
            continue
        fi
        AWK_DIR="${WORK}/awk-${impl}"
        mkdir -p "$AWK_DIR"
        if [[ "$impl" == "busybox" ]]; then
            printf '#!/bin/sh\nexec "%s" awk "$@"\n' "$found" > "${AWK_DIR}/awk"
            chmod +x "${AWK_DIR}/awk"
        else
            ln -sf "$found" "${AWK_DIR}/awk"
        fi
        new_home
        run
        check "jac installs with ${impl} as awk" jac_is_installed 0.70.1
        run --reference
        check "the reference design installs with ${impl} as awk" reference_is_installed 0.40.2
        AWK_DIR=""
    done
}

case_options() {
    new_home
    run --help
    check "--help succeeds" succeeded
    check "--help names --reference" says "--reference"
    check "--help documents JAC_HOME" says "JAC_HOME"
    check "--help documents JAC_BIN_DIR" says "JAC_BIN_DIR"
    check "--help documents JAC_RELEASES_API" says "JAC_RELEASES_API"
    check "--help documents JAC_RELEASES_DOWNLOAD" says "JAC_RELEASES_DOWNLOAD"
    check "--help installs nothing" nothing_installed
    run --no-such-option
    check "an unknown option is refused" refused
    run --version
    check "--version without a version is refused" says "--version requires a version"

    EXTRA_ENV="JAC_HOME=${H}/opt/jac JAC_BIN_DIR=${H}/bin" run
    check "JAC_HOME and JAC_BIN_DIR are where jac goes" [ "$(readlink "${H}/bin/jac")" = "${H}/opt/jac/current/bin/jac" ]
    check "JAC_HOME holds the unpacked release" present "${H}/opt/jac/0.70.1/bin/jac"
    check "the default places stay empty" nothing_installed
    EXTRA_ENV="JAC_HOME=${H}/opt/jac JAC_BIN_DIR=${H}/bin" run --reference
    check "JAC_BIN_DIR is where the reference design goes" is_binary "${H}/bin/jac"
    check "the release under JAC_HOME is gone with the switch" missing "${H}/opt/jac/0.70.1"
    EXTRA_ENV="JAC_HOME=${H}/opt/jac JAC_BIN_DIR=${H}/bin" run --uninstall
    check "--uninstall honors JAC_BIN_DIR" missing "${H}/bin/jac"
}

main() {
    write_tools
    build_assets
    usual_releases
    start_server

    case_default_install
    case_reference_install
    case_switching
    case_version
    case_uninstall
    case_missing_platform
    case_checksums
    case_paging
    case_tags
    case_compact_json
    case_other_awks
    case_options

    OUT=""
    check "the installer never asked for releases/latest" [ "$(grep -c 'releases/latest' "${FIX}/requests.log")" = "0" ]

    echo "install.sh: ${PASSED} checks passed, ${FAILED} failed"
    [[ $FAILED -eq 0 ]]
}

main "$@"
