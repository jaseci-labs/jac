import hashlib;
import os;
import shutil;
import tempfile;
import json;
import sys;
import time;
import importlib.util;
import from functools { lru_cache }
import from types { ModuleType }
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.modresolver {
    push_import_base,
    pop_import_base,
    find_project_root
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.placement.placement_facts { toolchain_native_by_policy }
import from jaclang.compiler.driver.jir {
    FLAG_PRECOMPILED,
    PRECOMPILE_SENTINEL,
    compute_precompile_module_key,
    precompiled_jir_matches_source,
    ct_deps_section,
    SEC_CTDEPS
}

def snapshot_sources(package: Path, destination: Path) {
    import from jaclang.dist.payload.fsutil { copy_tree, skip_jaclang }
    def excluded(path: str) -> bool {
        return skip_jaclang(path)
            or any(
                (part.startswith(".") and part not in (".gitignore", ".env.example"))
                    or part in ("tests", "test") for part in Path(path).parts
            );
    }
    copy_tree(str(package), str(destination), excluded);
    project = find_project_root(package);
    if project is None {
        raise ValueError("Compiler sources have no project manifest");
    }
    shutil.copyfile(project[1], destination.parent / "jac.toml");

    (destination / "jac0core").mkdir(exist_ok=True);
}

def native_python_sources -> tuple[str, ...] {
    return (
        "compiler/frontend/python",
        "compiler/backends/py/jacpython",
        "runtime/python"
    );
}

def exclude_native_python_sources(package: Path, snapshot: Path) {
    for relative in native_python_sources() {
        shutil.rmtree(snapshot / relative, ignore_errors=True);
    }
    license_file = Path("runtime/python/LICENSE.cpython");
    (snapshot / license_file).parent.mkdir(parents=True, exist_ok=True);
    shutil.copyfile(package / license_file, snapshot / license_file);
}

def verify_source_isolation(program: JacProgram) {
    producer = Path(jaclang.__file__).resolve().parent;
    foreign = [
        path for context in [program] + list(program.contexts.values())
        for path in context.mod.hub
        if path.endswith(".jac")
            and Path(path).is_relative_to(producer)
            and not toolchain_native_by_policy(str(producer), path)
    ];
    if foreign {
        raise RuntimeError(f"Target compilation read producer sources: {foreign}");
    }
}

def compile_native_python(package: Path, output: Path, target: str) {
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text,
        native_demoted_ir_symbols
    }
    import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
    import from jaclang.compiler.backends.native.shared_emit {
        init_object_codegen,
        inject_shared_init
    }
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    package = package.resolve(strict=True);
    output = output.resolve();
    output.parent.mkdir(parents=True, exist_ok=True);
    with tempfile.TemporaryDirectory(prefix="jac-python-native-") as work {
        snapshot = Path(work).resolve() / "jaclang";
        snapshot_sources(package, snapshot);
        program = JacProgram();
        push_import_base(str(snapshot.parent));
        try {
            module = program.compile(
                file_path=str(
                    snapshot / "compiler/backends/py/jacpython/native_api.jac"
                ),
                options=CompileOptions(
                    aot_mode=True,
                    default_codespace="native",
                    memory_profile="managed",
                    no_ir_cache=True,
                    opt_level=2,
                    native_target=target
                )
            );
            verify_source_isolation(program);
            if program.errors_had {
                for error in program.errors_had {
                    sys.stderr.write(error.pretty_print() + "\n");
                }
                raise RuntimeError("JacPython native compilation failed");
            }
            if module is None {
                raise RuntimeError("JacPython native compilation produced no module");
            }
            ir_text = native_linked_ir_text(module);
            issues = native_demoted_ir_symbols(ir_text);
            issues.extend(issue.symbol for issue in native_lowering_issues(ir_text));
            if issues {
                raise RuntimeError(
                    "JacPython may not demote to Python: "
                        + ", ".join(sorted(set(issues)))
                );
            }
            (ir_text, _) = inject_shared_init(ir_text, module.gen.interop_manifest);
            init_object_codegen();
            compiled = llvm.parse_assembly(ir_text);
            compiled.verify();
            machine = llvm.Target.from_triple(target).create_target_machine(
                opt=2, reloc="pic", codemodel="small"
            );
            output.write_bytes(machine.emit_object(compiled));
        } finally {
            pop_import_base();
            program.release_compile_closure(collect=True);
        }
    }
}

def compile_kernel(package: Path, output: Path, target: str) {
    import from jaclang.cli.cli_boot { start_cli }
    package = package.resolve(strict=True);
    output = output.resolve();
    output.parent.mkdir(parents=True, exist_ok=True);
    with tempfile.TemporaryDirectory(prefix="jac-compiler-kernel-") as work {
        snapshot = Path(work).resolve() / "jaclang";
        snapshot_sources(package, snapshot);
        argv = sys.argv;
        push_import_base(str(snapshot.parent));
        try {
            sys.argv = [
                "jac",
                "build",
                "--native",
                "--lib",
                "--target",
                target,
                str(snapshot / "compiler/jc_unit.jac"),
                "-o",
                str(output)
            ];
            try {
                start_cli();
            } except SystemExit as result {
                if result.code {
                    raise;
                }
            }
        } finally {
            pop_import_base();
            sys.argv = argv;
        }
    }
    if not output.is_file() or not Path(str(output) + ".layout.json").is_file() {
        raise RuntimeError(
            "Native compiler build did not produce its library and layout"
        );
    }
}

