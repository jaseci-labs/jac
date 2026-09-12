import hashlib;
import json;
import sys;
import time;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.jir {
    FLAG_PRECOMPILED,
    PRECOMPILE_SENTINEL,
    compute_precompile_module_key,
    patch_co_filenames_bytes,
    write_precompiled_jir
}

def compile_module(source: Path, package: Path, output: Path) {
    source = source.resolve(strict=True);
    package = package.resolve(strict=True);
    relative = source.relative_to(package);
    producer = Path(str(jaclang.__file__)).resolve().parent;
    if producer == package {
        raise ValueError(
            "The bootstrap producer must be independent of target sources"
        );
    }
    started = time.monotonic();
    program = JacProgram();
    try {
        module = program.compile(
            file_path=str(source),
            options=CompileOptions(
                force_target_program=True,
                force_codespace="server",
                need_full_ast=True,
                no_ir_cache=True,
                project_root=str(package.parent),
                entry_point=str(source)
            )
        );
        if program.errors_had {
            details = "\n".join(e.pretty_print() for e in program.errors_had);
            raise ValueError(f"{source}: compiler image build failed:\n{details}");
        }
        if module is None or not module.gen.py_bytecode {
            raise ValueError(f"{source}: compiler emitted no bytecode");
        }
        bytecode = patch_co_filenames_bytes(
            module.gen.py_bytecode, str(package), PRECOMPILE_SENTINEL
        );
        artifact = write_precompiled_jir(
            bytecode, compute_precompile_module_key(str(source)), FLAG_PRECOMPILED
        );
        output.parent.mkdir(parents=True, exist_ok=True);
        output.write_bytes(artifact);
        elapsed = time.monotonic() - started;
        sys.stdout.write(
            json.dumps(
                {
                    "source": relative.as_posix(),
                    "producer": str(producer),
                    "artifact": str(output),
                    "sha256": hashlib.sha256(artifact).hexdigest(),
                    "seconds": elapsed
                }
            )
                + "\n"
        );
        sys.stdout.flush();
    } finally {
        program.release_compile_closure();
    }
}

with entry {
    if len(sys.argv) != 4 {
        raise SystemExit(
            "usage: compiler.jac <package-dir> <source-relative-path> <output.jir>"
        );
    }
    package = Path(sys.argv[1]);
    compile_module(package / sys.argv[2], package, Path(sys.argv[3]));
}
