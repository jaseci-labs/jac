import hashlib;
import os;
import shutil;
import tempfile;
import json;
import sys;
import time;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.modresolver { push_import_base, pop_import_base }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.jir {
    FLAG_PRECOMPILED,
    PRECOMPILE_SENTINEL,
    compute_precompile_module_key,
    patch_co_filenames_bytes,
    write_precompiled_jir
}

def compile_module(source: Path, package: Path, output: Path) -> dict[str, any] {
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
    push_import_base(str(package.parent));
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
        foreign = [
            path
            for path in program.mod.hub
            if path.endswith(".jac") and Path(path).is_relative_to(producer)
        ];
        if foreign {
            raise RuntimeError(f"Target compilation read producer sources: {foreign}");
        }
        if module is None or not module.gen.py_bytecode {
            details = "\n".join(e.pretty_print() for e in program.errors_had);
            raise ValueError(
                f"{source}: compiler emitted no executable bytecode:\n{details}"
            );
        }
        for diagnostic in program.errors_had {
            sys.stderr.write(diagnostic.pretty_print() + "\n");
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
        return {
            "source": relative.as_posix(),
            "producer": str(producer),
            "artifact": str(output),
            "sha256": hashlib.sha256(artifact).hexdigest(),
            "seconds": elapsed,
            "diagnostics": len(program.errors_had)
        };
    } finally {
        pop_import_base();
        program.release_compile_closure();
    }
}


