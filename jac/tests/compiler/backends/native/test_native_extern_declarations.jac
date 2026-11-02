"""Extern reuse preserves the requested ABI independently of declaration order."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
import from jaclang.compiler.backends.native.llvm { ir, binding as llvm }
import from jaclang.compiler.passes.context { CompileContext }

def lowering -> NaIRGenPass {
    program = JacProgram();
    module = program.compile(
        file_path="extern_storage.jac",
        use_str="def identity(value: int) -> int { return value; }",
        options=CompileOptions(no_cgen=True)
    );
    assert isinstance(module, Module);
    ctx = CompileContext(
        current_node=module,
        from_pass=NaIRGenPass,
        pass_name="NaIRGenPass",
        program=program
    );
    result = NaIRGenPass(module=module, ctx=ctx);
    result._llvm_module = ir.Module(name="extern_test");
    return result;
}

test "address return and argument adapters work in either declaration order" {
    for reverse in [False, True] {
        p = lowering();
        integer = ir.IntType(64);
        pointer = ir.IntType(32).as_pointer();
        first = pointer if reverse else integer;
        second = integer if reverse else pointer;
        original = p._get_or_declare_extern("address", first, [first]);
        adapted = p._get_or_declare_extern("address", second, [second]);
        assert original.function_type == ir.FunctionType(first, [first]);
        assert adapted.function_type == ir.FunctionType(second, [second]);
        assert adapted is p._get_or_declare_extern("address", second, [second]);
        assert original is p._get_or_declare_extern("address", first, [first]);
        assert adapted.linkage == "internal";
        text = str(p.llvm_module);
        assert "inttoptr" in text and "ptrtoint" in text;
        llvm.parse_assembly(text).verify();
    }
}

test "module declarations are reused even when absent from the extern cache" {
    p = lowering();
    integer = ir.IntType(64);
    original = ir.Function(p.llvm_module, ir.FunctionType(integer, []), name="address");
    adapted = p._get_or_declare_extern("address", ir.IntType(8).as_pointer(), []);
    assert p.extern_funcs["address"] is original;
    assert adapted is not original;
    llvm.parse_assembly(str(p.llvm_module)).verify();
}

test "incompatible signatures are rejected before emitting an invalid adapter" {
    for mode in range(4) {
        p = lowering();
        integer = ir.IntType(64);
        original = p._get_or_declare_extern("foreign", integer, [integer]);
        caught = False;
        try {
            if mode == 0 {
                p._get_or_declare_extern("foreign", ir.DoubleType(), [integer]);
            } elif mode == 1 {
                p._get_or_declare_extern("foreign", integer, []);
            } elif mode == 2 {
                p._get_or_declare_extern("foreign", integer, [ir.IntType(32)]);
            } else {
                p._get_or_declare_extern("foreign", integer, [integer], var_arg=True);
            }
        } except ValueError as error {
            caught = "Incompatible native extern declaration for foreign" in str(error);
        }
        assert caught;
        assert len(list(p.llvm_module.global_values)) == 1;
        assert p.extern_funcs["foreign"] is original;
    }
}
