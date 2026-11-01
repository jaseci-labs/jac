"""Refcount/ownership regression tests for the native pathway (issue #7320,
Cluster 1).

Two ownership invariants of the na calling convention are exercised end to
end through the JIT:

  - every def returns a +1 reference: returning a module glob (heap string
    or list cache) must retain it, or the caller's release frees the glob
    (items 1d/1e);
  - named locals own what they hold: for-loop tuple unpack must retain the
    borrowed tuple fields it binds, or scope exit / early return releases
    strings still owned by the list (items 1a/1b/1c residue);
  - containers own what they hold: a comprehension's result must carry +1
    per element, so the elements outlive the source and the locals the
    comprehension was built from (issue #8088).

Fixtures encode first-use/second-use results into a single i64 so a wrong
value (freed glob, corrupted list) fails the assert rather than relying on
what freed memory happens to contain.
"""

import ctypes;
import json;
import from tests.support {
    KernelFixture,
    adopt_native_units,
    compile_native_ir,
    compile_native_unit,
    get_func,
    names_function,
    native_address,
    remember_native_unit,
    source_spelled
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.mir.emit { RETAIN_SYMBOL }

"""Slice one function's textual LLVM IR out of the unit the kernel emitted."""
def fn_ir(fx: KernelFixture, name: str) -> str {
    out: list[str] = [];
    inside = False;
    for ln in source_spelled(fx.llvm_ir()).split("\n") {
        if not inside and ln.startswith("define") and names_function(ln, name) {
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

# --- Returning module globs must hand the caller a +1 reference (1d/1e) ---
"""Compile a .jac fixture through the kernel under a collector mode and JIT
its native units here; return (engine, fixture)."""
def compile_native(
    fixture: str, gc_mode: str | None = None
) -> tuple[any, KernelFixture] {
    opts = CompileOptions(
        force_codespace='native',
        na_gc_mode=(gc_mode if gc_mode is not None else "cycles")
    );
    fx = compile_native_unit(fixture, "", opts, ["bytecode"]);
    prog = JacProgram();
    prog.options = opts;
    adopt_native_units(prog, fx.result, opts);
    prog._get_compiler()._load_native_from_cache(
        fx.path, prog, json.loads(fx.unit.interop) if fx.unit.interop else None
    );
    carrier = prog.hub.artifacts.get(fx.path);
    eng = carrier.native_engine if carrier is not None else None;
    assert eng is not None , f"No native engine produced for {fixture}";
    remember_native_unit(eng, fx);
    return (eng, fx);
}

test "glob return: list cache survives a for-loop over the accessor call" {
    # `for c in cmd_defs()` releases the loop collection it owns; the callee
    # must have retained the glob list or the cache dies after one scan.
    (eng, _) = compile_native("rc_glob_return.jac");
    get_func(eng, "jac_entry", None)();
    scan_twice = get_func(eng, "scan_twice", ctypes.c_int64);
    result = scan_twice();
    assert result == 13013 , f"Expected 13013 (13 per scan), got {result}";
}

test "glob return: heap glob string survives repeated accessor calls" {
    (eng, _) = compile_native("rc_glob_return.jac");
    get_func(eng, "jac_entry", None)();
    name_len_twice = get_func(eng, "name_len_twice", ctypes.c_int64);
    result = name_len_twice();
    assert result == 6006 , f"Expected 6006 (len('jactui') per read), got {result}";
}

test "glob return: accessor called inline inside len() twice" {
    (eng, _) = compile_native("rc_glob_return.jac");
    get_func(eng, "jac_entry", None)();
    defs_len_inline = get_func(eng, "defs_len_inline", ctypes.c_int64);
    result = defs_len_inline();
    assert result == 3003 , f"Expected 3003 (3 cmds per len), got {result}";
}

# --- Tuple unpack must retain the borrowed fields it binds (1a/1b/1c) ---
test "tuple unpack: second join over the same list is intact" {
    # Scope exit releases the unpack locals; without the retain the last
    # tuple's strings are freed while the list still holds them.
    (eng, _) = compile_native("rc_tuple_unpack.jac");
    get_func(eng, "jac_entry", None)();
    join_twice = get_func(eng, "join_twice", ctypes.c_int64);
    result = join_twice();
    assert result == 11 , f"Expected 11 (both joins match), got {result}";
}

test "tuple unpack: early return of an unpack-bound local keeps the list" {
    (eng, _) = compile_native("rc_tuple_unpack.jac");
    get_func(eng, "jac_entry", None)();
    early_ret = get_func(eng, "early_return_keeps_list", ctypes.c_int64);
    result = early_ret();
    assert result == 11 , f"Expected 11 (value and rejoin both ok), got {result}";
}

# --- Param names must stay per-function codegen state (issue #7466, 1/2) ---
test "param shadow: other fn's param names add no retain-on-return" {
    # `push(s, v)` is never called; its param `v` must not make `make_vec`'s
    # `return v` path treat the fresh local as a borrowed param and retain it
    # (rc=2 at the caller -> every returned Vec leaks).
    (eng, _) = compile_native("rc_param_shadow_return.jac");
    body = fn_ir(compile_native_ir("rc_param_shadow_return.jac"), "make_vec");
    n = sum(
        1
        for line in body.split("\n")
        if "call " in line and names_function(line, RETAIN_SYMBOL)
    );
    assert n == 0 , f"make_vec should return its owned local with no retain, found {n}";
    sum_first = get_func(eng, "sum_first", ctypes.c_int64, ctypes.c_int64);
    result = sum_first(3);
    assert result == 3 , f"Expected 3 (0.5 * 2 per round), got {result}";
}

test "param shadow: loop-exit cleanup still releases same-named locals" {
    # `use2(a: &Box, b: &Box)`'s param names match `churn`'s two fresh loop
    # locals; the loop-exit (iter_end) cleanup must still release both or the
    # final iteration's Boxes are never freed.
    (eng, _) = compile_native("rc_param_shadow_looptail.jac");
    churn = get_func(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    result = churn(10);
    assert result == 100 , f"Expected 100, got {result}";
}

# --- Heap-element containers under non-default gc modes (issue #7466, 3) ---
test "heap-element container compiles and runs under --memory rc" {
    # The list[str] element-release helper used to be emitted twice under
    # rc (a duplicated-name ICE), while the default cycles mode was fine.
    (eng, _) = compile_native("rc_heap_container.jac", gc_mode="rc");
    count_strs = get_func(eng, "count_strs", ctypes.c_int64);
    result = count_strs();
    assert result == 2 , f"Expected 2, got {result}";
}

test "heap-element container compiles and runs under plain --memory nogc" {
    (eng, _) = compile_native("rc_heap_container.jac", gc_mode="none");
    count_strs = get_func(eng, "count_strs", ctypes.c_int64);
    result = count_strs();
    assert result == 2 , f"Expected 2, got {result}";
}

test "import sys compiles under --memory rc (argv list is a heap container)" {
    (eng, _) = compile_native("rc_import_sys.jac", gc_mode="rc");
    addr = native_address(eng, "argc_minus_one");
    assert addr != 0 , "argc_minus_one not emitted";
}

# --- def drop parity across gc modes (issue #7466, 4) ---
"""Run the drop fixture and assert the hook fired once per destroyed Res."""
def check_drop_parity(gc_mode: str | None) {
    (eng, _) = compile_native("rc_drop_hook.jac", gc_mode=gc_mode);
    run_drops = get_func(eng, "run_drops", ctypes.c_int64);
    drop_count = get_func(eng, "drop_count", ctypes.c_int64);
    last_dropped = get_func(eng, "last_dropped", ctypes.c_int64);
    before = drop_count();
    total = run_drops();
    assert total == 18 , f"Expected 18 (5+6+7), got {total}";
    fired = drop_count() - before;
    assert fired == 3 , f"drop should fire once per Res (3), fired {fired}";
    last = last_dropped();
    assert last == 7 , f"last drop should see tag=7, got {last}";
}

test "drop hook fires on rc release (--memory rc)" {
    check_drop_parity("rc");
}

test "drop hook fires under the default cycles collector" {
    check_drop_parity(None);
}

# --- Tuple unpack across an optional store (PR #7982) ---
"""Call one fixture fn and return (result, drops it caused)."""
def call_counting_drops(eng: any, name: str, a: int, b: int) -> tuple[int, int] {
    fn = get_func(eng, name, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    drops = get_func(eng, "drop_count", ctypes.c_int64);
    before = drops();
    value = fn(a, b);
    return (value, drops() - before);
}

test "tuple unpack into an optional slot destroys each object exactly once" {
    # Two Res are allocated and bound into `Res | None` locals through the
    # coerced store. Each bind retains the field it borrows from the box,
    # the box release runs the destructor that drops the box's own
    # reference to each field, and scope exit releases each payload: one
    # destruction per allocation. The two ways to get this wrong land on
    # either side of 2, so the count discriminates between them.
    (eng, _) = compile_native("rc_tuple_unpack_optional.jac");
    (value, drops) = call_counting_drops(eng, "unpack_into_optional", 3, 4);
    assert value == 34 , f"Expected 34, got {value}";
    assert drops == 2 , (
        f"2 allocations must produce 2 drops, got {drops} "
        f"(0 means the box abandoned its fields, more than 2 that the bind "
        f"skipped its retain and each payload was released twice)"
    );
}

test "tuple unpack from an optional element costs no more than the plain one" {
    # Both fixtures allocate 4 Res and overwrite two locals through a value
    # tuple; `unpack_plain_into_plain` has no optional anywhere. They must
    # drop the same number, i.e. the optional coercion adds no leak of its
    # own. Both drop 4: the store releases what each target slot held for a
    # value tuple exactly as for a boxed one, reaching the overwritten
    # original through the optional payload when the slot is an optional.
    # Asserting the two are equal rather than naming a constant is what let
    # this survive the accounting change that moved both from 2 to 4.
    (eng, _) = compile_native("rc_tuple_unpack_optional.jac");
    (opt_value, opt_drops) = call_counting_drops(
        eng, "unpack_optional_into_plain", 3, 4
    );
    (plain_value, plain_drops) = call_counting_drops(
        eng, "unpack_plain_into_plain", 3, 4
    );
    assert opt_value == 34 , f"Expected 34 from the optional unpack, got {opt_value}";
    assert plain_value == 34 , f"Expected 34 from the plain unpack, got {plain_value}";
    assert opt_drops == plain_drops , (
        f"optional-element unpack dropped {opt_drops} but the identical "
        f"non-optional shape dropped {plain_drops}; the optional coercion "
        f"must not change ownership accounting"
    );
}

# --- Comprehension elements are owned by their container (issue #8088) ---
"""Call one fixture builder+reader and return the i64 it encodes."""
def call_elem_fn(eng: any, name: str, n: int) -> int {
    fn = get_func(eng, name, ctypes.c_int64, ctypes.c_int64);
    return fn(n);
}

test "list comprehension owns elements a borrow-returning call produced" {
    # `[x.self_ref(owner) for x in src]` -- `self_ref` hands back the receiver
    # the caller lent it, so the container's retain is the only reference the
    # element gains. `borrow_elems` then lets `src` and `owner` die, and the
    # 4 tags are read back afterwards: 10 means every element survived, 0 that
    # the list held pointers into freed heap.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "borrow_elem_sum", 4) == 10 , (
        "elements of the returned comprehension did not survive their source"
    );
    assert call_elem_fn(eng, "borrow_elem_parent_sum", 4) == 400 , (
        "the owner each element points at did not survive the builder"
    );
    # mid * 1000000 + after * 1000 + total: nothing may be destroyed while the
    # list is alive, and releasing it must destroy the 4 nodes plus the owner.
    assert call_elem_fn(eng, "borrow_elem_drops", 4) == 5010 , (
        "expected 0 destructions during the build, 5 on release and a tag sum " "of 10"
    );
}

test "list comprehension does not double-own a fresh element" {
    # `[Node(...) for x in src]` already hands over a +1; the container must
    # take that reference rather than add a second, or nothing is ever freed.
    # mid = 4 (the sources die with the builder), after = 8, total = 50.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "fresh_elem_sum", 4) == 50;
    assert call_elem_fn(eng, "fresh_elem_drops", 4) == 4008050 , (
        "a fresh element expression must net exactly one reference"
    );
}

test "list comprehension owns a bare loop variable element" {
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "alias_elem_sum", 4) == 10;
    assert call_elem_fn(eng, "alias_elem_drops", 4) == 4010 , (
        "aliasing the source's elements must still take a reference each"
    );
}

test "list comprehension owns heap string elements" {
    # The element slot is a string descriptor rather than a pointer, and the
    # strings belong to `src`, which dies with the builder. Each element is
    # compared byte for byte, so a freed descriptor cannot pass.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "label_match_count", 4) == 4 , (
        "string elements did not survive the source they were borrowed from"
    );
}

test "dict comprehension owns values a borrow-returning call produced" {
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "dict_elem_sum", 4) == 10;
    assert call_elem_fn(eng, "dict_elem_drops", 4) == 5010 , (
        "dict values must gain a reference of the dict's own"
    );
}

test "set comprehension owns elements a borrow-returning call produced" {
    # Native sets have no element iteration, so the read-back is the length;
    # the discriminator is `mid`, which counts destructions the builder caused.
    # An element expression whose storage class was inferred as a raw integer
    # takes no reference at all, and every node dies with the builder (5004).
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "set_elem_drops", 4) == 4 , (
        "set elements were destroyed while the set still held them"
    );
}

test "nested comprehension: inner lists own their elements too" {
    # `[[y.self_ref(owner) for y in src] for x in src]`: 4 inner lists of the
    # same 4 nodes, read back as 4 * (1+2+3+4). Only the construction side is
    # asserted -- releasing the outer list is left out because iterating a
    # list whose elements are themselves lists leaks the last loop value,
    # which is a separate defect from element ownership.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "nested_elem_drops", 4) == 40 , (
        "expected no destructions during the build and a tag sum of 40"
    );
}

