# Phase 1.2.4 — self-identity ownership conformance suite.  Exercises the
# `jac-bridge-identity` reference crate, the ONLY crate carrying a `&Self` return:
# `Node::alias(&self) -> &Self` hands back a SECOND handle onto the receiver's own
# box (not a fresh object).
#
# The self-identity contract keeps the two co-owning wrappers sound at the HANDLE
# layer.  The macro lowers the `&Self` return to the receiver's own handle integer
# (no fresh `Box::into_raw`), so the returned handle `rh` physically equals
# `self.__handle`.  The na loader adopts it and, seeing that runtime equality,
# RETAINS the box (rc 1 -> 2).  Each wrapper's `close()` is then a decref; the box
# — and its inner `Node` — drops exactly once, when the last handle releases
# (rc -> 0).  The retain is LOAD-BEARING and CHECKED: it fires only because
# `rh == self.__handle` is true at runtime, never on an author's say-so.  Were it
# absent, closing the original would free the box and the alias would read freed
# memory; were `alias` instead a fresh box, the retain would leak it (rc 2 -> 1,
# never 0) — the failure the retired `#[jac(shared)]` annotation invited.
#
# Idiom matches borrowed_conformance.jac: synthesize the na wrapper from the
# crate's .jac_bridge metadata, append an na probe, nacompile+run it, and diff
# against expected output.  A use-after-free surfaces as a garbage read or a
# nonzero process exit; a clean run with the correct value proves the RC-pin.
import os;
import tempfile;
import shutil;
import from _harness {
    bridge_so,
    jac_str,
    llvm_shim,
    run_na_probe,
    skip_gate,
    synthesize_source,
    nacompile_in_dir,
    run_binary
}


glob IDENTITY_SO = bridge_so("identity"),
     SHIM = llvm_shim();


# ---------------------------------------------------------------------------
# 1. RC-pin (DEFENDED): close the ORIGINAL while its alias is live, then read and
#    close the alias.  The alias retained the shared box on mint, so the original's
#    close() is only a decref (rc 2 -> 1): the value stays alive, the alias reads
#    the (mutated) value cleanly, and the final alias close() drops the last
#    reference (rc 1 -> 0), freeing the object exactly once.  No abort, no UAF.
# ---------------------------------------------------------------------------
test "self-identity alias RC-pins its box: reads live after the original closes" {
    if skip_gate(IDENTITY_SO, SHIM) {
        return;
    }
    src = synthesize_source(IDENTITY_SO) + "\nwith entry {\n" + "    reg = Registry();\n" + "    n = reg.make(5);\n" + "    a = n.alias();\n"  # a co-owns n's box; loader retains rc 1->2
     + "    n.set_(9);\n"  # mutate through the original -> 9
     + "    n.close();\n"  # decref rc 2->1; box alive via the alias
     + "    print(str(a.get()));\n"  # reads the live, mutated value -> 9
     + "    a.close();\n"  # decref rc 1->0; freed exactly once
     + "    print(" + jac_str("survived") + ");\n" + "}\n";
    td = tempfile.mkdtemp();
    try {
        binp = nacompile_in_dir(
            src, td, "identity_rcpin.na.jac", "identity_rcpin", SHIM
        );
        out = run_binary(binp, IDENTITY_SO);
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
    lines = [
        ln
        for ln in out.splitlines()
        if ln.strip()
    ];
    assert lines == ["9", "survived"];
}


# ---------------------------------------------------------------------------
# 2. Ordinary lifetime: close the ALIAS first (releasing its share), then keep
#    using the original.  The original is still live (its own reference remains),
#    mutations are observed, and closing it frees the object exactly once.
# ---------------------------------------------------------------------------
test "closing the alias first leaves the original fully usable" {
    if skip_gate(IDENTITY_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> str {",
        "    reg = Registry();",
        "    n = reg.make(3);",
        "    a = n.alias();",
        "    seen = str(a.get());",  # -> 3
        "    a.close();",  # release the alias's share (rc 2->1)
        "    n.set_(7);",
        "    seen = seen + " + jac_str(",") + " + str(n.get());",  # original still alive -> 7
        "    n.close();",  # rc 1->0
        "    return seen;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("normal = ") + " + _f());",
        "}"
    ];
    na = run_na_probe(
        IDENTITY_SO,
        probe,
        "identity_normal.na.jac",
        "identity_normal",
        strip_blank=True
    );
    assert na == ["normal = 3,7"];
}


# ---------------------------------------------------------------------------
# 3. Idempotent double-close of an alias: the redundant second close is a no-op via
#    the wrapper's __closed guard, so the shared box is decref'd exactly once (rc
#    does not underflow) and the process exits cleanly.
# ---------------------------------------------------------------------------
test "double-closing an alias is idempotent (no shared-box over-release)" {
    if skip_gate(IDENTITY_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> int {",
        "    reg = Registry();",
        "    n = reg.make(42);",
        "    a = n.alias();",
        "    v = a.get();",  # -> 42
        "    a.close();",
        "    a.close();",  # redundant: no-op, no second decref
        "    n.close();",
        "    return v;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("dbl = ") + " + str(_f()));",
        "}"
    ];
    na = run_na_probe(
        IDENTITY_SO, probe, "identity_dbl.na.jac", "identity_dbl", strip_blank=True
    );
    assert na == ["dbl = 42"];
}
