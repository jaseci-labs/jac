"""Behavioral tests for nested-function closure captures on native.

Graduated from the guardrail (`nested function capturing an enclosing local
is rejected` in test_native_feature_guardrail.jac). For direct calls in the
defining frame, read-only captures bind by value at each call and rebound
captures bind as a pointer to the enclosing frame's slot so writes
propagate. A capturing closure used as a VALUE (returned, stored, passed)
lowers via closure conversion: captured variables of the frame promote to
RC heap cells (Python cell semantics) and the closure becomes an RC
{fn, env} pair whose env keeps the cells alive after the frame dies. The
remaining unsupported shapes (a capture borrowed from an outer frame, a
call through an `any`-typed value) stay structured E5092 errors, never a
silently mis-bound value.
"""

import ctypes;
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    get_func,
    has_error_code,
    native_force_opts,
    native_str_func
}
import jaclang;

test "lambda parameters remain borrowed across explicit returns" {
    (engine, module) = compile_native("lambda_borrowed_params.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    call = get_func(engine, "call_lambda", ctypes.c_int64);
    drops = get_func(engine, "drop_count", ctypes.c_int64);
    assert call() == 770;
    assert drops() == 1;
}

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_closure_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

"""Like `compile_na_inline`, but also hand back the compiled module so a
granular demotion (epic #8201) is observable through the native layout."""
def compile_na_inline_ir(label: str, code: str) -> tuple {
    path = os.path.join(FIXTURES, f"_closure_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return (prog, ir, );
}

test "closure: nested def reads an enclosing param" {
    (eng, _) = compile_native("closures.jac");
    f = get_func(eng, "scaled", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(4, 5) == 20;
    assert f(0, 9) == 0;
}

test "closure: immediately invoked lambdas infer reference returns" {
    (prog, module) = compile_na_inline_ir(
        "immediate_reference",
        """
obj Box { has value: int; }
def compute(value: int) -> int {
    item = (lambda { result = Box(value); return result; })();
    return item.value;
}
"""
    );
    assert not prog.errors_had , "\n".join(str(e) for e in prog.errors_had);
    assert module.gen.native_engine is not None;
    call = get_func(
        module.gen.native_engine, "compute", ctypes.c_int64, ctypes.c_int64
    );
    assert call(37) == 37;
}

test "closure: nested method helpers retain the receiver and outer parameters" {
    (prog, module) = compile_na_inline_ir(
        "method_receiver",
        """
obj Counter {
    has value: int = 10;
    def add(amount: int = 1) -> int {
        return self.value + amount;
    }
    def compute(label: str) -> int {
        def invoke(amount: int) -> int {
            if label == "double" {
                return self.add(amount) * 2;
            }
            return self.value;
        }
        return invoke(3);
    }
}
obj Derived(Counter) {
    def inherited -> int {
        def invoke -> int {
            return super.add(4);
        }
        return invoke();
    }
}
def probe -> int {
    item = Counter();
    derived = Derived();
    return item.compute("double") + item.compute("single") + derived.inherited();
}
"""
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    call = get_func(module.gen.native_engine, "probe", ctypes.c_int64);
    assert call() == 50;
}

test "closure: an escaped receiver stays alive until the closure is released" {
    (prog, module) = compile_na_inline_ir(
        "receiver_escape",
        """
glob dropped: int = 0;
obj Owner {
    has value: int = 21;
    def callback -> Callable[[], int] {
        def read -> int { return self.value; }
        return read;
    }
    def drop { dropped += 1; }
}
def make -> Callable[[], int] { return Owner().callback(); }
def probe -> int {
    read = make();
    return read();
}
def drops -> int { return dropped; }
"""
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    call = get_func(module.gen.native_engine, "probe", ctypes.c_int64);
    drops = get_func(module.gen.native_engine, "drops", ctypes.c_int64);
    before = drops();
    assert call() == 21;
    assert drops() - before == 1;
}

test "closure: split method implementations capture their declaration scope" {
    (prog, module) = compile_na_inline_ir(
        "impl_receiver",
        """
obj Factory {
    has value: int = 30;
    def callback(label: str) -> Callable[[], int];
}
impl Factory.callback {
    def read -> int { return self.value + len(label); }
    return read;
}
def probe -> int {
    callback = Factory().callback("scope");
    return callback();
}
"""
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    call = get_func(module.gen.native_engine, "probe", ctypes.c_int64);
    assert call() == 35;
}

test "closure: read captures are late-bound (py backend parity)" {
    (eng, _) = compile_native("closures.jac");
    f = get_func(eng, "late_bound", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    # r1 = 10 + a (before rebind), r2 = 10 + b (after rebind).
    assert f(2, 7) == 12017;
}

test "closure: rebound capture writes through to the enclosing frame" {
    (eng, _) = compile_native("closures.jac");
    f = get_func(eng, "rebind_out", ctypes.c_int64, ctypes.c_int64);
    # total = 0; bump(5) twice writes through: total == 10.
    assert f(5) == 10;
}

test "closure: RC pointer capture (str) reads without double release" {
    (eng, _) = compile_native("closures.jac");
    f = native_str_func(eng, "str_capture", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"abcd") == 8;
}

test "closure: capturing lambda in the same frame keeps working" {
    (eng, _) = compile_native("closures.jac");
    f = get_func(eng, "lam_parity", ctypes.c_int64, ctypes.c_int64);
    assert f(6) == 18;
}

test "closure: self-recursive nested def forwards its own captures" {
    (eng, _) = compile_native("closures.jac");
    f = get_func(eng, "recursive_capture", ctypes.c_int64, ctypes.c_int64);
    # depth increments through the shared slot on every recursion level.
    assert f(3) == 4;
}

test "closure escape: counter factory returns a live closure" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "use_counter", ctypes.c_int64);
    assert f() == 3;
}

test "closure escape: two factory closures have independent cells" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "two_counters_independent", ctypes.c_int64);
    assert f() == 32;
}

test "closure escape: closure passed as argument writes through" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "pass_closure", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 16016;
}

test "closure escape: closure stored in a list and called later" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "stored_in_list", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(40, 2) == 42;
}

test "closure escape: two closures share one rebound cell" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "shared_cell", ctypes.c_int64);
    assert f() == 1;
}

