import hashlib;
import importlib.util;
import json;
import py_compile;
import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.dist.payload.artifacts { ArtifactStore }

def precompile_tree(python: str, stage: str, cache_dir: str) -> dict[str, int] {
    probe = subprocess.run(
        [
            python,
            "-I",
            "-c",
            "import sys, json, importlib.util; print(json.dumps([list(sys.version_info[:3]), importlib.util.MAGIC_NUMBER.hex(), sys.implementation.cache_tag]))"
        ],
        check=True,
        capture_output=True,
        text=True
    );
    target = json.loads(probe.stdout);
    local = [
        list(sys.version_info[:3]),
        importlib.util.MAGIC_NUMBER.hex(),
        sys.implementation.cache_tag
    ];
    directory = Path(stage);
    sources = sorted(
        path
        for path in directory.rglob("*.py")
        if "__pycache__" not in path.parts
    );
    if target != local {
        subprocess.run(
            [
                python,
                "-I",
                "-m",
                "compileall",
                "--invalidation-mode",
                "unchecked-hash",
                "-q",
                "-f",
                "-j",
                "0",
                "-s",
                stage,
                "-p",
                "/jac-rt",
                stage
            ],
            check=True
        );
        return {"compiled": len(sources), "reused": 0};
    }
    store = ArtifactStore(Path(cache_dir));
    counts = {"compiled": 0, "reused": 0};
    for source in sources {
        relative = source.relative_to(directory).as_posix();
        filename = "/jac-rt/" + relative;
        content = source.read_bytes();
        digest = hashlib.sha256(json.dumps([target, filename, "optimize=0"]).encode());
        digest.update(content);
        key = digest.hexdigest();
        output = source.parent
            / "__pycache__"
            / Path(importlib.util.cache_from_source(str(source))).name;
        outputs = {"bytecode.pyc": output};
        with store.lock("python_bytecode", key) {
            if store.restore("python_bytecode", key, outputs) {
                counts["reused"] += 1;
                continue;
            }
            py_compile.compile(
                str(source),
                cfile=str(output),
                dfile=filename,
                doraise=True,
                optimize=0,
                invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH
            );
            if source.read_bytes() != content {
                output.unlink(missing_ok=True);
                raise RuntimeError(f"Source changed while compiling {source}");
            }
            store.publish("python_bytecode", key, outputs);
            counts["compiled"] += 1;
        }
    }
    return counts;
}