@lru_cache(maxsize=4)
def image_codec(package: str) -> ModuleType {
    spec = importlib.util.spec_from_file_location(
        "_jac_compiler_image_codec", str(Path(package) / "compiler/driver/image.py")
    );
    if spec is None or spec.loader is None {
        raise RuntimeError("Missing target compiler image codec");
    }
    codec = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(codec);
    return codec;
}

def compile_module(
    source: Path,
    package: Path,
    output: Path,
    cache: Path | None = None,
    identity: str = "",
    version: str = ""
) -> dict[str, any] {
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
    codec = image_codec(str(package));
    cached = cache / relative.with_suffix(".jir") if cache is not None else None;
    if cached is not None and cached.is_file() {
        try {
            data = cached.read_bytes();
            if precompiled_jir_matches_source(
                data, str(source), identity, str(package)
            ) {
                codec.decode_code(data);
                output.parent.mkdir(parents=True, exist_ok=True);
                output.write_bytes(data);
                return {
                    "source": relative.as_posix(),
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "cached": True,
                    "seconds": time.monotonic() - started
                };
            }
        } except (OSError, ValueError, EOFError, TypeError) {}
    }
    program = JacProgram();
    push_import_base(str(package.parent));
    try {
        options = CompileOptions(
            force_codespace="server",
            need_full_ast=True,
            no_ir_cache=True,
            project_root=str(package.parent),
            entry_point=str(source)
        );

        if hasattr(options, "force_target_program") {
            setattr(options, "force_target_program", True);
        }
        module = program.compile(file_path=str(source), options=options);
        contexts = [program] + list(program.contexts.values());
        verify_source_isolation(program);
        if module is None or not module.gen.py_bytecode {
            details = "\n".join(e.pretty_print() for e in program.errors_had);
            raise ValueError(
                f"{source}: compiler emitted no executable bytecode:\n{details}"
            );
        }
        for diagnostic in program.errors_had {
            sys.stderr.write(diagnostic.pretty_print() + "\n");
        }
        bytecode = codec.patch_co_filenames_bytes(
            module.gen.py_bytecode, str(package), PRECOMPILE_SENTINEL, True
        );
        dependencies: set[str] = set();
        bodies: set[str] = set();
        for context in contexts {
            for (path, unit) in context.mod.hub.items() {
                if Path(path).is_file() {
                    dependencies.add(path);
                    if path.endswith(".jac") {
                        bodies.add(path);
                    }
                }
                dependencies.update(unit.ct_file_deps or []);
                bodies.update(unit.ct_body_deps or []);
            }
        }
        artifact = codec.write_precompiled_jir(
            bytecode,
            compute_precompile_module_key(str(source), identity),
            FLAG_PRECOMPILED,
            {
                int(SEC_CTDEPS): ct_deps_section(
                    list(dependencies), list(bodies), str(package)
                )
            },
            version
        );
        output.parent.mkdir(parents=True, exist_ok=True);
        output.write_bytes(artifact);
        if cached is not None {
            cached.parent.mkdir(parents=True, exist_ok=True);
            temporary = cached.with_suffix(f".{os.getpid()}.tmp");
            temporary.write_bytes(artifact);
            temporary.replace(cached);
        }
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
    native_only: list[str],
    cache: Path | None = None
) {
    import from jaclang.cli.workpool { WorkPool, pool_available, resolve_jobs }
    import from jaclang.dist.precompile_bytecode {
        find_jac_files,
        jir_to_module,
        write_manifest,
        _precompile_retire
    }
    import from jaclang.compiler.driver.jir { running_compiler_digest }

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
    project = find_project_root(package);
    if project is None {
        raise ValueError("Compiler sources have no project manifest");
    }
    import from jaclang.project.tomlio { read_toml_with_encoding }
    metadata = read_toml_with_encoding(str(project[1]));
    version = str(metadata["project"]["version"]);
    with tempfile.TemporaryDirectory(prefix="jac-compiler-image-") as work {
        site = Path(work).resolve() / "site";
        snapshot = site / "jaclang";
        snapshot_sources(package, snapshot);
        exclude_native_python_sources(package, snapshot);
        resolver_marker = snapshot / "jac0core";
        shutil.copyfile(
            package.parent / "bootstrap/pins.json", snapshot / "dist/payload/pins.json"
        );
        shutil.copyfile(
            package.parent / "bootstrap/python/sources.json",
            snapshot / "dist/payload/python-sources.json"
        );
        import from jaclang.dist.payload.assemble { write_dist_info }
        write_dist_info(str(package.parent), str(site));
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
        codec = image_codec(str(snapshot));
        layout_digest = hashlib.sha256(producer_digest.encode());
        layout_digest.update(Path(__file__).read_bytes());
        layout_digest.update((snapshot / "compiler/driver/image.py").read_bytes());
        layout_digest.update((site / "jac.toml").read_bytes());
        for path in sorted(snapshot.rglob("*")) {
            if path.is_file() and precompiled not in path.parents {
                relative_path = path.relative_to(snapshot).as_posix();
                layout_digest.update(relative_path.encode() + b"\0");
                if path.suffix in (".toml", ".json") {
                    layout_digest.update(path.read_bytes());
                }
            }
        }
        cache_identity = layout_digest.hexdigest();
        module_cache = cache / cache_identity if cache is not None else None;
        sources = [
            source
            for source in find_jac_files(str(snapshot))
            if Path(source).relative_to(snapshot).as_posix() not in native_only
                and not Path(source).is_relative_to(snapshot / "client/templates")
                and not toolchain_native_by_policy(str(snapshot), source)
        ];
        modules: dict[str, dict[str, any]] = {};
        results: list[dict[str, any]] = [];
        failures: list[str] = [];
        def job(request: dict[str, any]) -> dict[str, any] {
            source = Path(str(request["path"]));
            destination = artifacts / source.relative_to(snapshot).with_suffix(".jir");
            return compile_module(
                source, snapshot, destination, module_cache, cache_identity, version
            );
        }
        def record(index: int, message: dict[str, any]) {
            result = message.get("result");
            source = Path(sources[index]).relative_to(snapshot).as_posix();
            if not isinstance(result, dict) {
                failures.append(source);
                sys.stderr.write(json.dumps({** message, "source": source}) + "\n");
                return;
            }
            relative_jir = Path(source).with_suffix(".jir").as_posix();
            results.append(result);
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
        (site / "jac.toml").unlink();
        payloads: dict[str, str] = {};
        for path in sorted(snapshot.rglob("*")) {
            if path.is_file() and precompiled not in path.parents {
                payloads[path.relative_to(snapshot).as_posix()] = hashlib.sha256(
                    path.read_bytes()
                ).hexdigest();
            }
        }
        write_manifest(precompiled, "jaclang", pyver, modules, payloads);
        manifest_path = precompiled / "MANIFEST.json";
        manifest = json.loads(manifest_path.read_text());
        manifest["site_payloads"] = {
            path.relative_to(site).as_posix(): hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
            for path in sorted(site.rglob("*"))
            if path.is_file() and snapshot not in path.parents
        };
        manifest["jaclang_version"] = version;
        manifest["producer_digest"] = producer_digest;
        manifest["source_root"] = PRECOMPILE_SENTINEL;
        codec.write_compiler_manifest(precompiled, manifest);
        if output.exists() {
            output.rmdir();
        }
        shutil.move(str(site), str(output));
    }
    sys.stderr.write(
        json.dumps(
            {
                "image": str(output),
                "modules": len(modules),
                "reused": sum(
                    1
                    for result in results
                    if result.get("cached", False)
                ),
                "compiled": sum(
                    1
                    for result in results
                    if not result.get("cached", False)
                ),
                "seconds": time.monotonic() - started
            }
        )
            + "\n"
    );
}

def complete_image(source: Path, catalog: Path, output: Path) {
    source = source.resolve(strict=True);
    catalog = catalog.resolve(strict=True);
    output = output.resolve();
    codec = image_codec(str(source / "jaclang"));
    image = codec.load_image(source / "jaclang/_precompiled");
    if image is None {
        raise ValueError("Cannot complete a missing compiler image");
    }
    image.verify();
    if output.exists() {
        output.rmdir();
    }
    shutil.copytree(source, output);
    precompiled = output / "jaclang/_precompiled";
    destination = precompiled / "stubcat.bin";
    shutil.copyfile(catalog, destination);
    manifest = dict(image.manifest);
    manifest["payloads"] = {
        ** manifest["payloads"],
        "_precompiled/stubcat.bin": hashlib.sha256(destination.read_bytes()).hexdigest()
    };
    codec.write_compiler_manifest(precompiled, manifest);
}

with entry:__main__ {
    if len(sys.argv) == 5 and sys.argv[1] == "complete" {
        complete_image(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]));
    } elif len(sys.argv) == 5 and sys.argv[1] == "python-native" {
        compile_native_python(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]);
    } elif len(sys.argv) == 5 and sys.argv[1] == "kernel" {
        compile_kernel(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]);
    } elif len(sys.argv) >= 8 and sys.argv[1] == "image" {
        compile_image(
            Path(sys.argv[2]),
            Path(sys.argv[3]),
            Path(sys.argv[4]),
            Path(sys.argv[5]),
            int(sys.argv[6]),
            list(sys.argv[8:]),
            Path(sys.argv[7])
        );
    } elif len(sys.argv) == 4 {
        package = Path(sys.argv[1]);
        result = compile_module(package / sys.argv[2], package, Path(sys.argv[3]));
        sys.stdout.write(json.dumps(result, sort_keys=True) + "\n");
    } else {
        raise SystemExit(
            "usage: compiler.jac <package> <source-relative-path> <output.jir>\n"
            "       compiler.jac image <package> <output-site> <kernel> <shim> <jobs> <module-cache> [native-only-source ...]"
        );
    }
}
