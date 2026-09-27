import copy;
import from pathlib { Path }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.unitree { Module }

def python_source(path: str, program: JacProgram) -> tuple[str, Module | None] {
    if Path(path).suffix == '.py' {
        return (Path(path).read_text(encoding='utf-8'), None);
    }
    import from jaclang.compiler.driver.compilation_context { program_for }
    """A module the running compiler package owns compiles where the compiler
    compiles its own package: a source export of the runtime reads the trees
    the compiler already holds instead of analyzing the package again in a
    program of its own. Every other module keeps the caller's program.""";
    owner = program._get_compiler().selfhost.resolve(path, program);
    actual = program_for(path, owner);
    options = copy.copy(actual.options);
    options.need_full_ast = True;
    options.no_cgen = False;
    options.symtab_ir_only = False;
    before = len(actual.errors_had);
    module = actual.compile(file_path=path, options=options);
    if len(actual.errors_had) > before {
        raise RuntimeError(
            '\n'.join(error.pretty_print() for error in actual.errors_had[before:])
        );
    }
    if module is None or not module.gen.py_ast {
        import from jaclang.compiler.driver.source_failures {
            module_scoped_failure_details,
            bootstrap_tier_failure_details
        }
        details = module_scoped_failure_details(path, actual)
            or bootstrap_tier_failure_details(path);
        if details {
            raise RuntimeError(details);
        }
        raise RuntimeError(f'No Python source product for {path}');
    }
    import from jaclang.compiler.backends.py.codegen_shim { generated_python }
    return (generated_python(module.gen), module);
}
