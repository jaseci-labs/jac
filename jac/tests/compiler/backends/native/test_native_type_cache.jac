"""Native storage must distinguish annotations from class-valued types."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.passes.transform { PassResult }

test "native type caching preserves primitive and class value storage in either order" {
    program = JacProgram();
    module = program.compile(
        file_path="type_storage.jac",
        use_str="def identity(value: int) -> int { return value; }",
        options=CompileOptions(no_cgen=True)
    );
    assert isinstance(module, Module);
    assert not program.errors_had;
    prefetch = program.get_type_evaluator().prefetch;
    assert prefetch is not None;
    assert prefetch.int_class is not None;
    assert prefetch.type_class is not None;
    annotation = prefetch.int_class.clone_as_class();
    class_value = prefetch.type_class.clone_as_instance();
    class_value.private.type_args = [annotation.clone_as_instance()];
    assert annotation.mangle() == class_value.mangle();
    for reverse in [False, True] {
        lowering = NaIRGenPass(ir_in=module, prog=program, completed=PassResult());
        first = class_value if reverse else annotation;
        second = annotation if reverse else class_value;
        lowering._lower_type(first);
        lowering._lower_type(second);
        assert lowering._lower_type(annotation) == ir.IntType(64);
        assert lowering._lower_type(class_value) == ir.IntType(8).as_pointer();
    }
}
