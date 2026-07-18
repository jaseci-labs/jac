# Handle-soundness lane — ctor-bearing adopt-shell conformance suite. Exercises
# the `jac-bridge-adopt` reference crate, the ONLY crate whose bridge returns a
# CONSTRUCTOR-BEARING opaque type from a method: `Snapshot` has its own `new(v)`
# yet is also produced by `Counter::snapshot(&self) -> Snapshot`.
#
# Because `Snapshot`'s wrapper `init(v: int)` slot is taken by its real ctor, the
# adopt path cannot reuse `init(raw)` the way a constructor-LESS "adoptable" type
# does. The synth instead emits a static shell
#   static def _adopt(raw) { s = Snapshot.__new__(Snapshot); s.__handle = raw; ... }
# and `Counter::snapshot` returns `Snapshot._adopt(rh)`. That shell RENDERED
# before but did NOT native-compile: NaIRGenPass could not lower `T.__new__(T)`,
# so the method demoted to Python-only. With `__new__` lowering in place these
# probes nacompile+run — the end-to-end proof of that fix through a real .so.
# (The compiler-unit guard is jac/tests/compiler/passes/native/
# test_native_obj_new_adopt.jac; this drives the SYNTHESIZED shell.)
#
# `snapshot` returns an OWNED value (a fresh Box::into_raw), distinct from the
# receiver's box, so no self-identity retain is involved (that is the
# `&self -> &Self` lane); each wrapper owns its box and frees exactly once.
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob ADOPT_SO = bridge_so("adopt"),
     SHIM = llvm_shim();


# ---------------------------------------------------------------------------
# 1. Adopt round-trips a real handle: `snapshot()` allocates the wrapper via
#    Snapshot.__new__ (no init), writes the returned handle, and `value()` reads
#    the captured number back through it. Proves the `_adopt` shell lowers and the
#    adopted wrapper is a live, usable handle.
# ---------------------------------------------------------------------------
test "snapshot() adopts a ctor-bearing handle that reads back its value" {
    if skip_gate(ADOPT_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> int {",
        "    c = Counter(41);",
        "    s = c.snapshot();",
        "    v = s.value();",
        "    s.close();",
        "    c.close();",
        "    return v;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("adopted = ") + " + str(_f()));",
        "}"
    ];
    na = run_na_probe(
        ADOPT_SO, probe, "adopt_read.na.jac", "adopt_read", strip_blank=True
    );
    assert na == ["adopted = 41"];
}


# ---------------------------------------------------------------------------
# 2. Independence: the adopted Snapshot is a distinct box (owned return, not a
#    shared/self-identity handle), so mutating the Counter after the snapshot does
#    NOT change the captured value. Guards against the shell accidentally aliasing
#    the receiver's box.
# ---------------------------------------------------------------------------
test "an adopted snapshot is independent of the counter it came from" {
    if skip_gate(ADOPT_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> str {",
        "    c = Counter(10);",
        "    s = c.snapshot();",  # captures 10
        "    c.bump();",  # counter -> 11
        "    c.bump();",  # counter -> 12
        "    out = str(s.value()) + " + jac_str(",") + " + str(c.get());",
        "    s.close();",
        "    c.close();",
        "    return out;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("indep = ") + " + _f());",
        "}"
    ];
    na = run_na_probe(
        ADOPT_SO, probe, "adopt_indep.na.jac", "adopt_indep", strip_blank=True
    );
    # snapshot still 10, counter now 12
    assert na == ["indep = 10,12"];
}


# ---------------------------------------------------------------------------
# 3. The directly-constructed and the adopted Snapshot are the SAME wrapper shape:
#    `Snapshot(v)` (real ctor -> init) and `c.snapshot()` (adopt shell) both yield
#    a working handle whose value() reads correctly, and both close cleanly. Pins
#    that the `_adopt` shell coexists with the real ctor without clobbering it.
# ---------------------------------------------------------------------------
test "the real ctor and the adopt shell coexist on the same Snapshot wrapper" {
    if skip_gate(ADOPT_SO, SHIM) {
        return;
    }
    probe = [
        "def _f() -> str {",
        "    direct = Snapshot(7);",  # real ctor path (init -> jac_adopt_Snapshot_new)
        "    c = Counter(7);",
        "    adopted = c.snapshot();",  # adopt-shell path (__new__)
        "    out = str(direct.value()) + " + jac_str(",") + " + str(adopted.value());",
        "    direct.close();",
        "    adopted.close();",
        "    c.close();",
        "    return out;",
        "}",
        "\nwith entry {",
        "    print(" + jac_str("both = ") + " + _f());",
        "}"
    ];
    na = run_na_probe(
        ADOPT_SO, probe, "adopt_coexist.na.jac", "adopt_coexist", strip_blank=True
    );
    assert na == ["both = 7,7"];
}
