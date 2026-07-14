# Phase S, Track B — borrowed-view ownership conformance suite.  Exercises the
# `jac-bridge-view` reference crate, the ONLY crate carrying a `#[jac(borrowed)]`
# return: `Doc::peek(&self) -> Peek` mints a live, NON-owning view into `Doc`'s
# heap `i64` (the `Peek` holds a RAW pointer into the owner's allocation).
#
# The ownership contract keeps that pointer sound at the HANDLE layer: minting a
# borrowed view RETAINS the owner handle (rc+1), so the owner's box — and the
# `Box<i64>` it owns — physically cannot be freed while any view is live.  The
# view's `close()` releases the owner (a decref under Track A); the allocation is
# freed exactly once, when the last reference drops.  The retain is LOAD-BEARING:
# were it absent, closing the owner would free the `Box<i64>` and `Peek::read`
# would read freed memory (verified out-of-band — a de-retained build reads
# garbage, not the written value).
#
# Idiom matches aliasing_conformance.jac: synthesize the na wrapper from the
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


glob VIEW_SO = bridge_so("view"),
     SHIM = llvm_shim();


# ---------------------------------------------------------------------------
# 1. RC-pin (DEFENDED): close the OWNER while a borrowed view is live, then read
#    and close the view.  The view retained the owner on mint, so the owner's
#    close() is only a decref (rc 2 -> 1): the heap value stays alive, the view
#    reads the (mutated) value cleanly, and the final view close() drops the last
#    reference (rc 1 -> 0), freeing the object exactly once.  No abort, no UAF.
# ---------------------------------------------------------------------------
test "borrowed view RC-pins its owner: reads live after the owner closes" {
    if skip_gate(VIEW_SO, SHIM) {
        return;
    }
    src = synthesize_source(VIEW_SO) + "\nwith entry {\n" + "    d = Doc(5);\n" + "    p = d.peek();\n" + "    d.set_(9);\n"  # mutate through the owner -> 9
     + "    d.close();\n"  # decref owner rc 2->1; heap alive via the view
     + "    print(str(p.read()));\n"  # reads the live, mutated value -> 9
     + "    p.close();\n"  # decref rc 1->0; freed exactly once
     + "    print(" + jac_str("survived") + ");\n" + "}\n";
    td = tempfile.mkdtemp();
    try {
        binp = nacompile_in_dir(src, td, "view_rcpin.na.jac", "view_rcpin", SHIM);
        out = run_binary(binp, VIEW_SO);
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
# 2. Ordinary lifetime: close the VIEW first (releasing the owner retain), then
#    keep using the owner.  The owner is still live (its own reference remains),
#    mutations are observed, and closing it frees the object exactly once.
# ---------------------------------------------------------------------------
test "closing a borrowed view first leaves the owner fully usable" {
    if skip_gate(VIEW_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> str {",
        "    d = Doc(3);",
        "    p = d.peek();",
        "    seen = str(p.read());",  # -> 3
        "    p.close();",  # release the owner retain (rc 2->1)
        "    d.set_(7);",
        "    seen = seen + " + jac_str(",") + " + str(d.get());",  # owner still alive -> 7
        "    d.close();",  # rc 1->0
        "    return seen;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("normal = ") + " + _f());",
        "}"
    ];
    na = run_na_probe(
        VIEW_SO, probe, "view_normal.na.jac", "view_normal", strip_blank=True
    );
    assert na == ["normal = 3,7"];
}


# ---------------------------------------------------------------------------
# 3. Idempotent double-close of a borrowed view: the redundant second close is a
#    no-op via the wrapper's __closed guard, so the owner is decref'd exactly
#    once (rc does not underflow) and the process exits cleanly.
# ---------------------------------------------------------------------------
test "double-closing a borrowed view is idempotent (no owner over-release)" {
    if skip_gate(VIEW_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> int {",
        "    d = Doc(42);",
        "    p = d.peek();",
        "    v = p.read();",  # -> 42
        "    p.close();",
        "    p.close();",  # redundant: no-op, no second owner decref
        "    d.close();",
        "    return v;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("dbl = ") + " + str(_f()));",
        "}"
    ];
    na = run_na_probe(VIEW_SO, probe, "view_dbl.na.jac", "view_dbl", strip_blank=True);
    assert na == ["dbl = 42"];
}
