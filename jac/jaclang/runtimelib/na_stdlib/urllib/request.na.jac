"""Bundled native `urllib.request` -- libcurl (Mechanism F) floor + pure-Jac surface.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issues #6404 / #6940, Phase 3: transport + HTTP).
On the native (na) pathway `import from urllib.request { urlopen }` resolves to
this module through the shared bundled-stdlib resolver. Unlike a pure-Jac bundled
module (e.g. `os.path`, which the sv interpreter runs as ordinary Jac), this one
binds libcurl through the native FFI, so it cannot run under the sv/Python
interpreter: the sv reference is CPython's own `urllib.request`. The two are held
congruent by the loopback equivalence suite (`test_urllib_equivalence`), which
imports `urlopen` from CPython on sv and from this module on na.

Architecture (issue #6940). The security/perf-critical transport floor -- DNS,
TLS, HTTP/1.1, redirects, Range -- is **not** reimplemented here: it is libcurl,
reached through a thin native FFI (Mechanism F), exactly as CPython's `ssl`/
`http.client` ultimately lean on the system TLS + socket stack. libcurl abstracts
the per-OS TLS backend (SecureTransport on macOS, OpenSSL on Linux, Schannel on
Windows), so one binding covers all three native hosts. The `urlopen` API the
workload codes against is pure Jac (Mechanism B) layered on top, so the floor is
swappable (the deferred socket+ssl+http.client floor v2 under the same API)
without touching any program.

The libcurl easy handle writes the response body and response headers to two
temp files via libcurl's default `fwrite` callback (`CURLOPT_WRITEDATA` /
`CURLOPT_HEADERDATA` pointed at `FILE*`s), which this module then reads back
with the native `open(...).read()` builtin and parses into an `HTTPResponse`.
This keeps the FFI surface to a handful of stable C entry points and needs no
Jac<->C write callback.

Portability: **native-host-only** (Mechanism F over libcurl); a wasm target
emits a clean E5090 rather than silently breaking. Opaque C handles (`CURL*`,
`FILE*`) are carried as plain `int` (pointer-sized, never refcounted); C string
arguments are Jac `str`, which the FFI boundary lowers to their `char*` data
pointer. Response headers are kept as two parallel `list[str]` (name/value)
rather than a dict because the native pathway does not yet lower incremental
dict subscript-assignment.

Partial coverage (issue #6940 policy: ship the endpoints the workload needs,
expand over time). v1 implements `urlopen(url)` for `http`/`https` GET with
redirect-following, returning an `HTTPResponse` record (status, body length,
reason, url, body, headers). NOT yet covered (documented next slices):
`HTTPResponse` accessor methods (`read()` / `getheader()`) and cross-module
access to its `bytes`/`list` fields (only scalar `int` fields -- `status`,
`body_length` -- marshal across a native module boundary today); the effective
post-redirect URL (`geturl()`, via `curl_easy_getinfo(CURLINFO_EFFECTIVE_URL)` --
a variadic out-param read); a `Request` object (custom method / headers /
`Range`); POST `data`; `timeout`; and raising `HTTPError` on 4xx/5xx (v1 returns
the response with its `.status` set, matching libcurl semantics).
"""

import os;

# --- Mechanism F floor: libcurl easy interface (stable since libcurl 7.x). ---
# `curl_easy_setopt` is variadic in C (`CURL*, CURLoption, ...`); the trailing
# `*rest` marks it so the native FFI emits a `var_arg` declaration and the
# value lands per the platform psABI (on the stack for AArch64/AAPCS), where a
# fixed declaration would wrongly pass it in a register. A Jac `str` value
# (the URL) lowers to its `char*`; an `int` value (a `FILE*` handle or a long
# option like CURLOPT_FOLLOWLOCATION) is passed as-is.
import from curl {
    def curl_easy_init -> int;  def curl_easy_setopt(
        handle: int, option: int, *rest: int
    ) -> int;  def curl_easy_perform(handle: int) -> int;  def curl_easy_cleanup(
        handle: int
    ) -> None;
}

# --- libc: open the FILE* sinks curl streams into, and clean them up. ---
import from c {
    def fopen(path: str, mode: str) -> int;  def fclose(stream: int) -> int;  def remove(
        path: str
    ) -> int;
}

# CURLoption codes (curl/curl.h; ABI-stable). OBJECTPOINT options are +10000,
# LONG options are bare; both flow through the one variadic `setopt`.
glob _CURLOPT_WRITEDATA: int = 10001,
     _CURLOPT_URL: int = 10002,
     _CURLOPT_FOLLOWLOCATION: int = 52,
     _CURLOPT_HEADERDATA: int = 10029;

glob _CURLE_OK: int = 0;


"""A read HTTP response. Carries the data CPython's `http.client.HTTPResponse`
exposes via `.status` / `.read()` / `.getheader()` as plain fields:

  - `status`        : int   -- HTTP status code (e.g. 200), after redirects
  - `body_length`   : int   -- byte length of `body` (scalar mirror of `body`)
  - `reason`        : str   -- status reason phrase (e.g. "OK")
  - `url`           : str   -- the requested URL (not the effective post-redirect
                               URL; see the `geturl()` note in the next slices)
  - `body`          : bytes -- full response body, already buffered
  - `header_names`  : list[str] -- header names, lowercased
  - `header_values` : list[str] -- header values, parallel to `header_names`

v1 is a field record rather than carrying `read()` / `getheader()` accessor
methods: the native pathway does not yet marshal `bytes` / `list` object fields
or method results across a module boundary (only scalar `int` fields cross
today), so a caller in another native module reads `status` / `body_length`
directly. `body` / `header_*` are populated for in-module and JIT use; method
accessors and cross-module `bytes`/header access are the documented next slice
(issue #6940 partial-coverage policy). Header names are stored lowercased for
case-insensitive lookup."""
obj:pub HTTPResponse {
    has status: int,
        body_length: int,
        reason: str,
        url: str,
        body: bytes,
        header_names: list[str],
        header_values: list[str];
}


