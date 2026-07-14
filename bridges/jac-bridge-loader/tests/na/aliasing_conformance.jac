# Phase 0 aliasing + reentrancy conformance suite (Lanes Plan, tasks 0.0.2 /
# 0.2.1 / 0.2.2).  Exercises the `jac-bridge-reentrant` reference crate, the ONLY
# crate carrying the two genuinely-dangerous opaque shapes:
#
#   * Cell::apply(&mut self, cb) — a &mut-self method that invokes a JacCallback
#     while its exclusive borrow is live (the reentrancy hazard).
#   * Cell::alias(&self) -> CellAlias — mints a SECOND opaque wrapper that shares
#     the SAME underlying heap object as its receiver (the aliasing hazard).
#
# Idiom matches adversarial_conformance.jac / owning_conformance.jac: synthesize
# the na wrapper from the crate's .jac_bridge metadata, append an na probe,
# nacompile+run it, and diff against expected output.  A clean status-error
# surfaces as a normal exit plus an error line; a use-after-free / double-free
# surfaces as a nonzero process exit that run_binary raises on.
#
# ABI FINDING (see the crate's lib.rs header): the natural spelling
# `Cell::alias(&self) -> Self` is SILENTLY SKIPPED by the na loader — because Cell
# has a constructor, the synthesized wrapper cannot carry both the real
# `init(v: int)` and the adopt-ctor `init(raw: int)` at the same arity (an "na
# adopt-ctor signature clash", _synth.jac render()).  A method may only return an
# opaque wrapper of a CONSTRUCTOR-LESS type, so the alias view is its own type
# `CellAlias`, reachable only via Cell::alias.  Two Jac wrappers, one object.
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


glob REENTRANT_SO = bridge_so("reentrant"),
     SHIM = llvm_shim();


# ---------------------------------------------------------------------------
# 1. Reentrancy: a callback that re-enters a &mut-self method on the same handle
#    while the outer &mut borrow is live is two live &mut T -> instant UB.  The
#    per-handle busy guard (0.2.2) turns the second entry into a status-coded
#    error the loader raises as a catchable Jac exception.  DEFENDED.
# ---------------------------------------------------------------------------
test "reentrant method call yields a clean status error, not UB" {
    if skip_gate(REENTRANT_SO, SHIM) {
        return;
    }
    # cb re-enters c.bump() (a &mut method) during c.apply()'s live &mut borrow.
    probe = [
        "def _reentry() -> str {",
        "    c = Cell(0);",
        "    marker = \"NO-ERROR\";",
        "    try {",
        "        c.apply(lambda (m: str) -> str : str(c.bump()));",
        "    } except Exception as e {",
        "        marker = \"reentrant-error\";",
        "    }",
        "    c.close();",
        "    return marker;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("reentry = ") + " + _reentry());",
        "}"
    ];
    na = run_na_probe(
        REENTRANT_SO,
        probe,
        "alias_reentrant.na.jac",
        "alias_reentrant",
        strip_blank=True
    );
    # Clean exit (no crash) AND the error was catchable at the Jac level.
    assert na == ["reentry = reentrant-error"];
}


# ---------------------------------------------------------------------------
# 2. Aliasing (positive): Cell::alias mints a SECOND wrapper (a CellAlias) over
#    the SAME underlying object.  A mutation through the Cell is visible through
#    the alias, proving both wrappers point at one live object — the 0.0.2
#    construction the aliasing-defense gate needs.  (We neutralize the alias
#    wrapper before teardown so the shared slot is freed exactly once; letting
#    both wrappers' __del__ run is precisely the double-free exercised in test 3.)
# ---------------------------------------------------------------------------
test "alias mints a second wrapper sharing one underlying object" {
    if skip_gate(REENTRANT_SO, SHIM) {
        return;
    }
    probe = [
        "def _share() -> int {",
        "    c = Cell(7);",
        "    a = c.alias();",
        "    c.bump();",  # mutate through the Cell -> 8
        "    seen = a.get();",  # observed through the alias -> 8 iff shared
        # Detach the alias so only the Cell frees the shared slot at close.
        "    a.__handle = 0;",
        "    a.__closed = True;",
        "    c.close();",
        "    return seen;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("shared = ") + " + str(_share()));",
        "}"
    ];
    na = run_na_probe(
        REENTRANT_SO, probe, "alias_share.na.jac", "alias_share", strip_blank=True
    );
    assert na == ["shared = 8"];
}


