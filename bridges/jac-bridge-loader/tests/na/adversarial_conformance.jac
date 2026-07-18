# Phase 0 adversarial conformance suite (Lanes Plan, checklist task 0.6.3 — the
# Phase 0 EXIT GATE).  Every test here is RED (fails) or SKIP (unbuilt crate)
# against the current code and only goes green once the named Phase 0 fix lands.
# Do NOT weaken a test to make it pass; the point is that it stays red until the
# soundness bug it pins is actually closed.
#
# Idiom matches owning_conformance.jac: build an na probe, nacompile+run it via
# _harness helpers, and diff against the CPython loader.  A use-after-free that
# segfaults surfaces because run_binary raises on a nonzero exit; a clean
# status-error surfaces as a normal exit plus an error line.  Everything is gated
# via skip_gate(SO, SHIM) so it skips cleanly without the LLVM shim.
import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    jac_str,
    llvm_shim,
    run_na_probe,
    skip_gate,
    synthesize_source,
    run_binary,
    run_na_probe2,
    nacompile_dump_ir,
    nacompile_capture
}


glob SO = bridge_so("owning"),
     SHIM = llvm_shim(),
     # A SECOND callback-bearing crate (its own `jac_<mod>_make_buf` allocator) is
     # required to exercise the single-sink cross-allocator bug (task 0.1.1).  No
     # such crate exists yet — only jac-bridge-owning exposes a JacCallback param.
     # See TEST-MAP.md: this test is BLOCKED until a second callback crate ships.
     SO2 = bridge_so("owning2"),
     # A crate whose `&mut self` method invokes a JacCallback that re-enters the
     # same handle.  None exists yet (owning's replace_all is `&self`).  See
     # TEST-MAP.md: BLOCKED until a reentrancy-capable crate ships.
     REENTRANT_SO = bridge_so("reentrant");