test "comprehension over a borrowed collection leaves it intact" {
    # The walk releases the collection only when the frame owns it. Here the
    # source is a param, so releasing the built list must not reach into it:
    # mid = 0 and the caller's `src` still sums to 10.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "param_elem_sum", 4) == 20;
    assert call_elem_fn(eng, "param_elem_drops", 4) == 10 , (
        "releasing the built list destroyed elements the borrowed source held"
    );
}

test "returning the receiver hands the caller a reference of its own" {
    # The same `return self` outside any container: `src[0].self_ref(owner)` is
    # bound to a local, then the list that made the node is dropped. Encoded as
    # kept.tag * 1000 + owner.tag, so 1100 needs both the element and the owner
    # its parent field points at; 100 is what a freed element reads back as.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "self_ref_direct", 4) == 1100 , (
        "the returned receiver did not outlive the list that held it"
    );
}

test "returning an element indexed through the receiver still retains it" {
    # `return self.kids[0]` is the one shape whose retain is decided by a rule
    # that asks whether the container's root is a slot the frame owns. Making
    # the receiver a borrow changes that answer, so both element kinds are
    # pinned: a pointer, and a string descriptor, which the generic
    # retain-on-return does not cover because it is not a pointer type.
    (eng, _) = compile_native("rc_container_elem_ownership.jac");
    assert call_elem_fn(eng, "kid_elem_return", 4) == 1 , (
        "an object element returned out of a field slot was released early"
    );
    assert call_elem_fn(eng, "kid_label_return", 4) == 2 , (
        "a string element returned out of a field slot was released early"
    );
}
