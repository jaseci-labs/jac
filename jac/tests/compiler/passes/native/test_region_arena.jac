"""Native region arena tests (#7491 R1).

An `in <handle> {}` open bump-allocates its object instantiations into the
handle's arena (sentinel-stamped headers, inert to every RC fast path) and
reclaims wholesale at the handle's drop point: dtor-log walk (LIFO), then
one bulk chunk free. These tests pin the allocation routing at the IR level
and the drop-hook/teardown behavior through the JIT.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(
    fixture: str, gc_mode: str | None = None
) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    opts = CompileOptions(na_gc_mode=gc_mode) if gc_mode is not None else None;
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)), options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Slice one function's textual IR out of the module dump."""
def fn_ir(ir: uni.Module, name: str) -> str {
    out: list[str] = [];
    inside = False;
    for ln in str(ir.gen.llvm_ir).split("\n") {
        if not inside and ln.startswith("define") and (('@"' + name + '"') in ln) {
            inside = True;
        }
        if inside {
            out.append(ln);
            if ln == "}" {
                break;
            }
        }
    }
    assert out , f"No IR found for function '{name}'";
    return "\n".join(out);
}

test "arena: region interior bump-allocates and bulk-frees, not __rc_alloc" {
    # Stack-eligible objects (like region_arena's Box) may still take the
    # stack path inside an open; droppable types must route to the arena.
    (eng, ir) = compile_native("region_dtor.na.jac");
    body = fn_ir(ir, "dtor_order");
    n_arena = body.count('call i8* @"__jac_region_alloc"');
    assert n_arena == 3 , f"expected 3 arena allocs in dtor_order, found {n_arena}";
    n_rc = body.count('call i8* @"__rc_alloc"');
    assert n_rc == 0 , f"region interior must not hit __rc_alloc, found {n_rc}";
    n_drop = body.count('call void @"__jac_region_drop"');
    assert n_drop >= 1 , f"expected a region drop at the close, found {n_drop}";
}

test "arena: anonymous open sums correctly through the JIT" {
    (eng, ir) = compile_native("region_arena.na.jac");
    region_sum = get_func(eng, "region_sum", ctypes.c_int64, ctypes.c_int64);
    result = region_sum(5);
    assert result == 10 , f"region_sum(5) == {result}, expected 10";
}

test "arena: dtor-log runs drop hooks LIFO at the close of an anonymous open" {
    (eng, ir) = compile_native("region_dtor.na.jac");
    dtor_order = get_func(eng, "dtor_order", ctypes.c_int64);
    result = dtor_order();
    assert result == 321 , f"dtor_order() == {result}, expected LIFO 321";
}

test "arena: named handle drops on reassignment and at scope exit" {
    (eng, ir) = compile_native("region_dtor.na.jac");
    named_handle = get_func(eng, "named_handle", ctypes.c_int64);
    result = named_handle();
    # before reassignment nothing dropped (0), reassigning the handle drops
    # the first arena (7); the second arena drops at scope exit, AFTER the
    # return value is computed (handles hold to scope exit so borrows of
    # region values stay valid past the handle's own last mention, R2).
    assert result == 707 , f"named_handle() == {result}, expected 707";
    read_log = get_func(eng, "read_log", ctypes.c_int64);
    log = read_log();
    assert log == 79 , f"scope exit must run the dtor log: log {log} != 79";
}

test "arena: dynamic extent -- made in a helper, grown remotely, dropped here" {
    (eng, ir) = compile_native("region_extent.na.jac");
    scenario = get_func(eng, "scenario", ctypes.c_int64);
    result = scenario();
    # nothing drops while the handle travels through make/grow/grow
    assert result == 0 , f"scenario() == {result}, expected 0 before drop";
    read_log = get_func(eng, "read_log", ctypes.c_int64);
    log = read_log();
    # one arena, all three dtor-log entries, LIFO across the whole extent
    assert log == 321 , f"remote drop must run the full dtor log: {log} != 321";
}

test "arena: early return inside an open still tears the region down" {
    (eng, ir) = compile_native("region_dtor.na.jac");
    early_return = get_func(eng, "early_return", ctypes.c_int64, ctypes.c_int64);
    result = early_return(1);
    assert result == 0 , f"early_return(1) == {result}, expected 0";
    read_log = get_func(eng, "read_log", ctypes.c_int64);
    log = read_log();
    assert log == 5 , f"return path must drop the arena: log {log} != 5";
    result2 = early_return(0);
    assert result2 == 105 , f"early_return(0) == {result2}, expected 105";
}

test "arena: managed values cross an open safely" {
    (eng, ir) = compile_native("region_dtor.na.jac");
    mixed_managed = get_func(eng, "mixed_managed", ctypes.c_int64, ctypes.c_int64);
    result = mixed_managed(4);
    assert result == 6 , f"mixed_managed(4) == {result}, expected 6";
}

test "phase W: walkers reclaim -- spawn-heavy loop fires drop per walker" {
    (eng, ir) = compile_native("walker_reclaim.na.jac");
    run = get_func(eng, "run", ctypes.c_int64, ctypes.c_int64);
    result = run(4);
    assert result == 12 , f"run(4) == {result}, expected 12";
    read_dropped = get_func(eng, "read_dropped", ctypes.c_int64);
    n_dropped = read_dropped();
    assert n_dropped == 4 , f"expected 4 reclaimed walkers, got {n_dropped}";
}

test "R3: region-resident topology traverses live and reclaims at drop" {
    (eng, ir) = compile_native("region_graph.na.jac");
    scenario = get_func(eng, "scenario", ctypes.c_int64);
    result = scenario();
    assert result == 3 , f"scenario() == {result}, expected traversal sum 3";
    read_log = get_func(eng, "read_log", ctypes.c_int64);
    log = read_log();
    assert log == 2 , f"handle drop must reclaim both nodes: {log} != 2";
}

test "R3: growth rule -- mid-traversal allocations land in region_of(here)" {
    (eng, ir) = compile_native("region_growth.na.jac");
    scenario = get_func(eng, "scenario", ctypes.c_int64);
    result = scenario();
    assert result == 2 , f"scenario() == {result}, expected 2 grown nodes";
    read_log = get_func(eng, "read_log", ctypes.c_int64);
    log = read_log();
    assert log == 3 , f"drop must reclaim seed + grown nodes: {log} != 3";
}

test "R4: own rebox copies a string out of a region" {
    (eng, ir) = compile_native("region_rebox.na.jac");
    out = get_func(eng, "out", ctypes.c_char_p);
    result = out();
    assert result == b"hi" , f"out() == {result}, expected b'hi'";
}

test "a user archetype named Region shadows the builtin cleanly" {
    (eng, ir) = compile_native("region_shadow.na.jac");
    body = fn_ir(ir, "shadowed");
    n_new = body.count('call i8* @"__jac_region_new"');
    assert n_new == 0 , f"user Region must not intercept arena setup: {n_new}";
    shadowed = get_func(eng, "shadowed", ctypes.c_int64);
    result = shadowed();
    assert result == 7 , f"shadowed() == {result}, expected 7";
}
