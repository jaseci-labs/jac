impl write_native_product(
    source_path: str,
    directory: Path,
    relative: Path,
    shared: bool = True,
    memory: str = '',
    emit_source: bool = True,
    program: JacProgram | None = None
) -> dict[str, any] {
    if not shared and not emit_source {
        raise ValueError('Binary runtime products must be shared libraries');
    }
    if program is None {
        program = JacProgram();
    }
    output = relative.with_suffix('.so' if shared else '');
    source = relative.with_suffix('.c');
    target = directory / (source if emit_source else output);
    target.parent.mkdir(parents=True, exist_ok=True);
    request = native_build_request_for(
        [source_path],
        'shared' if shared else 'executable',
        CompileOptions(
            aot_mode=True, default_codespace='native', memory_profile=memory or None
        ),
        str(target)
    );
    request.callbacks = shared;
    request.emit_c = emit_source;
    request.refuse_python_imports = not shared;
    request.refuse_demoted = not shared;
    result = kernel_native_build(program, request);
    if not result.ok() {
        raise ValueError('\n'.join([diagnostic_text(error) for error in result.errors]));
    }
    if not shared and result.python_imports {
        raise ValueError('Standalone native products cannot import Python');
    }
    if not shared and result.demoted {
        raise ValueError(
            'Native declarations could not lower: ' + ', '.join(result.demoted)
        );
    }
    if not result.linked {
        raise ValueError(f'No native product was built for {source_path}');
    }
    return {
        'source': source.as_posix() if emit_source else '',
        'output': output.as_posix(),
        'kind': 'shared' if shared else 'executable',
        'libraries': list(result.libraries),
        'callbacks': [
            {
                'name': binding.name,
                'symbol': binding.symbol,
                'ret_type': binding.ret_type,
                'param_types': list(binding.param_types)
            } for binding in result.callbacks
        ]
    };
}
