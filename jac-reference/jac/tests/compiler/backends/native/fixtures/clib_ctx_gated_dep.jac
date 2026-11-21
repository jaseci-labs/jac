"""Dependency whose module-level clib import names a library that does not
exist on any machine. If it ever reaches the native link set the artifact
cannot link, which is exactly the failure this fixture set guards against."""

import from "/nonexistent/libctxgated.so.9" { def ctx_gated_probe(n: i64) -> i64;  }

def:pub gated_call(n: int) -> int {
    return ctx_gated_probe(i64(n));
}