test "closure escape: env keeps an RC capture alive after the frame dies" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "use_greeter", ctypes.c_int64);
    assert f() == 8;
}

test "closure escape: capturing lambda escapes as a value" {
    (eng, _) = compile_native("closures_escape.jac");
    f = get_func(eng, "lambda_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 124;
    g = get_func(eng, "use_adder", ctypes.c_int64);
    assert g() == 23;
}

test "closure escape: capture borrowed from an outer frame stays rejected" {
    (prog, ir) = compile_na_inline_ir(
        "transitive_escape",
        "def outer(y: int) -> Callable[[], int] {\n"
        "    def mid -> Callable[[], int] {\n"
        "        def inner -> int { return y; }\n"
        "        return inner;\n"
        "    }\n"
        "    return mid();\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the outer-frame capture refusal is owned by outer(), which must "
        f"demote to a seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "outer" not in ir.gen.native_layout.functions , (
        "a closure escaping with an outer-frame capture must demote its "
        "function out of the native layout, never lower wrongly"
    );
}

test "closure escape: calling a closure through an any-typed value stays rejected" {
    (prog, ir) = compile_na_inline_ir(
        "any_closure_call",
        "def outer(y: int) -> int {\n"
        "    def inner(x: int) -> int { return x * y; }\n"
        "    f: any = inner;\n"
        "    return f(3);\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the any-typed closure call refusal is owned by outer(), which must "
        f"demote to a seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "outer" not in ir.gen.native_layout.functions , (
        "an any-typed closure call site must demote its function out of the "
        "native layout, never lower wrongly"
    );
}

test "adapter: map with a capturing lambda callback" {
    (eng, _) = compile_native("closures_adapters.jac");
    f = get_func(eng, "scale_all", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 18 , "3+6+9";
    assert f(0) == 0;
}

test "adapter: filter with a capturing lambda predicate" {
    (eng, _) = compile_native("closures_adapters.jac");
    f = get_func(eng, "keep_over", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 14 , "5+9";
    assert f(0) == 18 , "1+5+9+3";
}

test "adapter: stored closure value drives map" {
    (eng, _) = compile_native("closures_adapters.jac");
    f = get_func(eng, "map_stored_closure", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 44 , "(10+7)+(20+7)";
}

test "adapter: named nested closure passed to map by name" {
    (eng, _) = compile_native("closures_adapters.jac");
    f = get_func(eng, "map_named_capture", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 50 , "20+30";
}

test "adapter: capturing filter chained into capturing map" {
    (eng, _) = compile_native("closures_adapters.jac");
    f = get_func(
        eng, "filter_then_map", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(3, 2) == 14 , "(3+4)*2";
}

test "frame scan: closure escaping an event-method frame" {
    (eng, _) = compile_native("closures_frames.jac");
    f = get_func(eng, "event_frame_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 30 , "here.val captured, f(10) = 10*3";
}

test "frame scan: closure escaping a no-signature method frame" {
    (eng, _) = compile_native("closures_frames.jac");
    f = get_func(eng, "nosig_frame_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(9) == 109 , "base captured, f(100) = 100+9";
}

test "frame scan: lambda escaping a global initializer" {
    (eng, _) = compile_native("closures_frames.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "globinit_lambda", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 15;
}

test "frame scan: lambda escaping the module entry frame" {
    (eng, _) = compile_native("closures_frames.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "entry_frame_escape", ctypes.c_int64);
    assert f() == 8 , "entry-frame lambda called through the list, f(1) = 1+7";
}

test "entry lambda reading an entry-assigned name lowers as a global read" {
    # Python treats `with entry` assignments as module globals; the native
    # backend now registers entry-block assignment targets as module globals
    # (#7626 A1), so a lambda there reads them like any `glob` -- no more
    # frame-local E5092. Behavioral parity is pinned in
    # test_native_entry_globals.jac.
    prog = compile_na_inline(
        "entry_local_lambda",
        "glob acc: list[int] = [];\n"
        "with entry {\n"
        "    k = 7;\n"
        "    fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x + k; }];\n"
        "    f = fns[0];\n"
        "    acc.append(f(1));\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"entry lambda over an entry-assigned name should lower natively, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
