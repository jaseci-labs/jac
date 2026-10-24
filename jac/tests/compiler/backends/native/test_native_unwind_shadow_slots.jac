"""Unwind records hold only the slots their cleanup reads, through shadows.

A function that owns a reference registers an unwind record on entry: the
slots a raise crossing the frame has to release. Handing the record a slot's
address keeps that slot out of a register for the whole function, so the
record holds only the slots its cleanup reads, and each of those through a
shadow copy written right after every store into the slot; the slot itself
stays promotable. These tests read the generated IR: the result and leak
checks of test_native_unwind_release would still pass if every local
escaped again.
"""

import re;
import from tests.support { compile_native_ir }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.llvm.binding { parse_bitcode }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }

glob FIXTURE: str = "na_unwind_shadow_slots.jac";

"""The text of function `name` in the module text `text` ("" when absent)."""
def fn_body(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    if found is None {
        return "";
    }
    return found.group(0);
}

"""The sizes of the function's unwind record arrays."""
def env_sizes(body: str) -> list[int] {
    return [int(n) for n in re.findall(r'unwind\.env"? = alloca \[(\d+) x', body)];
}

"""The locals that have a shadow slot."""
def shadowed(body: str) -> list[str] {
    return sorted(re.findall(r'%"?([\w. ]+?)\.unwind"? = alloca', body));
}

"""The stores whose target is the slot `slot`, as (line index, line)."""
def stores_into(lines: list[str], slot: str) -> list[tuple[int, str]] {
    pat = re.compile(r'^\s*store .*, .*%"' + re.escape(slot) + r'"\s*$');
    return [
        (i, line)
        for (i, line) in enumerate(lines)
        if pat.`match(line)
    ];
}

"""The unoptimized IR of the fixture, and the unit's optimized IR."""
def fixture_ir -> tuple[str, str] {
    mod = compile_native_ir(FIXTURE);
    text = str(mod.gen.llvm_ir);
    opt = str(parse_bitcode(mod.gen.native_bitcode))
        if mod.gen.native_bitcode is not None
        else "";
    return (text, opt);
}

test "scalars stay out of the record; the owned local is registered through its shadow" {
    (text, _opt) = fixture_ir();
    body = fn_body(text, "scalars_and_one_owner");
    assert body , "scalars_and_one_owner not found in the IR";
    # `a`, `b`, `f`, `flag` and `i` are scalars: only `box` is in the record
    assert env_sizes(body) == [1] , f"record sizes {env_sizes(body)}, want [1]";
    assert shadowed(body) == ["box"] , f"shadows {shadowed(body)}, want ['box']";
    # the record is handed the shadow's address, not the slot's
    assert re.search(r'bitcast [^\n]*%"box\.unwind" to i8\*', body) , "the record does not take box.unwind";
    assert not re.search(r'bitcast [^\n]*%"box" to i8\*', body) , "the record takes box's own slot";
}

test "after optimization the function's locals live in registers" {
    (_text, opt) = fixture_ir();
    assert opt , "no optimized bitcode";
    body = fn_body(opt, "scalars_and_one_owner");
    assert body , "scalars_and_one_owner not found in the optimized IR";
    # every local was promoted: the only stack slots left are the shadow, the
    # record and its chain node (an escaped scalar would keep an alloca)
    slots = sorted(re.findall(r'%"?([\w.]+)"? = alloca', body));
    assert slots == ["box.unwind", "unwind.env", "unwind.node"] , f"stack slots after optimization: {slots}";
}

test "every store into a registered slot is followed by the same store into its shadow" {
    (text, _opt) = fixture_ir();
    for (name, slot, min_stores) in [
        ("scalars_and_one_owner", "box", 2),
        ("reassigned", "box", 4),
        ("in_handler", "box", 3),
        ("owned_tuple", "t", 2)
    ] {
        lines = fn_body(text, name).splitlines();
        assert lines , f"{name} not found in the IR";
        stores = stores_into(lines, slot);
        assert len(stores) >= min_stores , f"{name}: {len(stores)} stores into {slot}, want at least {min_stores}";
        for (i, line) in stores {
            nxt = lines[i + 1] if i + 1 < len(lines) else "";
            assert re.`match(
                r'^\s*store .*, .*%"' + re.escape(slot) + r'\.unwind"\s*$', nxt
            ) , f"{name}: store into {slot} not mirrored:\n{line}\n{nxt}";
            # the same value goes into both
            value = line.split(",")[0].split()[-1];
            assert nxt.split(",")[0].split()[-1] == value , f"{name}: shadow of {slot} gets another value:\n{line}\n{nxt}";
        }
        assert len(stores_into(lines, slot + ".unwind")) == len(stores) , f"{name}: the shadow of {slot} has stores of its own";
    }
}

test "a store inside an exception handler is mirrored, and the caught exception is registered" {
    (text, _opt) = fixture_ir();
    body = fn_body(text, "in_handler");
    assert body , "in_handler not found in the IR";
    # `box` and the caught-exception holder: both are released by the cleanup
    assert env_sizes(body) == [2] , f"record sizes {env_sizes(body)}, want [2]";
    assert shadowed(body) == ["__jac caught", "box"] , f"shadows {shadowed(body)}";
    # the handler's `box = Box(v=7)` is one of the mirrored stores (the
    # previous test checks the mirroring): 1 zero-init + 1 initial + 1 in the
    # handler + the scope cleanup's null stores
    assert len(stores_into(body.splitlines(), "box")) >= 3;
}

test "a slot whose address is used other than by load and store is registered itself" {
    module = ir.Module(name="shadow_probe");
    i8p = ir.IntType(8).as_pointer();
    use_fn = ir.Function(
        module, ir.FunctionType(ir.VoidType(), [i8p.as_pointer()]), name="use_slot"
    );
    func = ir.Function(module, ir.FunctionType(ir.VoidType(), []), name="probe");
    b = ir.IRBuilder(func.append_basic_block("entry"));
    plain = b.alloca(i8p, name="plain");
    taken = b.alloca(i8p, name="taken");
    b.store(ir.Constant(i8p, None), plain);
    b.store(ir.Constant(i8p, None), taken);
    b.call(use_fn, [taken]);
    b.load(plain, name="plain.v");
    b.ret_void();
    # (it reads nothing of the pass, so no pass instance is needed)
    make_shadows = getattr(NaIRGenPass, "_unwind_shadow_slots");
    shadows: dict[int, ir.Value] = make_shadows(
        None, func, [("plain", plain), ("taken", taken)]
    );
    assert id(plain) in shadows , "the load/store-only slot got no shadow";
    assert id(taken) not in shadows , "the slot whose address is passed on was shadowed";
    text = str(func);
    assert '%"plain.unwind" = alloca' in text;
    assert '"taken.unwind"' not in text;
    # the store into `plain` is mirrored right after it
    lines = text.splitlines();
    for (i, line) in stores_into(lines, "plain") {
        nxt = lines[i + 1];
        assert re.`match(r'^\s*store .*%"plain\.unwind"\s*$', nxt) , f"store into plain not mirrored:\n{line}\n{nxt}";
    }
}
