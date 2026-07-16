"""Native startup-seam regression: decode of a managed start_result.

Root cause this guards (PLAN.md §5.3/§5.4, Phase 4): native `str(any)` on a
decoded JSON value returned the value's *tag* (e.g. "2"), not the underlying
scalar, so `bridge_schema._require_schema` rejected every real start_result as a
schema_id mismatch. The host then treated the post-side-effect decode failure as
"nothing started", marked workers safe unconditionally, and finalized over a live
`_legacy_feed` thread — hanging `jpy_Py_Finalize`.

The correct seam is:

    managed start_result JSON
        -> native bridge decoder
        -> startup cleanup / finalization gate

This file pins both halves:
  * a NATIVE-COMPILED selftest that decodes a real start_result (Python/static
    tests cannot see native `any` behavior), and
  * source guards that the decoder uses the isinstance+assign coercions and that
    the host's finalization gate rides on runtime-confirmed quiescence, not
    start.ok or successful response decoding.
"""

import os;
import re;
import sys;
import subprocess;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def _na_dir -> Path {
    return Path(tui_shared.__file__).resolve().parent.parent / "ai_tui_na";
}


def _jac_bin -> str | None {
    pkg_root = Path(tui_shared.__file__).resolve().parent.parent;
    return getattr(tui_shared, "_resolve_jac_build_bin")(str(pkg_root));
}


def _selftest_binary(na_dir: Path) -> Path {
    return na_dir / "bin" / "selftest_start_decode";
}


def _selftest_stale(na_dir: Path) -> bool {
    binary = _selftest_binary(na_dir);
    if not binary.is_file() {
        return True;
    }
    bin_mtime = binary.stat().st_mtime;
    # Rebuild if the entry or any module in its import closure is newer.
    for name in ("selftest_start_decode.na.jac", "bridge_schema.na.jac") {
        src = na_dir / name;
        if src.is_file() and src.stat().st_mtime > bin_mtime {
            return True;
        }
    }
    return False;
}


def _build_selftest(na_dir: Path, jac: str) {
    subprocess.run(
        [
            jac,
            "nacompile",
            "selftest_start_decode.na.jac",
            "-o",
            "bin/selftest_start_decode"
        ],
        cwd=str(na_dir),
        check=True,
        capture_output=True,
    );
}


def _run_selftest(na_dir: Path) -> str {
    proc = subprocess.run(
        [str(_selftest_binary(na_dir))], capture_output=True, check=True
    );
    return proc.stdout.decode("utf-8", errors="replace");
}


def _strip_comments(text: str) -> str {
    # Drop `# ...` to end-of-line so the regex guards below do not trip on
    # comments that quote the old buggy `str(...)` pattern for explanation.
    out: list[str] = [];
    for line in text.split("\n") {
        i = line.find("#");
        if i >= 0 {
            line = line[:i];
        }
        out.append(line);
    }
    return "\n".join(out);
}


def _starts_with_any(lines: list[str], prefix: str) -> bool {
    for ln in lines {
        if ln.startswith(prefix) {
            return True;
        }
    }
    return False;
}


test "native start_result decode succeeds and catches str-any regression" {
    jac = _jac_bin();
    if jac is None {
        pytest.skip("jac native toolchain not built (run zig build in jac/)");
    }
    na_dir = _na_dir();
    if _selftest_stale(na_dir) {
        _build_selftest(na_dir, jac);
    }
    output = _run_selftest(na_dir);

    lines: list[str] = [];
    for ln in output.splitlines() {
        if ln.strip() {
            lines.append(ln);
        }
    }
    assert lines , f"selftest emitted no output:\n{output}";

    failures: list[str] = [];
    for ln in lines {
        if ln.startswith("FAIL ") {
            failures.append(ln);
        }
    }
    assert not failures , (
        f"{len(failures)} native decode assertion(s) failed:\n" + "\n".join(failures) + f"\nfull output:\n{output}"
    );
    # The core regression: a real start_result must decode in native code.
    assert _starts_with_any(lines, "PASS na_decode_start_result_ok") , output;
    assert _starts_with_any(lines, "PASS na_start_schema_id_matches") , output;
    assert _starts_with_any(lines, "PASS na_start_epoch") , output;
    # Malformed responses must still raise (decoder stays strict).
    assert _starts_with_any(lines, "PASS na_malformed_schema_raises") , output;
}


