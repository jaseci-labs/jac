import json;
import os;
import shlex;
import shutil;
import subprocess;
import from pathlib { Path }


def build_native_product(base: Path, record: dict[str, any]) {
    source = base / record['source'];
    output = base / record['output'];
    output.parent.mkdir(parents=True, exist_ok=True);
    compiler = shlex.split(os.environ.get('CC', 'clang'));
    command = compiler + ['-O2', '-fwrapv', '-fno-strict-aliasing', '-fno-builtin'];
    if record['kind'] == 'wasm' {
        import from jaclang.compiler.backends.native.wasm_linker { WasmLinker }
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
        linker = WasmLinker();
        content = linker.link(
            obj_path.read_bytes(),
            export_funcs=record['exports'],
            host_abi=WASM_HOST_ABI,
            host_module=WASM_HOST_MODULE,
            app_imports=set(record['imports'])
        );
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

def build(base: Path) {
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
