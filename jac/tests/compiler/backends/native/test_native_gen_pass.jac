"""End-to-end tests for native LLVM IR compilation (na {} / .jac).

Tests verify that .jac fixtures compile to LLVM IR, JIT-compile to
native machine code, and produce correct results when executed via ctypes.

One test per fixture. Each fixture used to carry one hand-written test per
exported symbol -- `dicts_sets.jac` had 39 of them against 40 symbols -- so the
fixture was recompiled and re-JITed once per assertion group. The per-symbol
probes are plain functions now, named for the test they replaced and taking the
engine, and the fixture's single test compiles once and calls them in order. A
failing probe still names itself in the traceback.

The probes of one fixture SHARE that engine, so they also share the module's
globals -- what a probe writes, later probes in the same test see. A fixture
that reaches a mutated module glob, in itself or in any fixture it imports,
is therefore NOT merged: its cases stay separate tests so each compiles for
itself and starts from a pristine global. `fix_subscript_entry.jac` is why
the rule is mechanical rather than case-by-case -- its `ITEMS` glob lives in
the imported `fix_subscript_outer.jac`, three probes each `push_item` before
reading, and merged they read a list three pushes deep.

So: if a new fixture declares a glob anything writes, or imports one that
does, give each of its cases its own test.
"""

import ctypes;
import from _ctypes { CFuncPtr }
import io;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT, TESTS_DIR, compile_native, get_func, native_address, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }
import from jaclang.compiler.frontend.codeinfo {
    native_glob_init_name,
    native_symbol_name,
    native_unit_prefix
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""The engine symbol of a name the module under test defines.

`:pub` symbols and the synthesized `jac_entry` keep their bare names; every
other external symbol (functions, `Class.method`) lives under the unit's
prefix, `native_unit_prefix(path)` (#8943). The unit's interface records the
exact symbol when the compile produced one.
"""
def unit_sym(ir: any, name: str) -> str {
    iface = ir.gen.native_iface if (ir is not None and ir.gen is not None) else None;
    if iface is not None {
        found = iface.symbol_of(name);
        if found {
            return found;
        }
    }
    return native_symbol_name(native_unit_prefix(ir.loc.mod_path), name);
}

class JacStrABI(ctypes.Structure) {
    # Register view of a by-value JacStr {root, data, len} return. LLVM
    # lowers the aggregate return into scalar return registers; a 16-byte
    # two-pointer struct restype makes libffi read the first two of them,
    # which yields root and data. len rides in the third return register,
    # unreachable through libffi, but Jac string payloads are always
    # NUL-terminated at len so a bounded read is recovered from data.
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

def get_sfunc(
    eng: ExecutionEngine, name: str, restype: (type | None), *argtypes: type
) -> Callable[..., any] {
    # descriptor-ABI variant of get_func: a c_char_p spelling here means a
    # Jac `str` (the by-value {root, data, len} descriptor at the native
    # ABI). LLVM decomposes a by-value descriptor param into three scalar
    # slots, so each str param is declared as (root, data, len) scalars and
    # bytes/str args build their backing storage via jac_str_new; str
    # returns come back as the full bytes of the result string, so existing
    # comparisons keep working. The address comes through the shared
    # `get_func`, so the module-qualified symbol rule (#8943) applies here
    # exactly as it does to every other lookup.
    addr = ctypes.cast(get_func(eng, name, None), ctypes.c_void_p).value;
    assert addr , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list = [];
    real_args: list = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = native_address(eng, sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    _str_buf_cache: dict = {};
    def _call(*args: any) -> any {
        c_args: list = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                assert mkstr is not None , "jac_str_new not found in JIT engine";
                b = a.encode("utf-8") if isinstance(a, str) else a;
                p = _str_buf_cache.get(b);
                if p is None {
                    p = mkstr(b, len(b));
                    _str_buf_cache[b] = p;
                }
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}

"""Current resident-set-size of this process in kB (Linux), or -1 if the
/proc interface is unavailable (e.g. macOS) so callers can skip the gate."""
def _rss_kb -> int {
    if not os.path.exists("/proc/self/status") {
        return -1;
    }
    with open("/proc/self/status") as f {
        for line in f {
            if line.startswith("VmRSS") {
                return int(line.split()[1]);
            }
        }
    }
    return -1;
}

# --- TestNativeArithmeticExecution ---
"""arithmetic add"""
def _arithmetic__arithmetic_add(eng: any, _ir: any) {
    add = get_func(eng, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert add(3, 4) == 7;
    assert add(-1, 1) == 0;
    assert add(0, 0) == 0;
    assert add(100, 200) == 300;
}

"""arithmetic multiply"""
def _arithmetic__arithmetic_multiply(eng: any, _ir: any) {
    mul = get_func(eng, "multiply", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert mul(5, 6) == 30;
    assert mul(-3, 7) == -21;
    assert mul(0, 999) == 0;
}

"""arithmetic negate"""
def _arithmetic__arithmetic_negate(eng: any, _ir: any) {
    neg = get_func(eng, "negate", ctypes.c_int64, ctypes.c_int64);
    assert neg(5) == -5;
    assert neg(-3) == 3;
    assert neg(0) == 0;
}

"""arithmetic float add"""
def _arithmetic__arithmetic_float_add(eng: any, _ir: any) {
    fadd = get_func(
        eng, "float_add", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert abs(fadd(1.5, 2.5) - 4.0) < 1e-10;
    assert abs(fadd(-1.0, 1.0)) < 1e-10;
}

"""context isolation native ir contains function"""
def _arithmetic__context_isolation_native_ir_contains_function(eng: any, ir: any) {
    # If we can get the function address, the IR was generated correctly
    addr = native_address(eng, unit_sym(ir, "add"));
    assert addr != 0;
}

test "arithmetic" {
    (_eng, _ir) = compile_native("arithmetic.jac");
    _arithmetic__arithmetic_add(_eng, _ir);
    _arithmetic__arithmetic_multiply(_eng, _ir);
    _arithmetic__arithmetic_negate(_eng, _ir);
    _arithmetic__arithmetic_float_add(_eng, _ir);
    _arithmetic__context_isolation_native_ir_contains_function(_eng, _ir);
}

# Regression: CPython floor semantics for negative //, %, and divmod on native.
test "negative floor divmod" {
    (eng, _) = compile_native("neg_divmod.jac");
    fd = get_func(eng, "floordiv", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert fd(-6, 4) == -2;
    assert fd(6, -4) == -2;
    assert fd(-6, -4) == 1;
    im = get_func(eng, "intmod", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert im(-6, 4) == 2;
    assert im(6, -4) == -2;
    assert im(-6, -4) == -2;
    dq = get_func(eng, "divmod_quot", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    dr = get_func(eng, "divmod_rem", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert dq(-6, 4) == -2;
    assert dr(-6, 4) == 2;
    ff = get_func(
        eng, "float_floordiv", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert abs(ff(-6.0, 4.0) - (-2.0)) < 1e-10;
    fm = get_func(eng, "float_mod", ctypes.c_double, ctypes.c_double, ctypes.c_double);
    assert abs(fm(-6.5, 2.5) - 1.0) < 1e-10;
    assert abs(fm(7.5, -2.0) - (-0.5)) < 1e-10;
}

# Regression: sub-64-bit integer arithmetic must run at the operands'
# true width, not force i64 overflow intrinsics (i32/i16/i8 kernels).
"""arithmetic narrow int width"""
def _narrow_int_truediv__arithmetic_narrow_int_width(eng: any, _ir: any) {
    add32 = get_func(eng, "add32", ctypes.c_int32, ctypes.c_int32, ctypes.c_int32);
    assert add32(3, 4) == 7;
    sub32 = get_func(eng, "sub32", ctypes.c_int32, ctypes.c_int32, ctypes.c_int32);
    assert sub32(10, 3) == 7;
    mul32 = get_func(eng, "mul32", ctypes.c_int32, ctypes.c_int32, ctypes.c_int32);
    assert mul32(6, 7) == 42;
}

# Regression: `/` is true division (Python semantics) -- int / int is a
# float, while `//` stays integer floor division.
"""arithmetic true division"""
def _narrow_int_truediv__arithmetic_true_division(eng: any, _ir: any) {
    td = get_func(eng, "truediv", ctypes.c_double, ctypes.c_int64, ctypes.c_int64);
    assert td(3, 4) == 0.75;
    assert td(10, 2) == 5.0;
    fd = get_func(eng, "floordiv", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert fd(3, 4) == 0;
    assert fd(7, 2) == 3;
    assert fd(-6, 4) == -2;
    assert fd(6, -4) == -2;
    assert fd(-6, -4) == 1;
    im = get_func(eng, "intmod", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert im(-6, 4) == 2;
    assert im(6, -4) == -2;
    assert im(-6, -4) == -2;
    dq = get_func(eng, "divmod_quot", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    dr = get_func(eng, "divmod_rem", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert dq(-6, 4) == -2;
    assert dr(-6, 4) == 2;
}

test "narrow_int_truediv" {
    (_eng, _ir) = compile_native("narrow_int_truediv.jac");
    _narrow_int_truediv__arithmetic_narrow_int_width(_eng, _ir);
    _narrow_int_truediv__arithmetic_true_division(_eng, _ir);
}

# --- Function pointers in struct fields (the OSP dispatch-slot shape) ---
test "native callable struct field: indirect call through a field" {
    (eng, _) = compile_native("callable_field.jac");
    call_one = get_func(eng, "call_one", ctypes.c_int64, ctypes.c_int64);
    assert call_one(21) == 42;
    dispatch_all = get_func(eng, "dispatch_all", ctypes.c_int64, ctypes.c_int64);
    # double(x) + negate(x): a list of {tag, fn} structs iterated and called.
    assert dispatch_all(10) == 10;
    assert dispatch_all(3) == 3;
}

# --- Object-Spatial Programming (walker / node / spawn / abilities) ---
"""native osp: spawn dispatches entry ability and mutates walker state"""
def _osp_spawn__native_osp_spawn_dispatches_entry_ability_and_mutates_walker_state(
    eng: any, _ir: any
) {
    collect_two = get_func(
        eng, "collect_two", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    # Walker spawns on two Item nodes; the `grab with Item entry` ability reads
    # `here.val` and accumulates into `self.total` across both spawns.
    assert collect_two(10, 32) == 42;
    assert collect_two(0, 0) == 0;
    assert collect_two(5, 5) == 10;
}

"""native osp: spawn returns the walker"""
def _osp_spawn__native_osp_spawn_returns_the_walker(eng: any, _ir: any) {
    collect_one = get_func(eng, "collect_one", ctypes.c_int64, ctypes.c_int64);
    # `(Collector() spawn Item(val=v)).total` — spawn evaluates to the walker.
    assert collect_one(7) == 7;
    assert collect_one(0) == 0;
}

test "osp_spawn" {
    (_eng, _ir) = compile_native("osp_spawn.jac");
    _osp_spawn__native_osp_spawn_dispatches_entry_ability_and_mutates_walker_state(
        _eng, _ir
    );
    _osp_spawn__native_osp_spawn_returns_the_walker(_eng, _ir);
}

test "native osp: chained [?:Type] filter narrows adjacency" {
    (eng, _) = compile_native("osp_chained_filter.jac");
    count_tasks = get_func(eng, "count_tasks", ctypes.c_int64);
    assert count_tasks() == 2 , "the Note neighbour is filtered out";
    count_all = get_func(eng, "count_all", ctypes.c_int64);
    assert count_all() == 3;
    title_len = get_func(eng, "title_len_total", ctypes.c_int64);
    assert title_len() == 7 , "len('alpha') + len('be') via typed field access";
}

test "native osp: skip in an impl-annex walker event ability (issue #6794)" {
    # `skip` is a valid Return-family statement in a walker `with X entry` event
    # ability, and native lowers it there. When the ability is split decl/impl,
    # the `skip` lives in an `impl Walker.ability with X entry` ImplDef in the
    # annex. Before the fix the native capability check — now scanning annex
    # bodies (#6754) — saw the ImplDef (not an inline Ability) around the `skip`
    # and falsely rejected it (E5090), producing no IR; a module importing it
    # then failed to link (E5024) and `jac test` reported "native engine
    # unavailable". Here `grab` skips val==0 nodes and sums the rest.
    (eng, _) = compile_native("osp_skip_annex.jac");
    collect = get_func(
        eng, "collect", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert collect(10, 0, 32) == 42;  # the val==0 node is skipped
    assert collect(0, 0, 0) == 0;  # every node skipped
    assert collect(5, 5, 5) == 15;
}

# --- Partial-native classes / per-method opt-out (workstream A4, #6930) ---
test "native partial class: un-lowerable method skipped, sibling stays native" {
    # `Literal.evaluate` uses `eval` (no native lowering). Before A4 its E5090
    # poisoned the whole module, so the class lost its native layout and every
    # sibling method. Now the un-lowerable method is demoted to Python-only and
    # the rest of the class compiles: native construction + the native-eligible
    # `length` work, the module reports no errors.
    (eng, ir) = compile_native("partial_native.jac");
    measure = get_sfunc(eng, "measure", ctypes.c_int64, ctypes.c_char_p);
    assert measure(b"hello") == 5;
    assert measure(b"") == 0;
    layout = ir.gen.native_layout;
    assert layout is not None , "native layout missing";
    # The native-eligible method is exported; the eval-using one is skipped.
    assert "Literal.length" in layout.methods;
    assert "Literal.evaluate" not in layout.methods;
}

test "native partial class: demotion warns on the terminal by default (#6934)" {
    # warn_native_seams defaults True, so demoting an un-lowerable method prints
    # a terminal warning naming the method — a silent native fallback is visible
    # during a build. The compile still succeeds (A4 demotes, no errors).
    _saved = sys.stderr;
    _cap = io.StringIO();
    sys.stderr = _cap;
    try {
        prog = JacProgram();
        prog.compile(
            file_path=str(os.path.join(FIXTURES, "partial_native.jac")),
            options=native_force_opts()
        );
    } finally {
        sys.stderr = _saved;
    }
    assert not prog.errors_had;
    _out = _cap.getvalue();
    assert "native seam" in _out;
    assert "Literal.evaluate" in _out;
    assert "Python-only" in _out;
}

test "native partial class: native caller of a demoted method errors, not silent" {
    # A method demoted to Python-only is not callable from native code: the
    # native pathway cannot fall back to Python mid-stream. The free function
    # that calls it cascades into a seam of its own (granular demotion), and
    # the module entry that calls THAT function stays a loud E5092 naming its
    # call site instead of silently dropping to a null result.
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, "partial_native_native_caller.jac")),
        options=native_force_opts()
    );
    codes = [
        e.code.code
        for e in (prog.errors_had or [])
        if e.code
    ];
    assert "E5092" in codes , (
        f"expected E5092 for the native call chain into a demoted method, "
        f"got {codes}"
    );
    # The diagnostic names the demoted callable at the surviving call site,
    # not the discarded eval body that was demoted away.
    msgs = " ".join(str(e) for e in (prog.errors_had or []));
    assert "call_evaluate" in msgs , (f"E5092 should name call_evaluate, got: {msgs}");
}

test "native partial class: un-lowerable virtual method demotes to a stub slot" {
    # `render` is virtual (Base + Derived override -> vtable slot). An
    # un-lowerable virtual now demotes like any other method: its vtable
    # slot keeps the abort() stub so native dispatch that reaches it fails
    # loudly, the function is excluded from the exported layout, and the
    # module still lowers (#6930 W4).
    prog = JacProgram();
    ir_mod = prog.compile(
        file_path=str(os.path.join(FIXTURES, "partial_native_virtual.jac")),
        options=native_force_opts()
    );
    codes = [
        e.code.code
        for e in (prog.errors_had or [])
        if e.code
    ];
    assert codes == [] , (f"virtual demotion must not leave hard errors, got {codes}");
    assert ir_mod is not None and ir_mod.gen.llvm_ir is not None;
    layout = ir_mod.gen.native_layout;
    assert layout is not None;
    assert "Derived.render" not in layout.methods , (
        "demoted virtual must not be exported in the layout"
    );
    assert "Base.render" in layout.methods;
}

# Regression (#7593 item 1): f32 operands must promote to double instead of
# crashing the binop/compare emitters.
"""arithmetic f32 promotion binops"""
def _f32_promotion__arithmetic_f32_promotion_binops(eng: any, _ir: any) {
    ma = get_func(eng, "mixed_add", ctypes.c_double, ctypes.c_float, ctypes.c_double);
    assert ma(1.5, 2.25) == 3.75;
    mr = get_func(
        eng, "mixed_add_rev", ctypes.c_double, ctypes.c_double, ctypes.c_float
    );
    assert mr(2.25, 1.5) == 3.75;
    sa = get_func(eng, "same_add", ctypes.c_double, ctypes.c_float, ctypes.c_float);
    assert sa(1.5, 2.25) == 3.75;
    mm = get_func(eng, "mixed_mul", ctypes.c_double, ctypes.c_float, ctypes.c_double);
    assert mm(1.5, 2.0) == 3.0;
    md = get_func(eng, "mixed_div", ctypes.c_double, ctypes.c_float, ctypes.c_double);
    assert md(1.5, 0.5) == 3.0;
    mo = get_func(eng, "mixed_mod", ctypes.c_double, ctypes.c_float, ctypes.c_double);
    assert mo(5.5, 2.0) == 1.5;
    mf = get_func(
        eng, "mixed_floordiv", ctypes.c_double, ctypes.c_float, ctypes.c_double
    );
    assert mf(5.5, 2.0) == 2.0;
    nf = get_func(eng, "neg_fmod", ctypes.c_double, ctypes.c_double, ctypes.c_double);
    assert abs(nf(-6.5, 2.5) - 1.0) < 1e-10;
    assert abs(nf(7.5, -2.0) - (-0.5)) < 1e-10;
    fi = get_func(eng, "f32_int_add", ctypes.c_double, ctypes.c_float, ctypes.c_int64);
    assert fi(1.5, 2) == 3.5;
}

"""arithmetic f32 promotion comparisons"""
def _f32_promotion__arithmetic_f32_promotion_comparisons(eng: any, _ir: any) {
    cl = get_func(eng, "cmp_mixed_lt", ctypes.c_bool, ctypes.c_float, ctypes.c_double);
    assert cl(1.5, 2.25);
    assert not cl(2.5, 2.25);
    cs = get_func(eng, "cmp_same_lt", ctypes.c_bool, ctypes.c_float, ctypes.c_float);
    assert cs(1.5, 2.25);
    assert not cs(2.25, 1.5);
    cc = get_func(
        eng,
        "cmp_chain",
        ctypes.c_bool,
        ctypes.c_float,
        ctypes.c_double,
        ctypes.c_double
    );
    assert cc(1.0, 2.0, 3.0);
    assert not cc(1.0, 3.0, 2.0);
}

"""arithmetic f32 result narrows at typed sinks"""
def _f32_promotion__arithmetic_f32_result_narrows_at_typed_sinks(eng: any, _ir: any) {
    sn = get_func(
        eng, "same_add_narrow", ctypes.c_float, ctypes.c_float, ctypes.c_float
    );
    assert sn(1.5, 2.25) == 3.75;
    ng = get_func(eng, "neg32", ctypes.c_double, ctypes.c_float);
    assert ng(1.5) == -1.5;
}

"""aug assign f32 field promotes"""
def _f32_promotion__aug_assign_f32_field_promotes(eng: any, _ir: any) {
    fa = get_func(eng, "field_aug", ctypes.c_double, ctypes.c_double);
    assert fa(0.25) == 1.75;
}

test "f32_promotion" {
    (_eng, _ir) = compile_native("f32_promotion.jac");
    _f32_promotion__arithmetic_f32_promotion_binops(_eng, _ir);
    _f32_promotion__arithmetic_f32_promotion_comparisons(_eng, _ir);
    _f32_promotion__arithmetic_f32_result_narrows_at_typed_sinks(_eng, _ir);
    _f32_promotion__aug_assign_f32_field_promotes(_eng, _ir);
}

# --- TestNativeControlFlowExecution ---
"""control flow abs val"""
def _control_flow__control_flow_abs_val(eng: any, _ir: any) {
    f = get_func(eng, "abs_val", ctypes.c_int64, ctypes.c_int64);
    assert f(-5) == 5;
    assert f(5) == 5;
    assert f(0) == 0;
    assert f(-100) == 100;
}

"""control flow max val"""
def _control_flow__control_flow_max_val(eng: any, _ir: any) {
    f = get_func(eng, "max_val", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 7) == 7;
    assert f(10, 2) == 10;
    assert f(5, 5) == 5;
}

"""control flow factorial"""
def _control_flow__control_flow_factorial(eng: any, _ir: any) {
    f = get_func(eng, "factorial", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1;
    assert f(1) == 1;
    assert f(5) == 120;
    assert f(10) == 3628800;
}

"""control flow sum to n"""
def _control_flow__control_flow_sum_to_n(eng: any, _ir: any) {
    f = get_func(eng, "sum_to_n", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 55;
    assert f(100) == 5050;
    assert f(0) == 0;
}

test "control_flow" {
    (_eng, _ir) = compile_native("control_flow.jac");
    _control_flow__control_flow_abs_val(_eng, _ir);
    _control_flow__control_flow_max_val(_eng, _ir);
    _control_flow__control_flow_factorial(_eng, _ir);
    _control_flow__control_flow_sum_to_n(_eng, _ir);
}

# --- TestNativeRecursionExecution ---
test "recursion fibonacci" {
    (eng, _) = compile_native("fibonacci.jac");
    fib = get_func(eng, "fib", ctypes.c_int64, ctypes.c_int64);
    assert fib(0) == 0;
    assert fib(1) == 1;
    assert fib(10) == 55;
    assert fib(15) == 610;
}

"""nested functions helper recursion and module global"""
def _nested_def__nested_functions_helper_recursion_and_module_global(
    eng: any, _ir: any
) {
    use_helper = get_func(eng, "use_helper", ctypes.c_int64, ctypes.c_int64);
    # double(n) + double(n + 1) == 4n + 2
    assert use_helper(0) == 2;
    assert use_helper(5) == 22;
    nested_recursion = get_func(
        eng, "nested_recursion", ctypes.c_int64, ctypes.c_int64
    );
    assert nested_recursion(1) == 1;
    assert nested_recursion(5) == 120;
    uses_global = get_func(eng, "uses_global", ctypes.c_int64, ctypes.c_int64);
    # x + BASE, BASE == 100
    assert uses_global(0) == 100;
    assert uses_global(7) == 107;
}

# ─── Nested function definitions ─────────────────────────────────────────
"""nested function helper is callable from its enclosing function"""
def _nested_def__nested_function_helper_is_callable_from_its_enclosing_function(
    eng: any, _ir: any
) {
    f = get_func(eng, "use_helper", ctypes.c_int64, ctypes.c_int64);
    # double(5) + double(6) = 10 + 12 = 22
    assert f(5) == 22;
    assert f(0) == 2;
}

"""nested function can recurse"""
def _nested_def__nested_function_can_recurse(eng: any, _ir: any) {
    f = get_func(eng, "nested_recursion", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 120;
    assert f(1) == 1;
}

"""nested function can read a module global"""
def _nested_def__nested_function_can_read_a_module_global(eng: any, _ir: any) {
    f = get_func(eng, "uses_global", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 107;
}

test "nested_def" {
    (_eng, _ir) = compile_native("nested_def.jac");
    _nested_def__nested_functions_helper_recursion_and_module_global(_eng, _ir);
    _nested_def__nested_function_helper_is_callable_from_its_enclosing_function(
        _eng, _ir
    );
    _nested_def__nested_function_can_recurse(_eng, _ir);
    _nested_def__nested_function_can_read_a_module_global(_eng, _ir);
}

test "glob declared in an impl annex resolves on native (issue #6754)" {
    # A `glob` declared in the canonical bare IMPL ANNEX
    # (`impl/annex_glob.impl.jac`, base name resolved before the `.na` variant
    # suffix), not the head file, must be registered in the native module's
    # globals and resolved by references in the annexed ability bodies. Before
    # the fix, native global collection swept only the head module's `body`, so
    # the annex glob was never emitted and references bailed with E5090
    # 'Name'/'BinaryExpr'. The byte-identical program with the glob in the head
    # file always compiled.
    (eng, _) = compile_native("annex_glob.jac");
    get_sz = get_func(eng, "get_sz", ctypes.c_int64);
    double_sz = get_func(eng, "double_sz", ctypes.c_int64);
    assert get_sz() == 21;  # bare `Name` reference to the annex glob
    assert double_sz() == 42;  # `BinaryExpr` reference to the annex glob
}

# --- TestNativeContextIsolation ---
test "context isolation native excluded from python" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "mixed_contexts.jac")));
    # Python source should NOT contain native_add
    py_src = ir.gen.py;
    assert "native_add" not in py_src;
    # Python source should contain server_hello
    assert "server_hello" in py_src;
}

# --- TestNativeEnumsAndLoops ---
"""enums loops opposite color"""
def _enums_loops__enums_loops_opposite_color(eng: any, _ir: any) {
    f = get_func(eng, "opposite_color", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1;  # WHITE -> BLACK
    assert f(1) == 0;  # BLACK -> WHITE
}

"""enums loops enum kind"""
def _enums_loops__enums_loops_enum_kind(eng: any, _ir: any) {
    f = get_func(eng, "enum_kind_test", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 100;  # PAWN
    assert f(1) == 200;  # KNIGHT
    assert f(2) == 300;  # BISHOP
    assert f(99) == 0;  # unknown
}

"""enums loops sum range"""
def _enums_loops__enums_loops_sum_range(eng: any, _ir: any) {
    f = get_func(eng, "sum_range", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0;
    assert f(1) == 0;
    assert f(5) == 10;  # 0+1+2+3+4
    assert f(10) == 45;  # 0+1+...+9
}

"""enums loops first break"""
def _enums_loops__enums_loops_first_break(eng: any, _ir: any) {
    f = get_func(eng, "first_break", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 3;  # no break triggered
    assert f(10) == 5;  # breaks at i==5
    assert f(100) == 5;  # breaks at i==5
}

"""enums loops skip even"""
def _enums_loops__enums_loops_skip_even(eng: any, _ir: any) {
    f = get_func(eng, "skip_even", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 25;  # 1+3+5+7+9
    assert f(6) == 9;  # 1+3+5
}

"""enums loops bool and"""
def _enums_loops__enums_loops_bool_and(eng: any, _ir: any) {
    f = get_func(eng, "bool_and", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(1, 1) == 1;
    assert f(1, 0) == 0;
    assert f(0, 1) == 0;
    assert f(0, 0) == 0;
}

"""enums loops bool or"""
def _enums_loops__enums_loops_bool_or(eng: any, _ir: any) {
    f = get_func(eng, "bool_or", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(1, 1) == 1;
    assert f(1, 0) == 1;
    assert f(0, 1) == 1;
    assert f(0, 0) == 0;
}

"""enums loops ternary"""
def _enums_loops__enums_loops_ternary(eng: any, _ir: any) {
    f = get_func(eng, "ternary_test", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10;
    assert f(-5) == -10;
    assert f(0) == -10;
}

# Regression for #6987: a ternary whose two branches need a numeric coercion
# (int<->float, or differing int widths) used to emit the cast into the merge
# block ahead of the phi, so the LLVM verifier rejected the module with "PHI
# nodes not grouped at top of basic block" and native compilation failed. The
# cast now lands in the predecessor block before its branch, leaving the phi at
# the top of the merge block. If the fix regresses, compile_native here fails
# (no native engine) rather than asserting a wrong value.
"""mixed-type ternary coerces in predecessor block (#6987)"""
def _enums_loops__mixed_type_ternary_coerces_in_predecessor_block_6987(
    eng: any, _ir: any
) {
    # float "then" + int "else": int branch promoted to double.
    f1 = get_func(eng, "ternary_int_float_test", ctypes.c_double, ctypes.c_int64);
    assert f1(1) == 1.5;
    assert f1(0) == 2.0;
    # int "then" + float "else": the other predecessor side.
    f2 = get_func(eng, "ternary_float_int_test", ctypes.c_double, ctypes.c_int64);
    assert f2(1) == 2.0;
    assert f2(0) == 1.5;
    # bool "then" (i1) + int "else" (i64): the int-width zext path.
    f3 = get_func(eng, "ternary_widen_test", ctypes.c_int64, ctypes.c_int64);
    assert f3(1) == 1;
    assert f3(0) == 5;
}

test "enums_loops" {
    (_eng, _ir) = compile_native("enums_loops.jac");
    _enums_loops__enums_loops_opposite_color(_eng, _ir);
    _enums_loops__enums_loops_enum_kind(_eng, _ir);
    _enums_loops__enums_loops_sum_range(_eng, _ir);
    _enums_loops__enums_loops_first_break(_eng, _ir);
    _enums_loops__enums_loops_skip_even(_eng, _ir);
    _enums_loops__enums_loops_bool_and(_eng, _ir);
    _enums_loops__enums_loops_bool_or(_eng, _ir);
    _enums_loops__enums_loops_ternary(_eng, _ir);
    _enums_loops__mixed_type_ternary_coerces_in_predecessor_block_6987(_eng, _ir);
}

# --- TestNativeStrings ---
"""strings greet"""
def _strings__strings_greet(eng: any, _ir: any) {
    f = get_sfunc(eng, "greet", ctypes.c_char_p);
    assert f() == b"hello";
}

# Regression for #6442: native must decode numeric/codepoint escapes
# (\xNN, \uXXXX, \U00XXXXXX) identically to the sv pathway (ast.literal_eval),
# per the na ⊆ sv guarantee. Native returns the string as a UTF-8 byte buffer
# (c_char_p), so the expected value is the Python-decoded string, utf-8 encoded.
"""strings numeric escapes decode (na subseteq sv)"""
def _strings__strings_numeric_escapes_decode_na_subseteq_sv(eng: any, _ir: any) {
    f = get_sfunc(eng, "escapes_numeric", ctypes.c_char_p);
    assert f() == "aAbéc😀d".encode("utf-8");
}

"""strings unicode escape decode (na subseteq sv)"""
def _strings__strings_unicode_escape_decode_na_subseteq_sv(eng: any, _ir: any) {
    f = get_sfunc(eng, "escapes_u", ctypes.c_char_p);
    assert f() == "X—Y".encode("utf-8");
}

"""strings simple escapes still decode"""
def _strings__strings_simple_escapes_still_decode(eng: any, _ir: any) {
    f = get_sfunc(eng, "escapes_simple", ctypes.c_char_p);
    assert f() == b"p\tq\nr";
}

"""strings str equal"""
def _strings__strings_str_equal(eng: any, _ir: any) {
    f = get_sfunc(eng, "str_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p);
    assert f(b"hello", b"hello") == 1;
    assert f(b"hello", b"world") == 0;
}

"""strings str not equal"""
def _strings__strings_str_not_equal(eng: any, _ir: any) {
    f = get_sfunc(
        eng, "str_not_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert f(b"hello", b"world") == 1;
    assert f(b"hello", b"hello") == 0;
}

"""strings concat"""
def _strings__strings_concat(eng: any, _ir: any) {
    f = get_sfunc(
        eng, "concat_strings", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
    );
    assert f(b"hello ", b"world") == b"hello world";
}

"""strings fstring int"""
def _strings__strings_fstring_int(eng: any, _ir: any) {
    f = get_sfunc(eng, "format_int", ctypes.c_char_p, ctypes.c_int64);
    assert f(42) == b"val=42";
    assert f(0) == b"val=0";
    assert f(-7) == b"val=-7";
}

"""strings fstring two"""
def _strings__strings_fstring_two(eng: any, _ir: any) {
    f = get_sfunc(eng, "format_two", ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == b"3+4";
    assert f(10, 20) == b"10+20";
}

"""strings fstring mixed"""
def _strings__strings_fstring_mixed(eng: any, _ir: any) {
    f = get_sfunc(
        eng, "format_mixed", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    assert f(b"Alice", 30) == b"name=Alice, age=30";
}

"""strings str replace count arg respected"""
def _strings__strings_str_replace_count_arg_respected(eng: any, _ir: any) {
    f = get_sfunc(eng, "str_replace_first_only", ctypes.c_char_p, ctypes.c_char_p);
    # only the first 'a' should be replaced; remaining 'a's must be untouched
    assert f(b"aaa") == b"Xaa";
    assert f(b"banana") == b"bXnana";
}

"""strings for-in-str join"""
def _strings__strings_for_in_str_join(eng: any, _ir: any) {
    f = get_sfunc(eng, "str_for_in_join", ctypes.c_char_p, ctypes.c_char_p);
    assert f(b"Hello") == b"Hello";
    assert f(b"") == b"";
}

"""strings for-in-str count"""
def _strings__strings_for_in_str_count(eng: any, _ir: any) {
    f = get_sfunc(eng, "str_for_in_count", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"Hello") == 5;
    assert f(b"") == 0;
}

test "strings" {
    (_eng, _ir) = compile_native("strings.jac");
    _strings__strings_greet(_eng, _ir);
    _strings__strings_numeric_escapes_decode_na_subseteq_sv(_eng, _ir);
    _strings__strings_unicode_escape_decode_na_subseteq_sv(_eng, _ir);
    _strings__strings_simple_escapes_still_decode(_eng, _ir);
    _strings__strings_str_equal(_eng, _ir);
    _strings__strings_str_not_equal(_eng, _ir);
    _strings__strings_concat(_eng, _ir);
    _strings__strings_fstring_int(_eng, _ir);
    _strings__strings_fstring_two(_eng, _ir);
    _strings__strings_fstring_mixed(_eng, _ir);
    _strings__strings_str_replace_count_arg_respected(_eng, _ir);
    _strings__strings_for_in_str_join(_eng, _ir);
    _strings__strings_for_in_str_count(_eng, _ir);
}

# str(float) must be CPython's shortest round-trip repr, not %g (#6978 0.3).
# Every value below is compared byte-for-byte against Python's own repr(), so
# fixed vs. exponential notation, the trailing `.0`, -0.0, and inf/nan spelling
# are all held to sv parity.
test "float repr shortest round-trip matches CPython (na == sv) (#6978 0.3)" {
    (eng, _) = compile_native("float_repr.jac");
    f = get_func(eng, "frepr", ctypes.c_char_p, ctypes.c_double);
    cases = [
        0.0,
        1.0,
        -0.0,
        -1.0,
        0.1,
        0.2,
        0.3,
        1.1,
        3.14,
        2.5,
        0.5,
        -2.75,
        100.0,
        1234.5,
        100000.0,
        0.001,
        0.0001,
        0.000123,
        1234567890123456.0,
        123456789.123456789,
        0.1 + 0.2,
        1e16,
        1.5e16,
        1e-5,
        1e-10,
        1e100,
        1e-100,
        1.7976931348623157e308,
        2.2250738585072014e-308,
        5e-324,
        float("inf"),
        float("-inf"),
        float("nan")
    ];
    for v in cases {
        assert f(v) == repr(v).encode("utf-8") , (
            f"str({v!r}): na={f(v)!r} sv={repr(v).encode('utf-8')!r}"
        );
    }
}

# --- TestNativeGetenvDefault (regression: issue #6688) ---
test "os getenv honors default for unset var issue 6688" {
    # `os.getenv(key, default)` ignored its default and returned NULL for an
    # unset var; any downstream string op (`len`/`+`/`!=`) then `strlen`'d NULL
    # and segfaulted at startup. quakepassion's `os.getenv("QP_SMOKE", "") != ""`
    # crashed `./main` instantly (misread as a render-loop use-after-free). The
    # default must now be substituted. GETENV_UNSET_6688 is never set here.
    os.environ.pop("GETENV_UNSET_6688", None);
    (eng, _) = compile_native("fix_getenv_default.jac");
    f1 = get_func(eng, "getenv_unset_string_default", ctypes.c_int64);
    assert f1() == 8 , "os.getenv unset must return the string default ('fallback')";
    f2 = get_func(eng, "getenv_unset_empty_default", ctypes.c_int64);
    assert f2() == 0 , "os.getenv unset must return the empty-string default";
    f3 = get_func(eng, "getenv_unset_concat", ctypes.c_int64);
    assert f3() == 5 , "concatenating an unset os.getenv default must not crash";
}

# UTF-8 byte primitives the rune-aware lexer depends on. bytes.decode() was
# previously unimplemented in native (returned empty); these lock in that
# `s.encode()[a:b].decode()` round-trips and that byte access is portable.
"""bytes utf8 byte_len"""
def _bytes_utf8__bytes_utf8_byte_len(eng: any, _ir: any) {
    f = get_sfunc(eng, "byte_len", ctypes.c_int64, ctypes.c_char_p);
    assert f("café".encode("utf-8")) == 5;
    assert f("日本語".encode("utf-8")) == 9;
    assert f(b"ascii") == 5;
}

"""bytes utf8 byte_at portable"""
def _bytes_utf8__bytes_utf8_byte_at_portable(eng: any, _ir: any) {
    f = get_sfunc(eng, "byte_at", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64);
    enc = "café".encode("utf-8");  # 63 61 66 C3 A9
    for i in range(len(enc)) {
        assert f(enc, i) == enc[i] , f"byte_at({i}) native={f(enc, i)} py={enc[i]}";
    }
}

"""bytes utf8 decode roundtrip and slice"""
def _bytes_utf8__bytes_utf8_decode_roundtrip_and_slice(eng: any, _ir: any) {
    rt = get_sfunc(eng, "roundtrip", ctypes.c_char_p, ctypes.c_char_p);
    assert rt("café".encode("utf-8")) == "café".encode("utf-8");
    sd = get_sfunc(
        eng,
        "slice_decode",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    enc = "café".encode("utf-8");
    assert sd(enc, 0, 3) == b"caf";
    assert sd(enc, 3, 5) == "é".encode("utf-8");
}

test "bytes_utf8" {
    (_eng, _ir) = compile_native("bytes_utf8.jac");
    _bytes_utf8__bytes_utf8_byte_len(_eng, _ir);
    _bytes_utf8__bytes_utf8_byte_at_portable(_eng, _ir);
    _bytes_utf8__bytes_utf8_decode_roundtrip_and_slice(_eng, _ir);
}

# --- TestNativeForTupleUnpack ---
"""for-loop tuple unpack: homogeneous products (issue 7238)"""
def _for_tuple_unpack__for_loop_tuple_unpack_homogeneous_products_issue_7238(
    eng: any, _ir: any
) {
    f = get_func(eng, "run_products", ctypes.c_int64);
    assert f() == 140;
}

"""for-loop tuple unpack: heterogeneous str/bytes lengths (issue 7238)"""
def _for_tuple_unpack__for_loop_tuple_unpack_heterogeneous_str_bytes_lengths_issue_7238(
    eng: any, _ir: any
) {
    f = get_func(eng, "run_str_bytes_lengths", ctypes.c_int64);
    assert f() == 13;
}

"""for-loop tuple unpack: targets reused across loops (issue 7238)"""
def _for_tuple_unpack__for_loop_tuple_unpack_targets_reused_across_loops_issue_7238(
    eng: any, _ir: any
) {
    f = get_func(eng, "run_reuse_across_loops", ctypes.c_int64);
    assert f() == 24;
}

test "for_tuple_unpack" {
    (_eng, _ir) = compile_native("for_tuple_unpack.jac");
    _for_tuple_unpack__for_loop_tuple_unpack_homogeneous_products_issue_7238(_eng, _ir);
    _for_tuple_unpack__for_loop_tuple_unpack_heterogeneous_str_bytes_lengths_issue_7238(
        _eng, _ir
    );
    _for_tuple_unpack__for_loop_tuple_unpack_targets_reused_across_loops_issue_7238(
        _eng, _ir
    );
}

# --- TestNativePrintMultiArgs ---
"""print multi args compiles"""
def _print_multi_args__print_multi_args_compiles(eng: any, _ir: any) {
    assert eng is not None;
}

"""print multi args multiple args"""
def _print_multi_args__print_multi_args_multiple_args(eng: any, _ir: any) {
    f = get_func(eng, "test_multiple_args", ctypes.c_int64);
    assert f() == 0;
}

"""print multi args mixed types"""
def _print_multi_args__print_multi_args_mixed_types(eng: any, _ir: any) {
    f = get_func(eng, "test_mixed_types", ctypes.c_int64);
    assert f() == 0;
}

"""print multi args variables"""
def _print_multi_args__print_multi_args_variables(eng: any, _ir: any) {
    f = get_func(eng, "test_variables", ctypes.c_int64);
    assert f() == 0;
}

"""print multi args single arg"""
def _print_multi_args__print_multi_args_single_arg(eng: any, _ir: any) {
    f = get_func(eng, "test_single_arg", ctypes.c_int64);
    assert f() == 0;
}

"""print multi args many args"""
def _print_multi_args__print_multi_args_many_args(eng: any, _ir: any) {
    f = get_func(eng, "test_many_args", ctypes.c_int64);
    assert f() == 0;
}

test "print_multi_args" {
    (_eng, _ir) = compile_native("print_multi_args.jac");
    _print_multi_args__print_multi_args_compiles(_eng, _ir);
    _print_multi_args__print_multi_args_multiple_args(_eng, _ir);
    _print_multi_args__print_multi_args_mixed_types(_eng, _ir);
    _print_multi_args__print_multi_args_variables(_eng, _ir);
    _print_multi_args__print_multi_args_single_arg(_eng, _ir);
    _print_multi_args__print_multi_args_many_args(_eng, _ir);
}

# --- TestNativeObjects ---
"""objects make point"""
def _objects__objects_make_point(eng: any, _ir: any) {
    # make_point returns a Point* (opaque pointer)
    addr = native_address(eng, unit_sym(_ir, "make_point"));
    assert addr != 0 , "make_point function not found";
}

"""objects point sum"""
def _objects__objects_point_sum(eng: any, _ir: any) {
    f = get_func(eng, "point_sum", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == 7;
    assert f(10, 20) == 30;
    assert f(0, 0) == 0;
    assert f(-5, 5) == 0;
}

"""objects counter"""
def _objects__objects_counter(eng: any, _ir: any) {
    f = get_func(eng, "test_counter", ctypes.c_int64);
    assert f() == 3;
}

"""objects none check"""
def _objects__objects_none_check(eng: any, _ir: any) {
    f = get_func(eng, "test_none", ctypes.c_int64);
    assert f() == 1;
}

"""objects init called"""
def _objects__objects_init_called(eng: any, _ir: any) {
    f = get_func(eng, "test_init_called", ctypes.c_int64);
    assert f() == 42;
}

"""objects init executed"""
def _objects__objects_init_executed(eng: any, _ir: any) {
    f = get_func(eng, "test_init_executed", ctypes.c_int64);
    assert f() == 20;
}

"""objects init no args"""
def _objects__objects_init_no_args(eng: any, _ir: any) {
    f = get_func(eng, "test_init_no_args", ctypes.c_int64);
    assert f() == 99;
}

"""objects init positional"""
def _objects__objects_init_positional(eng: any, _ir: any) {
    f = get_func(eng, "test_init_positional", ctypes.c_int64);
    # KWInit(10, 20) → init adds 1 to each → x=11, y=21 → sum=32
    assert f() == 32;
}

"""objects init side effects"""
def _objects__objects_init_side_effects(eng: any, _ir: any) {
    f = get_func(eng, "test_init_side_effects", ctypes.c_int64);
    assert f() == 1;
}

"""objects empty dict in struct ctor"""
def _objects__objects_empty_dict_in_struct_ctor(eng: any, _ir: any) {
    # Container(entries={}) used to store null → segfault on first dict access.
    f = get_func(eng, "test_empty_dict_ctor_field", ctypes.c_int64);
    assert f() == 30;
}

test "objects" {
    (_eng, _ir) = compile_native("objects.jac");
    _objects__objects_make_point(_eng, _ir);
    _objects__objects_point_sum(_eng, _ir);
    _objects__objects_counter(_eng, _ir);
    _objects__objects_none_check(_eng, _ir);
    _objects__objects_init_called(_eng, _ir);
    _objects__objects_init_executed(_eng, _ir);
    _objects__objects_init_no_args(_eng, _ir);
    _objects__objects_init_positional(_eng, _ir);
    _objects__objects_init_side_effects(_eng, _ir);
    _objects__objects_empty_dict_in_struct_ctor(_eng, _ir);
}

# --- TestNativeOpaqueForeignField (issue #6930, Workstream A3) ---
# A field whose type the native backend cannot model (here `ast3.AST | None`,
# resolved by the checker to `<Unknown> | NoneType`) must lower to a nullable
# opaque slot, null at native construction, rather than rejecting the whole
# declaration with E5090. The native path touches only native fields, so the
# carrier still constructs and its native methods run. This is what keeps
# unitree's ~150 foreign-typed node declarations untouched (Tier-1-only).
"""opaque foreign field: carrier compiles with a native-unmodeled field type"""
def _opaque_field__opaque_foreign_field_carrier_compiles_with_a_native_unmodeled_field_ty(
    eng: any, _ir: any
) {
    f = get_func(eng, "make_name_len", ctypes.c_int64);
    assert f() == 5;  # len("store"), proving native construction + method work
}

"""opaque foreign field: native method reads only native fields"""
def _opaque_field__opaque_foreign_field_native_method_reads_only_native_fields(
    eng: any, _ir: any
) {
    f = get_func(eng, "make_label", ctypes.c_char_p);
    assert f() == b"store";  # py_ctx stays null; label() returns the native field
}

test "opaque_field" {
    (_eng, _ir) = compile_native("opaque_field.jac");
    _opaque_field__opaque_foreign_field_carrier_compiles_with_a_native_unmodeled_field_ty(
        _eng, _ir
    );
    _opaque_field__opaque_foreign_field_native_method_reads_only_native_fields(
        _eng, _ir
    );
}

# --- TestNativeSliceObjectField (issue #6473) ---
"""slice object field roundtrip matches local"""
def _slice_object_field__slice_object_field_roundtrip_matches_local(
    eng: any, _ir: any
) {
    # b.items[:pos] + b.items[pos:] on an object field used to abort (SIGABRT)
    # because the slice was mis-lowered as a plain index. It must now behave
    # identically to the same logic on a plain-list local.
    fld = get_func(eng, "field_roundtrip", ctypes.c_int64, ctypes.c_int64);
    loc = get_func(eng, "local_roundtrip", ctypes.c_int64, ctypes.c_int64);
    for k in [-1, 0, 1, 2, 3, -2] {
        assert fld(k) == 3 , f"field_roundtrip({k}) != 3";
        assert fld(k) == loc(k) , f"field/local mismatch at k={k}";
    }
}

"""slice object field takes correct elements"""
def _slice_object_field__slice_object_field_takes_correct_elements(eng: any, _ir: any) {
    f = get_func(eng, "field_prefix_sum", ctypes.c_int64, ctypes.c_int64);
    # items = [10, 20, 30, 40]
    assert f(0) == 0;
    assert f(1) == 10;
    assert f(2) == 30;
    assert f(3) == 60;
    assert f(4) == 100;
}

"""slice object field osp insert shape"""
def _slice_object_field__slice_object_field_osp_insert_shape(eng: any, _ir: any) {
    # The portable OSP-kernel osp_visit shape: scope.next[:pos] + filtered + scope.next[pos:]
    f = get_func(eng, "osp_insert", ctypes.c_int64, ctypes.c_int64);
    assert f(-1) == 4;  # insert before last
    assert f(0) == 4;  # prepend
    assert f(-100) == 4;  # clamp to 0
    assert f(3) == 4;  # append
}

test "slice_object_field" {
    (_eng, _ir) = compile_native("slice_object_field.jac");
    _slice_object_field__slice_object_field_roundtrip_matches_local(_eng, _ir);
    _slice_object_field__slice_object_field_takes_correct_elements(_eng, _ir);
    _slice_object_field__slice_object_field_osp_insert_shape(_eng, _ir);
}

# --- TestNativeBoxAnyTupleSlot (issue #6511) ---
"""box int into any tuple slot via append"""
def _box_any_tuple_slot__box_int_into_any_tuple_slot_via_append(eng: any, _ir: any) {
    # A concrete int appended in a tuple to a bare list whose slot is `any`
    # (the OSP-kernel work-stack shape) used to be stored unboxed and read back
    # as 0. It must now round-trip through the `any` seam.
    f = get_func(eng, "osp_append_entry", ctypes.c_int64);
    assert f() == 7;
}

"""box int into any tuple slot multiple appends"""
def _box_any_tuple_slot__box_int_into_any_tuple_slot_multiple_appends(
    eng: any, _ir: any
) {
    f = get_func(eng, "many_append_entry", ctypes.c_int64);
    assert f() == 30;
}

"""box int into any tuple slot via list literal"""
def _box_any_tuple_slot__box_int_into_any_tuple_slot_via_list_literal(
    eng: any, _ir: any
) {
    f = get_func(eng, "lit_mix_entry", ctypes.c_int64);
    assert f() == 7;
}

"""box float into any tuple slot"""
def _box_any_tuple_slot__box_float_into_any_tuple_slot(eng: any, _ir: any) {
    f = get_func(eng, "flt_append_entry", ctypes.c_double);
    assert f() == 3.5;
}

"""box any tuple slot via param still works"""
def _box_any_tuple_slot__box_any_tuple_slot_via_param_still_works(eng: any, _ir: any) {
    # The already-working control: an `any` value entering the slot stays boxed.
    f = get_func(eng, "via_param_entry", ctypes.c_int64);
    assert f() == 7;
}

test "box_any_tuple_slot" {
    (_eng, _ir) = compile_native("box_any_tuple_slot.jac");
    _box_any_tuple_slot__box_int_into_any_tuple_slot_via_append(_eng, _ir);
    _box_any_tuple_slot__box_int_into_any_tuple_slot_multiple_appends(_eng, _ir);
    _box_any_tuple_slot__box_int_into_any_tuple_slot_via_list_literal(_eng, _ir);
    _box_any_tuple_slot__box_float_into_any_tuple_slot(_eng, _ir);
    _box_any_tuple_slot__box_any_tuple_slot_via_param_still_works(_eng, _ir);
}

# --- TestNativeInheritance ---
"""inheritance dog speak"""
def _inheritance__inheritance_dog_speak(eng: any, _ir: any) {
    f = get_func(eng, "test_dog_speak", ctypes.c_int64);
    assert f() == 1;
}

"""inheritance cat speak"""
def _inheritance__inheritance_cat_speak(eng: any, _ir: any) {
    f = get_func(eng, "test_cat_speak", ctypes.c_int64);
    assert f() == 2;
}

"""inheritance inherited method"""
def _inheritance__inheritance_inherited_method(eng: any, _ir: any) {
    f = get_func(eng, "test_inherited_method", ctypes.c_int64);
    assert f() == 4;
}

"""inheritance polymorphic"""
def _inheritance__inheritance_polymorphic(eng: any, _ir: any) {
    f = get_func(eng, "test_polymorphic", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 1;  # Dog.speak
    assert f(0) == 2;  # Cat.speak
}

test "inheritance" {
    (_eng, _ir) = compile_native("inheritance.jac");
    _inheritance__inheritance_dog_speak(_eng, _ir);
    _inheritance__inheritance_cat_speak(_eng, _ir);
    _inheritance__inheritance_inherited_method(_eng, _ir);
    _inheritance__inheritance_polymorphic(_eng, _ir);
}

# --- TestMultipleInheritance ---
"""multi-inherit two parent fields"""
def _multi_inherit__multi_inherit_two_parent_fields(eng: any, _ir: any) {
    f = get_func(eng, "test_two_parent_fields", ctypes.c_int64);
    assert f() == 151;
}

"""multi-inherit two parent methods"""
def _multi_inherit__multi_inherit_two_parent_methods(eng: any, _ir: any) {
    f = get_func(eng, "test_two_parent_methods", ctypes.c_int64);
    assert f() == 192;
}

"""multi-inherit diamond field access"""
def _multi_inherit__multi_inherit_diamond_field_access(eng: any, _ir: any) {
    f = get_func(eng, "test_diamond_field_access", ctypes.c_int64);
    assert f() == 130;
}

"""multi-inherit diamond single id"""
def _multi_inherit__multi_inherit_diamond_single_id(eng: any, _ir: any) {
    f = get_func(eng, "test_diamond_single_id", ctypes.c_int64);
    assert f() == 42;
}

"""multi-inherit mro method resolution"""
def _multi_inherit__multi_inherit_mro_method_resolution(eng: any, _ir: any) {
    f = get_func(eng, "test_mro_method_resolution", ctypes.c_int64);
    assert f() == 2;
}

"""multi-inherit three mixins"""
def _multi_inherit__multi_inherit_three_mixins(eng: any, _ir: any) {
    f = get_func(eng, "test_three_mixins", ctypes.c_int64);
    assert f() == 10;
}

test "multi_inherit" {
    (_eng, _ir) = compile_native("multi_inherit.jac");
    _multi_inherit__multi_inherit_two_parent_fields(_eng, _ir);
    _multi_inherit__multi_inherit_two_parent_methods(_eng, _ir);
    _multi_inherit__multi_inherit_diamond_field_access(_eng, _ir);
    _multi_inherit__multi_inherit_diamond_single_id(_eng, _ir);
    _multi_inherit__multi_inherit_mro_method_resolution(_eng, _ir);
    _multi_inherit__multi_inherit_three_mixins(_eng, _ir);
}

# --- TestNativeLists ---
"""lists list len"""
def _lists__lists_list_len(eng: any, _ir: any) {
    f = get_func(eng, "list_len_test", ctypes.c_int64);
    assert f() == 3;
}

"""lists list get"""
def _lists__lists_list_get(eng: any, _ir: any) {
    f = get_func(eng, "list_get_test", ctypes.c_int64);
    assert f() == 20;
}

"""lists list append"""
def _lists__lists_list_append(eng: any, _ir: any) {
    f = get_func(eng, "list_append_test", ctypes.c_int64);
    assert f() == 4;
}

"""lists list sum"""
def _lists__lists_list_sum(eng: any, _ir: any) {
    f = get_func(eng, "list_sum", ctypes.c_int64);
    assert f() == 100;
}

"""lists list set"""
def _lists__lists_list_set(eng: any, _ir: any) {
    f = get_func(eng, "list_set_test", ctypes.c_int64);
    assert f() == 99;
}

test "lists" {
    (_eng, _ir) = compile_native("lists.jac");
    _lists__lists_list_len(_eng, _ir);
    _lists__lists_list_get(_eng, _ir);
    _lists__lists_list_append(_eng, _ir);
    _lists__lists_list_sum(_eng, _ir);
    _lists__lists_list_set(_eng, _ir);
}

# --- TestNativeComplexObjects ---
"""complex objects chained field"""
def _complex_objects__complex_objects_chained_field(eng: any, _ir: any) {
    f = get_func(eng, "test_chained_field", ctypes.c_int64);
    assert f() == 42;
}

"""complex objects chained method"""
def _complex_objects__complex_objects_chained_method(eng: any, _ir: any) {
    f = get_func(eng, "test_chained_method", ctypes.c_int64);
    assert f() == 99;
}

"""complex objects chained method args"""
def _complex_objects__complex_objects_chained_method_args(eng: any, _ir: any) {
    f = get_func(eng, "test_chained_method_args", ctypes.c_int64);
    assert f() == 15;
}

"""complex objects deep chain"""
def _complex_objects__complex_objects_deep_chain(eng: any, _ir: any) {
    f = get_func(eng, "test_deep_chain", ctypes.c_int64);
    assert f() == 14;
}

"""complex objects indexed field"""
def _complex_objects__complex_objects_indexed_field(eng: any, _ir: any) {
    f = get_func(eng, "test_indexed_field", ctypes.c_int64);
    assert f() == 20;
}

"""complex objects indexed field set"""
def _complex_objects__complex_objects_indexed_field_set(eng: any, _ir: any) {
    f = get_func(eng, "test_indexed_field_set", ctypes.c_int64);
    assert f() == 99;
}

"""complex objects field len"""
def _complex_objects__complex_objects_field_len(eng: any, _ir: any) {
    f = get_func(eng, "test_field_len", ctypes.c_int64);
    assert f() == 4;
}

"""complex objects field append"""
def _complex_objects__complex_objects_field_append(eng: any, _ir: any) {
    f = get_func(eng, "test_field_append", ctypes.c_int64);
    assert f() == 3;
}

test "complex_objects" {
    (_eng, _ir) = compile_native("complex_objects.jac");
    _complex_objects__complex_objects_chained_field(_eng, _ir);
    _complex_objects__complex_objects_chained_method(_eng, _ir);
    _complex_objects__complex_objects_chained_method_args(_eng, _ir);
    _complex_objects__complex_objects_deep_chain(_eng, _ir);
    _complex_objects__complex_objects_indexed_field(_eng, _ir);
    _complex_objects__complex_objects_indexed_field_set(_eng, _ir);
    _complex_objects__complex_objects_field_len(_eng, _ir);
    _complex_objects__complex_objects_field_append(_eng, _ir);
}

# --- TestNativeCrossModuleMethods ---
# Regression tests for: _register_imported_archetype must forward-declare all
# archetype methods so that method_funcs["Type.method"] is populated for
# imported types.  Before the fix every cross-module method call was silently
# dropped from the IR (value stayed null/0).
"""cross-module method call once"""
def _na_method_import__cross_module_method_call_once(eng: any, _ir: any) {
    f = get_func(eng, "test_imported_method_once", ctypes.c_int64);
    assert f() == 1;
}

"""cross-module method call five times"""
def _na_method_import__cross_module_method_call_five_times(eng: any, _ir: any) {
    f = get_func(eng, "test_imported_method_five", ctypes.c_int64);
    assert f() == 5;
}

"""cross-module method call with argument"""
def _na_method_import__cross_module_method_call_with_argument(eng: any, _ir: any) {
    f = get_func(eng, "test_imported_method_with_arg", ctypes.c_int64);
    assert f() == 10;
}

"""cross-module chained method calls"""
def _na_method_import__cross_module_chained_method_calls(eng: any, _ir: any) {
    f = get_func(eng, "test_imported_chained_methods", ctypes.c_int64);
    assert f() == 12;
}

test "na_method_import" {
    (_eng, _ir) = compile_native("na_method_import.jac");
    _na_method_import__cross_module_method_call_once(_eng, _ir);
    _na_method_import__cross_module_method_call_five_times(_eng, _ir);
    _na_method_import__cross_module_method_call_with_argument(_eng, _ir);
    _na_method_import__cross_module_chained_method_calls(_eng, _ir);
}

# Regression test for: a TRANSITIVE from-import chain (a -> b -> c) failed
# native lowering with E5092 ("type 'int'") under inferred-native, while a
# flat diamond (a imports b and c directly) lowered fine.
test "cross-module transitive chain executes via native inference" {
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    _prev = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        ir = prog.compile(
            file_path=os.path.join(
                TESTS_DIR,
                "compiler",
                "fixtures",
                "codespace",
                "nadefault_transchain_a.jac"
            ),
            options=CompileOptions(default_codespace="native")
        );
    } finally {
        set_effective_default_codespace(_prev);
    }
    assert not prog.errors_had , (f"errors: {[str(e) for e in prog.errors_had]}");
    eng = ir.gen.native_engine;
    assert eng is not None , "transitive chain did not produce a native engine";
    f = get_func(eng, "fa", ctypes.c_int64);
    assert f() == 5;
}

# --- TestNativeBuiltins ---
"""builtins char at"""
def _builtins__builtins_char_at(eng: any, _ir: any) {
    f = get_func(eng, "test_char_at", ctypes.c_int64);
    assert f() == 101;  # ord('e')
}

"""builtins ord"""
def _builtins__builtins_ord(eng: any, _ir: any) {
    f = get_func(eng, "test_ord", ctypes.c_int64);
    assert f() == 97;  # ord('a')
}

"""builtins int parse"""
def _builtins__builtins_int_parse(eng: any, _ir: any) {
    f = get_func(eng, "test_int_parse", ctypes.c_int64);
    assert f() == 42;
}

"""builtins strip"""
def _builtins__builtins_strip(eng: any, _ir: any) {
    f = get_sfunc(eng, "test_strip", ctypes.c_char_p);
    assert f() == b"hi";
}

"""builtins split len"""
def _builtins__builtins_split_len(eng: any, _ir: any) {
    f = get_func(eng, "test_split_len", ctypes.c_int64);
    assert f() == 3;
}

"""builtins split get"""
def _builtins__builtins_split_get(eng: any, _ir: any) {
    f = get_sfunc(eng, "test_split_get", ctypes.c_char_p);
    assert f() == b"world";
}

"""builtins strip split"""
def _builtins__builtins_strip_split(eng: any, _ir: any) {
    f = get_func(eng, "test_strip_split", ctypes.c_int64);
    assert f() == 2;
}

"""builtins split and slice do not leak (#6814)"""
def _builtins__builtins_split_and_slice_do_not_leak_6814(eng: any, _ir: any) {
    f_split = get_sfunc(
        eng, "split_count", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    f_slice = get_sfunc(eng, "slice_half_len", ctypes.c_int64, ctypes.c_char_p);
    many = b",".join([b"x"] * 200);
    big = b"x" * 10000;
    # Correctness must survive the ownership fix.
    assert f_split(many, b",") == 200;
    assert f_slice(big) == 5000;
    # Warm up the allocator to steady state before sampling, so arena growth is
    # not mistaken for a leak.
    for _w in range(2000) {
        f_split(many, b",");
        f_slice(big);
    }
    base = _rss_kb();
    for _i in range(20000) {
        f_split(many, b",");
        f_slice(big);
    }
    if base >= 0 {
        growth = _rss_kb() - base;
        assert growth < 32768 , (
            f"split/slice leaked: RSS grew {growth} kB over 20k iters "
            f"(expected ~0; unpatched leaks ~350 MB) -- #6814 regressed"
        );
    }
}

test "builtins" {
    (_eng, _ir) = compile_native("builtins.jac");
    _builtins__builtins_char_at(_eng, _ir);
    _builtins__builtins_ord(_eng, _ir);
    _builtins__builtins_int_parse(_eng, _ir);
    _builtins__builtins_strip(_eng, _ir);
    _builtins__builtins_split_len(_eng, _ir);
    _builtins__builtins_split_get(_eng, _ir);
    _builtins__builtins_strip_split(_eng, _ir);
    _builtins__builtins_split_and_slice_do_not_leak_6814(_eng, _ir);
}

# --- TestNativeRuntime ---
"""runtime for list literal"""
def _runtime_validate__runtime_for_list_literal(eng: any, _ir: any) {
    f = get_func(eng, "test_for_list_literal", ctypes.c_int64);
    assert f() == 60;
}

"""runtime for list var"""
def _runtime_validate__runtime_for_list_var(eng: any, _ir: any) {
    f = get_func(eng, "test_for_list_var", ctypes.c_int64);
    assert f() == 15;
}

"""runtime nested list"""
def _runtime_validate__runtime_nested_list(eng: any, _ir: any) {
    f = get_func(eng, "test_nested_list", ctypes.c_int64);
    assert f() == 5;
}

"""runtime nested set"""
def _runtime_validate__runtime_nested_set(eng: any, _ir: any) {
    f = get_func(eng, "test_nested_set", ctypes.c_int64);
    assert f() == 99;
}

"""runtime for nested"""
def _runtime_validate__runtime_for_nested(eng: any, _ir: any) {
    f = get_func(eng, "test_for_nested", ctypes.c_int64);
    assert f() == 0;
}

"""runtime grid init"""
def _runtime_validate__runtime_grid_init(eng: any, _ir: any) {
    f = get_func(eng, "test_grid_init", ctypes.c_int64);
    assert f() == 9;
}

"""runtime grid set get"""
def _runtime_validate__runtime_grid_set_get(eng: any, _ir: any) {
    f = get_func(eng, "test_grid_set_get", ctypes.c_int64);
    assert f() == 42;
}

test "runtime_validate" {
    (_eng, _ir) = compile_native("runtime_validate.jac");
    _runtime_validate__runtime_for_list_literal(_eng, _ir);
    _runtime_validate__runtime_for_list_var(_eng, _ir);
    _runtime_validate__runtime_nested_list(_eng, _ir);
    _runtime_validate__runtime_nested_set(_eng, _ir);
    _runtime_validate__runtime_for_nested(_eng, _ir);
    _runtime_validate__runtime_grid_init(_eng, _ir);
    _runtime_validate__runtime_grid_set_get(_eng, _ir);
}

# --- TestNativeAugAssign ---
"""aug assign add assign"""
def _aug_assign__aug_assign_add_assign(eng: any, _ir: any) {
    f = get_func(eng, "test_add_assign", ctypes.c_int64);
    assert f() == 15;
}

"""aug assign sub assign"""
def _aug_assign__aug_assign_sub_assign(eng: any, _ir: any) {
    f = get_func(eng, "test_sub_assign", ctypes.c_int64);
    assert f() == 63;
}

"""aug assign mul assign"""
def _aug_assign__aug_assign_mul_assign(eng: any, _ir: any) {
    f = get_func(eng, "test_mul_assign", ctypes.c_int64);
    assert f() == 42;
}

"""aug assign div assign"""
def _aug_assign__aug_assign_div_assign(eng: any, _ir: any) {
    f = get_func(eng, "test_div_assign", ctypes.c_int64);
    assert f() == 9;
}

"""aug assign mod assign"""
def _aug_assign__aug_assign_mod_assign(eng: any, _ir: any) {
    f = get_func(eng, "test_mod_assign", ctypes.c_int64);
    assert f() == 2;
}

"""aug assign chained aug"""
def _aug_assign__aug_assign_chained_aug(eng: any, _ir: any) {
    f = get_func(eng, "test_chained_aug", ctypes.c_int64);
    assert f() == 8;  # (1+2)*3 - 1
}

"""aug assign aug in while"""
def _aug_assign__aug_assign_aug_in_while(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_in_while", ctypes.c_int64);
    assert f() == 45;  # 0+1+2+...+9
}

"""aug assign aug in for"""
def _aug_assign__aug_assign_aug_in_for(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_in_for", ctypes.c_int64);
    assert f() == 45;  # 0+1+2+...+9
}

"""forever loop with break"""
def _aug_assign__forever_loop_with_break(eng: any, _ir: any) {
    f = get_func(eng, "test_forever_break", ctypes.c_int64);
    assert f() == 45;  # 0+1+2+...+9, then break
}

"""forever loop with continue"""
def _aug_assign__forever_loop_with_continue(eng: any, _ir: any) {
    f = get_func(eng, "test_forever_continue", ctypes.c_int64);
    assert f() == 30;  # 2+4+6+8+10, odds skipped via continue
}

"""aug assign aug conditional"""
def _aug_assign__aug_assign_aug_conditional(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_conditional", ctypes.c_int64);
    assert f() == 2025;  # even=20, odd=25 -> 20*100+25
}

"""aug assign aug nested loops"""
def _aug_assign__aug_assign_aug_nested_loops(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_nested_loops", ctypes.c_int64);
    assert f() == 25;  # 5*5
}

"""aug assign aug float add"""
def _aug_assign__aug_assign_aug_float_add(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_float_add", ctypes.c_double);
    assert abs(f() - 4.0) < 1e-10;
}

"""aug assign aug float mul"""
def _aug_assign__aug_assign_aug_float_mul(eng: any, _ir: any) {
    f = get_func(eng, "test_aug_float_mul", ctypes.c_double);
    assert abs(f() - 7.5) < 1e-10;
}

"""aug assign count primes"""
def _aug_assign__aug_assign_count_primes(eng: any, _ir: any) {
    # Count first 10 primes using += in nested while loops.
    f = get_func(eng, "test_count_primes", ctypes.c_int64);
    assert f() == 29;  # 10th prime
}

test "aug_assign" {
    (_eng, _ir) = compile_native("aug_assign.jac");
    _aug_assign__aug_assign_add_assign(_eng, _ir);
    _aug_assign__aug_assign_sub_assign(_eng, _ir);
    _aug_assign__aug_assign_mul_assign(_eng, _ir);
    _aug_assign__aug_assign_div_assign(_eng, _ir);
    _aug_assign__aug_assign_mod_assign(_eng, _ir);
    _aug_assign__aug_assign_chained_aug(_eng, _ir);
    _aug_assign__aug_assign_aug_in_while(_eng, _ir);
    _aug_assign__aug_assign_aug_in_for(_eng, _ir);
    _aug_assign__forever_loop_with_break(_eng, _ir);
    _aug_assign__forever_loop_with_continue(_eng, _ir);
    _aug_assign__aug_assign_aug_conditional(_eng, _ir);
    _aug_assign__aug_assign_aug_nested_loops(_eng, _ir);
    _aug_assign__aug_assign_aug_float_add(_eng, _ir);
    _aug_assign__aug_assign_aug_float_mul(_eng, _ir);
    _aug_assign__aug_assign_count_primes(_eng, _ir);
}

test "chess compiles" {
    (eng, ir) = compile_native("chess.jac");
    assert ir.gen.llvm_ir is not None;
}

test "chess opposite color" {
    (eng, _ir) = compile_native("chess.jac");
    opp = get_func(eng, "opposite_color", ctypes.c_int64, ctypes.c_int64);
    assert opp(0) == 1;  # WHITE -> BLACK
    assert opp(1) == 0;  # BLACK -> WHITE
}

test "chess create piece" {
    (eng, _ir) = compile_native("chess.jac");
    addr = native_address(eng, unit_sym(_ir, "create_piece"));
    assert addr != 0;
}

test "chess has entry" {
    (eng, _ir) = compile_native("chess.jac");
    addr = native_address(eng, "jac_entry");
    assert addr != 0;
}

test "chess all piece types" {
    (eng, _ir) = compile_native("chess.jac");
    # Verify all piece class methods are callable.
    piece_types = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"];
    for piece_type in piece_types {
        addr = native_address(eng, unit_sym(_ir, f"{piece_type}.get_symbol"));
        assert addr != 0 , f"{piece_type}.get_symbol not found";
    }
}

test "chess board methods" {
    (eng, _ir) = compile_native("chess.jac");
    # Verify Board methods are callable.
    methods = [
        "Board.is_valid_pos",
        "Board.get_piece",
        "Board.set_piece",
        "Board.make_move",
        "Board.undo_move",
        "Board.display"
    ];
    for method in methods {
        addr = native_address(eng, unit_sym(_ir, method));
        assert addr != 0 , f"{method} not found";
    }
}

test "chess game methods" {
    (eng, _ir) = compile_native("chess.jac");
    # Verify Game methods are callable.
    methods = [
        "Game.find_king",
        "Game.is_in_check",
        "Game.get_legal_moves",
        "Game.is_checkmate",
        "Game.is_stalemate",
        "Game.parse_input"
    ];
    for method in methods {
        addr = native_address(eng, unit_sym(_ir, method));
        assert addr != 0 , f"{method} not found";
    }
}

test "chess play random moves stress" {
    # Stress test: play 20 random moves then quit.
    # Exercises global dict GC root survival, tuple-keyed dict access,
    # and repeated make_move/undo_move cycles across many game iterations.
    chess_path = os.path.join(FIXTURES, "chess.jac");
    # 20 blank lines (random moves) followed by "quit"
    stdin_data = "\n" * 20 + "quit\n";
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", chess_path],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=120
    );
    assert result.returncode == 0 , (
        f"Chess crashed with exit code {result.returncode}.\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
    assert "Game ended." in result.stdout , (
        "Expected 'Game ended.' in output.\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
}

# --- TestNativeClassName (issue #6930 workstream A2) ---
"""class name: __class__.__name__ is polymorphic over subclasses"""
def _class_name__class_name_class_name_is_polymorphic_over_subclasses(
    eng: any, _ir: any
) {
    # `kind` is defined only on the base `Widget`, so a subclass instance must
    # recover its own runtime class name through the vtable, not freeze to the
    # declaring class. Before A2 these reads E5090'd ("attribute access
    # '__name__'"); now they lower to the per-class name.
    bk = get_func(eng, "button_kind", ctypes.c_char_p);
    sk = get_func(eng, "slider_kind", ctypes.c_char_p);
    wk = get_func(eng, "widget_kind", ctypes.c_char_p);
    assert bk() == b"Button";
    assert sk() == b"Slider";
    assert wk() == b"Widget";
}

"""class name: type(self).__name__ matches __class__.__name__"""
def _class_name__class_name_type_self_name_matches_class_name(eng: any, _ir: any) {
    f = get_func(eng, "button_kind_via_type", ctypes.c_char_p);
    assert f() == b"Button";
}

"""class name: vtable-less class lowers to a constant name"""
def _class_name__class_name_vtable_less_class_lowers_to_a_constant_name(
    eng: any, _ir: any
) {
    # `Lone` has no parents and no subclasses, so it carries no vtable; the
    # access lowers to a constant load rather than a vtable read.
    f = get_func(eng, "lone_kind", ctypes.c_char_p);
    assert f() == b"Lone";
}

"""class name: method-less vtable hierarchy still reads its own name"""
def _class_name__class_name_method_less_vtable_hierarchy_still_reads_its_own_name(
    eng: any, _ir: any
) {
    # `Tag`/`SubA`/`SubB` declare no methods, so their vtable method layout is
    # empty -- but `Tag` is still vtable-flagged (it has subclasses). The vtable
    # must be emitted anyway so the per-class name slot exists; otherwise reading
    # `t.__class__.__name__` off a base-typed receiver dereferences an
    # uninitialized field-0 slot (segfault, PR #6933 review).
    a = get_func(eng, "suba_name", ctypes.c_char_p);
    b = get_func(eng, "subb_name", ctypes.c_char_p);
    assert a() == b"SubA";
    assert b() == b"SubB";
}

test "class_name" {
    (_eng, _ir) = compile_native("class_name.jac");
    _class_name__class_name_class_name_is_polymorphic_over_subclasses(_eng, _ir);
    _class_name__class_name_type_self_name_matches_class_name(_eng, _ir);
    _class_name__class_name_vtable_less_class_lowers_to_a_constant_name(_eng, _ir);
    _class_name__class_name_method_less_vtable_hierarchy_still_reads_its_own_name(
        _eng, _ir
    );
}

# --- TestNativeIsinstanceUserArchetype (issue #6930, workstream A1) ---
"""isinstance user compiles"""
def _isinstance_user__isinstance_user_compiles(eng: any, ir: any) {
    assert ir.gen.llvm_ir is not None;
}

"""isinstance user exact and subclass match"""
def _isinstance_user__isinstance_user_exact_and_subclass_match(eng: any, _ir: any) {
    # 0=Shape, 1=Circle, 2=Square, 3=ColoredSquare(<:Square).
    f = get_func(eng, "test_kind", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0;  # Shape: neither Circle nor Square
    assert f(1) == 1;  # Circle
    assert f(2) == 2;  # Square
    assert f(3) == 2;  # ColoredSquare matches Square via inheritance
}

"""isinstance user narrowed field access"""
def _isinstance_user__isinstance_user_narrowed_field_access(eng: any, _ir: any) {
    # After `isinstance(s, Square)`, `s.side` must resolve to a field offset.
    f = get_func(eng, "test_side", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == -1;  # Shape: not a Square
    assert f(1) == -1;  # Circle: not a Square
    assert f(2) == 3;  # Square(side=3)
    assert f(3) == 4;  # ColoredSquare(side=4): inherited `side` offset holds
}

"""isinstance user tuple of classes"""
def _isinstance_user__isinstance_user_tuple_of_classes(eng: any, _ir: any) {
    f = get_func(eng, "test_round_or_square", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0;  # Shape
    assert f(1) == 1;  # Circle
    assert f(2) == 1;  # Square
    assert f(3) == 1;  # ColoredSquare (<: Square)
}

"""isinstance user no-vtable operand is clean false"""
def _isinstance_user__isinstance_user_no_vtable_operand_is_clean_false(
    eng: any, _ir: any
) {
    # A standalone struct (no vtable) checked against a vtable class must be a
    # principled False, never a garbage read of its first user field.
    f = get_func(eng, "test_loose_not_square", ctypes.c_int64);
    assert f() == 0;
}

test "isinstance_user" {
    (_eng, _ir) = compile_native("isinstance_user.jac");
    _isinstance_user__isinstance_user_compiles(_eng, _ir);
    _isinstance_user__isinstance_user_exact_and_subclass_match(_eng, _ir);
    _isinstance_user__isinstance_user_narrowed_field_access(_eng, _ir);
    _isinstance_user__isinstance_user_tuple_of_classes(_eng, _ir);
    _isinstance_user__isinstance_user_no_vtable_operand_is_clean_false(_eng, _ir);
}

test "dicts dict new empty" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_new_empty", ctypes.c_int64);
    assert f() == 0;
}

test "dicts dict literal len" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_literal_len", ctypes.c_int64);
    assert f() == 3;
}

test "dicts dict get value" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_value", ctypes.c_int64);
    assert f() == 200;
}

test "dicts dict set value" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_set_value", ctypes.c_int64);
    assert f() == 20;
}

test "dicts dict update value" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_update_value", ctypes.c_int64);
    assert f() == 99;
}

test "dicts dict len after set" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_len_after_set", ctypes.c_int64);
    assert f() == 3;
}

test "dicts dict contains true" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_contains_true", ctypes.c_int64);
    assert f() == 1;
}

test "dicts dict contains false" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_contains_false", ctypes.c_int64);
    assert f() == 0;
}

test "dicts dict string keys" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_string_keys", ctypes.c_int64);
    assert f() == 2;
}

test "dicts dict string values" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_string_values", ctypes.c_char_p);
    result = f();
    assert result == b"two";
}

test "dicts dict sum values" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_sum_values", ctypes.c_int64);
    assert f() == 100;
}

test "dicts dict overwrite" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_overwrite", ctypes.c_int64);
    assert f() == 30;
}

test "dicts dict multiple types" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_multiple_types", ctypes.c_int64);
    assert f() == 300;
}

test "dicts dict get first" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_first", ctypes.c_int64);
    assert f() == 100;
}

