"""Native struct names for classes reached through a module interface.

A native importer can see a class through the defining module's precompiled
interface instead of its source tree, so the class's symbol table is an
interface scope rather than an Archetype. The name it resolves to must be the
one the defining unit laid the struct out under: module scoped for a Jac class,
bare for an enum or a C struct declared in a library import block.
"""
import os;
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { native_arch_name }
import from jaclang.compiler.passes.layout_pass { class_type_native_name }
import from jaclang.compiler.types.types { ClassDetailsShared, ClassType, TypeFlags }

def interface_class(
    scope: any, path: str, name: str, is_extern_struct: bool = False
) -> ClassType {
    return ClassType(
        _shared=ClassDetailsShared(
            class_name=name,
            symbol_table=scope,
            is_extern_struct=is_extern_struct,
            _identity_key=(path, 1, 1, name)
        ),
        flags=TypeFlags.Instantiable
    );
}

test "an interface class resolves to its defining module's scoped name" {
    with TemporaryDirectory() as directory {
        path = os.path.realpath(os.path.join(directory, "model.jac"));
        with open(path, "w") as handle {
            handle.write("obj Handle {\n    has code: int = 0;\n}\n");
        }
        module = JacProgram().compile(path, no_cgen=True);
        typ = interface_class(module, path, "Handle");
        assert class_type_native_name(typ) == native_arch_name(path, "Handle");
        assert class_type_native_name(typ) != "Handle";
        extern = interface_class(module, path, "cef_ptr_wrap_t", is_extern_struct=True);
        assert class_type_native_name(extern) == "cef_ptr_wrap_t";
    }
}

test "a class from a Python stub keeps its bare name" {
    module = JacProgram().compile(
        os.path.join(os.path.dirname(__file__), "test_layout_native_names.jac"),
        no_cgen=True
    );
    typ = interface_class(module, "/stubs/builtins.pyi", "Thing");
    assert class_type_native_name(typ) == "Thing";
}
