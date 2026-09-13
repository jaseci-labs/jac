"""Native source products retain the compiler's ABI and initialization order."""

import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Module }


def write_native_library(module: Module, directory: Path, relative: Path) -> dict {
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text
    }
    import from jaclang.compiler.backends.native.shared_emit {
        inject_shared_init,
        bind_shared_callbacks
    }
    import from jaclang.compiler.backends.native.c_emit { emit_c }
    manifest = module.gen.interop_manifest;
    (llvm_ir, exports) = inject_shared_init(native_linked_ir_text(module), manifest);
    bindings = manifest.native_imports if manifest is not None else [];
    llvm_ir = bind_shared_callbacks(llvm_ir, bindings);
    source = Path('native') / relative.with_suffix('.c');
    output = source.with_suffix('.so');
    target = directory / source;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(emit_c(llvm_ir), encoding='utf-8');
    return {
        'source': source.as_posix(),
        'output': output.as_posix(),
        'kind': 'shared',
        'callbacks': [
            {
                'name': binding.name,
                'ret_type': binding.ret_type,
                'param_types': list(binding.param_types)
            } for binding in bindings
        ]
    };
}
