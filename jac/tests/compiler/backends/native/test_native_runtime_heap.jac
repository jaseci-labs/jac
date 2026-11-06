"""`native_heap` routes the runtime's own heap, not the program's C imports.

JacPython links mimalloc and sets `native_heap="mi"`: the runtime's
reference-counted objects and their list, dict and set storage come from
`mi_malloc`, so `jac_heap_size` can measure them with `mi_usable_size`.
Memory the program allocates through its own `import from c` malloc stays
the C library's.
"""

import os;
import re;
import from tests.support { compile_native_ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def heap_options -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        native_required=True,
        no_ir_cache=True,
        native_heap="mi"
    );
}

test "the runtime's list storage comes from the configured heap" {
    import jaclang;
    runtime = os.path.join(os.path.dirname(jaclang.__file__), "runtime", "native");
    text = str(
        compile_native_ir(
            "lists.jac", fixture_dir=runtime, options=heap_options()
        ).gen.llvm_ir
    );
    assert re.search(r'declare [^\n]*@"?mi_realloc"?\(', text) , "no mi_realloc";
    assert re.search(r'declare [^\n]*@"?mi_free"?\(', text) , "no mi_free";
    assert not re.search(r'declare [^\n]*@"?(malloc|realloc|free)"?\(', text) , (
        "the runtime still calls the C library's heap"
    );
}

test "a program's own C malloc stays the C library's" {
    text = str(
        compile_native_ir(
            "runtime_heap_routines.jac", options=heap_options()
        ).gen.llvm_ir
    );
    assert re.search(r'declare [^\n]*@"?malloc"?\(', text) , text;
    assert re.search(r'declare [^\n]*@"?free"?\(', text) , text;
    assert "mi_malloc" not in text;
}
