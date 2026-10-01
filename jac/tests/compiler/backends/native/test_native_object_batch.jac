"""Parallel object emission must preserve serial bytes and isolate LLVM state."""
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.kernel_resolve { kernel_options }
import from jaclang.compiler.backends.native.na_compile_pass { emit_unit_objects }

def bitcodes -> list[bytes] {
    result: list[bytes] = [];
    for n in range(12) {
        # Repeated type names with different layouts require separate contexts.
        source = "%Box = type { i64, ["
            + str(n + 1)
            + " x i8] }\n"
            + "define i64 @value(ptr %p) {\n"
            + "  %next = getelementptr %Box, ptr %p, i64 1\n"
            + "  %v = load i64, ptr %next\n"
            + "  %r = add i64 %v, "
            + str(n)
            + "\n"
            + "  ret i64 %r\n}\n";
        with llvm.create_context() as context {
            with llvm.parse_assembly(source, context=context) as mod {
                result.append(mod.as_bitcode());
            }
        }
    }
    return result;
}

test "parallel native objects equal serial objects across repeated batches" {
    units = bitcodes();
    options = kernel_options();
    for target in [options.native_target, "x86_64-unknown-linux-gnu"] {
        options.native_target = target;
        expected = emit_unit_objects(units, options, jobs=1);
        assert len(expected) == len(units);
        assert all(expected);
        for _ in range(3) {
            assert emit_unit_objects(units, options, jobs=4) == expected;
        }
    }
    assert emit_unit_objects([], options) == [];
}

test "failed emission closes its contexts and leaves later batches usable" {
    units = bitcodes();
    options = kernel_options();
    with testraises(RuntimeError) {
        emit_unit_objects([units[0], b"invalid bitcode", units[1]], options, jobs=3);
    }
    assert emit_unit_objects(units, options, jobs=4)
        == emit_unit_objects(units, options, jobs=1);
}