"""The system temp directory (honoring `$TMPDIR`), without a trailing slash."""
def _tmpdir -> str {
    d = os.getenv("TMPDIR");
    if len(d) == 0 {
        return "/tmp";
    }
    while len(d) > 1 and d[len(d) - 1] == "/" {
        d = d[:len(d) - 1];
    }
    return d;
}


"""Open `url` (http/https GET) and return an `HTTPResponse`.

Follows redirects (like urllib's default). The transport -- DNS, TLS, HTTP -- is
libcurl; this shim only drives the easy handle and parses the result. Raises on a
transport-level failure (DNS/connect/TLS/protocol error), mirroring urllib's
`URLError`; an HTTP error *status* (4xx/5xx) is returned on the response, not
raised, in v1 (see module docstring)."""
def:pub urlopen(url: str) -> HTTPResponse {
    h = curl_easy_init();
    if h == 0 {
        raise Exception("urlopen: curl_easy_init failed");
    }
    # Per-handle temp paths (the handle pointer is unique among live requests).
    stem = _tmpdir() + "/jac_urlopen_" + str(h);
    body_path = stem + ".body";
    hdr_path = stem + ".hdr";
    body_fp = fopen(body_path, "wb");
    hdr_fp = fopen(hdr_path, "wb");
    # A NULL FILE* would make libcurl's default writer fall back to stdout
    # (silently dumping the body) and would make fclose(NULL) undefined
    # behaviour, so bail out before wiring the handle up. fopen returns a
    # `char*`-shaped pointer (reusing the compiler's libc `fopen` declaration),
    # so the failure sentinel is a null pointer, tested with `is None`.
    if body_fp is None or hdr_fp is None {
        if body_fp is not None {
            fclose(body_fp);
        }
        if hdr_fp is not None {
            fclose(hdr_fp);
        }
        curl_easy_cleanup(h);
        remove(body_path);
        remove(hdr_path);
        raise Exception("urlopen: cannot open temp file under " + _tmpdir());
    }

    curl_easy_setopt(h, _CURLOPT_URL, url);
    curl_easy_setopt(h, _CURLOPT_WRITEDATA, body_fp);
    curl_easy_setopt(h, _CURLOPT_HEADERDATA, hdr_fp);
    curl_easy_setopt(h, _CURLOPT_FOLLOWLOCATION, 1);

    rc = curl_easy_perform(h);

    fclose(body_fp);
    fclose(hdr_fp);
    curl_easy_cleanup(h);

    if rc != _CURLE_OK {
        remove(body_path);
        remove(hdr_path);
        raise Exception("urlopen: transport error (curl code " + str(rc) + ")");
    }

    # Read curl's captured output back. The paths are locals (the builtin
    # `open()` lowers a local/computed path; a bare str *parameter* does not yet).
    hf = open(hdr_path, "r");
    hdr_text = hf.read();
    hf.close();
    bf = open(body_path, "rb");
    body = bf.read();
    bf.close();
    remove(body_path);
    remove(hdr_path);

    # Parse the captured header text. curl writes raw HTTP bytes with CRLF line
    # endings; the header file is read as text and split on "\n", so each line
    # keeps a trailing "\r" that `rstrip("\r")` strips (this also means an
    # obs-fold continuation or a stray bare "\r" inside a value is normalized
    # away -- acceptable for the header set this v1 surfaces). Redirects emit one
    # header block per hop; the FINAL block (after the last `HTTP/` status line)
    # is what urllib exposes, so scan to the last status line, then collect its
    # headers.
    lines = hdr_text.split("\n");
    start: int = 0;
    scan: int = 0;
    for raw in lines {
        if raw.rstrip("\r").startswith("HTTP/") {
            start = scan;
        }
        scan += 1;
    }
    status: int = 0;
    reason: str = "";
    status_line = lines[start].rstrip("\r");
    sp1 = status_line.find(" ");
    if sp1 != -1 {
        after = status_line[sp1 + 1:];
        sp2 = after.find(" ");
        if sp2 == -1 {
            status = int(after);
        } else {
            status = int(after[:sp2]);
            reason = after[sp2 + 1:];
        }
    }
    names: list[str] = [];
    values: list[str] = [];
    j: int = start + 1;
    while j < len(lines) {
        line = lines[j].rstrip("\r");
        if len(line) == 0 {
            j += 1;
            continue;
        }
        colon = line.find(":");
        if colon != -1 {
            names.append(line[:colon].strip().lower());
            values.append(line[colon + 1:].strip());
        }
        j += 1;
    }
    # `url` is the REQUESTED url, not the effective post-redirect url. CPython's
    # `geturl()` returns the final landing url; recovering it here needs
    # curl_easy_getinfo(CURLINFO_EFFECTIVE_URL, &char*) -- a variadic out-param
    # read -- which is a documented next slice (see the module docstring).
    return HTTPResponse(
        status=status,
        body_length=len(body),
        reason=reason,
        url=url,
        body=body,
        header_names=names,
        header_values=values
    );
}