def compile_image(
    package: Path,
    output: Path,
    kernel: Path,
    shim: Path,
    jobs: int,
    native_only: list[str]
) {
    import from jaclang.cli.workpool { WorkPool, pool_available, resolve_jobs }
    import from jaclang.dist.payload.fsutil { copy_tree, skip_jaclang }
    import from jaclang.dist.precompile_bytecode {
        find_jac_files,
        jir_to_module,
        write_manifest,
        _nested_project_dirs,
        _precompile_retire
    }
    import from jaclang.compiler.placement.placement_facts {
        toolchain_native_by_policy
    }
    import from jaclang.compiler.driver.jir {
        compiler_source_digest,
        running_compiler_digest
    }

    package = package.resolve(strict=True);
    output = output.resolve();
    kernel = kernel.resolve(strict=True);
    shim = shim.resolve(strict=True);
    layout = Path(str(kernel) + ".layout.json");
    if not layout.is_file() {
        raise ValueError(f"Compiler kernel has no layout sidecar: {kernel}");
    }
    if package == output or package in output.parents or output in package.parents {
        raise ValueError(
            "Compiler image output must be separate from its source package"
        );
    }
    if output.exists() and any(output.iterdir()) {
        raise FileExistsError(f"Compiler image output must be empty: {output}");
    }
    output.parent.mkdir(parents=True, exist_ok=True);
    started = time.monotonic();
    producer_digest = running_compiler_digest();
    source_digest = compiler_source_digest(str(package));
    with tempfile.TemporaryDirectory(
        prefix=".compiler-image-", dir=str(output.parent)
    ) as work {
        site = Path(work) / "site";
        snapshot = site / "jaclang";
        def exclude_path(relative: str) -> bool {
            return skip_jaclang(relative)
                or relative in ("jac0.py", "bootstrap_manifest.py", "jac0core")
                or relative.startswith("jac0core/");
        }
        copy_tree(str(package), str(snapshot), exclude_path);
        resolver_marker = snapshot / "jac0core";
        resolver_marker.mkdir();
        finder = package.parent / "_jac_finder.py";
        if finder.is_file() {
            shutil.copyfile(finder, site / finder.name);
        }
        kernel_name = "libjac_compiler.dylib"
            if sys.platform == "darwin"
            else "libjac_compiler.so";
        kernel_target = snapshot / "compiler" / kernel_name;
        shutil.copyfile(kernel, kernel_target);
        shutil.copyfile(layout, Path(str(kernel_target) + ".layout.json"));
        shim_name = "libjacllvm.dylib" if sys.platform == "darwin" else "libjacllvm.so";
        shutil.copyfile(
            shim, snapshot / "compiler" / "backends" / "native" / "llvm" / shim_name
        );
        pyver = str(sys.implementation.cache_tag);
        precompiled = snapshot / "_precompiled";
        artifacts = precompiled / pyver;
        artifacts.mkdir(parents=True, exist_ok=True);
        nested = _nested_project_dirs(str(snapshot));
        sources = [
            source
            for source in find_jac_files(str(snapshot))
            if Path(source).relative_to(snapshot).as_posix() not in native_only
                and not toolchain_native_by_policy(str(snapshot), source)
                and not any(source.startswith(nested_root) for nested_root in nested)
        ];
        modules: dict[str, dict[str, any]] = {};
        failures: list[str] = [];
        def job(request: dict[str, any]) -> dict[str, any] {
            source = Path(str(request["path"]));
            destination = artifacts / source.relative_to(snapshot).with_suffix(".jir");
            return compile_module(source, snapshot, destination);
        }
        def record(index: int, message: dict[str, any]) {
            result = message.get("result");
            source = Path(sources[index]).relative_to(snapshot).as_posix();
            if not isinstance(result, dict) {
                failures.append(source);
                sys.stderr.write(json.dumps(message) + "\n");
                return;
            }
            relative_jir = Path(source).with_suffix(".jir").as_posix();
            (_, fullname, is_package) = jir_to_module("jaclang", relative_jir);
            modules[source] = {
                "module": fullname,
                "jir": relative_jir,
                "package": is_package,
                "sha256": str(result["sha256"])
            };
            sys.stdout.write(json.dumps(result, sort_keys=True) + "\n");
            sys.stdout.flush();
        }
        workers = resolve_jobs(jobs, env_var="JAC_PRECOMPILE_JOBS");
        pool = WorkPool(
            items=sources,
            job=job,
            on_record=record,
            jobs=min(workers, len(sources)),
            retire=_precompile_retire,
            crash_prefix="jac-compiler-image-"
        );
        if pool_available() and workers > 1 {
            pool.run();
        } else {
            pool.run_inline();
        }
        if failures or len(modules) != len(sources) {
            raise RuntimeError(f"Incomplete compiler image: {failures}");
        }
        resolver_marker.rmdir();
        payloads: dict[str, str] = {};
        for path in sorted(snapshot.rglob("*")) {
            if path.is_file()
                and path.suffix in (".py", ".so", ".dylib", ".json")
                and precompiled not in path.parents {
                payloads[path.relative_to(snapshot).as_posix()] = hashlib.sha256(
                    path.read_bytes()
                ).hexdigest();
            }
        }
        write_manifest(precompiled, "jaclang", pyver, modules, payloads);
        manifest_path = precompiled / "MANIFEST.json";
        manifest = json.loads(manifest_path.read_text());
        identity = hashlib.sha256(
            json.dumps(
                {"modules": modules, "payloads": payloads, "python_tag": pyver},
                sort_keys=True,
                separators=(",", ":")
            ).encode()
        ).hexdigest();
        manifest["producer_digest"] = producer_digest;
        manifest["source_digest"] = source_digest;
        manifest["source_root"] = str(snapshot);
        manifest["compiler_digest"] = f"image:{identity}";
        manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=1) + "\n");
        site.replace(output);
    }
    sys.stdout.write(
        json.dumps(
            {
                "image": str(output),
                "modules": len(modules),
                "seconds": time.monotonic() - started
            }
        )
            + "\n"
    );
}

with entry {
    if len(sys.argv) >= 7 and sys.argv[1] == "image" {
        compile_image(
            Path(sys.argv[2]),
            Path(sys.argv[3]),
            Path(sys.argv[4]),
            Path(sys.argv[5]),
            int(sys.argv[6]),
            list(sys.argv[7:])
        );
    } elif len(sys.argv) == 4 {
        package = Path(sys.argv[1]);
        result = compile_module(package / sys.argv[2], package, Path(sys.argv[3]));
        sys.stdout.write(json.dumps(result, sort_keys=True) + "\n");
    } else {
        raise SystemExit(
            "usage: compiler.jac <package> <source-relative-path> <output.jir>\n"
            "       compiler.jac image <package> <output-site> <kernel> <shim> <jobs> [native-only-source ...]"
        );
    }
}