test "dicts dict get third" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_third", ctypes.c_int64);
    assert f() == 300;
}

test "dicts dict set then get" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_set_then_get", ctypes.c_int64);
    assert f() == 1500;
}

test "dicts global dict get" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    # Need to call jac_entry first to initialize globals
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get", ctypes.c_int64);
    assert f() == 200;
}

test "dicts global dict len" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_len", ctypes.c_int64);
    assert f() == 3;
}

test "sets set new empty" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_new_empty", ctypes.c_int64);
    assert f() == 0;
}

test "sets set literal len" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_literal_len", ctypes.c_int64);
    assert f() == 5;
}

test "sets set add element" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_add_element", ctypes.c_int64);
    assert f() == 4;
}

test "sets set add duplicate" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_add_duplicate", ctypes.c_int64);
    assert f() == 3;  # Duplicates shouldn't increase length
}

test "sets set contains true" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_contains_true", ctypes.c_int64);
    assert f() == 1;
}

test "sets set contains false" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_contains_false", ctypes.c_int64);
    assert f() == 0;
}

test "sets set string elements" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_string_elements", ctypes.c_int64);
    assert f() == 1;
}

test "sets set multiple adds" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "set_multiple_adds", ctypes.c_int64);
    assert f() == 3;  # 1, 2, 3 (duplicates ignored)
}

