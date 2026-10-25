"""A link's heap glue is read from each unit's own scan, kept by its bitcode.

The heap-accounting glue a link synthesizes depends on which units declare
`jac_heap_size` and `jac_list_heap_size` and which define them, and every link
parsed every unit's bitcode again to find out (twice per objects-mode link).
Each unit's answer is now kept by the hash of its bitcode, in memory and under
the JIR cache, so a link after a one-unit change parses only that unit, and an
edit that changes what a unit declares is scanned again.
"""
import os;
import tempfile;
import from unittest.mock { patch }
import jaclang.compiler.backends.native.llvm.binding as llvm_binding;
import from jaclang.compiler.backends.native.link_glue { inject_heap_accounting }
import from jaclang.compiler.backends.native.link_plan {
    build_link_plan,
    glue_symbol_memo_clear,
    heap_glue_ir
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob TOP = "import from lib { Box, box_size }\n\nwith entry {\n    print(box_size(Box()) + 1);\n}\n",
     TOP_EDITED = "import from lib { Box, box_size }\n\nwith entry {\n    print(box_size(Box()) + 2);\n}\n",
     LIB_PLAIN = "obj Box {\n    has values: list[int] = [];\n}\n\ndef box_size(b: Box) -> int {\n    return len(b.values);\n}\n",
     LIB_HEAP = "import from c {\n    def jac_heap_size(address: u64) -> i64;\n}\n\nobj Box {\n    has values: list[int] = [];\n}\n\ndef box_size(b: Box) -> int {\n    return int(jac_heap_size(u64(id(b))));\n}\n";

def write(directory: str, name: str, text: str) {
    with open(os.path.join(directory, name), "w") as handle {
        handle.write(text);
    }
}

def plan_for(directory: str) -> any {
    prog = JacProgram();
    opts = CompileOptions(
        aot_mode=True, default_codespace="native", skip_native_engine=True
    );
    prog.options = opts;
    return build_link_plan(prog, [os.path.join(directory, "top.jac")], opts);
}

"""The glue as every link computed it before: each unit's bitcode parsed."""
def parsed_heap_glue(plan: any) -> tuple[str, list[str]] {
    declarations: dict[str, str] = {};
    defined: set[str] = set();
    managed = not any(unit.iface.headerless for unit in plan.units);
    registry = plan.prog.native_units();
    for unit in plan.units {
        module = llvm_binding.parse_bitcode(
            registry.bitcode_for(unit.path, plan.options)
        );
        for function in module.functions {
            if function.name in ("jac_heap_size", "jac_list_heap_size") {
                if function.is_declaration {
                    declarations[function.name] = str(function);
                } else {
                    defined.add(function.name);
                }
            }
        }
    }
    text = "\n".join(
        value
        for (name, value) in declarations.items()
        if name not in defined
    );
    if not text {
        return ("", []);
    }
    return inject_heap_accounting(
        'target triple = "' + plan.triple + '"\n' + text, managed
    );
}

"""Run `heap_glue_ir` as a fresh process would, counting bitcode parses."""
def glue_counting_parses(plan: any) -> tuple[tuple[str, list[str]], list[bytes]] {
    glue_symbol_memo_clear();
    parsed: list[bytes] = [];
    real = llvm_binding.parse_bitcode;
    def counting(data: bytes) -> any {
        parsed.append(data);
        return real(data);
    }
    with patch.object(llvm_binding, "parse_bitcode", counting) {
        glue = heap_glue_ir(plan);
    }
    return (glue, parsed);
}

test "a link after a one-unit change parses only that unit and matches a cold link" {
    with tempfile.TemporaryDirectory() as directory {
        directory = os.path.realpath(directory);
        write(directory, "lib.jac", LIB_HEAP);
        write(directory, "top.jac", TOP);
        first = plan_for(directory);
        assert len(first.units) > 2 , [u.path for u in first.units];
        (cold, _) = glue_counting_parses(first);
        assert cold == parsed_heap_glue(first);
        assert "jac_heap_size" in cold[1] , cold[1];
        top = os.path.join(directory, "top.jac");
        before_edit = first.prog.native_units().bitcode_for(top, first.options);
        write(directory, "top.jac", TOP_EDITED);
        second = plan_for(directory);
        top_bitcode = second.prog.native_units().bitcode_for(top, second.options);
        assert top_bitcode != before_edit;
        (warm, parsed) = glue_counting_parses(second);
        assert parsed == [top_bitcode] , len(parsed);
        assert warm == parsed_heap_glue(second);
        assert warm == cold;
        parsed_again: list[bytes] = [];
        real = llvm_binding.parse_bitcode;
        def counting(data: bytes) -> any {
            parsed_again.append(data);
            return real(data);
        }
        with patch.object(llvm_binding, "parse_bitcode", counting) {
            assert heap_glue_ir(second) == warm;
        }
        assert parsed_again == [];
    }
}

test "a unit that comes to declare heap accounting is scanned again" {
    with tempfile.TemporaryDirectory() as directory {
        directory = os.path.realpath(directory);
        write(directory, "lib.jac", LIB_PLAIN);
        write(directory, "top.jac", TOP);
        plain = plan_for(directory);
        (before, _) = glue_counting_parses(plain);
        assert before == parsed_heap_glue(plain);
        assert "jac_heap_size" not in before[1] , before[1];
        write(directory, "lib.jac", LIB_HEAP);
        heap = plan_for(directory);
        (after, parsed) = glue_counting_parses(heap);
        lib_bitcode = heap.prog.native_units().bitcode_for(
            os.path.join(directory, "lib.jac"), heap.options
        );
        assert lib_bitcode in parsed;
        assert after == parsed_heap_glue(heap);
        assert "jac_heap_size" in after[1] , after[1];
    }
}
