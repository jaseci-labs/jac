impl build_native_product(base: Path, record: dict[str, any]) {
    source = base / record['source'];
    output = base / record['output'];
    output.parent.mkdir(parents=True, exist_ok=True);
    compiler = shlex.split(os.environ.get('CC', 'clang'));
    command = compiler + ['-O2', '-fwrapv', '-fno-strict-aliasing', '-fno-builtin'];
    if record['kind'] == 'wasm' {
        import from jaclang.compiler.backends.native.wasm_artifact {
            rename_wasm_imports,
            wasm_ld_args,
            wasm_object_functions,
            write_allowed_imports
        }
        import from jaclang.compiler.backends.native.wasm_host_abi {
            WASM_HOST_ABI,
            WASM_HOST_MODULE
        }
        obj_path = output.with_suffix('.o');
        command += ['--target=wasm32-wasip1', '-matomics', '-mbulk-memory'];
        sysroot = os.environ.get('WASI_SYSROOT', '');
        if sysroot {
            command.append('--sysroot=' + sysroot);
        }
        subprocess.run(command + ['-c', str(source), '-o', str(obj_path)], check=True);
        wasm_ld = os.environ.get('WASM_LD', '');
        if not wasm_ld {
            wasm_ld = subprocess.run(
                compiler + ['-print-prog-name=wasm-ld'],
                check=True,
                capture_output=True,
                text=True
            ).stdout.strip();
        }
        allow_path = output.with_suffix('.imports.txt');
        write_allowed_imports(
            str(allow_path), list(WASM_HOST_ABI) + list(record['imports'])
        );
        wasm_path = output.with_suffix('.linked.wasm');
        subprocess.run(
            [wasm_ld]
                + wasm_ld_args(
                    str(wasm_path),
                    [str(obj_path)],
                    list(record['exports'])
                        or wasm_object_functions(obj_path.read_bytes()),
                    str(allow_path)
                ),
            check=True
        );
        content = rename_wasm_imports(
            wasm_path.read_bytes(), set(WASM_HOST_ABI), WASM_HOST_MODULE
        );
        wasm_path.unlink();
        allow_path.unlink();
        import from jaclang.compiler.backends.native.wasm_artifact { wasm_assets }
        for (name, data) in wasm_assets(output.stem, content).items() {
            (output.parent / name).write_bytes(data);
        }
        obj_path.unlink();
    } else {
        if record['kind'] == 'shared' {
            command += ['-shared', '-fPIC'];
        }
        libraries = list(record.get('libraries', []));
        linker_flags = shlex.split(os.environ.get('LDFLAGS', ''));
        for library in libraries {
            name = Path(library).name;
            candidate = base / library;
            if candidate.is_file() {
                linker_flags.append(str(candidate));
            } elif name.startswith('lib') {
                linker_flags.append('-l' + name[3:].split('.')[0]);
            } else {
                linker_flags.append('-l' + name.split('.')[0]);
            }
        }
        subprocess.run(
            command + [str(source), '-o', str(output), '-lm'] + linker_flags, check=True
        );
    }
}

impl build(base: Path) {
    base = base.resolve();
    runtime_manifest = base / 'jaclang' / 'runtime.json';
    if runtime_manifest.is_file() {
        runtime = json.loads(runtime_manifest.read_text(encoding='utf-8'));
        for module in runtime['modules'] {
            if module.get('native') {
                build_native_product(base / 'jaclang', module['native']);
            }
        }
    }
    data = json.loads((base / 'project.json').read_text(encoding='utf-8'));
    for application in data['applications'] {
        directory = base / application['root'];
        if application.get('native') {
            build_native_product(directory, application['native']);
        }
        if application.get('client_dist') {
            bun = shutil.which('bun');
            if bun {
                subprocess.run([bun, 'install'], cwd=directory, check=True);
                subprocess.run([bun, 'run', 'build'], cwd=directory, check=True);
            } else {
                subprocess.run(['npm', 'install'], cwd=directory, check=True);
                subprocess.run(['npm', 'run', 'build'], cwd=directory, check=True);
            }
            records = json.loads(
                (directory / 'client' / 'native.json').read_text(encoding='utf-8')
            );
            for record in records {
                build_native_product(base, record);
            }
        }
        for module in application['modules'] {
            if module.get('native') {
                build_native_product(directory, module['native']);
            }
        }
    }
}