# ---------------------------------------------------------------------------
# 1. User lambda -> ordinary (non-bridge) Jac fn must NOT be rewritten into a
#    {call, ctx} bridge trampoline.  GREEN after task 0.1.2 (callee-driven
#    callback dispatch replaces the global lambda+IntType heuristic).
#
# Adversarial angle: the lambda is deliberately callback-SHAPED (unary, str->str)
# and the receiving param is typed bare `Callable`, which na lowers to i64 — the
# exact IntType slot the current heuristic keys on.  Because a bridge (`owning`)
# is imported, `_callback_make_buf` is set module-wide, so the heuristic wrongly
# synthesizes a `__jac_cb_tramp_` trampoline for a lambda that never goes to a
# bridge.  We prove non-rewrite by inspecting the emitted LLVM IR: a correctly
# dispatched build contains NO callback trampoline for this lambda.
# ---------------------------------------------------------------------------
test "user lambda to a non-bridge fn is not rewritten into a bridge trampoline" {
    if skip_gate(SO, SHIM) {
        return;
    }
    src = synthesize_source(SO) + "\ndef use_it(f: Callable) -> str {\n    return \"ok\";\n}\n" + "\nwith entry {\n" + "    print(use_it(lambda (m: str) -> str { m.upper(); }));\n" + "}\n";
    td = tempfile.mkdtemp();
    try {
        (binp, ir_text) = nacompile_dump_ir(
            src, td, "adv_nonbridge.na.jac", "adv_nonbridge", "adv_nonbridge.ll", SHIM
        );
        # It still compiles and runs the same either way — the misfire is silent
        # at runtime (use_it ignores its arg); the corruption is in the lowering.
        assert run_binary(binp, SO).strip() == "ok";
        # THE GATE: a user lambda handed to an ordinary Jac function must not be
        # lowered as a Rust {call, ctx} callback.  Today the global heuristic
        # emits one; 0.1.2 makes dispatch callee-driven so it does not.
        assert "__jac_cb_tramp_" not in ir_text;
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# 2. Two bridge crates in one module -> each callback trampoline must use its OWN
#    crate's buffer allocator.  GREEN as of task 0.1.1 (per-crate make_buf sink).
#
# Before 0.1.1 `_note_bridge_sink` collapsed every registered crate's make_buf
# into ONE `_callback_make_buf` slot (last writer wins), so with two callback
# crates the wrong crate's allocator filled the other's out-buffer -> cross-
# allocator UB.  Fixed by keying make_buf per crate (`_bridge_make_buf_fns` +
# `_bridge_type_crate`) and routing each callback via `_callback_make_buf_for`
# (the receiver type names the owning crate).
#
# The second crate `jac-bridge-owning2` (type `Regex2`) carries a GUARDED
# `#[global_allocator]` that abort()s on a cross-crate free, so a single-sink
# regression is a hard, deterministic failure here -- not silent UB.  Skip-gated
# on the second .so.  (A three-crate interleaved variant with `owning3` lives in
# scratchpad/run_threecrate.py as extra hardening.)
# ---------------------------------------------------------------------------
test "two bridge crates in one module use their own per-crate allocators" {
    if skip_gate(SO, SHIM) or not SO2.is_file() {
        return;
    }
    # Both crates' sources are merged into ONE na module (run_na_probe2) and a
    # replace_all callback runs against EACH crate's opaque type — owning's Regex
    # and owning2's Regex2.  Each callback returns its replacement through its
    # OWN `jac_<mod>_make_buf`; the pre-0.1.1 single-sink code routes both
    # trampolines through one crate's allocator, so freeing owning2's buffer with
    # owning's free_buf (or vice-versa) corrupts the heap and aborts (nonzero exit
    # -> run_binary raises).  We diff against the CPython loader, which keeps the
    # two crates' allocators separate by construction.
    a = load_bridge(str(SO));
    b = load_bridge(str(SO2));
    ra = a.Regex(r"\w+");
    rb = b.Regex2(r"\w+");
    exp_a = ra.replace_all("hello world", lambda (m: str) -> str { m.upper(); });
    exp_b = rb.replace_all("foo bar", lambda (m: str) -> str { "<" + m + ">"; });
    ra.close();
    rb.close();
    probe = [
        "\nwith entry {",
        "    ra = Regex(" + jac_str(r"\w+") + ");",
        "    print(" + jac_str("a=[") + " + ra.replace_all(" + jac_str("hello world") + ", lambda (m: str) -> str { m.upper(); }) + " + jac_str(
            "]"
        ) + ");",
        "    ra.close();",
        "    rb = Regex2(" + jac_str(r"\w+") + ");",
        "    print(" + jac_str("b=[") + " + rb.replace_all(" + jac_str("foo bar") + ", lambda (m: str) -> str { \"<\" + m + \">\"; }) + " + jac_str(
            "]"
        ) + ");",
        "    rb.close();",
        "}"
    ];
    na = run_na_probe2(
        SO, SO2, probe, "adv_twocrate.na.jac", "adv_twocrate", strip_blank=True
    );
    assert na == ["a=[" + exp_a + "]", "b=[" + exp_b + "]"];
}


# ---------------------------------------------------------------------------
# 3. Identity replacer (`lambda (m: str) -> str { m; }`) must not double-free.  GREEN
#    after task 0.1.3a (retain-on-return, or a pointer-equality guard before the
#    two `_emit_rc_release_simple` calls in the trampoline).
#
# For an identity callback the trampoline's `result` IS the same allocation as
# the input string `raw`, so the two releases free one buffer twice.  Driven in a
# 1000-iteration loop over a multi-match text, the double-free aborts/segfaults
# (nonzero exit -> run_binary raises).  This is reachable TODAY against owning.
# ---------------------------------------------------------------------------
def _identity_cpython(pat: str, text: str) -> str {
    owning = load_bridge(str(SO));
    re = owning.Regex(pat);
    out = re.replace_all(text, lambda (m: str) -> str { m; });
    re.close();
    return out;
}


test "identity replacer in a 1000-iteration loop does not double-free" {
    if skip_gate(SO, SHIM) {
        return;
    }
    pat = r"\w+";
    text = "a b c d e f g h";
    # Identity replacement returns the haystack unchanged; the interesting part is
    # surviving 1000 iterations (8 matches each -> 8000 callback frees).
    expected = [
        "identity result = [" + _identity_cpython(pat, text) + "]",
        "identity iters = 1000"
    ];
    # NOTE: the native backend does not support `for i in range(N)` (E5090), so
    # drive the loop with an explicit `while` counter — this test pins the
    # identity double-free guard, not iterator lowering.
    probe = [
        "\nwith entry {",
        "    last = \"\";",
        "    i = 0;",
        "    while i < 1000 {",
        "        re = Regex(" + jac_str(pat) + ");",
        "        last = re.replace_all(" + jac_str(text) + ", lambda (m: str) -> str { m; });",
        "        re.close();",
        "        i += 1;",
        "    }",
        "    print(" + jac_str("identity result = [") + " + last + " + jac_str("]") + ");",
        "    print(" + jac_str("identity iters = 1000") + ");",
        "}"
    ];
    na = run_na_probe(
        SO, probe, "adv_identity.na.jac", "adv_identity", strip_blank=True
    );
    assert na == expected;
}


# ---------------------------------------------------------------------------
# 4. Reentrant method call -> clean Jac-level error, NOT UB.  GREEN after task
#    0.2.2 (per-handle AtomicBool reentrancy guard on `&mut self` shims).
#
# A callback that re-enters a `&mut self` method on the same handle while the
# outer `&mut` borrow is live is two live `&mut T` -> instant UB in Rust.  The
# guard turns the second entry into a status-coded error the loader raises.
#
# BLOCKED: no current crate has a `&mut self` method that invokes a JacCallback.
# Minimal crate needed (`jac-bridge-reentrant`, module "reentrant"):
#   struct Cell { value: i64 }
#   impl Cell {
#     fn new(v: i64) -> Self
#     fn bump(&mut self) -> i64            // mutates self.value, returns it
#     fn apply(&mut self, cb: JacCallback) // invokes cb once while &mut self live
#   }
# Reentry: `c.apply(lambda (m: str) -> str { c.bump(); })` — cb captures `c` and calls
# `c.bump()` (a second &mut) during `apply`'s live borrow.  Written against that
# API and skip-gated on the crate's .so.
# ---------------------------------------------------------------------------
test "reentrant method call yields a clean status error, not UB" {
    if skip_gate(REENTRANT_SO, SHIM) {
        return;
    }
    # cb re-enters c.bump() (a &mut method) while c.apply()'s &mut borrow is live.
    # The reentrancy guard must surface a caught Jac error rather than corrupting.
    probe = [
        "def _reentry() -> str {",
        "    c = Cell(0);",
        "    marker = \"NO-ERROR\";",
        "    try {",
        "        c.apply(lambda (m: str) -> str { str(c.bump()); });",
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
        REENTRANT_SO, probe, "adv_reentrant.na.jac", "adv_reentrant", strip_blank=True
    );
    # Clean exit (no crash) AND the error was catchable at the Jac level.
    assert na == ["reentry = reentrant-error"];
}


# ---------------------------------------------------------------------------
# 5. Use-after-close -> clean status error, NOT a segfault.  GREEN after task
#    0.2.1 (null-handle guard in the method shims: `handle != 0` -> status 1).
#
# The synthesized wrapper already guards `__closed` at the Jac level AND zeroes
# `self.__handle` on close(), so a real use-after-close reaches the Rust shim
# with handle == 0 only if the wrapper is bypassed.  We bypass it directly —
# calling the raw imported shim with a null (0) handle, exactly what a
# closed-then-dereferenced handle is.  Today the shim dereferences null ->
# segfault (nonzero exit -> run_binary raises).  0.2.1 makes it return a nonzero
# status the caller can handle, and the process exits cleanly.
# ---------------------------------------------------------------------------
test "calling a method shim with a null (closed) handle returns a status error" {
    if skip_gate(SO, SHIM) {
        return;
    }
    probe = [
        "\nwith entry {",
        "    out_b = struct.pack(\"<B\", 0);",
        "    out_e = struct.pack(\"<Q\", 0);",
        # handle 0 == a closed handle (close() sets __handle = 0).
        "    st = jac_owning_Regex_is_match(0, \"hello\", strlen(\"hello\"), out_b, out_e);",
        "    print(" + jac_str("use-after-close status = ") + " + str(st));",
        "}"
    ];
    na = run_na_probe(
        SO, probe, "adv_useafterclose.na.jac", "adv_useafterclose", strip_blank=True
    );
    # RED today: the process never gets here (segfault). After 0.2.1: one clean
    # line with a NONZERO status (null-handle rejected, not dereferenced).
    assert len(na) == 1;
    line = na[0];
    assert line.startswith("use-after-close status = ");
    assert line.split("= ")[1] != "0";
}


# ---------------------------------------------------------------------------
# 6. (Bonus) Bad-arity / bad-return callback lambdas must produce a READABLE
#    nacompile error, not an ICE/miscompile.  GREEN after task 0.1.3 (b) arity
#    check and (c) non-str-return check.
#
# The trampoline blindly indexes `anon_fn.function_type.args[0]` and blindly
# `strlen`s the result, so a 0-param, 2-param, or non-str-returning callback
# lambda ICEs (Python traceback) or miscompiles today.  The fix emits a compile
# error naming the callback.  We assert: no binary produced AND the output is a
# clean diagnostic (no raw Python traceback).
# ---------------------------------------------------------------------------
def _callback_probe(lam: str) -> str {
    return synthesize_source(SO) + "\nwith entry {\n" + "    re = Regex(" + jac_str(
        r"\w+"
    ) + ");\n" + "    out = re.replace_all(" + jac_str("hello") + ", " + lam + ");\n" + "    print(out);\n" + "    re.close();\n" + "}\n";
}


def _assert_readable_compile_error(lam: str, jac_name: str, bin_name: str) {
    td = tempfile.mkdtemp();
    try {
        (produced, output) = nacompile_capture(
            _callback_probe(lam), td, jac_name, bin_name, SHIM
        );
        # No binary, and the diagnostic is readable — an ICE leaks a raw Python
        # traceback / IndexError, which the fix must replace with a real error.
        assert not produced;
        assert "Traceback (most recent call last)" not in output;
        assert "IndexError" not in output;
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "zero-parameter callback lambda is a readable compile error, not an ICE" {
    if skip_gate(SO, SHIM) {
        return;
    }
    _assert_readable_compile_error(
        "lambda () -> str { \"x\"; }", "adv_arity0.na.jac", "adv_arity0"
    );
}


test "two-parameter callback lambda is a readable compile error, not an ICE" {
    if skip_gate(SO, SHIM) {
        return;
    }
    _assert_readable_compile_error(
        "lambda (a: str, b: str) -> str { a; }", "adv_arity2.na.jac", "adv_arity2"
    );
}


test "non-str-returning callback lambda is a readable compile error, not an ICE" {
    if skip_gate(SO, SHIM) {
        return;
    }
    _assert_readable_compile_error(
        "lambda (m: str) -> int { 0; }", "adv_retty.na.jac", "adv_retty"
    );
}
