import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Module }


def write_native_product(
    module: Module,
    directory: Path,
    relative: Path,
    shared: bool = True,
    memory: str = '',
    emit_source: bool = True
) -> dict[str, any] {
    import from jaclang.compiler.backends.native.entry_points {
        inject_main,
        validate_native_application
    }
    import from jaclang.compiler.backends.native.shared_emit {
        inject_shared_init,
        bind_shared_callbacks,
        emit_shared_library
    }
    manifest = module.gen.interop_manifest;
    llvm_ir = validate_native_application(module, shared, memory);
    bindings = manifest.callable_native_imports if shared else [];
    output = relative.with_suffix('.so' if shared else '');
    source = relative.with_suffix('.c');
    target = directory / (source if emit_source else output);
    target.parent.mkdir(parents=True, exist_ok=True);
    if shared {
        (llvm_ir, bindings) = bind_shared_callbacks(llvm_ir, bindings);
    }
    if emit_source {
        import from jaclang.compiler.backends.native.c_emit { emit_c }
        if shared {
            (llvm_ir, _) = inject_shared_init(llvm_ir, manifest);
        } else {
            llvm_ir = inject_main(llvm_ir);
        }
        target.write_text(emit_c(llvm_ir), encoding='utf-8');
    } else {
        if not shared {
            raise ValueError('Binary runtime products must be shared libraries');
        }
        exports = list(module.gen._exported_symbols);
        exports.extend(binding.name for binding in manifest.native_exports);
        exports.extend('__jac_bind_' + binding.name for binding in bindings);
        (ok, error) = emit_shared_library(
            llvm_ir,
            manifest,
            exports,
            str(target),
            clib_paths=module.gen._clib_paths,
            clib_symbol_lib=module.gen._clib_symbol_lib
        );
        if not ok {
            raise RuntimeError(error);
        }
    }
    return {
        'source': source.as_posix() if emit_source else '',
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
