impl ClientBundleBuilder.postinit -> None {
    if not self.runtime_path {
        self.runtime_path = Path(__file__).with_name('client_runtime.jac');
    }
}

impl ClientBundleBuilder.build(
    module: ModuleType, force: bool = False
) -> ClientBundle {
    if not module?.__file__ {
        raise ClientBundleError(
            f"Module '{module.__name__}' has no __file__ attribute"
        );
    }
    module_path = module.__file__;
    source_path = Path(module_path).resolve();
    prebuilt = prebuilt_bundle(module, source_path);
    if prebuilt is not None {
        self._cache[module.__name__] = _CachedBundle(
            signature='prepared', bundle=prebuilt
        );
        return prebuilt;
    }
    manifest = self._compile_to_js(source_path).manifest;
    bundle_paths = [source_path];
    if (manifest and manifest.imports) {
        for import_path in manifest.imports.values() {
            bundle_paths.append(Path(import_path));
        }
    }
    signature = self._signature(bundle_paths);
    emitted = self._emitted_digest();
    if emitted {
        signature = f"{signature}:{emitted}";
    }
    cached = self._cache.get(module.__name__);
    if (not force and cached and (cached.signature == signature)) {
        return cached.bundle;
    }
    bundle = self._compile_bundle(module, source_path);
    self._cache[module.__name__] = _CachedBundle(signature=signature, bundle=bundle);
    return bundle;
}

impl ClientBundleBuilder._extract_client_exports(
    manifest: (ClientManifest | None)
) -> list[str] {
    return sorted(dict.fromkeys(manifest.exports)) if manifest else [];
}

impl ClientBundleBuilder._extract_client_globals(
    manifest: (ClientManifest | None), module: (ModuleType | None)
) -> dict[str, any] {
    client_globals_map: dict[(str, any)] = {};
    if manifest {
        for name in manifest.globals {
            if (name in manifest.globals_values) {
                client_globals_map[name] = manifest.globals_values[name];
            } elif module is not None and hasattr(module, name) {
                client_globals_map[name] = getattr(module, name);
            } else {
                client_globals_map[name] = None;
            }
        }
    }
    return {key: client_globals_map[key] for key in sorted(client_globals_map)};
}

impl ClientBundleBuilder._compile_bundle(
    module: ModuleType, module_path: Path
) -> ClientBundle {
    raise ClientBundleError(
        "Client bundling requires the built-in client framework (Vite/Bun pipeline), "
        "which ships with jaclang core; the base builder cannot bundle client "
        "code on its own."
    );
}

impl ClientBundleBuilder._compile_to_js(
    source_path: Path, source_root: Path | None = None
) -> ClientArtifact {
    program = client_program(self.program);
    root = str(source_root.resolve())
        if source_root is not None
        else (program.options.client_source_root if program.options is not None else "");
    mark = len(program.errors_had);
    artifact = kernel_client_artifact(
        program,
        str(source_path),
        CompileOptions(skip_native_engine=True, client_source_root=root)
    );
    if artifact is None {
        formatted = '\n'.join(str(err) for err in program.errors_had[mark:]);
        if not formatted {
            formatted = (
                " it lowers to no client code because it declares nothing that runs on "
                "or is exposed to the client."
            );
        }
        raise ClientBundleError(
            f"Failed to compile '{source_path}' for client bundle:{formatted}"
        );
    }
    return artifact;
}

impl ClientBundleBuilder._emitted_digest -> str {
    return '';
}

impl emitted_tree_digest(tree_root: Path) -> str {
    if not tree_root.is_dir() {
        return '';
    }
    hasher = hashlib.sha256();
    found = False;
    files = sorted(tree_root.rglob('*'));
    for p in files {
        if not p.is_file() or p.suffix not in ('.js', '.css') {
            continue;
        }
        found = True;
        hasher.update(str(p.relative_to(tree_root)).encode('utf-8'));
        try {
            hasher.update(p.read_bytes());
        } except OSError {
            hasher.update('?'.encode('utf-8'));
        }
    }
    if not found {
        return '';
    }
    return hasher.hexdigest();
}

impl ClientBundleBuilder._signature(paths: Iterable[Path]) -> str {
    parts = [f"{path}:{ct_dep_digest(str(path), with_annexes=True)}" for path in paths];
    return hashlib.sha256('|'.join(parts).encode('utf-8')).hexdigest();
}

impl client_program(program: JacProgram | None) -> JacProgram {
    if program is not None {
        return program;
    }

    current = JacRuntime.program;
    if current is None {
        raise ClientBundleError('No active compilation program for client products');
    }
    return current;
}