test "sets global set contains" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_set_contains", ctypes.c_int64);
    assert f() == 1;
}

test "sets global set len" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_set_len", ctypes.c_int64);
    assert f() == 5;
}

test "dicts items iteration sum" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_items_iter_sum", ctypes.c_int64);
    assert f() == 60;
}

test "dicts empty glob dict set and get" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    # glob x: dict[K,V] = {} previously left the global as null -> segfault on first access.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "empty_glob_dict_set_get", ctypes.c_int64);
    assert f() == 7;
}

test "dicts dict remove method" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_remove_method", ctypes.c_int64);
    assert f() == 1;  # key must be absent after .remove()
}

test "dicts dict delete keyword" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_delete_keyword", ctypes.c_int64);
    assert f() == 1;  # key must be absent after del d[k]
}

test "dicts dict.get found" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_found", ctypes.c_int64);
    assert f() == 10 , f"Expected 10, got {f()}";
}

test "dicts dict.get not found" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_notfound", ctypes.c_int64);
    assert f() == -99 , f"Expected -99, got {f()}";
}

test "dicts dict.get no default" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    f = get_func(eng, "dict_get_no_default", ctypes.c_int64);
    assert f() == 100 , f"Expected 100, got {f()}";
}

test "dicts global dict.get method" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get_method", ctypes.c_int64);
    assert f() == 200 , f"Expected 200, got {f()}";
}

test "dicts global dict.get not found method" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get_notfound_method", ctypes.c_int64);
    assert f() == -42 , f"Expected -42, got {f()}";
}

test "dicts for-in-dict param iteration" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    # for k in d where d is a dict parameter was always elided (body never ran).
    f = get_func(eng, "dict_param_iter_sum_fixture", ctypes.c_int64);
    assert f() == 60;
}

test "dicts for-in-dict field access iteration" {
    (eng, _ir) = compile_native("dicts_sets.jac");
    # for k in c.props where c is a struct with a dict field used to segfault
    # because the AtomTrailer expression had no bare name to look up in var_dict_type.
    f = get_func(eng, "dict_field_iter_sum_fixture", ctypes.c_int64);
    assert f() == 60;
}

# --- TestNativeExceptions ---
"""exceptions basic try except"""
def _exceptions__exceptions_basic_try_except(eng: any, _ir: any) {
    f = get_func(eng, "test_basic_try_except", ctypes.c_int64);
    assert f() == 2;
}

"""exceptions try no exception"""
def _exceptions__exceptions_try_no_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_try_no_exception", ctypes.c_int64);
    assert f() == 42;
}

"""exceptions except as binding"""
def _exceptions__exceptions_except_as_binding(eng: any, _ir: any) {
    f = get_func(eng, "test_except_as_binding", ctypes.c_char_p);
    assert f() == b"caught me";
}

"""exceptions try else no exception"""
def _exceptions__exceptions_try_else_no_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_try_else_no_exception", ctypes.c_int64);
    assert f() == 11;
}

"""exceptions try else with exception"""
def _exceptions__exceptions_try_else_with_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_try_else_with_exception", ctypes.c_int64);
    assert f() == 5;
}

"""exceptions try finally"""
def _exceptions__exceptions_try_finally(eng: any, _ir: any) {
    f = get_func(eng, "test_try_finally", ctypes.c_int64);
    assert f() == 111;
}

"""exceptions try finally no exception"""
def _exceptions__exceptions_try_finally_no_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_try_finally_no_exception", ctypes.c_int64);
    assert f() == 105;
}

"""exceptions multiple except"""
def _exceptions__exceptions_multiple_except(eng: any, _ir: any) {
    f = get_func(eng, "test_multiple_except", ctypes.c_int64);
    assert f() == 2;
}

"""exceptions catch all"""
def _exceptions__exceptions_catch_all(eng: any, _ir: any) {
    f = get_func(eng, "test_catch_all", ctypes.c_int64);
    assert f() == 42;
}

"""exceptions nested try"""
def _exceptions__exceptions_nested_try(eng: any, _ir: any) {
    f = get_func(eng, "test_nested_try", ctypes.c_int64);
    assert f() == 111;
}

"""exceptions raise func form"""
def _exceptions__exceptions_raise_func_form(eng: any, _ir: any) {
    f = get_func(eng, "test_raise_func_form", ctypes.c_int64);
    assert f() == 77;
}

"""exceptions full combo no exc"""
def _exceptions__exceptions_full_combo_no_exc(eng: any, _ir: any) {
    f = get_func(eng, "test_full_combo_no_exc", ctypes.c_int64);
    assert f() == 321;
}

test "exceptions" {
    (_eng, _ir) = compile_native("exceptions.jac");
    _exceptions__exceptions_basic_try_except(_eng, _ir);
    _exceptions__exceptions_try_no_exception(_eng, _ir);
    _exceptions__exceptions_except_as_binding(_eng, _ir);
    _exceptions__exceptions_try_else_no_exception(_eng, _ir);
    _exceptions__exceptions_try_else_with_exception(_eng, _ir);
    _exceptions__exceptions_try_finally(_eng, _ir);
    _exceptions__exceptions_try_finally_no_exception(_eng, _ir);
    _exceptions__exceptions_multiple_except(_eng, _ir);
    _exceptions__exceptions_catch_all(_eng, _ir);
    _exceptions__exceptions_nested_try(_eng, _ir);
    _exceptions__exceptions_raise_func_form(_eng, _ir);
    _exceptions__exceptions_full_combo_no_exc(_eng, _ir);
}

# --- TestNativeFileIO ---
"""file io open write"""
def _file_io__file_io_open_write(eng: any, _ir: any) {
    f = get_func(eng, "test_open_write", ctypes.c_int64);
    assert f() == 1;
}

"""file io write file"""
def _file_io__file_io_write_file(eng: any, _ir: any) {
    f = get_func(eng, "test_write_file", ctypes.c_int64);
    assert f() == 11;
}

"""file io write read"""
def _file_io__file_io_write_read(eng: any, _ir: any) {
    f = get_func(eng, "test_write_read", ctypes.c_char_p);
    assert f() == b"NativeIO";
}

"""file io readline"""
def _file_io__file_io_readline(eng: any, _ir: any) {
    f = get_func(eng, "test_readline", ctypes.c_char_p);
    assert f() == b"line1\n";
}

"""file io close idempotent"""
def _file_io__file_io_close_idempotent(eng: any, _ir: any) {
    f = get_func(eng, "test_close_idempotent", ctypes.c_int64);
    assert f() == 1;
}

"""file io open nonexistent"""
def _file_io__file_io_open_nonexistent(eng: any, _ir: any) {
    f = get_func(eng, "test_open_nonexistent", ctypes.c_int64);
    assert f() == 1;
}

"""file io file methods exist"""
def _file_io__file_io_file_methods_exist(eng: any, _ir: any) {
    f = get_func(eng, "test_file_methods_exist", ctypes.c_int64);
    assert f() == 1;
}

test "file_io" {
    (_eng, _ir) = compile_native("file_io.jac");
    _file_io__file_io_open_write(_eng, _ir);
    _file_io__file_io_write_file(_eng, _ir);
    _file_io__file_io_write_read(_eng, _ir);
    _file_io__file_io_readline(_eng, _ir);
    _file_io__file_io_close_idempotent(_eng, _ir);
    _file_io__file_io_open_nonexistent(_eng, _ir);
    _file_io__file_io_file_methods_exist(_eng, _ir);
}

# --- TestNativeContextManagers ---
"""context managers with enter"""
def _context_mgr__context_managers_with_enter(eng: any, _ir: any) {
    f = get_func(eng, "test_with_enter", ctypes.c_int64);
    assert f() == 1;
}

"""context managers with exit"""
def _context_mgr__context_managers_with_exit(eng: any, _ir: any) {
    f = get_func(eng, "test_with_exit", ctypes.c_int64);
    assert f() == 1;
}

"""context managers with body"""
def _context_mgr__context_managers_with_body(eng: any, _ir: any) {
    f = get_func(eng, "test_with_body", ctypes.c_int64);
    assert f() == 99;
}

"""context managers with as binding"""
def _context_mgr__context_managers_with_as_binding(eng: any, _ir: any) {
    f = get_func(eng, "test_with_as_binding", ctypes.c_int64);
    assert f() == 77;
}

"""context managers file context manager"""
def _context_mgr__context_managers_file_context_manager(eng: any, _ir: any) {
    f = get_func(eng, "test_file_context_manager", ctypes.c_int64);
    assert f() == 1;
}

"""context managers with enter exit once"""
def _context_mgr__context_managers_with_enter_exit_once(eng: any, _ir: any) {
    f = get_func(eng, "test_with_enter_exit_once", ctypes.c_int64);
    assert f() == 101;
}

test "context_mgr" {
    (_eng, _ir) = compile_native("context_mgr.jac");
    _context_mgr__context_managers_with_enter(_eng, _ir);
    _context_mgr__context_managers_with_exit(_eng, _ir);
    _context_mgr__context_managers_with_body(_eng, _ir);
    _context_mgr__context_managers_with_as_binding(_eng, _ir);
    _context_mgr__context_managers_file_context_manager(_eng, _ir);
    _context_mgr__context_managers_with_enter_exit_once(_eng, _ir);
}

# --- TestNativeRuntimeErrors ---

