"""Walk-order independence gates for native cross-module type identity (#7871 F).

Native lowering resolves type identity and layout through the central layout
authority (LayoutRegistry, keyed by defining module + symbol), so the order in
which the native pass walks imported modules must not change the emitted IR.
These tests compile the cross-module fixture chains under forward, reversed,
and shuffled module walk orders via the `native_module_walk_order` compile
option (the same code path production uses; production leaves it unset) and
require identical IR. The enum chain hashes byte-identical raw IR text; the
obj-field chain is hashed after sorting top-level IR entities, because the
only order-sensitive residue there is the print order of identified-struct
and extern declarations, never their content.

An unlowerable field type in a native context is a loud E5092 naming the
type. The slot does erase to an opaque pointer now -- a `has` type is resolved
while the archetype is laid out, outside every ability body, so there was no
demotion window to spend the refusal in and it withheld the whole module's IR
instead. `_opaque_field_if_unlowerable` gives the declaration its own: the
E5092 is re-published as a coverage seam keyed on the field, and the slot joins
`struct_field_foreign`.

That is only honest because the erasure is not a rescue. The slot holds
nothing the native side wrote, so it can never be read as though it did: every
callable touching it refuses with its own E5092 naming the field, inside its
own demotion window. The test below pins both halves against
`unlowerable_field.jac` -- the declaration's seam, the touching function's
refusal and demotion, and the untouched functions that keep lowering because
the refusal is no longer module-wide.
"""

import ctypes;
import hashlib;
import os;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from tests.support { native_address }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     WALK_ORDERS: list = [None, "reverse", "shuffle:1337", "shuffle:7", "shuffle:42"];

"""Compile a fixture natively under a given module walk order; return IR text."""
def compile_ir_text(fixture: str, walk_order: str | None) -> str {
    prog = JacProgram();
    opts = CompileOptions(
        force_codespace='native',
        force_target_program=True,
        skip_native_engine=True,
        native_module_walk_order=walk_order
    );
    mod = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    assert mod.gen.llvm_ir is not None , f"No IR emitted for {fixture}";
    return str(mod.gen.llvm_ir);
}

"""Rejoin IR with top-level entities sorted; function bodies stay intact."""
def toplevel_sorted(ir_text: str) -> str {
    blocks: list[str] = [];
    cur: list[str] = [];
    in_define = False;
    for line in ir_text.splitlines() {
        if in_define {
            cur.append(line);
            if line == "}" {
                blocks.append("\n".join(cur));
                cur = [];
                in_define = False;
            }
        } elif line.startswith("define ") {
            cur = [line];
            in_define = True;
        } elif line.strip() {
            blocks.append(line);
        }
    }
    if cur {
        blocks.append("\n".join(cur));
    }
    return "\n".join(sorted(blocks));
}

def ir_hash(text: str) -> str {
    return hashlib.sha256(text.encode()).hexdigest();
}

test "cross-module enum chain IR is byte-identical under any walk order" {
    hashes: dict = {};
    for order in WALK_ORDERS {
        hashes[order or "forward"] = ir_hash(
            compile_ir_text("opcodes_entry.jac", order)
        );
    }
    assert len(set(hashes.values())) == 1 , f"IR diverged by walk order: {hashes}";
}

test "imported obj-field chain IR is walk-order independent" {
    hashes: dict = {};
    for order in WALK_ORDERS {
        hashes[order or "forward"] = ir_hash(
            toplevel_sorted(compile_ir_text("xmodfield_entry.jac", order))
        );
    }
    assert len(set(hashes.values())) == 1 , f"IR diverged by walk order: {hashes}";
}

test "imported obj-field chain executes correctly" {
    prog = JacProgram();
    opts = CompileOptions(force_codespace='native', force_target_program=True);
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "xmodfield_entry.jac"), options=opts
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = mod.gen.native_engine;
    assert eng is not None , "No native engine produced";
    addr = native_address(eng, "imported_field_checksum");
    assert addr != 0 , "imported_field_checksum not found";
    result = ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
    assert result == 1020 , f"Expected 1020, got {result}";
}

test "an unlowerable field erases loudly: the declaration seams, every touch refuses" {
    prog = JacProgram();
    opts = CompileOptions(
        force_codespace='native', force_target_program=True, skip_native_engine=True
    );
    na_coverage_begin();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "unlowerable_field.jac"), options=opts
    );
    snap = na_coverage_end();
    seams: list = [];
    for (path, rec) in snap.items() {
        if os.path.basename(path) == "unlowerable_field.jac" {
            seams = list(rec['seams']);
        }
    }
    # The declaration owns its refusal: E5092 and the offending type name
    # survive verbatim, keyed on the field rather than dissolved into the
    # module.
    decl = [
        s
        for s in seams
        if s.startswith("Holder.view:")
    ];
    assert decl , f"no seam keyed on the erased field, got: {seams}";
    assert all("E5092" in s for s in decl) , (
        f"the field's seam must carry E5092: {decl}"
    );
    assert all("memoryview" in s for s in decl) , (
        f"the field's seam must name the unlowerable type: {decl}"
    );
    # The gate that replaced module-wide withholding: the erased slot holds
    # nothing the native side wrote, so a callable that touches it refuses by
    # name inside its own demotion window rather than reading the slot's bits.
    touch = [
        s
        for s in seams
        if s.startswith("read_view:")
    ];
    assert touch , f"touching an erased field must be its own seam, got: {seams}";
    assert all("E5092" in s and "Holder.view" in s for s in touch) , (
        f"the touch seam must be an E5092 naming the erased field: {touch}"
    );
    # Spending the refusal on the field is only worth anything if the module
    # survives it -- that is the whole reason the diagnostic moved off the
    # module, so it is pinned here rather than left implied.
    assert mod.gen.llvm_ir is not None , (
        "an erased field must no longer withhold the module's IR"
    );
    layout = mod.gen.native_layout;
    assert layout is not None , "an erased field must not abort the module";
    assert "read_view" not in layout.functions , (
        "a function that reads an erased slot must leave the native layout"
    );
    # And the reason the refusal moved onto the field at all: everything that
    # never names the erased slot still lowers. A module-wide E5092 took these
    # down with it.
    for fn in ["read_tag", "holder_tag"] {
        assert fn in layout.functions , (
            f"'{fn}' never touches the erased slot and must still lower; "
            + f"layout has {sorted(layout.functions.keys())}"
        );
    }
}
