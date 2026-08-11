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
type; the opaque i8* rescue does not exist.
"""

import ctypes;
import hashlib;
import os;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     WALK_ORDERS: list = [None, "reverse", "shuffle:1337", "shuffle:7", "shuffle:42"];

"""Compile a fixture natively under a given module walk order; return IR text."""
def compile_ir_text(fixture: str, walk_order: str | None) -> str {
    prog = JacProgram();
    opts = CompileOptions(
        type_check=False,
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
    opts = CompileOptions(
        type_check=False, force_codespace='native', force_target_program=True
    );
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "xmodfield_entry.jac"), options=opts
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = mod.gen.native_engine;
    assert eng is not None , "No native engine produced";
    addr = eng.get_function_address("imported_field_checksum");
    assert addr != 0 , "imported_field_checksum not found";
    result = ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
    assert result == 1020 , f"Expected 1020, got {result}";
}

test "unlowerable field type is a loud E5092 naming the type, never opaque i8*" {
    prog = JacProgram();
    opts = CompileOptions(
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        skip_native_engine=True
    );
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "unlowerable_field.jac"), options=opts
    );
    matches = [
        alrt
        for alrt in prog.errors_had
        if alrt.code is not None and alrt.code.code == "E5092"
    ];
    assert matches , (f"Expected E5092, got: {[str(e) for e in prog.errors_had]}");
    assert any("memoryview" in str(alrt) for alrt in matches) , (
        f"E5092 must name the unlowerable type: {[str(e) for e in matches]}"
    );
    assert mod.gen.llvm_ir is None , (
        "a module with an unlowerable field type must not publish llvm ir"
    );
    assert mod.gen.native_engine is None , (
        "a module with an unlowerable field type must not publish a jit engine"
    );
}