# -- ZeroDivisionError --
"""runtime errors int div by zero"""
def _runtime_errors__runtime_errors_int_div_by_zero(eng: any, _ir: any) {
    f = get_func(eng, "test_int_div_by_zero", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors int mod by zero"""
def _runtime_errors__runtime_errors_int_mod_by_zero(eng: any, _ir: any) {
    f = get_func(eng, "test_int_mod_by_zero", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors div by zero var"""
def _runtime_errors__runtime_errors_div_by_zero_var(eng: any, _ir: any) {
    f = get_func(eng, "test_div_by_zero_var", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors float div by zero"""
def _runtime_errors__runtime_errors_float_div_by_zero(eng: any, _ir: any) {
    f = get_func(eng, "test_float_div_by_zero", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors div no error"""
def _runtime_errors__runtime_errors_div_no_error(eng: any, _ir: any) {
    f = get_func(eng, "test_div_no_error", ctypes.c_int64);
    assert f() == 5;
}

# -- IndexError --
"""runtime errors list index oob"""
def _runtime_errors__runtime_errors_list_index_oob(eng: any, _ir: any) {
    f = get_func(eng, "test_list_index_oob", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors list negative index"""
def _runtime_errors__runtime_errors_list_negative_index(eng: any, _ir: any) {
    f = get_func(eng, "test_list_negative_index", ctypes.c_int64);
    assert f() == 1;
}

"""list valid negative index"""
def _runtime_errors__list_valid_negative_index(eng: any, _ir: any) {
    f = get_func(eng, "test_list_negative_valid", ctypes.c_int64);
    assert f() == 30;
}

"""runtime errors list index at len"""
def _runtime_errors__runtime_errors_list_index_at_len(eng: any, _ir: any) {
    f = get_func(eng, "test_list_index_at_len", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors list valid index"""
def _runtime_errors__runtime_errors_list_valid_index(eng: any, _ir: any) {
    f = get_func(eng, "test_list_valid_index", ctypes.c_int64);
    assert f() == 20;
}

"""runtime errors list set oob"""
def _runtime_errors__runtime_errors_list_set_oob(eng: any, _ir: any) {
    f = get_func(eng, "test_list_set_oob", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors empty list access"""
def _runtime_errors__runtime_errors_empty_list_access(eng: any, _ir: any) {
    f = get_func(eng, "test_empty_list_access", ctypes.c_int64);
    assert f() == 1;
}

# -- KeyError --
"""runtime errors dict missing key"""
def _runtime_errors__runtime_errors_dict_missing_key(eng: any, _ir: any) {
    f = get_func(eng, "test_dict_missing_key", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors dict valid key"""
def _runtime_errors__runtime_errors_dict_valid_key(eng: any, _ir: any) {
    f = get_func(eng, "test_dict_valid_key", ctypes.c_int64);
    assert f() == 2;
}

"""runtime errors dict int missing key"""
def _runtime_errors__runtime_errors_dict_int_missing_key(eng: any, _ir: any) {
    f = get_func(eng, "test_dict_int_missing_key", ctypes.c_int64);
    assert f() == 1;
}

# -- OverflowError --
"""runtime errors int add overflow"""
def _runtime_errors__runtime_errors_int_add_overflow(eng: any, _ir: any) {
    f = get_func(eng, "test_int_add_overflow", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors int sub underflow"""
def _runtime_errors__runtime_errors_int_sub_underflow(eng: any, _ir: any) {
    f = get_func(eng, "test_int_sub_underflow", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors int mul overflow"""
def _runtime_errors__runtime_errors_int_mul_overflow(eng: any, _ir: any) {
    f = get_func(eng, "test_int_mul_overflow", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors int no overflow"""
def _runtime_errors__runtime_errors_int_no_overflow(eng: any, _ir: any) {
    f = get_func(eng, "test_int_no_overflow", ctypes.c_int64);
    assert f() == 1;
}

# -- AttributeError (None dereference) --
"""runtime errors none field access"""
def _runtime_errors__runtime_errors_none_field_access(eng: any, _ir: any) {
    f = get_func(eng, "test_none_field_access", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors none method call"""
def _runtime_errors__runtime_errors_none_method_call(eng: any, _ir: any) {
    f = get_func(eng, "test_none_method_call", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors valid obj access"""
def _runtime_errors__runtime_errors_valid_obj_access(eng: any, _ir: any) {
    f = get_func(eng, "test_valid_obj_access", ctypes.c_int64);
    assert f() == 42;
}

# -- ValueError --
"""runtime errors int parse invalid"""
def _runtime_errors__runtime_errors_int_parse_invalid(eng: any, _ir: any) {
    f = get_func(eng, "test_int_parse_invalid", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors int parse valid"""
def _runtime_errors__runtime_errors_int_parse_valid(eng: any, _ir: any) {
    f = get_func(eng, "test_int_parse_valid", ctypes.c_int64);
    assert f() == 123;
}

"""runtime errors int parse empty"""
def _runtime_errors__runtime_errors_int_parse_empty(eng: any, _ir: any) {
    f = get_func(eng, "test_int_parse_empty", ctypes.c_int64);
    assert f() == 1;
}

# -- AssertionError --
"""runtime errors assert false"""
def _runtime_errors__runtime_errors_assert_false(eng: any, _ir: any) {
    f = get_func(eng, "test_assert_false", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors assert true"""
def _runtime_errors__runtime_errors_assert_true(eng: any, _ir: any) {
    f = get_func(eng, "test_assert_true", ctypes.c_int64);
    assert f() == 1;
}

# -- MemoryError --
"""runtime errors alloc ok"""
def _runtime_errors__runtime_errors_alloc_ok(eng: any, _ir: any) {
    f = get_func(eng, "test_alloc_ok", ctypes.c_int64);
    assert f() == 1;
}

# -- Combined / edge cases --
"""runtime errors catch base exception"""
def _runtime_errors__runtime_errors_catch_base_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_catch_base_exception", ctypes.c_int64);
    assert f() == 1;
}

"""runtime errors sequential errors"""
def _runtime_errors__runtime_errors_sequential_errors(eng: any, _ir: any) {
    f = get_func(eng, "test_sequential_errors", ctypes.c_int64);
    assert f() == 11;
}

"""runtime errors error in loop"""
def _runtime_errors__runtime_errors_error_in_loop(eng: any, _ir: any) {
    f = get_func(eng, "test_error_in_loop", ctypes.c_int64);
    assert f() == 1;
}

test "runtime_errors" {
    (_eng, _ir) = compile_native("runtime_errors.jac");
    _runtime_errors__runtime_errors_int_div_by_zero(_eng, _ir);
    _runtime_errors__runtime_errors_int_mod_by_zero(_eng, _ir);
    _runtime_errors__runtime_errors_div_by_zero_var(_eng, _ir);
    _runtime_errors__runtime_errors_float_div_by_zero(_eng, _ir);
    _runtime_errors__runtime_errors_div_no_error(_eng, _ir);
    _runtime_errors__runtime_errors_list_index_oob(_eng, _ir);
    _runtime_errors__runtime_errors_list_negative_index(_eng, _ir);
    _runtime_errors__list_valid_negative_index(_eng, _ir);
    _runtime_errors__runtime_errors_list_index_at_len(_eng, _ir);
    _runtime_errors__runtime_errors_list_valid_index(_eng, _ir);
    _runtime_errors__runtime_errors_list_set_oob(_eng, _ir);
    _runtime_errors__runtime_errors_empty_list_access(_eng, _ir);
    _runtime_errors__runtime_errors_dict_missing_key(_eng, _ir);
    _runtime_errors__runtime_errors_dict_valid_key(_eng, _ir);
    _runtime_errors__runtime_errors_dict_int_missing_key(_eng, _ir);
    _runtime_errors__runtime_errors_int_add_overflow(_eng, _ir);
    _runtime_errors__runtime_errors_int_sub_underflow(_eng, _ir);
    _runtime_errors__runtime_errors_int_mul_overflow(_eng, _ir);
    _runtime_errors__runtime_errors_int_no_overflow(_eng, _ir);
    _runtime_errors__runtime_errors_none_field_access(_eng, _ir);
    _runtime_errors__runtime_errors_none_method_call(_eng, _ir);
    _runtime_errors__runtime_errors_valid_obj_access(_eng, _ir);
    _runtime_errors__runtime_errors_int_parse_invalid(_eng, _ir);
    _runtime_errors__runtime_errors_int_parse_valid(_eng, _ir);
    _runtime_errors__runtime_errors_int_parse_empty(_eng, _ir);
    _runtime_errors__runtime_errors_assert_false(_eng, _ir);
    _runtime_errors__runtime_errors_assert_true(_eng, _ir);
    _runtime_errors__runtime_errors_alloc_ok(_eng, _ir);
    _runtime_errors__runtime_errors_catch_base_exception(_eng, _ir);
    _runtime_errors__runtime_errors_sequential_errors(_eng, _ir);
    _runtime_errors__runtime_errors_error_in_loop(_eng, _ir);
}

test "list method on object field (pop)" {
    (eng, _) = compile_native("list_field_methods.jac");
    # pop() on a field list must shrink it: depth 2 -> 1 encodes as 21.
    f = get_func(eng, "field_pop_shrinks", ctypes.c_int64);
    assert f() == 21;
}

# --- TestNativePyInterop ---
test "py interop interop module compiles" {
    # Module with na block, Python functions, and entry compiles.
    prog = JacProgram();
    prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
}

test "py interop native function exists in engine" {
    # Native function from na block is available in the JIT engine under
    # the unit's prefix (it is not `:pub`).
    (eng, ir) = compile_native("na_py_interop.jac");
    addr = native_address(eng, unit_sym(ir, "native_add_one_to_doubled"));
    assert addr != 0 , "native_add_one_to_doubled not found in JIT engine";
}

test "py interop py function not defined in native ir" {
    # py_double should be declared (external) but NOT defined in LLVM IR.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Must not have a define (body) for py_double -- it lives in Python
    assert 'define i64 @"py_double"' not in llvm_ir_str;
    # Should have an external declare so the native code can call it
    assert 'declare i64 @"py_double"' in llvm_ir_str;
}

test "py interop py functions in python codegen" {
    # py_double and call_native should appear in Python codegen output.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    py_src = ir.gen.py;
    assert "py_double" in py_src;
    assert "call_native" in py_src;
}

test "py interop native function has stub in python" {
    # Native function should have a ctypes stub in Python codegen output.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    py_src = ir.gen.py;
    # Stub for the native function should exist
    assert "native_add_one_to_doubled" in py_src;
    # The native function body should NOT appear as executable code in Python
    assert "return py_double(x) + 1" not in py_src;
    # Should reference ctypes for the bridge
    assert "CFUNCTYPE" in py_src;
    assert "get_function_address" in py_src;
}

test "py interop interop manifest built" {
    # InteropAnalysisPass should detect cross-boundary calls.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    manifest = ir.gen.interop_manifest;
    assert manifest is not None;
    # py_double: defined in SERVER, called from NATIVE
    assert "py_double" in manifest.bindings;
    b = manifest.bindings["py_double"];
    assert b.source_context.value == "server";
    # native_add_one_to_doubled: defined in NATIVE, called from SERVER
    assert "native_add_one_to_doubled" in manifest.bindings;
    b2 = manifest.bindings["native_add_one_to_doubled"];
    assert b2.source_context.value == "native";
}

test "py interop native calls python function" {
    # Native->Python: native_add_one_to_doubled calls py_double.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    eng = ir.gen.native_engine;
    assert eng is not None;
    # Register the Python function in the interop callback table
    py_func_table = ir.gen.interop_py_funcs;
    py_func_table["py_double"] = lambda (x: int) { x * 2; };
    # Now call the native function
    f = get_func(eng, "native_add_one_to_doubled", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11;  # py_double(5) = 10, + 1 = 11
    assert f(0) == 1;  # py_double(0) = 0,  + 1 = 1
    assert f(-3) == -5;  # py_double(-3) = -6, + 1 = -5
}

test "py interop full entry chain" {
    # Full chain: entry (Py) -> call_native (Py) -> native (na) -> py_double (Py).
    import contextlib;
    import io;

    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert not prog.errors_had;
    # Execute the compiled module with interop context injected
    py_code = compile(
        ir.gen.py, str(os.path.join(FIXTURES, "na_py_interop.jac")), "exec"
    );
    namespace = {
        "__jac_native_engine__": ir.gen.native_engine,
        "__jac_interop_py_funcs__": ir.gen.interop_py_funcs
    };
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, namespace);
    }
    output = buf.getvalue().strip();
    assert output == "11";
}

# --- TestNativeMultiModuleInterop ---
test "multi module na module compiles" {
    # A standalone .jac module compiles to LLVM IR.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_math_utils.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    assert "triple" in llvm_ir_str;
    assert "square" in llvm_ir_str;
}

test "multi module module level na import" {
    # Module-level import of .jac file is recognized.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop_multi.jac")),
        options=CompileOptions(default_codespace='server')
    );
    # Should compile without errors
    assert ir is not None;
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    # triple should be in manifest as a cross-module import
    manifest = ir.gen.interop_manifest;
    assert "triple" in manifest.bindings;
    assert manifest.bindings["triple"].source_module == "na_math_utils.jac";
}

test "multi module na scoped import" {
    # Import inside na {} block is recognized.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop_multi.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    # The na-scoped import should be tracked in manifest
    manifest = ir.gen.interop_manifest;
    # add_ten should be recognized as a NATIVE->NATIVE binding
    assert "add_ten" in manifest.bindings;
    assert manifest.bindings["add_ten"].source_module == "na_transformers.jac";
}

test "multi module native module linking" {
    # Functions from imported .jac modules are callable.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop_multi.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine created";
    # Imported native functions should be resolvable
    triple_addr = native_address(eng, "triple");
    assert triple_addr != 0 , "triple not linked into engine";
}

test "multi module full multi module chain" {
    # Full call chain with multi-module native imports works.
    import contextlib;
    import io;

    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_py_interop_multi.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine created";

    py_code = compile(
        ir.gen.py, str(os.path.join(FIXTURES, "na_py_interop_multi.jac")), "exec"
    );
    namespace = {
        "__jac_native_engine__": ir.gen.native_engine,
        "__jac_interop_py_funcs__": ir.gen.interop_py_funcs
    };
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, namespace);
    }
    output = buf.getvalue().strip();
    assert output == "35";
}

# --- TestCrossModuleStructTypes ---
test "cross module struct compile" {
    # Importing a struct type from another .jac module compiles without errors.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_struct_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module struct function call" {
    # Imported function returning a struct and function accepting a struct work correctly.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_struct_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    # make_point and get_x should be linked
    make_point_addr = native_address(eng, "make_point");
    assert make_point_addr != 0 , "make_point not linked into engine";
    get_x_addr = native_address(eng, "get_x");
    assert get_x_addr != 0 , "get_x not linked into engine";
}

test "cross module struct execution" {
    # Call use_imported_point via ctypes to verify cross-module struct passing works.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_struct_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    use_imported_point = get_func(
        eng, "use_imported_point", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    result = use_imported_point(3, 4);
    assert result == 3 , f"Expected 3, got {result}";
    result2 = use_imported_point(7, 9);
    assert result2 == 7 , f"Expected 7, got {result2}";
}

test "unstamped imported struct return: entry module compiles without errors (issue #6822)" {
    # An UNANNOTATED local bound to an imported factory (`p = make_point(...)`)
    # gets its type from the imported `-> Point` return annotation alone. When
    # this module is the entry, that annotation can be unstamped, so the field
    # accesses `p.x`/`p.y` used to E5090 ("attribute access not supported")
    # because the return lowered to the i64 fallback instead of `Point*`.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_unstamped_struct_ret.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "unstamped imported struct return: field sum is correct (issue #6822)" {
    # compute(5) = make_point(5, 6).x + make_point(5, 6).y = 5 + 6 = 11.
    # Proves the receiver resolved to the real Point struct, not a scalar.
    (eng, _) = compile_native("fix_unstamped_struct_ret.jac");
    compute = get_func(eng, "compute", ctypes.c_int64, ctypes.c_int64);
    assert compute(5) == 11 , f"Expected 11, got {compute(5)}";
    assert compute(0) == 1 , f"Expected 1, got {compute(0)}";
}

# --- TestCrossModuleGlobalLinkage ---
# Regression tests for: global-internal-linkage-breaks-cross-module
# Before fix: module globals were emitted with LLVM `internal` linkage. The
# linker renamed the definition (e.g. @MAGIC -> @MAGIC.467) when another module
# declared it as `external`, leaving the external reference permanently null.
# Any read then caused a null-pointer segfault (exit 134).
# After fix: globals use default (public) linkage; the symbol resolves correctly.
test "cross module global linkage compile" {
    # Importing a module that directly reads globals from another .jac module
    # must compile and JIT without errors.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_glob_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module global direct read" {
    # read_magic() directly accesses the imported MAGIC global.
    # With internal linkage this segfaulted; with public linkage it must return 42.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_glob_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    read_magic = get_func(eng, "read_magic", ctypes.c_int64);
    result = read_magic();
    assert result == 42 , f"Expected MAGIC==42, got {result}";
}

test "cross module global via function" {
    # read_magic_via_func() delegates to get_magic() from the exporting module.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_glob_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had;
    eng = ir.gen.native_engine;
    assert eng is not None;
    read_via_func = get_func(eng, "read_magic_via_func", ctypes.c_int64);
    result = read_via_func();
    assert result == 42 , f"Expected 42 via get_magic(), got {result}";
}

test "cross module global arithmetic" {
    # sum_globals() reads both MAGIC and BASE from the exporting module and adds
    # them; read_base_plus(n) delegates to add_base(n).
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "na_glob_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had;
    eng = ir.gen.native_engine;
    assert eng is not None;
    sum_g = get_func(eng, "sum_globals", ctypes.c_int64);
    result = sum_g();
    assert result == 142 , f"Expected MAGIC+BASE==142, got {result}";
    add_b = get_func(eng, "read_base_plus", ctypes.c_int64, ctypes.c_int64);
    result2 = add_b(5);
    assert result2 == 105 , f"Expected BASE+5==105, got {result2}";
}

# --- TestNativeCacheMarker ---
test "cache marker non native file has no native section in jir" {
    # Compiling a file without na blocks should NOT write any native section
    # (SEC_NBITCODE / SEC_NIFACE / SEC_NOBJ) into the JIR cache.
    import tempfile;
    import time;
    import shutil;
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        read_sections,
        SECTIONS_MAGIC,
        HEADER_SIZE,
        NATIVE_SECTIONS
    }

    tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False);
    tmp.write("glob x = 1;\n");
    tmp.flush();
    jac_file = tmp.name;
    tmp.close();

    # Set source mtime slightly in the past so cache files are strictly newer
    past = time.time() - 2;
    os.utime(jac_file, (past, past));

    try {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        prog = JacProgram();
        JacCompiler().get_bytecode(jac_file, prog);

        cache_path = get_module_cache_path(jac_file);
        assert cache_path.exists() , f"JIR cache file not created at {cache_path}";

        data = cache_path.read_bytes();
        magic_bytes = SECTIONS_MAGIC;
        pos = data.find(magic_bytes, HEADER_SIZE);
        secs: dict[int, bytes] = {};
        if pos >= 0 {
            secs = read_sections(data, pos + len(magic_bytes));
        }
        for sec in NATIVE_SECTIONS {
            assert sec not in secs , (
                f"Non-native file should not have native section {sec} in JIR cache"
            );
        }
    } except Exception as e {
        os.unlink(jac_file);
        raise;
    }
    os.unlink(jac_file);
}

# --- TestNativeLLVMIR ---
test "llvmir ir has function definitions" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "arithmetic.jac")), options=native_force_opts()
    );
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Non-`:pub` functions are defined under the unit's prefix (#8943).
    assert f'define i64 @"{unit_sym(ir, "add")}"' in llvm_ir_str;
    assert f'define i64 @"{unit_sym(ir, "multiply")}"' in llvm_ir_str;
    assert f'define i64 @"{unit_sym(ir, "negate")}"' in llvm_ir_str;
    assert f'define double @"{unit_sym(ir, "float_add")}"' in llvm_ir_str;
}

# --- TestCLibImportSyntax ---
test "clib import produces extern declares" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Extern C functions should be 'declare' (no body), not 'define'
    assert 'declare double @"sqrt"' in llvm_ir_str;
    assert 'declare double @"pow"' in llvm_ir_str;
    assert 'define double @"sqrt"' not in llvm_ir_str;
    assert 'define double @"pow"' not in llvm_ir_str;
    # Native Jac function should be 'define' (has body), under the unit prefix
    assert f'define double @"{unit_sym(ir, "hypotenuse")}"' in llvm_ir_str;
    # Library path should be stored for the compile pass
    assert ir.gen._clib_paths is not None;
    assert "/usr/lib/libm.so.6" in ir.gen._clib_paths;
}

test "single-file clib: _clib_symbol_lib attributes each symbol to its source lib" {
    # The PE linker attributes each extern import to a DLL via symbol_lib_map
    # (defaulting every unmapped symbol to needed_libs[0] = msvcrt.dll →
    # WinError 127). For a single-file program the symbol→DLL map is built
    # directly on the entry module during IR gen (NaIRGenPass sets
    # _cur_lib = _clib_paths[-1] and writes _clib_symbol_lib[fn] = _cur_lib),
    # so it needs no cross-module propagation. This test pins that path so a
    # future regression in single-file clib attribution can't hide behind the
    # multi-module propagation tests (PR #6828 review).
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_import.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    sym_lib = ir.gen._clib_symbol_lib;
    assert sym_lib , "_clib_symbol_lib not set on single-file module IR";
    assert "sqrt" in sym_lib , f"'sqrt' missing from _clib_symbol_lib: {sym_lib}";
    assert "pow" in sym_lib , f"'pow' missing from _clib_symbol_lib: {sym_lib}";
    assert "libm" in sym_lib["sqrt"] , f"sqrt attributed to wrong lib: {sym_lib[
        'sqrt'
    ]}";
    assert "libm" in sym_lib["pow"] , f"pow attributed to wrong lib: {sym_lib['pow']}";
}

test "clib decl with no return arrow lowers to void, not i64" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "_clib_void_ret.jac")),
        use_str="import from \"/usr/lib/libm.so.6\" {\n"
        "    def no_arrow(x: f64);\n"
        "    def explicit_none(x: f64) -> None;\n"
        "}\n"
        "def use_it(n: f64) -> f64 { return n; }\n",
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    s = str(ir.gen.llvm_ir);
    assert 'declare void @"no_arrow"(double' in s , f"omitted return arrow did not lower to void: {s}";
    assert 'declare i64 @"no_arrow"' not in s , "omitted return arrow silently lowered to i64";
    # Parity with the explicit `-> None` spelling.
    assert 'declare void @"explicit_none"(double' in s , "explicit -> None did not lower to void";
}

test "clib import inside na block" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_import_na_block.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Extern C functions from na {} block should be 'declare'
    assert 'declare double @"ceil"' in llvm_ir_str;
    assert 'declare double @"floor"' in llvm_ir_str;
    # Native Jac function should be 'define', under the unit prefix
    assert f'define double @"{unit_sym(ir, "round_up")}"' in llvm_ir_str;
    # Library path should be stored
    assert ir.gen._clib_paths is not None;
    assert "/usr/lib/libm.so.6" in ir.gen._clib_paths;
}

test "clib bytes argument lowers to a raw data pointer (issue #6940 Phase 2)" {
    # A `bytes` parameter on a foreign signature is the C buffer-protocol
    # convention: the extern declares an `i8*` (not the internal jacbytes
    # `{ i64 len, [n x i8] }` struct pointer), and the call site passes the
    # pointer to the first data byte so C never reads the 8-byte length header
    # as leading data. The element count travels through the explicit length
    # parameter. This is the FFI floor under the bundled na_stdlib zlib tier.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_bytes_buffer.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # The extern's bytes parameter is declared as a raw i8*, not jacbytes*.
    assert 'declare i64 @"crc32_z"(i64 %"crc", i8* %"buf", i64 %"len")'
        in llvm_ir_str , (f"clib bytes param not declared as i8*: {llvm_ir_str}");
    # The call passes the data pointer (the by.data GEP/bitcast), and the
    # jacbytes struct pointer is never handed to C.
    assert 'call i64 @"crc32_z"(i64 0, i8* %"by.data.i8"' in llvm_ir_str , (
        f"clib call did not pass the bytes data pointer: {llvm_ir_str}"
    );
    assert 'i8* %"by.data.i8"' in llvm_ir_str , "no data-pointer bitcast emitted";
}

test "clib extensionless logical import produces extern declares (issue #6387)" {
    # `import from raylib { def ... }` (no path, no extension) must still emit
    # extern `declare`s for the brace-block decls and resolve to exactly one
    # logical library name -- no cross-module dependency leak.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_logical_import.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    s = str(ir.gen.llvm_ir);
    assert 'declare void @"InitWindow"(i32' in s , "InitWindow not externed";
    assert 'declare void @"CloseWindow"()' in s , "CloseWindow not externed";
    assert f'define void @"{unit_sym(ir, "open_then_close")}"' in s , "wrapper not defined";
    assert ir.gen._clib_paths is not None;
    assert len(ir.gen._clib_paths) == 1 , f"unexpected clib paths: {ir.gen._clib_paths}";
    # Managed inertness: the bare-name `raylib` must NOT be resolved as a managed
    # module, so the type-checker emits no W1100 "module not found" for it. (A
    # W5021 "C library not found" at JIT time is expected here and unrelated --
    # raylib is not installed on the test host.)
    _warns = [
        w
        for w in prog.warnings_had
        if w?.code and w.code.code == "W1100"
    ];
    assert not _warns , f"unexpected W1100 module-not-found: {[
        str(w.msg) for w in _warns
    ]}";
}

test "clib extensionless import resolves per platform (issue #6387)" {
    # The same source names the platform-correct filename off the target triple:
    # libraylib.so (ELF) / libraylib.dylib (Mach-O) / raylib.dll (PE). Cross-
    # targets via JAC_NATIVE_TARGET, mirroring the AArch64 ABI test below.
    import os as _os;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    _saved = _os.environ.get("JAC_NATIVE_TARGET");
    _fix = str(os.path.join(FIXTURES, "clib_logical_import.jac"));
    try {
        for (tgt, want) in [
            ("x86_64-unknown-linux-gnu", "libraylib.so"),
            ("aarch64-unknown-linux-gnu", "libraylib.so"),
            ("x86_64-apple-darwin", "libraylib.dylib"),
            ("arm64-apple-darwin", "libraylib.dylib"),
            ("x86_64-pc-windows-msvc", "raylib.dll")
        ] {
            _os.environ["JAC_NATIVE_TARGET"] = tgt;
            prog = JacProgram();
            ir = prog.compile(_fix, options=CompileOptions());
            assert not prog.errors_had , f"{tgt}: {prog.errors_had}";
            assert list(ir.gen._clib_paths) == [want] , f"{tgt}: got {ir.gen._clib_paths}, want [{want}]";
        }
    } finally {
        if _saved is None {
            del _os.environ["JAC_NATIVE_TARGET"];
        } else {
            _os.environ["JAC_NATIVE_TARGET"] = _saved;
        }
    }
}

test "clib dotted logical import maps to origin-relative subdir (issue #6387)" {
    # A dotted name puts leading components in a sub-directory and pins the
    # lookup to the binary's directory via the loader token, composing with the
    # $ORIGIN / @loader_path runpath from #6380.
    import os as _os;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    _saved = _os.environ.get("JAC_NATIVE_TARGET");
    _fix = str(os.path.join(FIXTURES, "clib_logical_dotted.jac"));
    try {
        _os.environ["JAC_NATIVE_TARGET"] = "x86_64-unknown-linux-gnu";
        ir = JacProgram().compile(_fix, options=CompileOptions());
        assert list(ir.gen._clib_paths) == ["$ORIGIN/libs/libraylib.so"] , f"ELF: {ir.gen._clib_paths}";
        _os.environ["JAC_NATIVE_TARGET"] = "arm64-apple-darwin";
        ir2 = JacProgram().compile(_fix, options=CompileOptions());
        assert list(ir2.gen._clib_paths) == ["@loader_path/libs/libraylib.dylib"] , f"Mach-O: {ir2.gen._clib_paths}";
    } finally {
        if _saved is None {
            del _os.environ["JAC_NATIVE_TARGET"];
        } else {
            _os.environ["JAC_NATIVE_TARGET"] = _saved;
        }
    }
}

test "clib struct value-type coercion" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_struct_coerce.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # --- Large struct (Vec2: 128-bit, float fields) ---
    # Extern sqrt should use value type (f64 -> f64)
    assert 'declare double @"sqrt"' in llvm_ir_str;
    # Vec2 struct type should be defined
    assert '%"Vec2"' in llvm_ir_str , "Vec2 struct type not found in IR";
    # Jac functions should use pointer types for Vec2 (Jac semantics)
    assert f'%"Vec2"* @"{unit_sym(ir, "make_vec")}"' in llvm_ir_str , "make_vec should return Vec2 pointer";
    assert '%"Vec2"* %"v"' in llvm_ir_str , "vec_length should take Vec2 pointer param";
    # --- Small struct (Color: 32-bit, integer fields) ABI coercion ---
    # Color struct type should be defined
    assert '%"Color" = type {i8, i8, i8, i8}' in llvm_ir_str , "Color struct type not found";
    # Jac test_draw function should use Color pointer internally
    assert f'define void @"{unit_sym(ir, "test_draw")}"' in llvm_ir_str;
    # Struct-by-value coercion at the call site: the small struct is passed in
    # an integer register, loaded out of the struct slot.
    assert "clib.arg.load" in llvm_ir_str , "Missing struct ABI register load";
    import platform;
    if "x86_64" in platform.machine() or "AMD64" in platform.machine() {
        # System V AMD64: the 4-byte Color eightbyte coerces to i32 and the
        # value is reinterpreted via a struct-to-ABI bitcast.
        assert 'declare void @"draw"(i32 %"x", i32 %"y", i32 %"color")'
            in llvm_ir_str , "draw should use i32 for Color param (SysV ABI coercion)";
        assert "clib.arg.cast" in llvm_ir_str , "Missing struct-to-ABI bitcast";
    } elif platform.machine() in ("arm64", "aarch64") {
        # AAPCS64: composites are rounded up to the 8-byte register size.
        assert 'declare void @"draw"(i32 %"x", i32 %"y", i64 %"color")'
            in llvm_ir_str , "draw should use i64 for Color param (AAPCS64 coercion)";
    }
}

test "clib System V AMD64 ABI lowering" {
    # x86_64-only: asserts the emitted foreign-call ABI matches what clang/gcc
    # produce for each eightbyte classification case (Phase 1 of #6353).
    import platform;
    if "x86_64" not in platform.machine() and "AMD64" not in platform.machine() {
        return;
    }
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "clib_sysv_abi.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    s = str(ir.gen.llvm_ir);
    # SSE eightbytes: float fields pack into <2 x float> / trailing float.
    assert 'declare float @"v2_sum"(<2 x float> %"v")' in s , "V2 -> <2 x float>";
    assert 'declare {<2 x float>, float} @"v3_scale"(<2 x float> %"v.0", float %"v.1", float %"s")'
        in s , "V3 expand + 2-eightbyte SSE return";
    assert 'declare float @"v4_sum"(<2 x float> %"v.0", <2 x float> %"v.1")' in s , "V4 -> two <2 x float>";
    # INTEGER eightbyte: all-int small struct coerces to a single integer.
    assert 'declare i32 @"col_sum"(i32 %"c")' in s , "Color -> i32";
    # SSE+INTEGER in one eightbyte merges to INTEGER (i64), not a float.
    assert 'declare float @"fi_mix"(i64 %"s")' in s , "{float,int} -> i64 (merge to INTEGER)";
    # Two SSE double eightbytes.
    assert 'declare double @"dd_sum"(double %"d.0", double %"d.1")' in s , "DD -> two doubles";
    # MEMORY class (>16B, nested): byval pointer argument, sret return.
    assert '%"Cam.cabi" = type' in s , "C-layout type for nested struct";
    assert 'byval(%"Cam.cabi")' in s , "Cam passed byval";
    assert 'sret(%"Cam.cabi")' in s , "Cam returned via sret";
    # The non-injective return-boxing (gap #7) is gone: a scalar return is never
    # rerouted through struct boxing.
    assert "clib.cabi.arg" in s , "nested struct packed to C layout for byval";
}

test "jac run loads a transitive imported-module clib (issue #6687)" {
    # `jac run` JIT-executes a native module in-process via MCJIT. A C shared
    # library declared in an IMPORTED module through a dotted logical import
    # carries an `$ORIGIN`-relative path; the imported-dependency clib loader
    # did not strip that loader token, so the library was never loaded into the
    # JIT and its FFI symbols resolved to NULL -- the process SIGSEGV'd after a
    # clean compile, while the byte-identical `jac nacompile` binary ran fine.
    # The library must now be loaded so the cross-module FFI call returns 21.
    import platform;
    import shutil;
    import tempfile;
    if "x86_64" not in platform.machine() and "AMD64" not in platform.machine() {
        testskip("x86_64-only shared-library build");
    }
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available to build the test shared library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        os.makedirs(os.path.join(tmpdir, "libs"));
        # Build libs/libclibjit6687.so from the C fixture.
        so_path = os.path.join(tmpdir, "libs", "libclibjit6687.so");
        build = subprocess.run(
            [
                cc,
                "-shared",
                "-fPIC",
                "-o",
                so_path,
                str(os.path.join(FIXTURES, "clib_jit_xmod.c"))
            ],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert build.returncode == 0 , f"cc failed: {build.stderr}";
        # The `$ORIGIN` token strips to the cwd at JIT time, so the .jac
        # fixtures and the lib subdir must sit together in the run directory.
        for _f in ["clib_jit_xmod_lib.jac", "clib_jit_xmod_main.jac"] {
            shutil.copy(os.path.join(FIXTURES, _f), os.path.join(tmpdir, _f));
        }
        result = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", "clib_jit_xmod_main.jac"],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=tmpdir
        );
        assert result.returncode == 0 , (
            f"`jac run` crashed (transitive clib unresolved): "
            f"exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        assert result.stdout.strip() == "21" , (
            f"Expected '21', got stdout={result.stdout!r} stderr={result.stderr!r}"
        );
    }
}

test "clib AArch64 AAPCS ABI lowering" {
    # Cross-targets aarch64 (works from any host) and asserts the emitted
    # foreign-call ABI matches what clang produces under AAPCS (Phase 2 of #6353).
    import os as _os;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    _saved = _os.environ.get("JAC_NATIVE_TARGET");
    _os.environ["JAC_NATIVE_TARGET"] = "aarch64-unknown-linux-gnu";
    try {
        prog = JacProgram();
        ir = prog.compile(
            str(os.path.join(FIXTURES, "clib_sysv_abi.jac")), options=CompileOptions()
        );
        assert not prog.errors_had , f"Errors: {prog.errors_had}";
        assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
        s = str(ir.gen.llvm_ir);
        assert "aarch64" in str(ir.gen.llvm_ir.triple) , "module not retargeted";
        # Homogeneous float aggregates pass/return in SIMD regs as [N x float].
        assert 'declare float @"v2_sum"([2 x float] %"v")' in s , "V2 -> [2 x float]";
        assert 'declare [3 x float] @"v3_scale"([3 x float] %"v", float %"s")' in s , "V3 HFA arg + return";
        assert 'declare float @"v4_sum"([4 x float] %"v")' in s , "V4 -> [4 x float]";
        # HFA of doubles.
        assert 'declare double @"dd_sum"([2 x double] %"d")' in s , "DD -> [2 x double]";
        # Non-HFA <=8 bytes -> one i64 GP register (the whole register, even for
        # a 4-byte struct).
        assert 'declare i32 @"col_sum"(i64 %"c")' in s , "Color -> i64";
        assert 'declare float @"fi_mix"(i64 %"s")' in s , "{float,int} -> i64";
        # Large (>16B) aggregate: indirect via a PLAIN pointer (no byval), and
        # sret for the return.
        assert 'declare float @"cam_fovy"(%"Cam.cabi"* %"c")' in s , "Cam -> plain ptr (indirect)";
        assert "byval" not in s , "AAPCS must not emit byval";
        assert 'sret(%"Cam.cabi")' in s , "Cam returned via sret";
    } finally {
        if _saved is None {
            del _os.environ["JAC_NATIVE_TARGET"];
        } else {
            _os.environ["JAC_NATIVE_TARGET"] = _saved;
        }
    }
}

# --- TestRefCounting ---
"""rc basic alloc"""
def _refcount__rc_basic_alloc(eng: any, _ir: any) {
    f = get_func(eng, "test_alloc_basic", ctypes.c_int64);
    assert f() == 42;
}

"""rc object lifecycle"""
def _refcount__rc_object_lifecycle(eng: any, _ir: any) {
    f = get_func(eng, "test_object_lifecycle", ctypes.c_int64);
    assert f() == 10;
}

"""rc reassignment"""
def _refcount__rc_reassignment(eng: any, _ir: any) {
    f = get_func(eng, "test_reassign", ctypes.c_int64);
    assert f() == 2;
}

"""rc list growth"""
def _refcount__rc_list_growth(eng: any, _ir: any) {
    f = get_func(eng, "test_list_growth", ctypes.c_int64);
    assert f() == 20;
}

"""rc list of objects"""
def _refcount__rc_list_of_objects(eng: any, _ir: any) {
    f = get_func(eng, "test_list_of_objects", ctypes.c_int64);
    assert f() == 3;
}

"""rc nested structure"""
def _refcount__rc_nested_structure(eng: any, _ir: any) {
    f = get_func(eng, "test_nested_structure", ctypes.c_int64);
    assert f() == 3;
}

"""rc string alloc"""
def _refcount__rc_string_alloc(eng: any, _ir: any) {
    f = get_func(eng, "test_string_alloc", ctypes.c_int64);
    assert f() == 11;
}

"""rc return transfer"""
def _refcount__rc_return_transfer(eng: any, _ir: any) {
    f = get_func(eng, "test_return_transfer", ctypes.c_int64);
    assert f() == 42;
}

"""rc dict growth"""
def _refcount__rc_dict_growth(eng: any, _ir: any) {
    f = get_func(eng, "test_dict_growth", ctypes.c_int64);
    assert f() == 20;
}

"""rc loop reassign"""
def _refcount__rc_loop_reassign(eng: any, _ir: any) {
    f = get_func(eng, "test_loop_reassign", ctypes.c_int64);
    assert f() == 10;
}

"""rc set operations"""
def _refcount__rc_set_operations(eng: any, _ir: any) {
    f = get_func(eng, "test_set_operations", ctypes.c_int64);
    assert f() == 5;
}

"""rc string reassign"""
def _refcount__rc_string_reassign(eng: any, _ir: any) {
    f = get_func(eng, "test_string_reassign", ctypes.c_int64);
    assert f() == 5;
}

test "refcount" {
    (_eng, _ir) = compile_native("refcount.jac");
    _refcount__rc_basic_alloc(_eng, _ir);
    _refcount__rc_object_lifecycle(_eng, _ir);
    _refcount__rc_reassignment(_eng, _ir);
    _refcount__rc_list_growth(_eng, _ir);
    _refcount__rc_list_of_objects(_eng, _ir);
    _refcount__rc_nested_structure(_eng, _ir);
    _refcount__rc_string_alloc(_eng, _ir);
    _refcount__rc_return_transfer(_eng, _ir);
    _refcount__rc_dict_growth(_eng, _ir);
    _refcount__rc_loop_reassign(_eng, _ir);
    _refcount__rc_set_operations(_eng, _ir);
    _refcount__rc_string_reassign(_eng, _ir);
}

# --- TestRefCountingStress ---
"""rc stress many objects"""
def _rc_stress__rc_stress_many_objects(eng: any, _ir: any) {
    f = get_func(eng, "test_many_objects", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

"""rc stress rapid reassign"""
def _rc_stress__rc_stress_rapid_reassign(eng: any, _ir: any) {
    f = get_func(eng, "test_rapid_reassign", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 999;
}

"""rc stress large list"""
def _rc_stress__rc_stress_large_list(eng: any, _ir: any) {
    f = get_func(eng, "test_large_list", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

"""rc stress string concat"""
def _rc_stress__rc_stress_string_concat(eng: any, _ir: any) {
    f = get_func(eng, "test_string_concat_stress", ctypes.c_int64, ctypes.c_int64);
    assert f(100) == 100;
}

"""rc stress large dict"""
def _rc_stress__rc_stress_large_dict(eng: any, _ir: any) {
    f = get_func(eng, "test_large_dict", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

test "rc_stress" {
    (_eng, _ir) = compile_native("rc_stress.jac");
    _rc_stress__rc_stress_many_objects(_eng, _ir);
    _rc_stress__rc_stress_rapid_reassign(_eng, _ir);
    _rc_stress__rc_stress_large_list(_eng, _ir);
    _rc_stress__rc_stress_string_concat(_eng, _ir);
    _rc_stress__rc_stress_large_dict(_eng, _ir);
}

test "cycle collector reclaims A<->B cycles without double-free" {
    # collect_white reclaims each white node through its own per-type destructor
    # so container backing arrays are freed, not just the header allocation. The
    # dtor's recursive child-release is gated on __rc_collecting, so mid-sweep it
    # frees backing storage + the struct WITHOUT re-releasing the cyclic members
    # that collect_white already reclaims (which would double-free). The probe
    # drives both a plain struct A<->B cycle and a cycle routed through a list
    # field, over repeated sweeps in-process: an invalid/double free aborts the
    # JIT here, and a leaked backing array shows up under ASan/valgrind. This runs
    # without the static musl toolchain the RSS reclamation test in
    # test_native_gc.jac needs, so it guards the free path locally and in CI.
    (eng, _) = compile_native("cycle_collect_jit_probe.jac");
    f = get_func(eng, "drive_cycles", ctypes.c_int64, ctypes.c_int64);
    assert f(20000) == 20000;
    assert f(20000) == 20000;
    assert f(20000) == 20000;
}

# --- TestNativeDictItemsRefcount (regression: issue #6688) ---
test "dict items iteration does not over release key val issue 6688" {
    # `__dict_get_key`/`__dict_get_val` hand back BORROWED pointers into the
    # dict's backing arrays. `for (k, v) in d.items()` bound them into pointer
    # locals that scope-exit cleanup releases, but never retained them -- so the
    # dict's last key+val were over-released, freeing their heap backing under
    # the still-live dict. In a long-running native OSP loop that read a node's
    # str field each spawn, this surfaced as a dangling `char*` strlen'd by a
    # C-FFI call. `verify_items_rc` drains a dict via `.items()` in a helper,
    # churns same-size allocations to reuse the freed block, then re-reads the
    # value: it returns 1 when the value survived intact, 0 when corrupted.
    (eng, _) = compile_native("fix_dict_items_rc.jac");
    f = get_func(eng, "verify_items_rc", ctypes.c_int64);
    assert f() == 1 , "dict .items() over-released its key/val (issue #6688)";
}

test "default params omitted trailing defaults" {
    (eng, _) = compile_native("default_params.jac");
    method_f = get_func(eng, "test_method_default_omitted", ctypes.c_int64);
    assert method_f() == 22;  # 5 + 7 + 10 (offset default)
    free_f = get_func(eng, "test_free_fn_default_omitted", ctypes.c_int64);
    assert free_f() == 142;  # 42 + 100 (bias default)
}

test "keyword arguments bind to their named parameters (issue #7026)" {
    (eng, _) = compile_native("kwargs_call.jac");
    cases = {
        "test_positional": 305,
        "test_keyword": 407,
        "test_keyword_partial": 201,
        "test_keyword_reordered": 509,
        "test_mixed_pos_kw": 304,
        "test_method_keyword": 1206,
        "test_xmod_keyword": 508
    };
    for (name, expected) in cases.items() {
        f = get_func(eng, name, ctypes.c_int64);
        assert f() == expected , f"{name}() == {f()}, expected {expected}";
    }
}

# --- Native-Default Inference Tests ---
glob CHESS_JAC = os.path.join(JAC_ROOT, "examples", "chess", "chess.jac");

"""Compile a regular .jac file under a native default and return the engine."""
def compile_auto_native(file_path: str) -> tuple[uni.Module, JacProgram] {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.codeinfo { set_effective_default_codespace }
    prog = JacProgram();
    try {
        ir = prog.compile(
            file_path=file_path, options=CompileOptions(default_codespace='native')
        );
    } finally {
        set_effective_default_codespace('');
    }
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    return (ir, prog);
}

test "native default infers chess.jac native" {
    (ir, _) = compile_auto_native(CHESS_JAC);
    assert ir is not None;
    assert ir.decided_codespace == 'native' , (
        "chess.jac should infer native under a native default"
    );
    assert ir.gen.native_engine is not None , (
        "Inferred-native chess.jac should have a native engine"
    );
}

test "inferred-native chess.jac has entry and key functions" {
    (ir, _) = compile_auto_native(CHESS_JAC);
    eng = ir.gen.native_engine;
    assert eng is not None;
    # jac_entry must exist
    assert native_address(eng, "jac_entry") != 0;
    # Key game functions must be present, under the unit's prefix
    for func_name in [
        "opposite_color",
        "create_piece",
        "Board.display",
        "Game.is_checkmate",
        "Game.find_king",
        "Game.play"
    ] {
        assert native_address(eng, unit_sym(ir, func_name)) != 0 , (
            f"{func_name} not found in auto-promoted native engine"
        );
    }
}

test "native-default chess.jac runs via cli" {
    # End-to-end: chess in a project with [build] default_codespace = "na"
    # executes through the native engine. Congruence makes native-vs-server
    # unobservable from output; the in-process tests above pin the engine,
    # this pins the CLI path end to end.
    import shutil;
    import tempfile;
    stdin_data = "\n" * 20 + "quit\n";
    with tempfile.TemporaryDirectory() as tmpdir {
        shutil.copy(CHESS_JAC, os.path.join(tmpdir, "chess.jac"));
        shutil.copy(
            os.path.join(os.path.dirname(CHESS_JAC), "chess.impl.jac"),
            os.path.join(tmpdir, "chess.impl.jac")
        );
        import jaclang as _jl;
        _src = os.path.dirname(os.path.dirname(os.path.abspath(_jl.__file__)));
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "chess-na"\n\n[dev]\njaclang_source = "'
                    + _src.replace("\\", "/")
                    + '"\n\n[build]\ndefault_codespace = "na"\n'
            );
        }
        result = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", "chess.jac"],
            input=stdin_data,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=120,
            cwd=tmpdir
        );
    }
    assert result.returncode == 0 , (
        f"Native-default chess crashed with exit code {result.returncode}.\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
    );
    assert "Game ended." in result.stdout , (
        "Expected 'Game ended.' in output.\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
}

test "nacompile auto-promoted .jac links a bundled na_stdlib import (#7013 Finding 2)" {
    # A regular `.jac` (no `na {}` block) that imports a bundled na_stdlib module
    # is auto-promoted by `jac nacompile`. The unit records a native edge to
    # the bundled module (`mod.gen.native_deps`, mirrored in
    # `mod.gen.native_iface.deps`); the link plan walks those edges and the
    # synthesized `jac_entry` calls every unit's initializer
    # (`native_glob_init_name(path)`), so the linked artifact MUST hold the
    # bundled modules' definitions. Before the fix, BoundaryAnalysisPass only
    # classified the imports as native cross-module when the main file was a
    # `.jac` or the import sat in a `na {}` block, so the auto-promote case
    # recorded no dependency: the bundled unit was never linked, its glob-init
    # stayed `declare`-only, and the loader aborted with an undefined symbol.
    # The `.jac` form already worked; this pins the auto-promote (plain
    # `.jac`) form on Linux/ELF.
    import platform;
    fixture = str(os.path.join(FIXTURES, "autopromote_bundled_zlib.jac"));
    # Compile side: the dependency edge is recorded on the unit.
    prog = JacProgram();
    mod = prog.compile(
        fixture,
        options=CompileOptions(
            aot_mode=True,
            default_codespace='native',
            force_target_program=True,
            skip_native_engine=True
        )
    );
    assert not prog.errors_had , f"Errors: {[str(e) for e in prog.errors_had]}";
    deps = list(mod.gen.native_deps);
    assert any(os.path.basename(d) == "zlib.jac" for d in deps) , (
        f"auto-promoted unit did not record the bundled zlib unit: {deps}"
    );
    assert all(os.path.isabs(d) for d in deps) , f"native_deps must be resolved paths: {deps}";
    assert mod.gen.native_iface is not None , "no native interface exported";
    assert list(mod.gen.native_iface.deps) == deps , (
        f"interface deps {mod.gen.native_iface.deps} != gen deps {deps}"
    );
    with tempfile.TemporaryDirectory() as tmpdir {
        out = os.path.join(tmpdir, "autopromote_bundled_zlib");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out],
            capture_output=True,
            text=True,
            timeout=180
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stdout: {comp.stdout[-600:]}\nstderr: {comp.stderr[-600:]}"
        );
        assert os.path.exists(out) , "nacompile produced no binary";
        # Only a Linux x86_64 host can execute the produced ELF. A missing unit
        # leaves the bundled module's glob-init an undefined symbol, so the
        # loader aborts before `main` -- a clean run with the right CRC proves
        # the link.
        if sys.platform.startswith("linux") and ("x86_64" in platform.machine()) {
            res = subprocess.run([out], capture_output=True, text=True, timeout=30);
            assert res.returncode == 0 , (
                f"binary aborted (bundled module not linked): exit={res.returncode}\n"
                f"stdout: {res.stdout[-400:]}\nstderr: {res.stderr[-400:]}"
            );
            assert "crc32: 3421780262" in res.stdout , (
                f"unexpected output: stdout={res.stdout!r} stderr={res.stderr!r}"
            );
        }
    }
}

# --- Native sys Module Tests ---
test "sys argv via jac run native default" {
    # sys.argv must reach native code when the knob selects native execution.
    import shutil;
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "sys_argv.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        shutil.copy(fixture, os.path.join(tmpdir, "sys_argv.jac"));
        import jaclang as _jl;
        _src = os.path.dirname(os.path.dirname(os.path.abspath(_jl.__file__)));
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "argv-na"\n\n[dev]\njaclang_source = "'
                    + _src.replace("\\", "/")
                    + '"\n\n[build]\ndefault_codespace = "na"\n'
            );
        }
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "run",
                "sys_argv.jac",
                "hello",
                "--test-flag",
                "world"
            ],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=tmpdir
        );
    }
    assert result.returncode == 0 , (
        f"sys_argv fixture crashed: exit={result.returncode}\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
    );
    out = result.stdout;
    # Should report correct argc (fixture path + 3 args = 4)
    assert "argc: 4" in out , (f"Expected 'argc: 4' in output.\nstdout: {out}");
    # Should find the --test-flag
    assert "FLAG_FOUND" in out , (f"Expected 'FLAG_FOUND' in output.\nstdout: {out}");
    # Should print each argument
    assert "arg: hello" in out , (f"Expected 'arg: hello' in output.\nstdout: {out}");
    assert "arg: world" in out , (f"Expected 'arg: world' in output.\nstdout: {out}");
    assert "DONE" in out , (f"Expected 'DONE' in output.\nstdout: {out}");
}

test "sys argv via nacompile" {
    # Test that sys.argv works when compiled to a standalone binary via nacompile
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "sys_argv.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "sys_argv_bin");
        # Step 1: Compile to native binary
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        # Step 2: Run the binary with arguments
        result = subprocess.run(
            [out_bin, "hello", "--test-flag", "world"],
            capture_output=True,
            text=True,
            timeout=10
        );
        assert result.returncode == 0 , (
            f"Native binary crashed: exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        out = result.stdout;
        # Should report correct argc (binary path + 3 args = 4)
        assert "argc: 4" in out , (f"Expected 'argc: 4' in output.\nstdout: {out}");
        # Should find the --test-flag
        assert "FLAG_FOUND" in out , (
            f"Expected 'FLAG_FOUND' in output.\nstdout: {out}"
        );
        # Should print each argument
        assert "arg: hello" in out , (
            f"Expected 'arg: hello' in output.\nstdout: {out}"
        );
        assert "arg: world" in out , (
            f"Expected 'arg: world' in output.\nstdout: {out}"
        );
        assert "DONE" in out , (f"Expected 'DONE' in output.\nstdout: {out}");
        # Step 3: Run with --exit-code flag to test sys.exit()
        exit_result = subprocess.run(
            [out_bin, "--exit-code", "1"], capture_output=True, text=True, timeout=10
        );
        assert exit_result.returncode == 1 , (
            f"Expected exit code 1, got {exit_result.returncode}"
        );
        # DONE should NOT appear (sys.exit called before it)
        assert "DONE" not in exit_result.stdout , (
            f"DONE should not appear after sys.exit()\nstdout: {exit_result.stdout}"
        );
    }
}

test "native sys stream write returns count and hits the real fds" {
    (eng, _) = compile_native("sys_streams.jac");
    wout = get_func(eng, "write_out", ctypes.c_int64);
    (r, w) = os.pipe();
    saved = os.dup(1);
    os.dup2(w, 1);
    os.close(w);
    try {
        n = wout();
    } finally {
        os.dup2(saved, 1);
        os.close(saved);
    }
    got = os.read(r, 64);
    os.close(r);
    assert n == 10 , f"write must return the byte count, got {n}";
    assert got == b"out-bytes\n" , f"fd1 bytes wrong: {got!r}";
    werr = get_func(eng, "write_err", ctypes.c_int64);
    (r2, w2) = os.pipe();
    saved2 = os.dup(2);
    os.dup2(w2, 2);
    os.close(w2);
    try {
        n2 = werr();
    } finally {
        os.dup2(saved2, 2);
        os.close(saved2);
    }
    got2 = os.read(r2, 64);
    os.close(r2);
    assert n2 == 6 , f"stderr write count wrong, got {n2}";
    assert got2 == b"err-7\n" , f"fd2 bytes wrong: {got2!r}";
}

test "sys stdout/stderr streams via nacompile" {
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "sys_streams_bin.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "sys_streams_bin");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        result = subprocess.run([out_bin], capture_output=True, text=True, timeout=10);
        assert result.returncode == 0 , (
            f"Native binary crashed: exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        assert result.stdout == "A:bc\nn 2\n" , (
            f"stream writes must share the stdio buffer with print, "
            f"got stdout: {result.stdout!r}"
        );
        assert result.stderr == "E:err\n" , (
            f"stderr bytes must stay on fd 2, got: {result.stderr!r}"
        );
    }
}

test "native osp kernel links transitively through an imported module (issue #6669)" {
    # A thin entry that uses no OSP itself but imports a module whose `run_it`
    # does the `spawn`. Only the imported unit records a native edge to the
    # OSP kernel unit (`runtime/osp_kernel.jac`), so the entry's own interface
    # names no kernel. The link plan (`link_plan.build_link_plan`) walks the
    # dep edges transitively and must still pull the kernel unit and its
    # initializer in. Before the fix the binary built cleanly but failed at
    # load with an undefined kernel glob-init symbol.
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "osp_kernel_transitive_main.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "osp_kernel_transitive");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        result = subprocess.run([out_bin], capture_output=True, text=True, timeout=10);
        assert result.returncode == 0 , (
            f"Native binary crashed at load: exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        assert result.stdout.strip() == "7" , (
            f"Expected '7', got stdout={result.stdout!r} stderr={result.stderr!r}"
        );
    }
}

test "native osp graph survives a cross-module spawn (kernel glob-init runs once)" {
    # The graph is BUILT in an imported module (`build`) and SPAWNED in the entry
    # module. The OSP kernel's adjacency globals (`_e_src`/`_walk_stack`) are
    # link-merged singletons, but `__osp_setup` + its `__osp_inited` guard are
    # per-module (internal). The entry module's first `spawn` therefore hit its
    # OWN (unset) guard and re-ran the SHARED kernel glob-init via
    # `__osp_ensure_init`, re-initializing `_e_src = []` and wiping the graph the
    # imported module had built -- so `[root -->]` collapsed from 2 to 0 after a
    # single spawn. The kernel glob-init must run exactly once program-wide.
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "osp_xmod_buildsplit_main.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "osp_xmod_buildsplit");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        result = subprocess.run([out_bin], capture_output=True, text=True, timeout=10);
        assert result.returncode == 0 , (
            f"Native binary crashed: exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        # before=2, after=2 (graph survives the spawn), seen=1+2=3.
        assert result.stdout.strip() == "2 2 3" , (
            f"Expected '2 2 3', got stdout={result.stdout!r} stderr={result.stderr!r}"
        );
    }
}

test "native osp node constructed in a non-OSP module carries its dispatch tag (issue #6683)" {
    # The entry module CONSTRUCTS an OSP node (`Hub`) but uses no OSP construct
    # of its own; the spawn happens inside the imported `run_probe`. Tag-table
    # population is gated on a module actually using OSP, so the construct-only
    # entry assigned the node NO tag -- its reserved `__type_tag` field stayed 0.
    # When `run_probe` spawned on it, the kernel's `tag_of` read 0 and
    # `node_desc(0)` returned a null descriptor, aborting the walk
    # (`Aborted (core dumped)`, exit 134). The construction site must write the
    # node's globally-stable tag regardless of whether the constructing module
    # uses OSP. The byte-identical program with the spawn in the entry module
    # always ran clean. Fixed: prints `7`.
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "osp_ctor_only_main.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "osp_ctor_only");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        result = subprocess.run([out_bin], capture_output=True, text=True, timeout=10);
        assert result.returncode == 0 , (
            f"Native binary aborted mid-walk (null dispatch descriptor): "
            f"exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        assert result.stdout.strip() == "7" , (
            f"Expected '7', got stdout={result.stdout!r} stderr={result.stderr!r}"
        );
    }
}

test "native osp construct living only in an impl annex materializes imported archetypes" {
    # A builder module IMPORTS OSP archetypes (`Hub`/`Area`) from another native
    # module and wires them (`++>`) from an IMPL ANNEX (`.impl.jac`), not its
    # head file. The annex body is woven into the head module's tree as the
    # module is produced, while keeping its own `loc.mod_path`, so the OSP
    # construct lives off the head but originates in the annex file.
    # The OSP construct scan (now `OspAnalysis._uses_construct`) historically
    # swept just the head file's own statements, classified the builder as a
    # non-OSP user, and never gave the imported archetypes their stable type-tag
    # -- the annexed `++>` then failed with
    # E5090 ("not materialized") at nacompile (or mis-codegen SIGSEGV in a fuller
    # graph). The byte-identical program with `build`'s body INLINE in the head
    # file always compiled. Fixed: prints `2 2 3` (graph built, walker sums 1+2).
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "osp_xmod_annexbuild_main.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "osp_xmod_annexbuild");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed (annexed OSP construct not materialized): "
            f"exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        result = subprocess.run([out_bin], capture_output=True, text=True, timeout=10);
        assert result.returncode == 0 , (
            f"Native binary crashed (imported archetype tag not materialized): "
            f"exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        # before=2 (graph built via annexed `build`), after=2 (survives spawn),
        # seen=1+2=3 (walker reaches both Area nodes and sums their tags).
        assert result.stdout.strip() == "2 2 3" , (
            f"Expected '2 2 3', got stdout={result.stdout!r} stderr={result.stderr!r}"
        );
    }
}

# --- TestNativeAArch64Linker ---
test "aarch64 standalone binary runs (issue #6366)" {
    # Cross-compile a trivial program to aarch64 via the in-house ELF linker
    # and run it under qemu-user. Guards the linker's absolute-address
    # relocations (R_AARCH64_MOVW_UABS_G0..G3): without them every global /
    # .rodata reference materializes to NULL and the binary segfaults at entry.
    import shutil;
    import tempfile;
    qemu = shutil.which("qemu-aarch64-static") or shutil.which("qemu-aarch64");
    ld_prefix = "/usr/aarch64-linux-gnu";
    loader = os.path.join(ld_prefix, "lib", "ld-linux-aarch64.so.1");
    if not qemu or not os.path.exists(loader) {
        testskip("aarch64 qemu-user + cross libc not installed");
    }
    fixture = str(os.path.join(FIXTURES, "aarch64_global_roundtrip.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "a64_roundtrip");
        # Step 1: cross-compile for aarch64.
        comp_env = dict(os.environ);
        comp_env["JAC_NATIVE_TARGET"] = "aarch64-unknown-linux-gnu";
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120,
            env=comp_env
        );
        assert comp.returncode == 0 , (
            f"aarch64 nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        # Step 2: run under qemu-user. total = add(40, 2) = 42, surfaced via
        # sys.exit. A dropped MOVW_UABS reloc stores to NULL -> SIGSEGV
        # (returncode -11 / 139) instead of the expected 42.
        run_env = dict(os.environ);
        run_env["QEMU_LD_PREFIX"] = ld_prefix;
        result = subprocess.run(
            [qemu, out_bin], capture_output=True, text=True, timeout=30, env=run_env
        );
        assert result.returncode == 42 , (
            f"Expected exit 42, got {result.returncode} "
            f"(SIGSEGV/-11/139 == dropped R_AARCH64_MOVW_UABS relocations).\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
    }
}

test "aarch64 static-musl binary runs (cross vendor-musl, #7626 C1)" {
    # Cross static-link against the arch-parameterized vendored musl
    # (`zig build vendor-musl-linux-aarch64`) and run the fully static
    # binary under qemu-user with NO cross loader/libc prefix. Pins the
    # whole cross pathway: MOVW_UABS relocations + per-arch musl staging
    # + static ELF emission for a non-host arch.
    import shutil;
    import tempfile;
    import jaclang;
    qemu = shutil.which("qemu-aarch64-static") or shutil.which("qemu-aarch64");
    _musl_env = os.environ.get("JAC_NATIVE_MUSL_DIR", "");
    musl_a64 = os.path.join(_musl_env, "libc.a")
        if _musl_env
        else os.path.join(
            os.path.dirname(jaclang.__file__),
            "..",
            ".pbs-build",
            "linux-aarch64",
            "musl",
            "lib",
            "libc.a"
        );
    if not qemu or not os.path.exists(musl_a64) {
        testskip(
            "aarch64 qemu-user or cross vendored musl not present "
            "(run `zig build vendor-musl-linux-aarch64`, or set "
            "JAC_NATIVE_MUSL_DIR)"
        );
    }
    fixture = str(os.path.join(FIXTURES, "aarch64_global_roundtrip.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "a64_static");
        comp_env = dict(os.environ);
        comp_env["JAC_NATIVE_TARGET"] = "aarch64-unknown-linux-musl";
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=180,
            env=comp_env
        );
        assert comp.returncode == 0 , (
            f"aarch64 static nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        result = subprocess.run(
            [qemu, out_bin], capture_output=True, text=True, timeout=30
        );
        assert result.returncode == 42 , (
            f"Expected exit 42 from the static aarch64 binary, got "
            f"{result.returncode}.\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
    }
}

test "elf linker rejects unhandled relocation (issue #6366 guard)" {
    # Defense-in-depth: the linker must refuse to emit a binary when a
    # relocation targeting an emitted section has no handler, rather than
    # silently leaving the reference pointing at NULL (the #6366 failure mode).
    # Pure link-time check -- no execution, so it runs without qemu.
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    # A function that loads a module global forces an address-materialization
    # relocation into .text against the global.
    ir = "target triple = \"aarch64-unknown-linux-gnu\"\n"
        + "@g = global i64 0\n"
        + "define i64 @f() {\n  %v = load i64, i64* @g\n  ret i64 %v\n}\n";
    mod = llvm.parse_assembly(ir);
    tm = llvm.Target.from_triple("aarch64-unknown-linux-gnu").create_target_machine(
        opt=2
    );
    obj_bytes = tm.emit_object(mod);
    linker = ElfLinker(
        obj_data=obj_bytes,
        sections=[],
        symbols=[],
        relocations=[],
        needed_libs=["libc.so.6"]
    );
    assert linker.parse_object() , "parse_object failed on aarch64 object";
    assert len(linker.relocations) > 0 , "expected at least one relocation";
    # Corrupt a relocation that patches the emitted code section to an unknown
    # type; the linker must raise instead of emitting an unrelocated binary.
    target = None;
    for r in linker.relocations {
        if r.target_sec and "text" in r.target_sec {
            target = r;
            break;
        }
    }
    assert target is not None , "no .text relocation found to corrupt";
    _corrupt: any = target;
    _corrupt.rtype = 9999;
    raised = False;
    try {
        linker.build_executable();
    } except ValueError as e {
        raised = True;
        assert "relocation type" in str(e) , f"unexpected message: {e}";
    }
    assert raised , "linker silently accepted an unhandled relocation";
}

test "elf linker emits DT_RUNPATH=$ORIGIN (issue #6353 gap 4)" {
    # A standalone binary must find a sibling shared library regardless of the
    # launch directory. The linker emits DT_RUNPATH=$ORIGIN so the loader
    # resolves needed libraries relative to the executable. Pure link-time
    # check -- no execution, so it runs without qemu.
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    import struct;
    import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    ir = "target triple = \"x86_64-unknown-linux-gnu\"\n"
        + "define i64 @f() {\n  ret i64 0\n}\n";
    mod = llvm.parse_assembly(ir);
    tm = llvm.Target.from_triple("x86_64-unknown-linux-gnu").create_target_machine(
        opt=2
    );
    obj_bytes = tm.emit_object(mod);
    linker = ElfLinker(
        obj_data=obj_bytes,
        sections=[],
        symbols=[],
        relocations=[],
        needed_libs=["libc.so.6", "libfoo.so"]
    );
    assert linker.parse_object() , "parse_object failed";
    out = linker.build_executable();
    # The $ORIGIN runpath string is emitted into .dynstr ...
    assert b"$ORIGIN\x00" in out , "DT_RUNPATH $ORIGIN string not emitted";
    # ... and referenced by a DT_RUNPATH (tag 29) dynamic entry.
    assert struct.pack("<q", 29) in out , "DT_RUNPATH (tag 29) dynamic entry missing";
}

test "list_bugs pop local removes element" {
    (eng, _ir) = compile_native("list_bugs.jac");
    f = get_func(eng, "pop_and_len", ctypes.c_int64);
    assert f() == 2;
}

test "list_bugs pop local returns last value" {
    (eng, _ir) = compile_native("list_bugs.jac");
    f = get_func(eng, "pop_value", ctypes.c_int64);
    assert f() == 30;
}

test "list_bugs pop loop drains list" {
    (eng, _ir) = compile_native("list_bugs.jac");
    f = get_func(eng, "pop_loop", ctypes.c_int64);
    assert f() == 3;
}

test "list_bugs pop global removes element" {
    (eng, _ir) = compile_native("list_bugs.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "pop_global_len", ctypes.c_int64);
    assert f() == 2;
}

test "list_bugs obj list field access" {
    (eng, _ir) = compile_native("list_bugs.jac");
    f = get_func(eng, "obj_list_field", ctypes.c_int64);
    assert f() == 42;
}

test "list_bugs obj list two items" {
    (eng, _ir) = compile_native("list_bugs.jac");
    f = get_func(eng, "obj_list_two_items", ctypes.c_int64);
    assert f() == 40;
}

test "list_bugs obj global list" {
    (eng, _ir) = compile_native("list_bugs.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "obj_global_list", ctypes.c_int64);
    assert f() == 100;
}

test "list_bugs reassign int list with empty literal" {
    (eng, _ir) = compile_native("list_bugs.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "reassign_int_list", ctypes.c_int64);
    assert f() == 99;
}

test "list_bugs reassign str list with empty literal" {
    (eng, _ir) = compile_native("list_bugs.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "reassign_str_list", ctypes.c_int64);
    assert f() == 1;
}

# --- String Enum Tests ---
"""string_enums comparison"""
def _string_enums__string_enums_comparison(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_cmp", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 10 , "color_cmp(RED=0) should be 10";
    assert f(1) == 20 , "color_cmp(GREEN=1) should be 20";
    assert f(2) == 30 , "color_cmp(BLUE=2) should be 30";
}

"""string_enums value access"""
def _string_enums__string_enums_value_access(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_value", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"red" , f"Color.RED.value should be 'red', got {f(0)}";
    assert f(1) == b"green" , "Color.GREEN.value should be 'green'";
    assert f(2) == b"blue" , "Color.BLUE.value should be 'blue'";
}

"""string_enums name access"""
def _string_enums__string_enums_name_access(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_name", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"RED" , f"Color.RED.name should be 'RED', got {f(0)}";
    assert f(1) == b"GREEN" , "Color.GREEN.name should be 'GREEN'";
    assert f(2) == b"BLUE" , "Color.BLUE.name should be 'BLUE'";
}

"""string_enums direction value"""
def _string_enums__string_enums_direction_value(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "direction_value", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"N" , "Direction.NORTH.value should be 'N'";
    assert f(1) == b"S" , "Direction.SOUTH.value should be 'S'";
}

"""string_enums int enum still works"""
def _string_enums__string_enums_int_enum_still_works(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "int_enum_still_works", ctypes.c_int64);
    assert f() == 2 , f"Priority.HIGH should be 2, got {f()}";
}

"""string_enums int enum name access"""
def _string_enums__string_enums_int_enum_name_access(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "priority_high_name", ctypes.c_char_p);
    assert f() == b"HIGH" , f"Priority.HIGH.name should be 'HIGH', got {f()}";
    g = get_func(eng, "priority_low_name", ctypes.c_char_p);
    assert g() == b"LOW" , f"Priority.LOW.name should be 'LOW', got {g()}";
}

test "string_enums" {
    (_eng, _ir) = compile_native("string_enums.jac");
    _string_enums__string_enums_comparison(_eng, _ir);
    _string_enums__string_enums_value_access(_eng, _ir);
    _string_enums__string_enums_name_access(_eng, _ir);
    _string_enums__string_enums_direction_value(_eng, _ir);
    _string_enums__string_enums_int_enum_still_works(_eng, _ir);
    _string_enums__string_enums_int_enum_name_access(_eng, _ir);
}

# --- Cross-Module Enum Import Tests ---
"""enum_import compiles"""
def _na_enum_import__enum_import_compiles(eng: any, _ir: any) {
    assert eng is not None;
}

"""enum_import enum comparison"""
def _na_enum_import__enum_import_enum_comparison(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "use_imported_enum", ctypes.c_int64);
    assert f() == 1 , "TokenKind.KW_IF == TokenKind.KW_IF should return 1";
}

"""enum_import value access"""
def _na_enum_import__enum_import_value_access(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "imported_enum_value", ctypes.c_char_p);
    assert f() == b"+" , f"TokenKind.PLUS.value should be '+', got {f()}";
}

"""enum_import cross module function call"""
def _na_enum_import__enum_import_cross_module_function_call(eng: any, _ir: any) {
    # The synthesized `jac_entry` runs every unit's initializer in
    # dependency order (the imported module's globals included) before the
    # root's own entry body; no per-module entry needs calling by hand.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "check_if_keyword", ctypes.c_int64);
    r = f();
    assert r == 3 , f"Expected 3 (KW_IF ordinal), got {r}";
    f2 = get_func(eng, "check_else_keyword", ctypes.c_int64);
    r2 = f2();
    assert r2 == 4 , f"Expected 4 (KW_ELSE ordinal), got {r2}";
    f3 = get_func(eng, "check_unknown_keyword", ctypes.c_int64);
    r3 = f3();
    assert r3 == -1 , f"Expected -1 (not found), got {r3}";
}

test "na_enum_import" {
    (_eng, _ir) = compile_native("na_enum_import.jac");
    _na_enum_import__enum_import_compiles(_eng, _ir);
    _na_enum_import__enum_import_enum_comparison(_eng, _ir);
    _na_enum_import__enum_import_value_access(_eng, _ir);
    _na_enum_import__enum_import_cross_module_function_call(_eng, _ir);
}

# --- Switch statement tests ---
"""switch int match"""
def _switch_stmt__switch_int_match(eng: any, _ir: any) {
    `entry = get_func(eng, "jac_entry", None);
    `entry();
    f = get_func(eng, "switch_int", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 10 , f"switch_int(1) should be 10, got {f(1)}";
    assert f(2) == 20 , f"switch_int(2) should be 20, got {f(2)}";
    assert f(3) == 30 , f"switch_int(3) should be 30, got {f(3)}";
    assert f(99) == -1 , f"switch_int(99) should be -1 (default), got {f(99)}";
}

"""switch enum"""
def _switch_stmt__switch_enum(eng: any, _ir: any) {
    `entry = get_func(eng, "jac_entry", None);
    `entry();
    f = get_func(eng, "switch_enum", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 100 , f"switch_enum(RED=0) should be 100, got {f(0)}";
    assert f(1) == 200 , f"switch_enum(GREEN=1) should be 200, got {f(1)}";
    assert f(2) == 300 , f"switch_enum(BLUE=2) should be 300, got {f(2)}";
}

"""switch string"""
def _switch_stmt__switch_string(eng: any, _ir: any) {
    `entry = get_func(eng, "jac_entry", None);
    `entry();
    f = get_sfunc(eng, "switch_str", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"(") == 1 , f"switch_str('(') should be 1, got {f(b'(')}";
    assert f(b")") == 2 , f"switch_str(')') should be 2, got {f(b')')}";
    assert f(b"{") == 3;
    assert f(b"}") == 4;
    assert f(b"x") == 0 , f"switch_str('x') should be 0 (default), got {f(b'x')}";
}

"""switch no default"""
def _switch_stmt__switch_no_default(eng: any, _ir: any) {
    `entry = get_func(eng, "jac_entry", None);
    `entry();
    f = get_func(eng, "switch_no_default", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 100 , f"switch_no_default(10) should be 100, got {f(10)}";
    assert f(20) == 200 , f"switch_no_default(20) should be 200, got {f(20)}";
    assert f(99) == -1 , f"switch_no_default(99) should be -1 (unchanged), got {f(99)}";
}

test "switch_stmt" {
    (_eng, _ir) = compile_native("switch_stmt.jac");
    _switch_stmt__switch_int_match(_eng, _ir);
    _switch_stmt__switch_enum(_eng, _ir);
    _switch_stmt__switch_string(_eng, _ir);
    _switch_stmt__switch_no_default(_eng, _ir);
}

# --- TestJIRBitcodeCaching ---
test "jir bitcode cache round-trip" {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.jir {
        NativeStamp,
        get_module_cache_path,
        SECTIONS_MAGIC,
        HEADER_SIZE,
        read_sections,
        running_compiler_digest,
        SEC_NBITCODE
    }

    compiler = JacCompiler();
    fixture = str(os.path.join(FIXTURES, "arithmetic.jac"));

    # Step 1: Compile via get_bytecode to populate JIR cache
    prog1 = JacProgram();
    code1 = compiler.get_bytecode(fixture, prog1);
    assert code1 is not None , "get_bytecode should return code object";

    # Step 2: Verify SEC_NBITCODE section exists in the cached JIR file
    cache_path = get_module_cache_path(fixture);
    assert cache_path.exists() , f"JIR cache file should exist at {cache_path}";
    jir_data = cache_path.read_bytes();
    magic: bytes = SECTIONS_MAGIC;
    pos = jir_data.find(magic, HEADER_SIZE);
    assert pos >= 0 , "JIR file should contain SECTIONS_MAGIC";
    secs = read_sections(jir_data, pos + len(magic));
    assert SEC_NBITCODE in secs , f"JIR should contain SEC_NBITCODE, got sections: {list(
        secs.keys()
    )}";

    # Step 3: Verify the native stamp heading SEC_NBITCODE: the compiler
    # digest, codegen identity and target triple the bitcode was produced
    # under, followed by the bitcode payload.
    sec_data = secs[SEC_NBITCODE];
    unpacked = NativeStamp.unpack(sec_data);
    assert unpacked is not None , "SEC_NBITCODE does not start with a native stamp";
    (stamp, payload) = unpacked;
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    assert stamp.triple == llvm.get_default_triple() , (
        f"Triple mismatch: {stamp.triple} != {llvm.get_default_triple()}"
    );
    assert stamp.compiler_digest == running_compiler_digest() , (
        "stamp does not carry the running compiler digest"
    );
    assert stamp.codegen_identity , "stamp carries no codegen identity";
    assert len(payload) > 0 , "Bitcode should not be empty";

    # Step 4: Load from cache with a fresh compiler and call native function
    compiler2 = JacCompiler();
    prog2 = JacProgram();
    code2 = compiler2.get_bytecode(fixture, prog2);
    assert code2 is not None , "Cache reload should return code object";

    # Step 5: Verify native engine was restored via get_native_interop_setup
    (engine, _) = compiler2.get_native_interop_setup(fixture, prog2);
    assert engine is not None , "Native engine should be restored from bitcode cache";
    assert isinstance(engine, ExecutionEngine) , "restored engine has the wrong type";
    add = get_func(engine, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert add(17, 25) == 42 , f"add(17,25) via cached engine should be 42, got {add(
        17, 25
    )}";
}

# --- CType struct contract: layout metadata and field types ---
"""struct layout exports correct field types"""
def _func_ptr_fields__struct_layout_exports_correct_field_types(eng: any, ir: any) {
    layout = ir.gen.native_layout;
    assert layout is not None , "Native layout should be exported";
    assert "AllFields" in layout.structs , "AllFields struct should be in layout";
    af = layout.structs["AllFields"];
    field_map = {f.name: f for f in af.fields};
    assert field_map["x"].llvm_type == "i64";
    assert field_map["y"].llvm_type == "f64";
    assert field_map["name"].llvm_type == "i8*";
    assert field_map["flag"].llvm_type == "i1";
    assert field_map["items"].llvm_type.startswith("List.");
}

"""struct layout tracks field indices correctly"""
def _func_ptr_fields__struct_layout_tracks_field_indices_correctly(eng: any, ir: any) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    af = layout.structs["AllFields"];
    indices = [f.index for f in af.fields];
    # Indices should be consecutive starting from 0
    assert indices == list(range(len(af.fields)));
}

"""optional field compiles to a tagged optional slot"""
def _func_ptr_fields__optional_field_compiles_to_a_tagged_optional_slot(
    eng: any, ir: any
) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert "MaybePoint" in layout.structs;
    mp = layout.structs["MaybePoint"];
    field_map = {f.name: f for f in mp.fields};
    assert field_map["x"].llvm_type == "i64";
    assert field_map["y"].llvm_type == "i64";
    # label is str|None -> a tagged JacOptional slot (#7871 A), never a
    # bare nullable pointer
    assert field_map["label"].llvm_type == "opt.i8*";
}

"""all_fields struct round-trip via ctypes"""
def _func_ptr_fields__all_fields_struct_round_trip_via_ctypes(eng: any, ir: any) {
    make = get_sfunc(
        eng,
        "make_all_fields",
        ctypes.c_void_p,
        ctypes.c_int64,
        ctypes.c_double,
        ctypes.c_char_p
    );
    get_x = get_func(eng, "get_all_fields_x", ctypes.c_int64, ctypes.c_void_p);
    ptr = make(42, 3.14, b"hello");
    assert ptr != 0;
    assert get_x(ptr) == 42;
}

"""all_fields bool field round-trip"""
def _func_ptr_fields__all_fields_bool_field_round_trip(eng: any, ir: any) {
    make = get_sfunc(
        eng,
        "make_all_fields",
        ctypes.c_void_p,
        ctypes.c_int64,
        ctypes.c_double,
        ctypes.c_char_p
    );
    get_flag = get_func(eng, "get_all_fields_flag", ctypes.c_bool, ctypes.c_void_p);
    ptr = make(1, 2.0, b"test");
    assert get_flag(ptr) == True;
}

"""maybe_point struct round-trip"""
def _func_ptr_fields__maybe_point_struct_round_trip(eng: any, ir: any) {
    make = get_func(
        eng, "make_maybe_point", ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64
    );
    get_x = get_func(eng, "get_maybe_x", ctypes.c_int64, ctypes.c_void_p);
    ptr = make(10, 20);
    assert ptr != 0;
    assert get_x(ptr) == 10;
}

"""NativeFieldInfo func_ptr defaults to False"""
def _func_ptr_fields__nativefieldinfo_func_ptr_defaults_to_false(eng: any, ir: any) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    af = layout.structs["AllFields"];
    for f in af.fields {
        assert f.is_func_ptr == False , f"Field {f.name} should not be func_ptr";
        assert f.func_param_types is None;
        assert f.func_ret_type is None;
    }
}

"""function layout exports param and return types"""
def _func_ptr_fields__function_layout_exports_param_and_return_types(
    eng: any, ir: any
) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert "add" in layout.functions;
    add_layout = layout.functions["add"];
    assert add_layout.param_types == ["i64", "i64"];
    assert add_layout.ret_type == "i64";
}

"""layout exports all expected functions"""
def _func_ptr_fields__layout_exports_all_expected_functions(eng: any, ir: any) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    expected = {
        "add",
        "mul",
        "negate",
        "identity",
        "make_all_fields",
        "get_all_fields_x",
        "get_all_fields_flag",
        "make_maybe_point",
        "get_maybe_x"
    };
    assert expected == set(layout.functions.keys());
}

test "func_ptr_fields" {
    (_eng, _ir) = compile_native("func_ptr_fields.jac");
    _func_ptr_fields__struct_layout_exports_correct_field_types(_eng, _ir);
    _func_ptr_fields__struct_layout_tracks_field_indices_correctly(_eng, _ir);
    _func_ptr_fields__optional_field_compiles_to_a_tagged_optional_slot(_eng, _ir);
    _func_ptr_fields__all_fields_struct_round_trip_via_ctypes(_eng, _ir);
    _func_ptr_fields__all_fields_bool_field_round_trip(_eng, _ir);
    _func_ptr_fields__maybe_point_struct_round_trip(_eng, _ir);
    _func_ptr_fields__nativefieldinfo_func_ptr_defaults_to_false(_eng, _ir);
    _func_ptr_fields__function_layout_exports_param_and_return_types(_eng, _ir);
    _func_ptr_fields__layout_exports_all_expected_functions(_eng, _ir);
}

# --- Jac-to-Jac callable tests (Callable[[...], ret] type annotation) ---
# Callable params carry the native closure-pair ABI, so the tests enter
# through native wrappers that pass a plain `def` (null-env wrap path).
"""fnptr apply2 with add"""
def _fnptr_jac__fnptr_apply2_with_add(eng: any, _ir: any) {
    apply2_add = get_func(
        eng, "apply2_add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert apply2_add(3, 4) == 7;
    assert apply2_add(0, 0) == 0;
    assert apply2_add(-1, 1) == 0;
}

"""fnptr apply2 with mul"""
def _fnptr_jac__fnptr_apply2_with_mul(eng: any, _ir: any) {
    apply2_mul = get_func(
        eng, "apply2_mul", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert apply2_mul(3, 4) == 12;
    assert apply2_mul(0, 99) == 0;
    assert apply2_mul(-2, 5) == -10;
}

"""fnptr apply1 with negate"""
def _fnptr_jac__fnptr_apply1_with_negate(eng: any, _ir: any) {
    apply1_negate = get_func(eng, "apply1_negate", ctypes.c_int64, ctypes.c_int64);
    assert apply1_negate(5) == -5;
    assert apply1_negate(0) == 0;
    assert apply1_negate(-3) == 3;
}

"""fnptr call_via_local stores and calls pointer"""
def _fnptr_jac__fnptr_call_via_local_stores_and_calls_pointer(eng: any, _ir: any) {
    cvl_add = get_func(
        eng, "call_via_local_add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    cvl_mul = get_func(
        eng, "call_via_local_mul", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert cvl_add(6, 7) == 13;
    assert cvl_mul(6, 7) == 42;
}

test "fnptr_jac" {
    (_eng, _ir) = compile_native("fnptr_jac.jac");
    _fnptr_jac__fnptr_apply2_with_add(_eng, _ir);
    _fnptr_jac__fnptr_apply2_with_mul(_eng, _ir);
    _fnptr_jac__fnptr_apply1_with_negate(_eng, _ir);
    _fnptr_jac__fnptr_call_via_local_stores_and_calls_pointer(_eng, _ir);
}

# --- Callable null (`= 0`) field defaults (issue #6569) ---
"""callable field accepts int 0 default in native (issue #6569)"""
def _fnptr_null_default__callable_field_accepts_int_0_default_in_native_issue_6569(
    eng: any, _ir: any
) {
    op_default = get_func(eng, "op_default_is_null", ctypes.c_int64);
    assert op_default() == 0;
    vt_default = get_func(eng, "vt_default_is_null", ctypes.c_int64);
    assert vt_default() == 0;
}

"""callable field slot resets to null via int 0 (issue #6569)"""
def _fnptr_null_default__callable_field_slot_resets_to_null_via_int_0_issue_6569(
    eng: any, _ir: any
) {
    reset = get_func(eng, "op_slot_reset_to_null", ctypes.c_int64, ctypes.c_int64);
    assert reset(5) == 0;
}

test "fnptr_null_default" {
    (_eng, _ir) = compile_native("fnptr_null_default.jac");
    _fnptr_null_default__callable_field_accepts_int_0_default_in_native_issue_6569(
        _eng, _ir
    );
    _fnptr_null_default__callable_field_slot_resets_to_null_via_int_0_issue_6569(
        _eng, _ir
    );
}

# --- C→Jac callback trampolines for clib vtable structs (issue #6570) ---
"""clib vtable slot store emits C-ABI trampoline (issue #6570)"""
def _clib_vtable_trampoline__clib_vtable_slot_store_emits_c_abi_trampoline_issue_6570(
    _eng: any, ir: any
) {
    llvm_ir_str = str(ir.gen.llvm_ir);
    # The Jac def has native signature i64(i64, i64); the slot declares
    # i32(i32, i32). Storing it must go through a __clibcb trampoline with
    # the C signature, not a raw bitcast of the Jac function.
    assert "__clibcb" in llvm_ir_str , "no trampoline emitted for vtable slot";
    on_event = unit_sym(ir, "_on_event");
    assert f'define internal i32 @"{on_event}.__clibcb.0"(i32' in llvm_ir_str , "trampoline must carry the C function signature";
    # The trampoline calls back into the Jac function.
    assert f'@"{on_event}"' in llvm_ir_str;
}

"""clib vtable trampolines are cached per (fn, type) pair (issue #6570)"""
def _clib_vtable_trampoline__clib_vtable_trampolines_are_cached_per_fn_type_pair_issue_6570(
    _eng: any, ir: any
) {
    llvm_ir_str = str(ir.gen.llvm_ir);
    # One store site → exactly one trampoline definition.
    on_event = unit_sym(ir, "_on_event");
    assert llvm_ir_str.count(f'define internal i32 @"{on_event}.__clibcb.0"') == 1;
    assert f"{on_event}.__clibcb.1" not in llvm_ir_str;
}

# --- Flat (no-RC) allocation for clib vtable structs (issue #6571) ---
"""clib vtable structs allocate flat without RC header (issue #6571)"""
def _clib_vtable_trampoline__clib_vtable_structs_allocate_flat_without_rc_header_issue_6571(
    _eng: any, ir: any
) {
    llvm_ir_str = str(ir.gen.llvm_ir);
    # C reads the vtable starting at field 0 (CEF validates struct->size
    # there) and owns its lifetime, so the instance must be plain zeroed C
    # memory — no RC header, no destructor, no type tag.
    assert "clib.vt.raw" in llvm_ir_str , "vtable must allocate through the flat calloc path";
    assert "__rc_release_event_handler_vt" not in llvm_ir_str , "C-owned vtable struct must not get an RC destructor";
}

test "clib_vtable_trampoline" {
    (_eng, _ir) = compile_native("clib_vtable_trampoline.jac");
    _clib_vtable_trampoline__clib_vtable_slot_store_emits_c_abi_trampoline_issue_6570(
        _eng, _ir
    );
    _clib_vtable_trampoline__clib_vtable_trampolines_are_cached_per_fn_type_pair_issue_6570(
        _eng, _ir
    );
    _clib_vtable_trampoline__clib_vtable_structs_allocate_flat_without_rc_header_issue_6571(
        _eng, _ir
    );
}

test "clib vtable: C invokes Jac callback through trampoline (issue #6570)" {
    import shutil;
    if not shutil.which("gcc") {
        testskip("gcc not installed");
    }
    td = tempfile.mkdtemp();
    c_src_path = os.path.join(td, "cbtest.c");
    c_lines = [
        "typedef struct {",
        "    long size;",
        "    int (*on_event)(int, int);",
        "    void (*on_close)(long);",
        "} event_handler_vt;",
        "",
        "long invoke_event(event_handler_vt* h, int a, int b) {",
        "    if (h->on_event) { return (long)h->on_event(a, b); }",
        "    return -1;",
        "}",

    ];
    with open(c_src_path, "w") as f {
        f.write("\n".join(c_lines) + "\n");
    }
    lib_path = os.path.join(td, "libcbtest.so");
    r = subprocess.run(
        ["gcc", "-shared", "-fPIC", "-o", lib_path, c_src_path],
        capture_output=True,
        text=True
    );
    assert r.returncode == 0 , f"gcc failed: {r.stderr}";
    jac_lines = [
        f'import from "{lib_path}" {{',
        "    obj event_handler_vt {",
        "        has size: int = 0,",
        "            on_event: Callable[[i32, i32], i32] = 0,",
        "            on_close: Callable[[int], None] = 0;",
        "    }",
        "    def invoke_event(h: int, a: i32, b: i32) -> int;",
        "}",
        "",
        "def _on_event(a: i32, b: i32) -> i32 {",
        "    return a * 10 + b;",
        "}",
        "",
        "def run_with_cb(a: int, b: int) -> int {",
        "    h = event_handler_vt(size=24, on_event=_on_event);",
        "    return invoke_event(h, i32(a), i32(b));",
        "}",
        "",
        "def run_null(a: int, b: int) -> int {",
        "    h = event_handler_vt(size=24);",
        "    return invoke_event(h, i32(a), i32(b));",
        "}",
        "",
        "def make_handler_ptr() -> int {",
        "    h = event_handler_vt(size=24, on_event=_on_event);",
        "    return h;",
        "}",
        "",
        "def invoke_after_maker_returns(a: int, b: int) -> int {",
        "    p = make_handler_ptr();",
        "    return invoke_event(p, i32(a), i32(b));",
        "}",

    ];
    jac_src_path = os.path.join(td, "cb_fixture.jac");
    with open(jac_src_path, "w") as f {
        f.write("\n".join(jac_lines) + "\n");
    }
    prog = JacProgram();
    ir = prog.compile(jac_src_path, options=native_force_opts());
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine produced";
    # C calls back into the Jac def via the trampoline: i32 args widen to
    # the Jac i64 params, the i64 result narrows to the slot's i32.
    run_cb = get_func(
        eng, "run_with_cb", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert run_cb(3, 4) == 34;
    assert run_cb(0, 0) == 0;
    # Negative args prove real C-ABI marshalling: the trampoline must
    # sign-extend the C i32 args into the Jac i64 params (a raw bitcast of
    # the Jac function leaves the upper 32 bits of the registers undefined).
    assert run_cb(-3, 4) == -26;
    assert run_cb(3, -4) == 26;
    # A defaulted (`= 0`) slot stays NULL — C sees a null fn ptr and skips it.
    run_null = get_func(
        eng, "run_null", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert run_null(3, 4) == -1;
    # CEF pattern: the vtable is registered by one function and invoked by
    # the C runtime after that function has returned — the C-owned flat
    # allocation must outlive the creating scope (issue #6571).
    invoke_later = get_func(
        eng,
        "invoke_after_maker_returns",
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    assert invoke_later(5, 6) == 56;
}

# --- TestCrossModuleGlobInit ---
test "cross module glob init compiles without errors" {
    # Importing a module with a glob list initializer must compile cleanly.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "cross_module_glob_init.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module glob init: imported glob is non-null on first access" {
    (eng, _ir) = compile_native("cross_module_glob_init.jac");
    # Before the fix, _TABLE in the library module stayed null after import,
    # causing table_len() to return garbage and table_push() to segfault.
    # After the fix, the synthesized jac_entry calls the imported unit's
    # initializer (`native_glob_init_name(lib_path)`) before this unit's own,
    # so the list is properly allocated before any code touches it.
    # Call jac_entry to trigger the initializers of both this module and the import.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_test = get_func(eng, "run_glob_init_test", ctypes.c_int64);
    result = run_test();
    # Encoded: initial_len*10000 + after_one*100 + after_two = 0*10000 + 1*100 + 2 = 102
    assert result == 102 , f"Expected 102 (0 items, then 1, then 2), got {result}";
}

test "cross module glob init: pushed values are readable" {
    (eng, _ir) = compile_native("cross_module_glob_init.jac");
    # Verify table_get(0) and table_get(1) return the values pushed by run_test.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_test = get_func(eng, "run_glob_init_test", ctypes.c_int64);
    run_test();  # populate: push(42), push(99)
    get_first = get_func(eng, "get_first", ctypes.c_int64);
    get_second = get_func(eng, "get_second", ctypes.c_int64);
    assert get_first() == 42 , f"Expected 42, got {get_first()}";
    assert get_second() == 99 , f"Expected 99, got {get_second()}";
}

"""transitive import: function call through two import hops returns correct value"""
def _fix_transitive_entry__transitive_import_function_call_through_two_import_hops_returns_correc(
    eng: any, _ir: any
) {
    # run_transitive_test() → get_mid() → get_leaf() → 99
    # All three functions must be linked for this to work.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_transitive_test", ctypes.c_int64);
    assert run_fn() == 99 , f"Expected 99, got {run_fn()}";
}

"""transitive import: same result on repeated calls (no state corruption)"""
def _fix_transitive_entry__transitive_import_same_result_on_repeated_calls_no_state_corruption(
    eng: any, _ir: any
) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_transitive_test", ctypes.c_int64);
    assert run_fn() == 99 , f"First call: expected 99, got {run_fn()}";
    assert run_fn() == 99 , f"Second call: expected 99, got {run_fn()}";
    assert run_fn() == 99 , f"Third call: expected 99, got {run_fn()}";
}

test "fix_transitive_entry" {
    (_eng, _ir) = compile_native("fix_transitive_entry.jac");
    _fix_transitive_entry__transitive_import_function_call_through_two_import_hops_returns_correc(
        _eng, _ir
    );
    _fix_transitive_entry__transitive_import_same_result_on_repeated_calls_no_state_corruption(
        _eng, _ir
    );
}

# ─── Mixed transitive duplicate linking ───────────────────────────────────────
# When B imports A, B's IR carries A's symbols as definitions. If A is linked
# before B, the old has_collision=True path skipped all of B — including B's
# unique exports. The scan-then-decide fix demotes benign duplicates to
# available_externally and still link_in()s B's unique symbols.
test "mixed transitive dup: compiles without errors when A is linked before B" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_mixed_dup_entry.jac")),
        options=native_force_opts()
    );
    assert ir is not None , "Expected successful compile";
    assert not prog.errors_had , (
        f"Expected no errors, got: {[str(e) for e in prog.errors_had]}"
    );
}

test "mixed transitive dup: unique symbol from B resolves after A was linked" {
    # get_foo()=10 from A, get_bar()=42 from B, call_foo()=10 via B's import.
    (eng, _) = compile_native("fix_mixed_dup_entry.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_mixed_dup_test", ctypes.c_int64);
    assert run_fn() == 62 , f"Expected 62 (10+42+10), got {run_fn()}";
}

# ─── native_safe_sym: per-module glob-init / entry symbol uniqueness ──────────
# native_safe_sym is the single naming contract behind `native_unit_prefix`:
# every unit's initializer (`native_glob_init_name`), entry
# (`native_entry_name`) and non-`:pub` symbol (`native_symbol_name`) is
# derived from it, and the link plan (`link_plan.build_link_plan`) orders and
# names those initializers from the same function. The legacy
# `re.sub(r'[^a-zA-Z0-9_]', '_', src)` collapsed 'math_utils.na' (flat) and
# 'math/utils.na' (dotted math.utils) to the same 'math_utils_na', so two
# distinct transitive native deps collided on __jac_glob_init_<safe> and
# LLVM's first-seen-wins silently dropped the second module's initializer.
# The hash suffix must keep them distinct, and the result must stay
# LLVM-identifier-safe.
test "native_safe_sym disambiguates flat vs dotted path collision" {
    import re;
    import from jaclang.compiler.frontend.codeinfo {
        native_entry_name,
        native_safe_sym
    }
    flat = "math_utils.na";
    dotted = "math/utils.na";
    # Document the pre-existing collision under the legacy transform: both
    # collapse to 'math_utils_na', which is exactly why the hash is required.
    legacy_flat = re.sub(r'[^a-zA-Z0-9_]', '_', flat);
    legacy_dotted = re.sub(r'[^a-zA-Z0-9_]', '_', dotted);
    assert legacy_flat == legacy_dotted , (
        f"Sanity: legacy transform must collide for this pair, got "
        f"{legacy_flat!r} vs {legacy_dotted!r}"
    );
    sym_flat = native_safe_sym(flat);
    sym_dotted = native_safe_sym(dotted);
    assert sym_flat != sym_dotted , (
        f"native_safe_sym must disambiguate: {sym_flat!r} == {sym_dotted!r}"
    );
    # LLVM identifier safety: only [a-zA-Z0-9_].
    valid = re.compile(r'^[a-zA-Z0-9_]+$');
    assert valid.`match(sym_flat) , f"unsafe symbol: {sym_flat!r}";
    assert valid.`match(sym_dotted) , f"unsafe symbol: {sym_dotted!r}";
    # Deterministic: same input → same output (emit and lookup sides agree).
    assert native_safe_sym(flat) == sym_flat , "native_safe_sym must be deterministic";
    # The full glob-init symbols built from these must also differ.
    assert f"__jac_glob_init_{sym_flat}" != f"__jac_glob_init_{sym_dotted}";
    # The unit-level names are pure functions of the resolved path, so two
    # units with the same stem in different directories never share an
    # initializer, an entry or a symbol prefix; a unit's own names agree with
    # each other, which is what lets a consumer name a dependency's symbols
    # without the dependency's object.
    with tempfile.TemporaryDirectory() as tmp {
        a = os.path.join(tmp, "math_utils.jac");
        b = os.path.join(tmp, "math", "utils.jac");
        os.makedirs(os.path.dirname(b), exist_ok=True);
        prefix_a = native_unit_prefix(a);
        prefix_b = native_unit_prefix(b);
        assert prefix_a != prefix_b , f"same prefix for {a} and {b}: {prefix_a!r}";
        assert valid.`match(prefix_a) , f"unsafe unit prefix: {prefix_a!r}";
        assert native_unit_prefix(a) == prefix_a , "native_unit_prefix must be deterministic";
        assert native_glob_init_name(a) == f"__jac_glob_init_{prefix_a}";
        assert native_entry_name(a) == f"__jac_entry_{prefix_a}";
        assert native_glob_init_name(a) != native_glob_init_name(b);
        assert native_symbol_name(prefix_a, "fn") == f"{prefix_a}.fn";
        assert native_symbol_name(prefix_a, "fn") != native_symbol_name(prefix_b, "fn");
    }
    # The OSP kernel is an ordinary native unit (`runtime/osp_kernel.jac`, one
    # of `KERNEL_UNIT_REL`): the link plan pulls it by dependency edge and
    # names its initializer through `native_glob_init_name` like any other
    # unit, so no hash-free sentinel spelling exists any more (issue #6669
    # was the old fixed-symbol kernel link).
    assert native_safe_sym("osp_kernel") != "osp_kernel" , (
        "native_safe_sym must not special-case the kernel stem"
    );
}

"""del list item: length decrements after delete"""
def _fix_del_list__del_list_item_length_decrements_after_delete(eng: any, _ir: any) {
    # Container starts with [10, 20, 30]; after del items[2] length must be 2.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_shrinks_length", ctypes.c_int64);
    result = f();
    assert result == 2 , f"Expected length 2 after del, got {result}";
}

"""del list item: remaining elements shift left after delete"""
def _fix_del_list__del_list_item_remaining_elements_shift_left_after_delete(
    eng: any, _ir: any
) {
    # After del items[0] from [10, 20, 30], items[0] must become 20.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_shifts_elements", ctypes.c_int64);
    result = f();
    assert result == 20 , f"Expected items[0]=20 after del, got {result}";
}

"""del list item: deleting only element yields empty list"""
def _fix_del_list__del_list_item_deleting_only_element_yields_empty_list(
    eng: any, _ir: any
) {
    # del items[0] from single-element list — length must become 0.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_last_element", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected length 0 after del, got {result}";
}

test "fix_del_list" {
    (_eng, _ir) = compile_native("fix_del_list.jac");
    _fix_del_list__del_list_item_length_decrements_after_delete(_eng, _ir);
    _fix_del_list__del_list_item_remaining_elements_shift_left_after_delete(_eng, _ir);
    _fix_del_list__del_list_item_deleting_only_element_yields_empty_list(_eng, _ir);
}

"""imported archetype method: single increment returns 1"""
def _fix_method_entry__imported_archetype_method_single_increment_returns_1(
    eng: any, _ir: any
) {
    # Counter.increment() on an imported struct; expect 1 after one call.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_increment_once", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected 1, got {result}";
}

"""imported archetype method: double increment returns 2"""
def _fix_method_entry__imported_archetype_method_double_increment_returns_2(
    eng: any, _ir: any
) {
    # Two calls to increment() on the same Counter; expect 2.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_increment_twice", ctypes.c_int64);
    result = f();
    assert result == 2 , f"Expected 2, got {result}";
}

"""imported archetype method: add_delta returns updated value"""
def _fix_method_entry__imported_archetype_method_add_delta_returns_updated_value(
    eng: any, _ir: any
) {
    # Counter starts at 5, add_delta(3); expect 8.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_add_delta", ctypes.c_int64);
    result = f();
    assert result == 8 , f"Expected 8, got {result}";
}

"""imported archetype method: independent instances do not share state"""
def _fix_method_entry__imported_archetype_method_independent_instances_do_not_share_state(
    eng: any, _ir: any
) {
    # Two counters accumulate independently; encoded as a*100 + b.
    # a = 2 (incremented twice), b = 15 (start 10 + delta 5) → 215.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_two_counters", ctypes.c_int64);
    result = f();
    assert result == 215 , f"Expected 215 (a=2, b=15), got {result}";
}

test "fix_method_entry" {
    (_eng, _ir) = compile_native("fix_method_entry.jac");
    _fix_method_entry__imported_archetype_method_single_increment_returns_1(_eng, _ir);
    _fix_method_entry__imported_archetype_method_double_increment_returns_2(_eng, _ir);
    _fix_method_entry__imported_archetype_method_add_delta_returns_updated_value(
        _eng, _ir
    );
    _fix_method_entry__imported_archetype_method_independent_instances_do_not_share_state(
        _eng, _ir
    );
}

test "third module struct: compiles without type errors" {
    # fix_third_entry imports from fix_third_a and fix_third_b.
    # fix_third_b's read_value takes a DataA from fix_third_a — third-module struct.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_third_entry.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine";
}

"""third module struct: value field survives cross-module round-trip"""
def _fix_third_entry__third_module_struct_value_field_survives_cross_module_round_trip(
    eng: any, _ir: any
) {
    # make_data_a(77, 3) → pass to read_value; expect 77.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_third_struct_value", ctypes.c_int64);
    result = f();
    assert result == 77 , f"Expected 77, got {result}";
}

"""third module struct: both fields correct after cross-module call"""
def _fix_third_entry__third_module_struct_both_fields_correct_after_cross_module_call(
    eng: any, _ir: any
) {
    # make_data_a(77, 3) → read_sum (value+tag); expect 80.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_third_struct_sum", ctypes.c_int64);
    result = f();
    assert result == 80 , f"Expected 80, got {result}";
}

test "fix_third_entry" {
    (_eng, _ir) = compile_native("fix_third_entry.jac");
    _fix_third_entry__third_module_struct_value_field_survives_cross_module_round_trip(
        _eng, _ir
    );
    _fix_third_entry__third_module_struct_both_fields_correct_after_cross_module_call(
        _eng, _ir
    );
}

test "cross-module subscript: compiles without errors" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_subscript_entry.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine";
}

test "cross-module subscript: inline ITEMS[0].value returns correct value" {
    (eng, _ir) = compile_native("fix_subscript_entry.jac");
    # push_item(42, 7) then ITEMS[0].value inline (no typed local); expect 42.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();  # initialises ITEMS glob in fix_subscript_outer
    f = get_func(eng, "test_subscript_value", ctypes.c_int64);
    result = f();
    assert result == 42 , f"Expected 42, got {result}";
}

test "cross-module subscript: inline ITEMS[0].extra returns correct value" {
    (eng, _ir) = compile_native("fix_subscript_entry.jac");
    # push_item(42, 7) then ITEMS[0].extra inline; expect 7.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_subscript_extra", ctypes.c_int64);
    result = f();
    assert result == 7 , f"Expected 7, got {result}";
}

test "cross-module subscript: inline access to second item returns correct value" {
    (eng, _ir) = compile_native("fix_subscript_entry.jac");
    # push (42,7) then (99,3); ITEMS[1].value inline; expect 99.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_subscript_second_item", ctypes.c_int64);
    result = f();
    assert result == 99 , f"Expected 99, got {result}";
}

test "transitive glob init: compiles without errors" {
    # fix_transitive_glob_entry → fix_transitive_glob_mid → fix_transitive_glob_deep
    # deep has a glob list; its init must be called even though entry only imports mid.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_transitive_glob_entry.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "transitive glob init: glob list in deep module is not null (no segfault)" {
    (eng, _ir) = compile_native("fix_transitive_glob_entry.jac");
    # Before the fix this would SIGSEGV because _TABLE in deep was never initialised.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_transitive_glob_len", ctypes.c_int64);
    result = run_fn();
    assert result == 0 , f"Expected initial list length 0, got {result}";
}

test "transitive glob init: push through mid updates deep glob list" {
    (eng, _ir) = compile_native("fix_transitive_glob_entry.jac");
    # Verifies the glob list in the transitive module is live and mutable.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    push_fn = get_func(eng, "run_transitive_glob_push_and_len", ctypes.c_int64);
    result = push_fn();
    assert result == 1 , f"Expected list length 1 after push, got {result}";
}

# ─── FIX: Transitive C-library dependency loading ────────────────────────────
# When module A imports module B which in turn imports a .so (e.g. libm), the
# .so was only loaded during B's compilation. When A linked B's bitcode, MCJIT
# could not resolve the extern symbols from B's clib import, causing a segfault.
# Today every unit's interface (`NativeIface.clib_paths` /
# `clib_symbol_lib`, served by the program's `NativeUnitRegistry`) records the
# libraries it declares, and the link plan (`link_plan.build_link_plan`)
# collects them across the whole closure (`plan.clib_paths()`,
# `plan.clib_symbol_lib()`); `jit_engine` loads each one permanently before
# the engine is created.
test "transitive clib: compiles without errors when dep imports a .so" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_clib_transitive_entry.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "transitive clib: clib paths of dep module reach the entry's link plan" {
    # The plan's clib paths must include libm even though only the lib module
    # directly imports it: the dep's interface records the library and the
    # plan walks the dep edge.
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    prog = JacProgram();
    fixture = str(os.path.join(FIXTURES, "fix_clib_transitive_entry.jac"));
    opts = native_force_opts();
    ir = prog.compile(fixture, options=opts);
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert "fix_clib_transitive_lib" in " ".join(ir.gen.native_deps) , (
        f"entry did not record its native dependency: {ir.gen.native_deps}"
    );
    plan = build_link_plan(prog, [fixture], opts);
    clib_paths = plan.clib_paths();
    assert clib_paths , "the link plan collected no clib paths";
    assert any("/libm" in p or "libm" in p for p in clib_paths) , f"libm not found in the plan's clib paths: {clib_paths}";
    dep_unit = [u for u in plan.units if u.path.endswith("fix_clib_transitive_lib.jac")];
    assert dep_unit , f"dep unit missing from the plan: {[u.path for u in plan.units]}";
    assert any("libm" in p for p in dep_unit[0].iface.clib_paths) , (
        f"dep interface does not record libm: {dep_unit[0].iface.clib_paths}"
    );
}

test "transitive clib: clib symbol map of dep module reaches the entry's link plan" {
    # The symbol→library map that the PE linker uses to attribute each import
    # to the right DLL must cross the module boundary, just like the clib
    # paths. Before the fix only the paths crossed while the symbol map was
    # dropped, so on Windows every Win32 symbol imported from a sub-module
    # fell back to msvcrt.dll → WinError 127 at runtime. The dep declares
    # `sqrt` from libm; assert the plan carries that symbol→lib mapping
    # (regression guard for PR #6828).
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    prog = JacProgram();
    fixture = str(os.path.join(FIXTURES, "fix_clib_transitive_entry.jac"));
    opts = native_force_opts();
    prog.compile(fixture, options=opts);
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    plan = build_link_plan(prog, [fixture], opts);
    sym_lib = plan.clib_symbol_lib();
    assert sym_lib , "the link plan collected no clib symbol map";
    assert "sqrt" in sym_lib , f"transitive symbol 'sqrt' missing from the plan's symbol map: {sym_lib}";
    assert "libm" in sym_lib["sqrt"] , f"sqrt attributed to wrong library: {sym_lib[
        'sqrt'
    ]}";
}

test "transitive clib: JIT call through dep-module extern returns correct value" {
    # wrapped_sqrt(9.0) must return 3.0 — proves libm was actually JIT-loaded.
    # Before the fix this would segfault because sqrt was unresolved at JIT time.
    (eng, _) = compile_native("fix_clib_transitive_entry.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_transitive_clib_sqrt", ctypes.c_double);
    result = f();
    assert abs(result - 3.0) < 1e-9 , f"Expected sqrt(9.0)=3.0, got {result}";
}

# ─── FIX: Duplicate C-symbol declaration (DuplicatedNameError) ───────────────
# When user code imported a C function the compiler also uses internally
# (strlen, memcpy, calloc, free …), llvmlite raised DuplicatedNameError because
# two ir.Function objects with the same name were created in the same module.
# Fix: _get_or_declare_extern now scans global_values for an existing declaration
# before calling ir.Function(); _emit_rc_helpers pre-declares all internal libc
# symbols so user imports always find an existing entry.
test "dup clib: importing compiler-internal symbols compiles without DuplicatedNameError" {
    # Imports strlen, memcpy, calloc, free — all pre-declared by the compiler.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_dup_clib.jac")), options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors (expected none, DuplicatedNameError before fix): {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine created";
}

"""dup clib: user-declared strlen returns correct length for 'hello'"""
def _fix_dup_clib__dup_clib_user_declared_strlen_returns_correct_length_for_hello(
    eng: any, _ir: any
) {
    # Verifies the reused declaration is the real strlen, not a stub.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_strlen_hello", ctypes.c_int64);
    result = f();
    assert result == 5 , f"Expected strlen('hello')=5, got {result}";
}

"""dup clib: user-declared strlen returns 0 for empty string"""
def _fix_dup_clib__dup_clib_user_declared_strlen_returns_0_for_empty_string(
    eng: any, _ir: any
) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_strlen_empty", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected strlen('')=0, got {result}";
}

test "fix_dup_clib" {
    (_eng, _ir) = compile_native("fix_dup_clib.jac");
    _fix_dup_clib__dup_clib_user_declared_strlen_returns_correct_length_for_hello(
        _eng, _ir
    );
    _fix_dup_clib__dup_clib_user_declared_strlen_returns_0_for_empty_string(_eng, _ir);
}

# ─── FIX: Argument type coercion at C call boundaries ────────────────────────
# C functions declared with 'int' params could not receive str (i8*) args and
# vice versa. Fix: _coerce_type now has a generic PointerType→IntType fallback
# (ptrtoint) and IntType→PointerType fallback (inttoptr).
test "ptr-to-int coerce: compiles without IR type mismatch" {
    # strlen declared with int param, called with str — triggers ptrtoint.
    # Before the fix this crashed at IR verification time.
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "fix_ptr_int_coerce.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine created";
}

"""ptr-to-int coerce: strlen(int-param) called with str returns correct length"""
def _fix_ptr_int_coerce__ptr_to_int_coerce_strlen_int_param_called_with_str_returns_correct_len(
    eng: any, _ir: any
) {
    # ptrtoint converts i8* → i64; strlen interprets it as char* and counts bytes.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_ptrtoint_strlen", ctypes.c_int64);
    result = f();
    assert result == 5 , f"Expected ptrtoint strlen('hello')=5, got {result}";
}

"""ptr-to-int coerce: strlen(int-param) returns 0 for empty string"""
def _fix_ptr_int_coerce__ptr_to_int_coerce_strlen_int_param_returns_0_for_empty_string(
    eng: any, _ir: any
) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_ptrtoint_strlen_empty", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected ptrtoint strlen('')=0, got {result}";
}

"""int-to-ptr coerce: calloc result (int) assigned to str and measured by strlen"""
def _fix_ptr_int_coerce__int_to_ptr_coerce_calloc_result_int_assigned_to_str_and_measured_by_st(
    eng: any, _ir: any
) {
    # calloc declared as returning int; result stored in str local — inttoptr.
    # calloc zeroes memory so strlen of the buffer must be 0.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_inttoptr_calloc", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected strlen of zeroed calloc buffer=0, got {result}";
}

test "fix_ptr_int_coerce" {
    (_eng, _ir) = compile_native("fix_ptr_int_coerce.jac");
    _fix_ptr_int_coerce__ptr_to_int_coerce_strlen_int_param_called_with_str_returns_correct_len(
        _eng, _ir
    );
    _fix_ptr_int_coerce__ptr_to_int_coerce_strlen_int_param_returns_0_for_empty_string(
        _eng, _ir
    );
    _fix_ptr_int_coerce__int_to_ptr_coerce_calloc_result_int_assigned_to_str_and_measured_by_st(
        _eng, _ir
    );
}

# ─── FIX: IEEE 754 float != returns wrong result for NaN ─────────────────────
# Before the fix, float != used fcmp_ordered, which returns false when either
# operand is NaN — so 'NaN != NaN' was 0 (false), violating IEEE 754.
# Fix: _emit_comparison now routes != through fcmp_unordered so NaN != NaN
# returns 1 (true), while all other float comparisons keep ordered semantics.
"""float NaN: NaN != NaN must be true (1)"""
def _fix_float_nan__float_nan_nan_nan_must_be_true_1(eng: any, _ir: any) {
    # Core IEEE 754 requirement violated before the fix.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "nan_neq_self", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected NaN != NaN = 1, got {result} (fcmp_ordered bug?)";
}

"""float NaN: NaN == NaN must be false (0)"""
def _fix_float_nan__float_nan_nan_nan_must_be_false_0(eng: any, _ir: any) {
    # Ordered == returns false for NaN operands — this should still hold.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "nan_eq_self", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected NaN == NaN = 0, got {result}";
}

"""float NaN: 1.0 != 2.0 must still be true (1) after fix"""
def _fix_float_nan__float_nan_1_0_2_0_must_still_be_true_1_after_fix(
    eng: any, _ir: any
) {
    # The fix must not break ordered != for normal finite values.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "finite_ne_distinct", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected 1.0 != 2.0 = 1, got {result}";
}

"""float NaN: 1.0 != 1.0 must be false (0) after fix"""
def _fix_float_nan__float_nan_1_0_1_0_must_be_false_0_after_fix(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "finite_ne_self", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected 1.0 != 1.0 = 0, got {result}";
}

"""float NaN: 3.14 == 3.14 must be true (1) after fix"""
def _fix_float_nan__float_nan_3_14_3_14_must_be_true_1_after_fix(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "finite_eq_self", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected 3.14 == 3.14 = 1, got {result}";
}

test "fix_float_nan" {
    (_eng, _ir) = compile_native("fix_float_nan.jac");
    _fix_float_nan__float_nan_nan_nan_must_be_true_1(_eng, _ir);
    _fix_float_nan__float_nan_nan_nan_must_be_false_0(_eng, _ir);
    _fix_float_nan__float_nan_1_0_2_0_must_still_be_true_1_after_fix(_eng, _ir);
    _fix_float_nan__float_nan_1_0_1_0_must_be_false_0_after_fix(_eng, _ir);
    _fix_float_nan__float_nan_3_14_3_14_must_be_true_1_after_fix(_eng, _ir);
}

# --- Lambda Support (Phase 1: simple, no captures) ---
"""lambda simple add"""
def _lambdas__lambda_simple_add(eng: any, _ir: any) {
    f = get_func(eng, "apply_int_op", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == 7 , f"Expected 7, got {f(3, 4)}";
    assert f(10, 20) == 30 , f"Expected 30, got {f(10, 20)}";
}

"""lambda negate single param"""
def _lambdas__lambda_negate_single_param(eng: any, _ir: any) {
    f = get_func(eng, "negate_via_lambda", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == -5 , f"Expected -5, got {f(5)}";
    assert f(0) == 0 , f"Expected 0, got {f(0)}";
    assert f(-3) == 3 , f"Expected 3, got {f(-3)}";
}

"""lambda no params"""
def _lambdas__lambda_no_params(eng: any, _ir: any) {
    f = get_func(eng, "get_forty_two", ctypes.c_int64);
    assert f() == 42 , f"Expected 42, got {f()}";
}

# --- Lambda Closures (Phase 2: capturing outer scope) ---
"""lambda closure captures local"""
def _lambdas__lambda_closure_captures_local(eng: any, _ir: any) {
    f = get_func(eng, "add_offset", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(10, 5) == 15 , f"Expected 15, got {f(10, 5)}";
    assert f(0, 42) == 42 , f"Expected 42, got {f(0, 42)}";
    assert f(7, -3) == 4 , f"Expected 4, got {f(7, -3)}";
}

"""lambda closure captures multiple vars"""
def _lambdas__lambda_closure_captures_multiple_vars(eng: any, _ir: any) {
    f = get_func(
        eng,
        "weighted_sum",
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    assert f(3, 4, 2, 5) == 26 , f"Expected 26, got {f(3, 4, 2, 5)}";
    assert f(1, 1, 10, 20) == 30 , f"Expected 30, got {f(1, 1, 10, 20)}";
}

"""lambda closure as scaler"""
def _lambdas__lambda_closure_as_scaler(eng: any, _ir: any) {
    f = get_func(eng, "make_scaler", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(5, 3) == 15 , f"Expected 15, got {f(5, 3)}";
    assert f(10, 0) == 0 , f"Expected 0, got {f(10, 0)}";
    assert f(7, -2) == -14 , f"Expected -14, got {f(7, -2)}";
}

test "lambdas" {
    (_eng, _ir) = compile_native("lambdas.jac");
    _lambdas__lambda_simple_add(_eng, _ir);
    _lambdas__lambda_negate_single_param(_eng, _ir);
    _lambdas__lambda_no_params(_eng, _ir);
    _lambdas__lambda_closure_captures_local(_eng, _ir);
    _lambdas__lambda_closure_captures_multiple_vars(_eng, _ir);
    _lambdas__lambda_closure_as_scaler(_eng, _ir);
}

# --- Multi-statement lambda callback parity (P2 cross-target probe) ---
"""multi-statement lambda map callback (native inline lowering)"""
def _lambda_multi_stmt_callback__multi_statement_lambda_map_callback_native_inline_lowering(
    eng: any, _ir: any
) {
    f = get_func(eng, "map_multi_stmt_callback", ctypes.c_int64);
    assert f() == 18 , f"Expected 18 from sum of (x+1)*2 over [1,2,3], got {f()}";
}

"""multi-statement lambda sort key callback (native inline lowering)"""
def _lambda_multi_stmt_callback__multi_statement_lambda_sort_key_callback_native_inline_lowering(
    eng: any, _ir: any
) {
    f = get_func(eng, "sort_multi_stmt_key", ctypes.c_int64);
    # keys: 31->1, 12->2, 23->3 => sorted order [31, 12, 23]
    assert f() == 3243 , f"Expected 3243 (31*100+12*10+23), got {f()}";
}

test "lambda_multi_stmt_callback" {
    (_eng, _ir) = compile_native("lambda_multi_stmt_callback.jac");
    _lambda_multi_stmt_callback__multi_statement_lambda_map_callback_native_inline_lowering(
        _eng, _ir
    );
    _lambda_multi_stmt_callback__multi_statement_lambda_sort_key_callback_native_inline_lowering(
        _eng, _ir
    );
}

# ─── Symbol Collision Detection ───────────────────────────────────────────────
# Before the fix, when two imported native modules both exported a symbol with
# the same name, link_in() would silently merge them and produce a binary that
# crashed with SIGSEGV at runtime. W5024/W5025 were mere warnings, so nacompile
# wrote a corrupt binary without aborting.
#
# After the fix:
#  - The compiler tracks exported symbols in a symbol_origins dict.
#  - When a collision is detected before link_in(), E5026 is emitted and
#    compilation is aborted (errors_had is non-empty).
#  - Import compile/link failures (W5024/W5025) are now errors (E5024/E5025).
test "symbol collision: importing two modules with the same exported symbol emits E5026" {
    # sym_collision_lib_a and sym_collision_lib_b both export `shared_fn`.
    # Compiling the entry that imports both must emit at least one error.
    prog = JacProgram();
    prog.compile(
        str(os.path.join(FIXTURES, "sym_collision_entry.jac")),
        options=native_force_opts()
    );
    assert prog.errors_had , (
        "Expected E5026 symbol collision error, but errors_had is empty"
    );
    error_strs = [str(e) for e in prog.errors_had];
    found_e5026 = any(
        "E5026" in e or "Symbol collision" in e or "symbol collision" in e
        for e in error_strs
    );
    assert found_e5026 , (f"Expected E5026 in errors, got: {error_strs}");
}

test "symbol collision: both conflicting module names appear in the error" {
    # The error message must name both source files so the developer knows which
    # modules need to be fixed.
    prog = JacProgram();
    prog.compile(
        str(os.path.join(FIXTURES, "sym_collision_entry.jac")),
        options=native_force_opts()
    );
    assert prog.errors_had , "Expected collision error";
    combined = " ".join(str(e) for e in prog.errors_had);
    assert "sym_collision_lib_a" in combined or "lib_a" in combined , (
        f"Expected lib_a module name in error. Got: {combined}"
    );
    assert "sym_collision_lib_b" in combined or "lib_b" in combined , (
        f"Expected lib_b module name in error. Got: {combined}"
    );
}

test "symbol collision: the colliding symbol name is reported" {
    # E5026 message must include the name of the duplicated symbol.
    prog = JacProgram();
    prog.compile(
        str(os.path.join(FIXTURES, "sym_collision_entry.jac")),
        options=native_force_opts()
    );
    assert prog.errors_had , "Expected collision error";
    combined = " ".join(str(e) for e in prog.errors_had);
    assert "collision_fn" in combined , (
        f"Expected 'collision_fn' in error message. Got: {combined}"
    );
}

# ─── Variable Re-Declaration Type Fix ────────────────────────────────────────
# Before the fix, when a variable was re-declared with a different type
# (x: int = 0; x: bool = True;), codegen would store through the original
# wrongly-typed alloca (e.g. i1 stored into i64 allocation), causing IR type
# mismatches or corrupt values at runtime.
#
# After the fix, the codegen allocates a fresh alloca of the declared type
# whenever a typed re-declaration (x: T = ...) differs from the existing
# alloca's pointee type. Collection types (list/dict/set/frozenset) are skipped
# as they are handled separately.
"""redecl type: int-to-bool re-declaration (True) returns 1"""
def _redecl_type__redecl_type_int_to_bool_re_declaration_true_returns_1(
    eng: any, _ir: any
) {
    # x: int = 0; x: bool = True; if x { return 1; } return 0;
    # Before fix: wrong alloca type → crash or wrong value.
    # After fix: fresh i1 alloca; x == True → returns 1.
    f = get_func(eng, "redecl_int_to_bool_true", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected 1 (True branch taken), got {result}";
}

"""redecl type: int-to-bool re-declaration (False) returns 0"""
def _redecl_type__redecl_type_int_to_bool_re_declaration_false_returns_0(
    eng: any, _ir: any
) {
    # x: int = 99; x: bool = False; if x { return 1; } return 0;
    # After fix: fresh i1 alloca; x == False → returns 0.
    f = get_func(eng, "redecl_int_to_bool_false", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected 0 (False branch not taken), got {result}";
}

"""redecl type: same-type re-declaration updates value correctly"""
def _redecl_type__redecl_type_same_type_re_declaration_updates_value_correctly(
    eng: any, _ir: any
) {
    # x: int = 50; x: int = 99; return x; → must return 99.
    # Same type: no fresh alloca needed; value must still be updated.
    f = get_func(eng, "redecl_same_type_int", ctypes.c_int64);
    result = f();
    assert result == 99 , f"Expected 99, got {result}";
}

"""redecl type: bool-to-int re-declaration returns int value"""
def _redecl_type__redecl_type_bool_to_int_re_declaration_returns_int_value(
    eng: any, _ir: any
) {
    # x: bool = True; x: int = 42; return x; → must return 42.
    # After fix: fresh i64 alloca for int; correct value stored.
    f = get_func(eng, "redecl_bool_to_int", ctypes.c_int64);
    result = f();
    assert result == 42 , f"Expected 42, got {result}";
}

test "redecl_type" {
    (_eng, _ir) = compile_native("redecl_type.jac");
    _redecl_type__redecl_type_int_to_bool_re_declaration_true_returns_1(_eng, _ir);
    _redecl_type__redecl_type_int_to_bool_re_declaration_false_returns_0(_eng, _ir);
    _redecl_type__redecl_type_same_type_re_declaration_updates_value_correctly(
        _eng, _ir
    );
    _redecl_type__redecl_type_bool_to_int_re_declaration_returns_int_value(_eng, _ir);
}

# ─── Global Variable Scoping (na ⊆ sv) ───────────────────────────────────────
# Python (and the sv pathway) bind a bare function-scope assignment as a NEW
# function-local, even when a module global of the same name exists. Rebinding
# the module global requires an explicit `global x;`.
#
# Before the fix the native pathway diverged: a bare `counter = 5` inside a
# function rebound the module global, so `.jac` code observed different
# results than the identical source run through the sv pathway.
#
# `run_sv_source` below executes a Jac source string through the sv pathway so
# the cross-pathway test can prove both pathways agree on scoping.
"""Run a .jac source string through the sv pathway; return captured stdout."""
def run_sv_source(code: str) -> str {
    tmpdir = tempfile.mkdtemp();
    src_path = os.path.join(tmpdir, "xpath_mod.jac");
    fh = open(src_path, "w");
    fh.write(code);
    fh.close();
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        JacRuntime.jac_import(
            target="xpath_mod", base_path=tmpdir, override_name="__main__"
        );
    } finally {
        sys.stdout = old_stdout;
    }
    return buf.getvalue();
}

test "glob scoping: bare function-scope assignment does not touch the module global" {
    (eng, _ir) = compile_native("glob_scoping.jac");
    # bump_local() does `counter = 5;` with no `global` declaration — Python
    # semantics make this a function-local, so the module global stays 0.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    bump_local = get_func(eng, "bump_local", ctypes.c_int64);
    read_global = get_func(eng, "read_global", ctypes.c_int64);
    assert bump_local() == 5 , "bare local assignment should evaluate to 5";
    assert read_global() == 0 , (
        "module global must be untouched by a bare function-scope assignment "
        "(before the fix this returned 5 — the native pathway rebound the global)"
    );
}

test "glob scoping: explicit `global` still rebinds the module global" {
    (eng, _ir) = compile_native("glob_scoping.jac");
    # bump_global() declares `global counter;` first, so `counter = 99;` is a
    # genuine global store — this must keep working.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    bump_global = get_func(eng, "bump_global", ctypes.c_int64);
    read_global = get_func(eng, "read_global", ctypes.c_int64);
    assert bump_global() == 99;
    assert read_global() == 99 , "explicit `global x;` must rebind the global";
}

test "cross-pathway: glob scoping is identical in the na and sv pathways" {
    # The SAME source is run through both pathways and the observable results
    # must match (the na ⊆ sv guarantee). Before the fix the native pathway
    # produced [5, 5, 99, 99] while the sv pathway produced [5, 0, 99, 99].
    fixture_path = os.path.join(FIXTURES, "glob_scoping.jac");
    fh = open(fixture_path);
    base_src = fh.read();
    fh.close();

    # --- native pathway ---
    (eng, _) = compile_native("glob_scoping.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    bump_local = get_func(eng, "bump_local", ctypes.c_int64);
    read_global = get_func(eng, "read_global", ctypes.c_int64);
    bump_global = get_func(eng, "bump_global", ctypes.c_int64);
    na_results = [bump_local(), read_global(), bump_global(), read_global()];

    # --- sv pathway: identical source, entry block prints the same sequence ---
    sv_src = base_src.replace(
        "with entry {}",
        "with entry {\n"
            + "    print(bump_local());\n"
            + "    print(read_global());\n"
            + "    print(bump_global());\n"
            + "    print(read_global());\n"
            + "}"
    );
    assert "with entry {\n" in sv_src , "fixture entry block not substituted";
    sv_out = run_sv_source(sv_src);
    sv_results = [int(tok) for tok in sv_out.split()];

    assert sv_results == [5, 0, 99, 99] , (
        f"sv pathway diverged from CPython scoping: {sv_results}"
    );
    assert na_results == sv_results , (
        f"native pathway diverges from sv: na={na_results} sv={sv_results}. "
        "A bare function-scope assignment to a glob name must be a local."
    );
}

# ─── Finding 2 guard: native pointer-bitcast escape hatch stays native-only ──
# The type checker permits a handful of pointer-shaped cross-type assignments
# (int/str/obj) because in native code they are all 64-bit pointers. That
# escape hatch is gated to native modules via `_in_native_context()`. This
# test locks that gating in: the sv pathway must still reject the assignment,
# so the escape hatch can never silently weaken sv type-checking.
test "finding 2 guard: int-to-obj escape hatch does not leak into the sv pathway" {
    code = (
        "obj Wrapper { has slot: int; }\n"
        + "def make(raw: int) -> Wrapper {\n"
        + "    w: Wrapper = raw;\n"
        + "    return w;\n"
        + "}\n"
    );
    # sv pathway (.sv.jac): assigning an int to an obj-typed variable must
    # remain a type error. The snippet is otherwise valid, so any error here
    # is the assignability error.
    sv_prog = JacProgram();
    sv_path = os.path.join(FIXTURES, "_finding2_guard.jac");
    sv_prog.compile(file_path=sv_path, use_str=code);
    assert sv_prog.errors_had , (
        "sv pathway must reject `w: Wrapper = raw` (int → obj). The native "
        "pointer-bitcast escape hatch must not apply outside native modules."
    );
}

# ─── async / await (synchronous model) ───────────────────────────────────
"""await resolves an async call to its value"""
def _async_await__await_resolves_an_async_call_to_its_value(eng: any, _ir: any) {
    f = get_func(eng, "driver", ctypes.c_int64, ctypes.c_int64);
    # x = await get_val() = 5; y = await add_async(5, n)
    assert f(10) == 15;
    assert f(0) == 5;
}

"""nested awaits evaluate inside-out"""
def _async_await__nested_awaits_evaluate_inside_out(eng: any, _ir: any) {
    f = get_func(eng, "nested_await", ctypes.c_int64, ctypes.c_int64);
    # add_async(get_val()=5, n)
    assert f(3) == 8;
    assert f(-5) == 0;
}

test "async_await" {
    (_eng, _ir) = compile_native("async_await.jac");
    _async_await__await_resolves_an_async_call_to_its_value(_eng, _ir);
    _async_await__nested_awaits_evaluate_inside_out(_eng, _ir);
}

# ─── flow / wait (synchronous model) ─────────────────────────────────────
"""flow then wait returns the task result"""
def _flow_wait__flow_then_wait_returns_the_task_result(eng: any, _ir: any) {
    f = get_func(eng, "run_one", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10;
    assert f(0) == 0;
}

"""wait directly on a flow expression"""
def _flow_wait__wait_directly_on_a_flow_expression(eng: any, _ir: any) {
    f = get_func(eng, "run_inline", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 14;
}

"""multiple flow handles waited independently"""
def _flow_wait__multiple_flow_handles_waited_independently(eng: any, _ir: any) {
    f = get_func(eng, "run_two", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    # task(3)+task(4) = 6+8 = 14
    assert f(3, 4) == 14;
}

test "flow_wait" {
    (_eng, _ir) = compile_native("flow_wait.jac");
    _flow_wait__flow_then_wait_returns_the_task_result(_eng, _ir);
    _flow_wait__wait_directly_on_a_flow_expression(_eng, _ir);
    _flow_wait__multiple_flow_handles_waited_independently(_eng, _ir);
}

# ─── C-style iter-for loop ───────────────────────────────────────────────
"""iter-for sums a counted range"""
def _iter_for__iter_for_sums_a_counted_range(eng: any, _ir: any) {
    f = get_func(eng, "sum_n", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10;  # 0+1+2+3+4
    assert f(0) == 0;
    assert f(1) == 0;
}

"""iter-for counts down with a decrementing step"""
def _iter_for__iter_for_counts_down_with_a_decrementing_step(eng: any, _ir: any) {
    f = get_func(eng, "count_down", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 5;  # i = 5,4,3,2,1
    assert f(0) == 0;
}

"""iter-for honors break"""
def _iter_for__iter_for_honors_break(eng: any, _ir: any) {
    f = get_func(eng, "with_break", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 3;  # 0+1+2, break at i==3
    assert f(2) == 1;  # 0+1
}

"""iter-for honors continue and still advances the counter"""
def _iter_for__iter_for_honors_continue_and_still_advances_the_counter(
    eng: any, _ir: any
) {
    f = get_func(eng, "with_continue", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 8;  # 0+1+3+4 (skip 2)
    assert f(2) == 1;  # 0+1
}

test "iter_for" {
    (_eng, _ir) = compile_native("iter_for.jac");
    _iter_for__iter_for_sums_a_counted_range(_eng, _ir);
    _iter_for__iter_for_counts_down_with_a_decrementing_step(_eng, _ir);
    _iter_for__iter_for_honors_break(_eng, _ir);
    _iter_for__iter_for_honors_continue_and_still_advances_the_counter(_eng, _ir);
}

# ─── Match statements ────────────────────────────────────────────────────
"""match dispatches on literal value patterns"""
def _match_stmt__match_dispatches_on_literal_value_patterns(eng: any, _ir: any) {
    f = get_func(eng, "classify", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 100;
    assert f(1) == 200;
    assert f(5) == 300;
}

"""match supports OR patterns"""
def _match_stmt__match_supports_or_patterns(eng: any, _ir: any) {
    f = get_func(eng, "with_or", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 1;
    assert f(2) == 1;
    assert f(3) == 1;
    assert f(4) == 0;
}

"""match capture pattern binds the subject"""
def _match_stmt__match_capture_pattern_binds_the_subject(eng: any, _ir: any) {
    f = get_func(eng, "with_capture", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == -1;
    assert f(7) == 14;
}

"""match honors case guards"""
def _match_stmt__match_honors_case_guards(eng: any, _ir: any) {
    f = get_func(eng, "with_guard", ctypes.c_int64, ctypes.c_int64);
    assert f(20) == 1;
    assert f(11) == 1;
    assert f(5) == 2;
    assert f(-1) == 3;
}

"""match dispatches on string patterns"""
def _match_stmt__match_dispatches_on_string_patterns(eng: any, _ir: any) {
    f = get_sfunc(eng, "match_str", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"hi") == 1;
    assert f(b"bye") == 2;
    assert f(b"nope") == 0;
}

test "match_stmt" {
    (_eng, _ir) = compile_native("match_stmt.jac");
    _match_stmt__match_dispatches_on_literal_value_patterns(_eng, _ir);
    _match_stmt__match_supports_or_patterns(_eng, _ir);
    _match_stmt__match_capture_pattern_binds_the_subject(_eng, _ir);
    _match_stmt__match_honors_case_guards(_eng, _ir);
    _match_stmt__match_dispatches_on_string_patterns(_eng, _ir);
}

# ─── Pipe-forward operator `|>` ──────────────────────────────────────────
"""pipe-forward feeds lhs as the sole argument"""
def _pipe_fwd__pipe_forward_feeds_lhs_as_the_sole_argument(eng: any, _ir: any) {
    f = get_func(eng, "pipe_single", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 6;
    assert f(-1) == 0;
}

"""pipe-forward chains left-associatively"""
def _pipe_fwd__pipe_forward_chains_left_associatively(eng: any, _ir: any) {
    f = get_func(eng, "pipe_chain", ctypes.c_int64, ctypes.c_int64);
    # inc(inc(5)) == 7
    assert f(5) == 7;
    assert f(0) == 2;
}

"""pipe-forward spreads a tuple lhs into multiple args"""
def _pipe_fwd__pipe_forward_spreads_a_tuple_lhs_into_multiple_args(eng: any, _ir: any) {
    f = get_func(eng, "pipe_tuple", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    # add(3, 4) == 7
    assert f(3, 4) == 7;
    assert f(10, -2) == 8;
}

test "pipe_fwd" {
    (_eng, _ir) = compile_native("pipe_fwd.jac");
    _pipe_fwd__pipe_forward_feeds_lhs_as_the_sole_argument(_eng, _ir);
    _pipe_fwd__pipe_forward_chains_left_associatively(_eng, _ir);
    _pipe_fwd__pipe_forward_spreads_a_tuple_lhs_into_multiple_args(_eng, _ir);
}

# ─── Walrus operator `:=` ────────────────────────────────────────────────
"""walrus operator binds inside an if-condition"""
def _walrus__walrus_operator_binds_inside_an_if_condition(eng: any, _ir: any) {
    f = get_func(eng, "walrus_in_if", ctypes.c_int64, ctypes.c_int64);
    # x=10 -> n=20 (>5) -> 21
    assert f(10) == 21;
    # x=1 -> n=2 (not >5) -> returns n=2
    assert f(1) == 2;
}

"""walrus operator rebinds inside a while-condition"""
def _walrus__walrus_operator_rebinds_inside_a_while_condition(eng: any, _ir: any) {
    f = get_func(eng, "walrus_in_while", ctypes.c_int64, ctypes.c_int64);
    # sum(0..4) = 10
    assert f(5) == 10;
    assert f(0) == 0;
    # sum(0..9) = 45
    assert f(10) == 45;
}

"""walrus expression evaluates to the assigned value"""
def _walrus__walrus_expression_evaluates_to_the_assigned_value(eng: any, _ir: any) {
    f = get_func(eng, "walrus_value", ctypes.c_int64, ctypes.c_int64);
    # m = a+10 = 15, y = 15, y+m = 30
    assert f(5) == 30;
    # m = 10, y = 10, 20
    assert f(0) == 20;
}

test "walrus" {
    (_eng, _ir) = compile_native("walrus.jac");
    _walrus__walrus_operator_binds_inside_an_if_condition(_eng, _ir);
    _walrus__walrus_operator_rebinds_inside_a_while_condition(_eng, _ir);
    _walrus__walrus_expression_evaluates_to_the_assigned_value(_eng, _ir);
}

test "user function shadowing a builtin name is called instead of the builtin" {
    (eng, _) = compile_native("shadow_builtin.jac");
    f = get_func(eng, "call_shadowed_len", ctypes.c_int64);
    # User `def len(x) { return x + 99; }` must win over the `len` builtin.
    assert f() == 100;
}

# Primitive method dispatch now keys off the emitter contract (no hardcoded
# method-name tuples); exercise int/float methods to lock that in.
"""primitive int bit_length via emitter dispatch"""
def _prim_method_dispatch__primitive_int_bit_length_via_emitter_dispatch(
    eng: any, _ir: any
) {
    f = get_func(eng, "int_bit_length", ctypes.c_int64);
    assert f() == 8;
}

"""primitive int bit_count via emitter dispatch"""
def _prim_method_dispatch__primitive_int_bit_count_via_emitter_dispatch(
    eng: any, _ir: any
) {
    f = get_func(eng, "int_bit_count", ctypes.c_int64);
    assert f() == 3;
}

"""primitive float is_integer via emitter dispatch"""
def _prim_method_dispatch__primitive_float_is_integer_via_emitter_dispatch(
    eng: any, _ir: any
) {
    f = get_func(eng, "float_is_integer", ctypes.c_int64);
    assert f() == 1;
}

test "prim_method_dispatch" {
    (_eng, _ir) = compile_native("prim_method_dispatch.jac");
    _prim_method_dispatch__primitive_int_bit_length_via_emitter_dispatch(_eng, _ir);
    _prim_method_dispatch__primitive_int_bit_count_via_emitter_dispatch(_eng, _ir);
    _prim_method_dispatch__primitive_float_is_integer_via_emitter_dispatch(_eng, _ir);
}

# Integer enum members fold through the AST .lit_value getter (base-0), so
# hex/oct/bin literals work (base-10 int(value) parsing would have raised).
test "enum hex/oct/bin int members fold via lit_value" {
    (eng, _) = compile_native("hex_enum.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    assert get_func(eng, "flag_a", ctypes.c_int64)() == 255;
    assert get_func(eng, "flag_b", ctypes.c_int64)() == 15;
    assert get_func(eng, "flag_c", ctypes.c_int64)() == 10;
}

test "parameterless no-return function (def foo {}) is not dropped" {
    # `def foo { ... }` (no parens, no return type) is semantically
    # `def foo() -> None`. The native backend used to drop such functions and
    # their call sites entirely, so `run_ticks(n)` returned 0 instead of n.
    (eng, ir) = compile_native("noret_no_params.jac");
    # The function must actually be emitted, not silently elided.
    assert native_address(eng, unit_sym(ir, "tick")) != 0 , "void no-signature function 'tick' was dropped from the module";
    run_ticks = get_func(eng, "run_ticks", ctypes.c_int64, ctypes.c_int64);
    # If the tick() calls are emitted and run, hits == n.
    assert run_ticks(5) == 5 , "calls to a no-signature void function were not emitted";
    assert run_ticks(0) == 0;
    assert run_ticks(13) == 13;
    # The no-parens form must behave identically to the explicit `()` form.
    run_ticks_parens = get_func(
        eng, "run_ticks_parens", ctypes.c_int64, ctypes.c_int64
    );
    assert run_ticks_parens(5) == run_ticks(5);
}

# --- Union / tuple-trigger field access (issue #6470) ---
"""field access on a `|` union parameter lowers the field load"""
def _union_field_access__field_access_on_a_union_parameter_lowers_the_field_load(
    eng: any, _ir: any
) {
    # `get_val(x: A | B) -> int { return x.val; }` -- both members carry `val`
    # at the same offset, so the access resolves via either member's layout.
    get_val = get_func(eng, "get_val", ctypes.c_int64, ctypes.c_void_p);
    # A is `{ val: int }` -> a single-i64 struct at offset 0.
    a = (ctypes.c_int64 * 1)(5);
    assert get_val(ctypes.cast(a, ctypes.c_void_p)) == 5;
    b = (ctypes.c_int64 * 1)(42);
    assert get_val(ctypes.cast(b, ctypes.c_void_p)) == 42;
}

"""tuple-trigger union gives `here` a usable field layout (issue #6470)"""
def _union_field_access__tuple_trigger_union_gives_here_a_usable_field_layout_issue_6470(
    eng: any, _ir: any
) {
    # `can on_either with (Sub, Other) entry { self.either += here.val; }`.
    # The tuple trigger types `here` as a union of node members; the body must
    # not truncate at `here.val` (the original bug emitted an empty body and no
    # `field.val` load, so `either` silently stayed 0).
    addr = native_address(eng, unit_sym(_ir, "W.on_either"));
    assert addr != 0 , "event ability 'W.on_either' was dropped from the module";
    fn = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p)(addr);
    # `self` is the walker W: { vtable@0, __type_tag@1, reports@2, either@3 } --
    # walkers carry the built-in `reports` list at index 2, so the user field
    # `either` sits at index 3. `here` is a node: { vtable@0, __type_tag@1,
    # val@2 } (nodes have no reports field), so `val` sits at index 2.
    self_buf = (ctypes.c_int64 * 4)(0, 0, 0, 0);
    here_buf = (ctypes.c_int64 * 3)(0, 0, 5);
    fn(ctypes.cast(self_buf, ctypes.c_void_p), ctypes.cast(here_buf, ctypes.c_void_p));
    assert self_buf[3] == 5 , "here.val was not read through the union member layout";
    # A second member instance must accumulate the same way.
    here_buf2 = (ctypes.c_int64 * 3)(0, 0, 7);
    fn(ctypes.cast(self_buf, ctypes.c_void_p), ctypes.cast(here_buf2, ctypes.c_void_p));
    assert self_buf[3] == 12;
}

test "union_field_access" {
    (_eng, _ir) = compile_native("union_field_access.jac");
    _union_field_access__field_access_on_a_union_parameter_lowers_the_field_load(
        _eng, _ir
    );
    _union_field_access__tuple_trigger_union_gives_here_a_usable_field_layout_issue_6470(
        _eng, _ir
    );
}

# --- TestNativeTestBlocks ---
"""native test blocks compile to pass/fail functions"""
def _test_blocks__native_test_blocks_compile_to_pass_fail_functions(eng: any, ir: any) {
    layout = ir.gen.native_layout;
    assert layout is not None;
    tests = layout.tests;
    assert len(tests) == 3 , f"expected 3 test entries in layout, got {len(tests)}";
    by_name = {t.name: t for t in tests};
    assert set(by_name.keys())
        == {
            "test_add_works",
            "test_globals_visible_in_tests",
            "test_deliberate_failure"
        };
    assert by_name["test_add_works"].description == "add works";
    # Globals must be initialized before tests touch them. The engine runs
    # the unit's initializer itself on the first address it hands out; the
    # initializer is idempotent, so calling it by name is harmless.
    glob_init_addr = native_address(eng, native_glob_init_name(ir.loc.mod_path));
    assert glob_init_addr != 0 , "unit initializer not found in JIT engine";
    ctypes.CFUNCTYPE(None)(glob_init_addr)();
    # Convention: null (None) = pass, static message pointer = fail.
    passing = get_func(eng, by_name["test_add_works"].symbol, ctypes.c_char_p);
    assert passing() is None , "passing test returned a failure message";
    uses_glob = get_func(
        eng, by_name["test_globals_visible_in_tests"].symbol, ctypes.c_char_p
    );
    assert uses_glob() is None , "test reading module globals failed";
    failing = get_func(eng, by_name["test_deliberate_failure"].symbol, ctypes.c_char_p);
    msg = failing();
    assert msg is not None , "failing assert did not produce a message";
    text = msg.decode("utf-8");
    assert "assertion failed" in text;
    # The failing assert sits on line 23 of the fixture; the message must
    # carry the source location so the host report can point at it.
    assert "test_blocks.jac:23" in text , f"no source location in: {text}";
}

"""a failing native test must not abort the host process"""
def _test_blocks__a_failing_native_test_must_not_abort_the_host_process(
    eng: any, ir: any
) {
    # The implicit per-test handler is what stands between a failing assert
    # and the no-handler abort() path -- calling the failing test twice in
    # one process proves the handler is popped/re-armed correctly too.
    blocks_layout = ir.gen.native_layout;
    assert blocks_layout is not None , "native layout missing";
    by_name = {t.name: t for t in blocks_layout.tests};
    failing = get_func(eng, by_name["test_deliberate_failure"].symbol, ctypes.c_char_p);
    assert failing() is not None;
    assert failing() is not None;
}

test "test_blocks" {
    (_eng, _ir) = compile_native("test_blocks.jac");
    _test_blocks__native_test_blocks_compile_to_pass_fail_functions(_eng, _ir);
    _test_blocks__a_failing_native_test_must_not_abort_the_host_process(_eng, _ir);
}

test "jac test runs .jac test blocks end to end" {
    fixture = os.path.join(FIXTURES, "test_blocks.jac");
    # The fixture holds 3 native `test` blocks, exactly 1 of them a deliberate
    # failure. Serial so the summary is not interleaved by worker output.
    env = dict(os.environ);
    env["JAC_TEST_JOBS"] = "0";
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "test", fixture],
        capture_output=True,
        text=True,
        timeout=300,
        env=env
    );
    output = result.stdout + result.stderr;
    assert "2 passed, 1 failed" in output , (
        f"expected 3 tests to run with 1 failure.\nstdout: {result.stdout[-800:]}\n"
        f"stderr: {result.stderr[-800:]}"
    );
    assert "test_blocks.jac:23" in output , (
        f"failure report must point at the failing assert.\noutput tail: {output[-800:]}"
    );
    assert result.returncode != 0 , "jac test must exit non-zero on failure";
}

test "jac test runs test blocks inside inline na blocks (no false green)" {
    fixture = os.path.join(FIXTURES, "test_blocks_inline.jac");
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "test", fixture],
        capture_output=True,
        text=True,
        timeout=300
    );
    output = result.stdout + result.stderr;
    assert "no tests ran" not in output , "inline na-block tests were silently dropped";
    # jac test reports 2 tests, exactly 1 deliberate failure.
    assert "1 passed" in output and "1 failed" in output , (
        f"expected 2 tests to run with 1 failure.\nstdout: {result.stdout[-800:]}\n"
        f"stderr: {result.stderr[-800:]}"
    );
    assert result.returncode != 0 , "jac test must exit non-zero on failure";
}

test "jac test runs inferred-native test blocks natively (item #19)" {
    fixture = os.path.join(FIXTURES, "test_blocks_inferred.jac");
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "test", fixture],
        capture_output=True,
        text=True,
        timeout=300
    );
    output = result.stdout + result.stderr;
    assert "1 passed" in output and "1 failed" in output , (
        f"expected 2 tests to run with 1 failure.\nstdout: {result.stdout[-800:]}\n"
        f"stderr: {result.stderr[-800:]}"
    );
    # The native failure format carries the source location; the python path
    # reports a bare AssertionError -- this is the native-execution discriminator.
    assert "assertion failed at" in output , (
        f"inferred test blocks must execute natively.\noutput tail: {output[-800:]}"
    );
    assert "test_blocks_inferred.jac:12" in output , (
        f"failure report must point at the failing assert.\noutput tail: {output[-800:]}"
    );
    assert result.returncode != 0 , "jac test must exit non-zero on failure";
}

test "restore-failure falls back to recompile for inferred modules (item #19)" {
    import shutil;
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    tmpdir = tempfile.mkdtemp();
    fx = os.path.join(tmpdir, "test_blocks_restore.jac");
    shutil.copyfile(os.path.join(FIXTURES, "test_blocks_inferred.jac"), fx);
    _prev = get_effective_default_codespace_override();
    set_effective_default_codespace('native');
    try {
        comp = JacCompiler();
        bc1 = comp.get_bytecode(fx, JacProgram());
        assert bc1 is not None , "warm-up compile must produce bytecode";
        prog2 = JacProgram();
        with patch.object(
            JacCompiler, '_load_native_from_bitcode', side_effect=RuntimeError('boom')
        ), patch.object(
            JacCompiler, '_load_native_from_cache', side_effect=RuntimeError('boom')
        ) {
            bc2 = comp.get_bytecode(fx, prog2);
        }
        assert bc2 is not None;
        (eng, _) = comp.get_native_interop_setup(fx, prog2);
        assert eng is not None , (
            "restore failure must trigger recompile for inferred modules"
        );
    } finally {
        set_effective_default_codespace(_prev);
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

# isinstance over a tuple mixing builtin and archetype targets lowers as a
# guarded tag/vtable disjunction; behavioral coverage lives in
# test_native_isinstance_mixed.jac (graduated from the E5092 guardrail that
# stood here after the review of #6421).

# ─── FIX: clib struct pointer subscript read/write (#6707, #6708) ─────────────
# Before the fix, buf[i] on a clib struct pointer emitted E5090.
# Fix: a struct-typed param/local (`buf: Color`) lowers to a StructName*, so
# NaIRGenPass emits a single-index GEP (one index advances a whole struct) for
# buf[i], and a struct load + store into the element pointer for buf[i] = val.
test "ptr subscript read/write: no E5090 and correct GEP IR (#6707, #6708)" {
    prog = JacProgram();
    ir = prog.compile(
        str(os.path.join(FIXTURES, "ptr_subscript.jac")), options=native_force_opts()
    );
    e5090 = [
        e.code.code
        for e in (prog.errors_had or [])
        if e.code and e.code.code == "E5090"
    ];
    assert not e5090 , f"Unexpected E5090 errors: {e5090}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    s = str(ir.gen.llvm_ir);
    # Read path (#6708): single-index GEP on the StructName* base yields the
    # element pointer, which is returned as-is (aliases the buffer, no copy).
    assert "ptr.elem.ptr" in s , "Expected array-element GEP (ptr.elem.ptr)";
    # Write path (#6707): GEP the element, load the source struct value, store.
    assert "arr.val.struct" in s , "Expected struct load for write (arr.val.struct)";
}

# ─── #7593 item 10: bare `import x` of a sibling plain .jac module ───────────
# Before the fix, `import bare_import_helper;` in a .jac emitted E5090
# "Python module import 'bare_import_helper'". After the fix, unaliased
# single-segment bare imports of resolvable Jac modules register the dep and
# `mod.fn()` / `mod.GLOB` resolve at compile time to the linked symbols.
"""bare import of user jac module compiles and links"""
def _bare_import_main__bare_import_of_user_jac_module_compiles_and_links(
    eng: any, _ir: any
) {
    assert eng is not None;
}

"""bare import module-qualified call resolves to linked symbol"""
def _bare_import_main__bare_import_module_qualified_call_resolves_to_linked_symbol(
    eng: any, _ir: any
) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    use_fn = get_func(eng, "use_fn", ctypes.c_int64);
    assert use_fn() == 42 , f"Expected 42, got {use_fn()}";
    use_twice = get_func(eng, "use_twice", ctypes.c_int64, ctypes.c_int64);
    assert use_twice(21) == 42 , f"Expected 42, got {use_twice(21)}";
}

"""bare import module glob attr reads dep glob"""
def _bare_import_main__bare_import_module_glob_attr_reads_dep_glob(eng: any, _ir: any) {
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    read_glob = get_func(eng, "read_glob", ctypes.c_int64);
    assert read_glob() == 7 , f"Expected 7, got {read_glob()}";
}

test "bare_import_main" {
    (_eng, _ir) = compile_native("bare_import_main.jac");
    _bare_import_main__bare_import_of_user_jac_module_compiles_and_links(_eng, _ir);
    _bare_import_main__bare_import_module_qualified_call_resolves_to_linked_symbol(
        _eng, _ir
    );
    _bare_import_main__bare_import_module_glob_attr_reads_dep_glob(_eng, _ir);
}

test "default-codespace option does not leak across compiles in one process" {
    # Regression: JacCompiler used to stamp the process-wide effective
    # default codespace from CompileOptions.default_codespace and never
    # restore it, so one server-pinned compile disabled plain-.jac native
    # dep resolution (bare and from-import) for every later program in the
    # same process.
    prog0 = JacProgram();
    prog0.compile(
        str(os.path.join(FIXTURES, "na_py_interop_multi.jac")),
        options=CompileOptions(default_codespace='server')
    );
    assert not prog0.errors_had , f"Errors: {prog0.errors_had}";
    (eng_a, _) = compile_native("bare_import_main.jac");
    assert eng_a is not None;
    (eng_b, _) = compile_native("glob_dep_main.jac");
    assert eng_b is not None;
}

test "from-imported plain jac dep with glob does not demote" {
    # Pins the dep-glob type-tag path: `glob G: int` in a plain .jac dep must
    # lower via the inferred tag type instead of demoting with E5092.
    (eng, _) = compile_native("glob_dep_main.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    use_dep_glob = get_func(eng, "use_dep_glob", ctypes.c_int64);
    assert use_dep_glob() == 5 , f"Expected 5, got {use_dep_glob()}";
}

# ─── #7593 item 14 (M1): new(Cls, ...) builtin + positional implicit ctors ───
# `new(Cls, args...)` is the builtin direct-constructor form (sv impl is
# `cls(*args)`, positional-only). Natively it must delegate to the same
# instantiation path as a direct `Cls(...)` call, and positional args on an
# archetype WITHOUT an explicit init must map onto the declared has-field
# order (dataclass semantics) instead of demoting with E5092.
"""native new(): positional construction of a has-field obj"""
def _new_builtin__native_new_positional_construction_of_a_has_field_obj(
    eng: any, _ir: any
) {
    make_area = get_func(eng, "make_area", ctypes.c_int64, ctypes.c_int64);
    assert make_area(5) == 25 , f"Expected 25, got {make_area(5)}";
    assert make_area(0) == 0 , f"Expected 0, got {make_area(0)}";
}

"""native new(): forwards positionally to explicit init"""
def _new_builtin__native_new_forwards_positionally_to_explicit_init(
    eng: any, _ir: any
) {
    make_sum = get_func(
        eng, "make_sum", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert make_sum(3, 4) == 7 , f"Expected 7, got {make_sum(3, 4)}";
    assert make_sum(-2, 2) == 0 , f"Expected 0, got {make_sum(-2, 2)}";
}

"""native new(): no-arg call applies field defaults"""
def _new_builtin__native_new_no_arg_call_applies_field_defaults(eng: any, _ir: any) {
    make_tag = get_func(eng, "make_tag", ctypes.c_int64);
    assert make_tag() == 7 , f"Expected 7, got {make_tag()}";
}

test "new_builtin" {
    (_eng, _ir) = compile_native("new_builtin.jac");
    _new_builtin__native_new_positional_construction_of_a_has_field_obj(_eng, _ir);
    _new_builtin__native_new_forwards_positionally_to_explicit_init(_eng, _ir);
    _new_builtin__native_new_no_arg_call_applies_field_defaults(_eng, _ir);
}

test "native positional construction maps has fields (parity with sv)" {
    (eng, _) = compile_native("pos_ctor.jac");
    direct_area = get_func(eng, "direct_area", ctypes.c_int64, ctypes.c_int64);
    assert direct_area(5) == 25 , f"Expected 25, got {direct_area(5)}";
    vec_mix = get_func(
        eng, "vec_mix", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert vec_mix(1.5, 3.25) == 153.25 , f"Expected 153.25, got {vec_mix(1.5, 3.25)}";
    label_count = get_func(eng, "label_count", ctypes.c_int64, ctypes.c_int64);
    assert label_count(9) == 12 , f"Expected 12, got {label_count(9)}";
}

# ─── #8090: inherited postinit must run on cross-module construction ─────────
# `Leaf` inherits its postinit from `Mid` in an imported module (the unitree
# `ElseIf(IfStmt)` shape). The constructor resolves the postinit owner along
# the MRO exactly like an inherited `init`; before the fix the exact-name
# lookup missed in the importing module, the chain never ran, and the
# postinit-set field read back as its zero default.
"""cross-module construction runs an inherited postinit chain"""
def _postinit_inherited_xmod_main__cross_module_construction_runs_an_inherited_postinit_chain(
    eng: any, _ir: any
) {
    make_leaf = get_func(eng, "make_leaf", ctypes.c_int64);
    assert make_leaf() == 42 , f"Expected 42, got {make_leaf()}";
}

"""cross-module construction runs an own postinit"""
def _postinit_inherited_xmod_main__cross_module_construction_runs_an_own_postinit(
    eng: any, _ir: any
) {
    make_mid = get_func(eng, "make_mid", ctypes.c_int64);
    assert make_mid() == 42 , f"Expected 42, got {make_mid()}";
}

test "postinit_inherited_xmod_main" {
    (_eng, _ir) = compile_native("postinit_inherited_xmod_main.jac");
    _postinit_inherited_xmod_main__cross_module_construction_runs_an_inherited_postinit_chain(
        _eng, _ir
    );
    _postinit_inherited_xmod_main__cross_module_construction_runs_an_own_postinit(
        _eng, _ir
    );
}
