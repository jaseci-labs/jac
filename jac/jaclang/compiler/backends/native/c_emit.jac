import subprocess;
import tempfile;
import from pathlib { Path }

def emit_c(llvm_ir: str) -> str {
    import from jaclang.toolchains.c_backend { ensure_c_backend }
    backend = ensure_c_backend();
    with tempfile.TemporaryDirectory(prefix='jac-c-') as temporary {
        directory = Path(temporary);
        source = directory / 'module.ll';
        output = directory / 'module.c';
        source.write_text(llvm_ir, encoding='utf-8');
        result = subprocess.run(
            [str(backend), '-O0', str(source), '-o', str(output)],
            capture_output=True,
            text=True,
            timeout=300
        );
        if result.returncode {
            raise RuntimeError(f'Native C projection failed:\n{result.stderr}');
        }
        return output.read_text(encoding='utf-8');
    }
}
