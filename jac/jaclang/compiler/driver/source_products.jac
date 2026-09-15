import copy;
import from pathlib { Path }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.unitree { Module }

def python_source(path: str, program: JacProgram) -> tuple[str, Module | None] {
    if Path(path).suffix == '.py' {
        return (Path(path).read_text(encoding='utf-8'), None);
    }
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual = program_for(path, program);
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
        raise RuntimeError(f'No Python source product for {path}');
    }
    return (str(module.gen.py), module);
}