# ---------------------------------------------------------------------------
# 3. Aliasing (DEFENDED, Phase S): TWO live wrappers over ONE object, close one,
#    then use/close the other.  Before Phase S this was "real UB today" — the two
#    wrappers each owned a raw `Box<i64>` smuggled through a `usize`, so closing
#    the Cell freed the shared i64 and the alias became a dangling double-owner
#    (use-after-free on get, double-free on close), aborting the process.
#
#    Phase S rewrote the reference crate to hold the counter behind an
#    `Arc<Mutex<i64>>` and made `alias` clone the `Arc` (honestly shared
#    ownership), so closing the Cell drops only its clone: the counter stays
#    alive for the alias, `a.get()` reads it cleanly, and `a.close()` drops the
#    last clone, freeing the counter exactly once.  No abort.  This is the flip
#    the old NOTE anticipated ("reference-counted handles so the object outlives
#    every wrapper").
# ---------------------------------------------------------------------------
test "closing one aliased wrapper leaves the other valid (aliasing defended by RC)" {
    if skip_gate(REENTRANT_SO, SHIM) {
        return;
    }
    src = synthesize_source(REENTRANT_SO) + "\nwith entry {\n" + "    c = Cell(5);\n" + "    a = c.alias();\n" + "    c.close();\n"  # drops the Cell's Arc clone; counter alive via `a`
     + "    print(str(a.get()));\n"  # reads the still-live shared counter -> 5
     + "    a.close();\n"  # drops the last clone; counter freed exactly once
     + "    print(" + jac_str("survived") + ");\n" + "}\n";
    td = tempfile.mkdtemp();
    try {
        binp = nacompile_in_dir(src, td, "alias_uaf.na.jac", "alias_uaf", SHIM);
        # A clean run (no abort) proves the aliasing double-free is defended: the
        # alias reads the live counter after the Cell closes, and the final close
        # frees it exactly once.
        out = run_binary(binp, REENTRANT_SO);
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
    lines = [
        ln
        for ln in out.splitlines()
        if ln.strip()
    ];
    assert lines == ["5", "survived"];
}


# ---------------------------------------------------------------------------
# 4. Shared alias survives independent close of the originator, AND a redundant
#    double-close is idempotent (Phase S, Track A).  Closes the Cell first, keeps
#    mutating through the alias (the counter is still live), then closes the alias
#    twice — the second close is a no-op via the wrapper's __closed guard, and the
#    process exits cleanly (the RC'd inner reaches zero exactly once).
# ---------------------------------------------------------------------------
test "shared alias outlives closed originator; double-close is idempotent" {
    if skip_gate(REENTRANT_SO, SHIM) {
        return;
    }
    probe = [
        "def _outlive() -> int {",
        "    c = Cell(10);",
        "    a = c.alias();",
        "    c.close();",  # originator gone; alias keeps the counter alive
        "    a.bump();",  # mutate through the surviving alias -> 11
        "    seen = a.get();",  # -> 11
        "    a.close();",
        "    a.close();",  # redundant double-close: idempotent, no abort
        "    return seen;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("outlive = ") + " + str(_outlive()));",
        "}"
    ];
    na = run_na_probe(
        REENTRANT_SO, probe, "alias_outlive.na.jac", "alias_outlive", strip_blank=True
    );
    assert na == ["outlive = 11"];
}
