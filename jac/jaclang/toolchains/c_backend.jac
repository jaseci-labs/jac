import from jaclang.jac0core.cache_paths { FileLock }
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.toolchains.host { executable, host_platform, run_step }
import from jaclang.toolchains.store {
    Artifact,
    build_slot,
    extract,
    fetch,
    file_digest,
    publish_build_slot,
    slot_ready
}

glob LLVM_MAJOR: int = 22,
     C_BACKEND: Artifact = Artifact(
         'llvm-cbe',
         'a13fcf3b27079f4989902594b7c72f81f75c5357',
         'source',
         'https://codeload.github.com/JuliaHubOSS/llvm-cbe/tar.gz/a13fcf3b27079f4989902594b7c72f81f75c5357',
         'd425227fe3bd6a69299b188754403e20b0c840cf1609955c0ccbb68827e34ab9'
     );

def ensure_c_backend -> Path {
    configured = os.environ.get('JAC_LLVM_CBE', '');
    if configured {
        path = Path(configured).expanduser().resolve();
        if not path.is_file() {
            raise FileNotFoundError(
                f'JAC_LLVM_CBE does not name an executable: {path}'
            );
        }
        return path;
    }
    patch = Path(__file__).parent / 'patches' / 'llvm-cbe-runtime-semantics.patch';
    directory = build_slot(
        C_BACKEND.name,
        host_platform(),
        f"{C_BACKEND.version[:16]}-{file_digest(patch)[:16]}"
    );
    binary = directory / 'bin' / executable('llvm-cbe');
    with FileLock(directory.with_suffix('.lock')) {
        if slot_ready(directory) and binary.is_file() {
            return binary;
        }
        llvm_config = shutil.which(f'llvm-config-{LLVM_MAJOR}')
            or shutil.which('llvm-config');
        if not llvm_config or not shutil.which('cmake') {
            raise RuntimeError(
                f'C source export requires CMake and the LLVM {LLVM_MAJOR} development toolchain '
                    + '(llvm-config), or JAC_LLVM_CBE pointing to a built LLVM C backend.'
            );
        }
        version = subprocess.check_output(
            [llvm_config, '--version'], text=True
        ).strip();
        if int(version.split('.')[0]) != LLVM_MAJOR {
            raise RuntimeError(
                f'LLVM C backend requires LLVM {LLVM_MAJOR}, found {version}'
            );
        }
        cmake_dir = subprocess.check_output(
            [llvm_config, '--cmakedir'], text=True
        ).strip();
        archive = fetch(C_BACKEND);
        directory.parent.mkdir(parents=True, exist_ok=True);
        with tempfile.TemporaryDirectory(
            prefix=f".tmp.{os.getpid()}.", dir=directory.parent
        ) as temporary {
            staging = Path(temporary);
            extract(archive, staging / 'source');
            source = next((staging / 'source').iterdir());
            subprocess.run(['git', 'apply', str(patch)], cwd=source, check=True);
            build = staging / 'build';
            env = dict(os.environ);
            run_step(
                'Configuring the LLVM C backend',
                [
                    'cmake',
                    '-S',
                    str(source),
                    '-B',
                    str(build),
                    '-DCMAKE_BUILD_TYPE=Release',
                    f'-DLLVM_DIR={cmake_dir}'
                ],
                staging,
                env
            );
            run_step(
                'Building the LLVM C backend',
                [
                    'cmake',
                    '--build',
                    str(build),
                    '--parallel',
                    str(min(os.cpu_count() or 1, 4))
                ],
                staging,
                env
            );
            ready = staging / 'ready';
            (ready / 'bin').mkdir(parents=True);
            shutil.copy2(
                build / 'tools' / 'llvm-cbe' / executable('llvm-cbe'), ready / 'bin'
            );
            shutil.copy2(source / 'LICENSE', ready / 'LICENSE');
            publish_build_slot(ready, directory);
        }
    }
    return binary;
}


def c_backend_provenance -> dict[str, str | int] {
    configured = os.environ.get('JAC_LLVM_CBE', '');
    if configured {
        return {
            'name': C_BACKEND.name,
            'provider': 'JAC_LLVM_CBE',
            'executable_sha256': file_digest(ensure_c_backend())
        };
    }
    patch = Path(__file__).parent / 'patches' / 'llvm-cbe-runtime-semantics.patch';
    return {
        'name': C_BACKEND.name,
        'revision': C_BACKEND.version,
        'source': C_BACKEND.url,
        'source_sha256': C_BACKEND.digest,
        'patch_sha256': file_digest(patch),
        'llvm_major': LLVM_MAJOR
    };
}

def c_backend_license -> Path {
    return Path(__file__).parent / 'patches' / 'llvm-cbe-LICENSE';
}
