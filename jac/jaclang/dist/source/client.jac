import json;
import shutil;
import from pathlib { Path }
import from jaclang.runtime.prepared { PreparedApplication }


def write_client(application: PreparedApplication, base: Path) -> str {
    import from jaclang.client.vite_bundler { ViteBundler }
    import from jaclang.client.client_bundle { client_program }
    import from jaclang.compiler.driver.pipeline_runner { wasm_ir }
    import from jaclang.compiler.backends.native.wasm_build { prepare_wasm_module }
    import from jaclang.compiler.backends.native.c_emit { emit_c }
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    compiler = application.client_compiler;
    if compiler is None {
        raise ValueError(
            f'Application {application.name!r} has no prepared client product'
        );
    }
    directory = base / 'applications' / application.name;
    workspace = directory / 'client';
    compiled = workspace / 'compiled';
    shutil.copytree(compiler.compiled_dir, compiled, dirs_exist_ok=True);
    bundler = ViteBundler(Path(application.root), entry_path=application.entry);
    bundler.build_dir = workspace;
    bundler.output_dir = workspace / 'dist';
    bundler.project_dir = directory;
    package = bundler.create_package_json();
    shutil.copy2(package, directory / 'package.json');
    bundler.create_vite_config(compiled / '_entry.js');
    native = [];
    for target in compiler._wasm_targets(Path(application.entry)) {
        (llvm_ir, imports) = wasm_ir(client_program(compiler.program), str(target));
        (module, machine, linked) = prepare_wasm_module(llvm_ir);
        stem = native_wasm_stem(str(target));
        source = workspace / 'native' / f'{stem}.c';
        source.parent.mkdir(parents=True, exist_ok=True);
        source.write_text(emit_c(str(module)), encoding='utf-8');
        native.append(
            {
                'source': source.relative_to(base).as_posix(),
                'output': (bundler.output_dir / f'{stem}.wasm').relative_to(
                    base
                ).as_posix(),
                'kind': 'wasm',
                'imports': sorted(imports),
                'exports': []
            }
        );
    }
    (workspace / 'native.json').write_text(
        json.dumps(native, indent=2), encoding='utf-8'
    );
    return bundler.output_dir.relative_to(base).as_posix();
}
