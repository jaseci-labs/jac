import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Module }


def write_native_product(
    module: Module,
    directory: Path,
    relative: Path,
    shared: bool = True,
    memory: str = ''
) -> dict {
    import from jaclang.compiler.backends.native.entry_points {
        inject_main,
        validate_native_application
    }
    import from jaclang.compiler.backends.native.shared_emit {
        inject_shared_init,
        bind_shared_callbacks
    }
    import from jaclang.compiler.backends.native.c_emit { emit_c }
    manifest = module.gen.interop_manifest;
    llvm_ir = validate_native_application(module, shared, memory);
    bindings = manifest.native_imports if shared else [];
    if shared {
        (llvm_ir, exports) = inject_shared_init(llvm_ir, manifest);
        llvm_ir = bind_shared_callbacks(llvm_ir, bindings);
    } else {
        llvm_ir = inject_main(llvm_ir);
    }
    source = relative.with_suffix('.c');
    output = relative.with_suffix('.so' if shared else '');
    target = directory / source;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(emit_c(llvm_ir), encoding='utf-8');
    return {
        'source': source.as_posix(),
        'output': output.as_posix(),
        'kind': 'shared' if shared else 'executable',
        'libraries': list(module.gen._clib_paths),
        'callbacks': [
            {
                'name': binding.name,
                'ret_type': binding.ret_type,
                'param_types': list(binding.param_types)
            } for binding in bindings
        ]
    };
}
