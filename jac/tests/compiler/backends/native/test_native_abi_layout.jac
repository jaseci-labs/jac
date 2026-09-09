"""Bridge metadata uses the target ABI, including small nested aggregates."""

import from jaclang.compiler.backends.native.abi { struct_layouts }
import from jaclang.compiler.backends.native.llvm { binding, ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

test "target data retains its type through the context manager" {
    source = """
import from jaclang.compiler.backends.native.llvm.binding.targets { create_target_data }
import from jaclang.compiler.backends.native.llvm.binding.value { ValueRef }

def layout(value: ValueRef) -> tuple[list[int], int] {
    with create_target_data("e-p:64:64") as data {
        return data.get_global_struct_layout(value, 1);
    }
}
""";
    prog = JacProgram();
    prog.compile(
        use_str=source,
        file_path="abi_type_contract.jac",
        options=CompileOptions(
            no_cgen=True, no_ir_cache=True, force_target_program=True
        )
    );
    assert not prog.errors_had , str(prog.errors_had);
}

test "a nullable boolean does not add eight bytes of padding" {
    binding.initialize_native_target();
    target = binding.Target.from_default_triple().create_target_machine();
    module = ir.Module(context=ir.Context());
    module.data_layout = str(target.target_data);
    small = ir.LiteralStructType([ir.IntType(8), ir.IntType(1)]);
    example = module.context.get_identified_type("Example");
    example.set_body(ir.IntType(8), small, ir.IntType(8));
    assert struct_layouts(module)["Example"] == ([0, 1, 3], 4);
}
