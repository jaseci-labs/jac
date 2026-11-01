"""Walk-order independence gates for native cross-module type identity (#7871 F).

Native lowering resolves type identity and layout by defining module and
symbol, so the order in which the backend walks imported modules must not
change the emitted IR. These tests compile the cross-module fixture chains
under forward, reversed, and shuffled module walk orders via the
`native_module_walk_order` compile option (production leaves it unset) and
require identical IR. The enum chain hashes byte-identical raw IR text; the
obj-field chain is hashed after sorting top-level IR entities, because the
only order-sensitive residue there is the print order of identified-struct
and extern declarations, never their content.

An unlowerable field type in a native context is a loud E5092 naming the
type, spent on the field rather than on the module. The slot holds nothing
the native side wrote, so every function touching it refuses by name, while
the functions that never touch it keep lowering. The last test pins both
halves against `unlowerable_field.jac`.
"""

import ctypes;
import hashlib;
import from tests.support {
    compile_mir,
    compile_native,
    compile_native_ir,
    compile_native_refused,
    diagnostics_text,
    error_codes,
    native_address
}
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob WALK_ORDERS: list[any] = [
         None,
         "reverse",
         "shuffle:1337",
         "shuffle:7",
         "shuffle:42"
     ];

"""Compile a fixture natively under a given module walk order; return IR text."""
def compile_ir_text(fixture: str, walk_order: str | None) -> str {
    text = compile_native_ir(
        fixture,
        options=CompileOptions(
            force_codespace='native', native_module_walk_order=walk_order
        )
    ).llvm_ir();
    assert text , f"No IR emitted for {fixture}";
    return text;
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
    hashes: dict[str, any] = {};
    for order in WALK_ORDERS {
        hashes[order or "forward"] = ir_hash(
            compile_ir_text("opcodes_entry.jac", order)
        );
    }
    assert len(set(hashes.values())) == 1 , f"IR diverged by walk order: {hashes}";
}

test "imported obj-field chain IR is walk-order independent" {
    hashes: dict[str, any] = {};
    for order in WALK_ORDERS {
        hashes[order or "forward"] = ir_hash(
            toplevel_sorted(compile_ir_text("xmodfield_entry.jac", order))
        );
    }
    assert len(set(hashes.values())) == 1 , f"IR diverged by walk order: {hashes}";
}

test "imported obj-field chain executes correctly" {
    (eng, _) = compile_native("xmodfield_entry.jac");
    addr = native_address(eng, "imported_field_checksum");
    assert addr != 0 , "imported_field_checksum not found";
    result = ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
    assert result == 1020 , f"Expected 1020, got {result}";
}

test "an unlowerable field erases loudly: the declaration refuses, every touch refuses" {
    # The declaration owns its refusal: where native is required it is an
    # E5092 naming the offending type.
    refused = compile_native_refused("unlowerable_field.jac");
    text = diagnostics_text(refused);
    assert "E5092" in error_codes(refused) , text;
    assert "memoryview" in text , f"the refusal must name the unlowerable type: {text}";
    # The erased slot holds nothing the native side wrote, so a function that
    # touches it refuses by name rather than reading the slot's bits.
    fx = compile_mir("unlowerable_field.jac");
    assert fx.is_demoted("read_view") , (
        f"a function that reads an erased slot must be demoted: {fx.demoted()}"
    );
    assert "view" in fx.reason("read_view") , (
        f"the touch must be refused naming the erased field: {fx.reason('read_view')}"
    );
    # And the reason the refusal moved onto the field at all: everything that
    # never names the erased slot still lowers. A module-wide refusal took
    # these down with it.
    for fn in ["read_tag", "holder_tag"] {
        assert not fx.is_demoted(fn) , (
            f"'{fn}' never touches the erased slot and must still lower: {fx.demoted()}"
        );
    }
}
