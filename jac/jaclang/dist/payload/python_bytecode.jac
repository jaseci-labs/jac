"""Reuse Python products by source, normalized filename, and target interpreter."""

import hashlib;
import json;
import py_compile;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.dist.payload.artifacts { ArtifactStore }
import from jaclang.dist.payload.python_runtime {
    current_identity,
    interpreter_identity
}

obj BytecodeRequest {
    has source: Path,
        output: Path,
        filename: str,
        content: bytes,
        key: str;
}

def precompile_tree(python: str, stage: str, cache_dir: str) -> dict[str, int] {
    target = interpreter_identity(python);
    directory = Path(stage);
    store = ArtifactStore(Path(cache_dir));
    counts = {"compiled": 0, "reused": 0};
    pending: list[BytecodeRequest] = [];
    producer = hashlib.sha256(json.dumps(target, sort_keys=True).encode()).hexdigest();
    # One transaction per target interpreter allows a single subprocess to batch
    # all misses without retaining one open lock descriptor per source file.
    with store.lock("python_bytecode", producer) {
        for source in sorted(directory.rglob("*.py")) {
            if "__pycache__" in source.parts {
                continue;
            }
            filename = "/jac-rt/" + source.relative_to(directory).as_posix();
            content = source.read_bytes();
            digest = hashlib.sha256(
                json.dumps([target, filename, "optimize=0"], sort_keys=True).encode()
            );
            digest.update(content);
            key = digest.hexdigest();
            output = source.parent
                / "__pycache__"
                / (source.stem + "." + target["cache_tag"] + ".pyc");
            if store.restore("python_bytecode", key, {"bytecode.pyc": output}) {
                counts["reused"] += 1;
            } else {
                pending.append(BytecodeRequest(source, output, filename, content, key));
            }
        }
        if target == current_identity() {
            for request in pending {
                py_compile.compile(
                    str(request.source),
                    cfile=str(request.output),
                    dfile=request.filename,
                    doraise=True,
                    optimize=0,
                    invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH
                );
            }
        } elif pending {
            with TemporaryDirectory() as work {
                manifest = Path(work) / "bytecode.json";
                manifest.write_text(
                    json.dumps(
                        [
                            [
                                str(request.source),
                                str(request.output),
                                request.filename
                            ] for request in pending
                        ]
                    )
                );
                subprocess.run(
                    [
                        python,
                        "-I",
                        "-c",
                        "import json, py_compile, sys\n"
                        "with open(sys.argv[1]) as stream: requests = json.load(stream)\n"
                        "for source, output, filename in requests:\n"
                        "    py_compile.compile(source, cfile=output, dfile=filename, "
                        "doraise=True, optimize=0, "
                        "invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH)\n",
                        str(manifest)
                    ],
                    check=True
                );
            }
        }
        for request in pending {
            if request.source.read_bytes() != request.content {
                request.output.unlink(missing_ok=True);
                raise RuntimeError(f"Source changed while compiling {request.source}");
            }
            store.publish(
                "python_bytecode", request.key, {"bytecode.pyc": request.output}
            );
            counts["compiled"] += 1;
        }
    }
    return counts;
}
