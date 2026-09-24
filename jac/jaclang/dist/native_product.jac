import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.driver.program { JacProgram }


def write_native_product(
    module: Module,
    directory: Path,
    relative: Path,
    shared: bool = True,
    memory: str = '',
    emit_source: bool = True,
    program: JacProgram | None = None
) -> dict[str, any] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        whole_program_module,
        optimize_merged_program,
        link_artifact
    }
    if program is None {
        program = JacProgram();
    }
    plan = build_link_plan(program, [module.loc.mod_path], program.options);
    manifest = module.gen.interop_manifest;
    bindings = manifest.native_imports if shared else [];
    plan.callback_bindings = list(bindings);
    kind = ArtifactKind.SHARED if shared else ArtifactKind.EXECUTABLE;
    if not shared and any(unit.iface.python_imports for unit in plan.units) {
        raise ValueError('Standalone native products cannot import Python');
    }
    if not shared and plan.demoted_symbols() {
        raise ValueError(
            'Native declarations could not lower: ' + ', '.join(plan.demoted_symbols())
        );
    }
    output = relative.with_suffix('.so' if shared else '');
    source = relative.with_suffix('.c');
    target = directory / (source if emit_source else output);
    target.parent.mkdir(parents=True, exist_ok=True);
    if emit_source {
        import from jaclang.compiler.backends.native.c_emit { emit_c }
        spec = plan.glue_spec(kind, "c", False);
        (merged, _) = whole_program_module(plan, spec);
        optimize_merged_program(plan, merged, kind);
        llvm_ir = str(merged);
        if memory == 'nogc' {
            import from jaclang.compiler.backends.native.wasm_build {
                _assert_ir_rc_free
            }
            _assert_ir_rc_free(llvm_ir, module.loc.mod_path);
        }
        target.write_text(emit_c(llvm_ir), encoding='utf-8');
    } else {
        if not shared {
            raise ValueError('Binary runtime products must be shared libraries');
        }
        link_artifact(plan, str(target), kind);
    }
    return {
        'source': source.as_posix() if emit_source else '',
        'output': output.as_posix(),
        'kind': 'shared' if shared else 'executable',
        'libraries': plan.clib_paths(),
        'callbacks': [
            {
                'name': binding.name,
                'ret_type': binding.ret_type,
                'param_types': list(binding.param_types)
            } for binding in bindings
        ]
    };
}
