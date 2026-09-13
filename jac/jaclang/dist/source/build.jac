"""Build editable source artifacts with Python, a C compiler and Node or Bun."""

import json;
import os;
import shlex;
import shutil;
import subprocess;
import from pathlib { Path }


def _compile_native(base: Path, record: dict) -> None {
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
        output.write_bytes(content);
        obj_path.unlink();
    } else {
        if record['kind'] == 'shared' {
            command += ['-shared', '-fPIC'];
        }
        subprocess.run(command + [str(source), '-o', str(output), '-lm'], check=True);
    }
}

def build(base: Path) -> None {
    base = base.resolve();
    runtime_manifest = base / 'jaclang' / 'runtime.json';
    if runtime_manifest.is_file() {
        runtime = json.loads(runtime_manifest.read_text(encoding='utf-8'));
        for module in runtime['modules'] {
            if module.get('native') {
                _compile_native(base / 'jaclang', module['native']);
            }
        }
    }
    data = json.loads((base / 'project.json').read_text(encoding='utf-8'));
    for application in data['applications'] {
        directory = base / application['root'];
        if application.get('native') {
            _compile_native(directory, application['native']);
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
                _compile_native(base, record);
            }
        }
        for module in application['modules'] {
            if module.get('native') {
                _compile_native(directory, module['native']);
            }
        }
    }
}
