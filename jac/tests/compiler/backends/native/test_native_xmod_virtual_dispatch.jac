"""A base's own body reaches an importer's override (#8288 seat 2).

Devirtualization asked a question one module cannot answer. When a base
class's method calls another of its own methods on `self`, the backend
looked for a subclass that overrides the callee and, finding none, bound
the call straight to the base body. The set it searched is
`_non_overridden_methods`, built from `get_layout_registry(self.ir_in, ...)`
-- the registry of ONE module. An importer's subclass is not in it, so
every overridable method of every imported class bound statically and the
override never ran. Nothing diagnosed it: the vtables were correct, the
slot held the right function pointer, and only the call site was wrong.

That is what held the fused native prefix at seat one. `UniPass.transform`
calls `self.before_pass()`; `SymTabBuildPass.before_pass` is the override
that creates the pass's scope stack. Bound to the empty `UniPass` body --
which LLVM then inlined away to nothing -- the stack stayed null,
`cur_scope` read `self.cur_sym_tab[-1]` off a null pointer, and the
crossing took SIGSEGV at address 0.

The fix keeps the optimization only where the question is answerable: a
module-private archetype cannot be named outside its module, so it cannot
be subclassed outside it either, and that module's registry is complete
for it. Every other class dispatches through the vtable slot it already
carries.

The fixture pins both halves, which is what makes it a test rather than a
demonstration:

  * `drive()` is declared on the imported `Driver` and calls `self.hook()`
    from inside the base's own unit. This is the broken shape. Before the
    fix the native binary printed `consumer_mark=0 / consumer_tick=1` --
    `Driver.hook` ran in place of `Consumer.hook`.
  * `label()` is called on the consumer from the *importing* module, where
    the registry does see the override. It was correct before the fix and
    must stay correct after, so a regression that simply stopped
    dispatching anywhere cannot pass.
  * `Driver` is exercised unsubclassed in the same run, so the base body
    still has to be reachable for a base instance.

The subprocess pair is the contract, the same one
`test_native_xmod_inherited_fields.jac` sets: the fixture runs through the
server pathway (CPython) and as a native binary, and the two must print
identical lines. Pinning the values is the point -- a dispatch that lands
on the wrong body still lowers, links and exits 0.

Each pathway runs once per process, not once per test. `nacompile` is a
full native build, the four tests below all want the same fixture's
output, and `ForkPool._dispatch` hands a worker a whole FILE rather than
a test -- so they share this process and the memo turns four builds into
one. On the four-vCPU box `test-native` runs on, that is the difference
between this file costing one native compile and costing four.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MAIN_FIXTURE = "xmod_dispatch_main.jac",
     _RUN_MEMO: dict[(str, str)] = {};

"""Run a fixture through the server pathway and hand back its stdout."""
def sv_run(fixture: str) -> str {
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(FIXTURES, fixture)],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

"""Compile a fixture to a native binary, run it, and hand back its stdout."""
def na_run(fixture: str) -> str {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            os.path.join(FIXTURES, fixture),
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-900:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

"""Split stdout into the non-empty lines a comparison should see."""
def kept_lines(text: str) -> list[str] {
    return [
        _l.strip()
        for _l in text.split("\n")
        if _l.strip()
    ];
}

"""The native binary's output lines, built at most once per process."""
def na_lines(fixture: str) -> list[str] {
    key = f"na:{fixture}";
    if key not in _RUN_MEMO {
        _RUN_MEMO[key] = na_run(fixture);
    }
    return kept_lines(_RUN_MEMO[key]);
}

"""The server pathway's output lines, built at most once per process."""
def sv_lines(fixture: str) -> list[str] {
    key = f"sv:{fixture}";
    if key not in _RUN_MEMO {
        _RUN_MEMO[key] = sv_run(fixture);
    }
    return kept_lines(_RUN_MEMO[key]);
}

test "an imported base's own call reaches the importer's override" {
    na = na_lines(MAIN_FIXTURE);
    assert "consumer_mark=7" in na , (
        f"Driver.drive() did not reach Consumer.hook natively; got {na}"
    );
    assert "consumer_tick=0" in na , (
        f"Driver.hook ran in place of the override; got {na}"
    );
}

test "the importing module's own call site keeps dispatching" {
    na = na_lines(MAIN_FIXTURE);
    assert "consumer_label=consumer" in na , (
        f"a call from the importing module lost its override; got {na}"
    );
}

test "an unsubclassed base instance still runs the base body" {
    na = na_lines(MAIN_FIXTURE);
    assert "base_tick=1" in na , f"Driver.hook did not run for a Driver; got {na}";
    assert "base_label=base" in na , f"Driver.label did not run for a Driver; got {na}";
}

test "the native binary and the server pathway agree line for line" {
    sv = sv_lines(MAIN_FIXTURE);
    na = na_lines(MAIN_FIXTURE);
    assert sv , "the server pathway produced no output";
    assert len(sv) == len(na) , f"line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , (f"line {idx}: sv {sv[idx]!r} vs na {na[idx]!r}");
    }
}