test "native bridge decoder extracts typed values via isinstance plus assign" {
    na_dir = _na_dir();
    schema_src = (na_dir / "bridge_schema.na.jac").read_text();
    client_src = (na_dir / "embed_session_client.na.jac").read_text();
    apply_src = (na_dir / "session_apply.na.jac").read_text();

    # Canonical coercion helpers exist in the bridge schema module.
    assert "def as_str(" in schema_src , "bridge_schema must define as_str()";
    assert "def as_int(" in schema_src , "bridge_schema must define as_int()";
    assert "def as_bool(" in schema_src , "bridge_schema must define as_bool()";
    # The decoder uses them (regression: it used str(data.get(...))).
    assert "as_str(data.get(\"schema_id\"" in schema_src;
    assert "as_str(data.get(\"kind\"" in schema_src;

    # The session client imports and uses the helpers; the broken local
    # _as_bool/_as_int (which called str(any)) are gone.
    assert "as_str," in client_src
    and "as_int," in client_src
    and "as_bool," in client_src;
    assert "def _as_bool" not in client_src , "local _as_bool must be removed";
    assert "def _as_int" not in client_src , "local _as_int must be removed";
    assert "as_str(data.get(\"session_id\"" in client_src;
    assert "as_int(data.get(\"epoch\"" in client_src;

    # session_apply consumes decoded mutations/snapshots through the helpers too.
    assert "as_str(m.get(\"kind\"" in apply_src;
    assert "return as_int(raw, 1);" in apply_src;

    # Catch-all: no str() coercion of decoded .get() values remains anywhere in
    # the native decode path (comments stripped so explanatory str(...) quotes
    # don't trip the guard).
    pat = r"\bstr\(\s*[^)]*\.get\(";
    assert not re.search(pat, _strip_comments(schema_src)) , (
        "bridge_schema: decoded bridge value coerced with str(...) — use as_str() "
        "instead (native str(any) returns the tag, not the scalar)"
    );
    assert not re.search(pat, _strip_comments(client_src)) , (
        "embed_session_client: decoded bridge value coerced with str(...) — use as_str()"
    );
    assert not re.search(pat, _strip_comments(apply_src)) , (
        "session_apply: decoded bridge value coerced with str(...) — use as_str()"
    );
}


test "start is a side-effecting transaction with bounded cleanup on decode failure" {
    na_dir = _na_dir();
    client_src = (na_dir / "embed_session_client.na.jac").read_text();

    # After the managed call executes, both failure branches (managed ok=false
    # AND decode exception) route through bounded dispose-based cleanup rather
    # than implying "nothing started".
    assert "def _cleanup_started_runtime" in client_src , (
        "EmbedSessionClient must encapsulate post-side-effect cleanup"
    );
    assert "self._cleanup_started_runtime(reason=\"bad_start_result\")" in client_src , (
        "decode failure after managed startup must trigger bounded cleanup, "
        "not be treated as nothing started"
    );
    # Cleanup derives worker safety from runtime-confirmed quiescence (dispose),
    # never from start.ok.
    assert "self.dispose(reason=reason, deadline_ms=1000)" in client_src;
}


test "host finalization gate rides on worker quiescence not start ok" {
    na_dir = _na_dir();
    host_src = (na_dir / "host_embed.na.jac").read_text();

    # Regression: the start-failure path used to call mark_workers_safe(True)
    # unconditionally, finalizing over a live _legacy_feed thread. The gate must
    # now be finalize_if_safe() driven by runtime-confirmed quiescence only.
    assert "embed.mark_workers_safe(True)" not in host_src , (
        "host start-failure path must not unconditionally mark workers safe; "
        "gate finalization on dispose-confirmed quiescence"
    );
    # The successful-quit teardown still disposes before finalizing.
    assert "mark_workers_safe(not disp2.timed_out)" in host_src;
    assert "finalize_if_safe" in host_src;
}
