import os;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host {
    HostServices,
    active_host,
    install_host,
    kernel_host_mode
}
import from jaclang.compiler.frontend.kernel_inputs {
    KernelInputs,
    ManifestSets,
    PythonInterface,
    request_of
}
import from jaclang.compiler.frontend.kernel_host { HostCensus, KernelHost }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    ANALYSIS_OK,
    AnalysisReport,
    analysis_report,
    run_kernel_analysis
}
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis, analyze_module }
import from jaclang.compiler.driver.session_compile {
    CompileFrame,
    SessionContext,
    SessionHooks,
    compile_in_session
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
import type from jaclang.compiler.native_compiler { NativeCompiler }

glob SCAN_LIMIT: int = 4000,
     PACKAGE_CHAIN_DEPTH: int = 8,
     INTERFACE_LIMIT: int = 4000,
     _IFACE_MEMO: dict[str, tuple[list[str], list[str], PythonInterface]] = {},
     _IFACE_REFUSED: dict[str, str] = {},
     _PACKAGE_SCANS: dict[str, PackageScan] = {},
     NATIVE_INT_OVERFLOW: str = "integer overflow",
     MISS_ROUNDS: int = 12,
     INTERFACE_MISSES: tuple[str, ...] = ("compile_module", "parse_python"),
     DIRECT_MISS_ROUNDS: int = 2,
     PATH_MISSES: tuple[str, ...] = (
         "workspace",
         "app_for_path",
         "project_root",
         "project_facts",
         "lint_settings",
         "native_verdict",
         "is_untyped_third_party",
         "sibling_declaration"
     ),
     PRELUDE_STUBS: tuple[str, ...] = (
         "builtins.pyi",
         "typing.pyi",
         "types.pyi",
         "enum.pyi"
     ),
     THIRD_PARTY_DIRS: tuple[str, ...] = ("/site-packages/", "/dist-packages/"),
     _TOTALS: list[HostCensus] = [],
     _EXIT_REPORT: list[bool] = [];

class KernelAnalysisError(RuntimeError) {}

obj PackageScan {
    has learned: KernelInputs,
        edges: list[str] = [],
        string_specs: list[tuple[str, str]] = [];
}

def package_scan_file(path: str, target_app: str) -> str {
    import hashlib;
    import from jaclang.compiler.driver.jir {
        get_jir_cache_dir,
        running_compiler_digest
    }
    key = hashlib.sha256(
        (running_compiler_digest() + "\x1f" + path + "\x1f" + target_app).encode(
            "utf-8"
        )
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "kernel_scans", key[:2], key + ".json"
    );
}

def stored_package_scan(target: str) -> (PackageScan | None) {
    import json;
    import from jaclang.compiler.frontend.kernel_inputs { inputs_from_dict, json_map }
    try {
        with open(target, "r", encoding="utf-8") as f {
            record = json.load(f);
        }
        return PackageScan(
            learned=inputs_from_dict(json_map(record["learned"])),
            edges=[str(e) for e in record["edges"]],
            string_specs=[(str(s[0]), str(s[1])) for s in record["string_specs"]]
        );
    } except (OSError, ValueError, KeyError, TypeError, IndexError) {
        return None;
    }
}

def store_package_scan(target: str, found: PackageScan) {
    import json;
    import from jaclang.compiler.frontend.kernel_inputs { inputs_to_dict }
    try {
        os.makedirs(os.path.dirname(target), exist_ok=True);
        scratch_file = target + f".{os.getpid()}.tmp";
        with open(scratch_file, "w", encoding="utf-8") as f {
            json.dump(
                {
                    "learned": inputs_to_dict(found.learned),
                    "edges": list(found.edges),
                    "string_specs": [
                        [spec, owner] for (spec, owner) in found.string_specs
                    ]
                },
                f
            );
        }
        os.replace(scratch_file, target);
    } except OSError {}
}

def package_scan(
    host: HostServices, program: JacProgram, options: CompileOptions, path: str
) -> PackageScan {
    target_app = options.target_app or "";
    memo_key = path + "\x1f" + target_app;
    found = _PACKAGE_SCANS.get(memo_key);
    if found is not None {
        return found;
    }
    target = package_scan_file(path, target_app);
    found = stored_package_scan(target);
    if found is None {
        learner = KernelHost(inputs=KernelInputs(entry_path=path), fallback=host);
        scan = ClosureScan(
            learner=learner, program=program, options=options, entry_path=path
        );
        previous = active_host();
        install_host(learner);
        try {
            scan.scan_module(path);
        } finally {
            install_host(previous);
        }
        found = PackageScan(
            learned=learner.inputs,
            edges=sorted(scan.package_edges),
            string_specs=sorted(scan.string_specs)
        );
        store_package_scan(target, found);
    }
    _PACKAGE_SCANS[memo_key] = found;
    return found;
}

def merge_learned(into: KernelInputs, part: KernelInputs) {
    for (key, facts) in part.project_facts.items() {
        into.project_facts.setdefault(key, facts);
    }
    for (key, ws) in part.workspaces.items() {
        into.workspaces.setdefault(key, ws);
    }
    for (key, text) in part.facts_of.items() {
        into.facts_of.setdefault(key, text);
    }
    for (key, text) in part.workspace_of.items() {
        into.workspace_of.setdefault(key, text);
    }
    for (key, text) in part.app_of.items() {
        into.app_of.setdefault(key, text);
    }
    for (key, text) in part.project_root_of.items() {
        into.project_root_of.setdefault(key, text);
    }
    for (key, lint) in part.lint_of.items() {
        into.lint_of.setdefault(key, lint);
    }
    for (key, verdict) in part.verdicts.items() {
        into.verdicts.setdefault(key, verdict);
    }
    for (key, flag) in part.untyped.items() {
        into.untyped.setdefault(key, flag);
    }
    for (key, text) in part.siblings.items() {
        into.siblings.setdefault(key, text);
    }
    for (key, flag) in part.path_aliases.items() {
        into.path_aliases.setdefault(key, flag);
    }
    for (key, text) in part.virtual_modules.items() {
        into.virtual_modules.setdefault(key, text);
    }
    into.imports.extend(part.imports);
    into.local_imports.extend(part.local_imports);
    into.npm.extend(part.npm);
    into.declared.extend(part.declared);
}

obj ClosureScan {
    has learner: KernelHost,
        program: JacProgram,
        options: CompileOptions,
        entry_path: str,
        entry_source: (str | None) = None,
        scratch: (JacProgram | None) = None,
        scope: list[str] = [],
        seen: set[str] = set(),
        package_edges: set[str] = set(),
        learned: set[str] = set(),
        merged_packages: set[str] = set(),
        closed_packages: set[str] = set(),
        wiring_trees: dict[str, uni.Module] = {},
        wired_dirs: set[tuple[str, str]] = set(),
        string_specs: set[tuple[str, str]] = set(),
        queue: list[str] = [];

    def run {
        owner = self.learner.project_root(self.entry_path);
        cwd_owner = self.learner.project_root("");
        if cwd_owner {
            self.learner.project_facts(cwd_owner);
        }
        top = owner or os.path.dirname(os.path.abspath(self.entry_path));
        self.scope.append(os.path.join(os.path.realpath(top), ""));
        self.queue.append(self.entry_path);
        self.settle();
    }

    def settle {
        while self.queue and len(self.seen) < SCAN_LIMIT {
            path = self.queue.pop();
            if path in self.seen {
                continue;
            }
            self.seen.add(path);
            self.scan_module(path);
        }
        for package_path in sorted(self.package_edges) {
            self.learn_package(package_path);
        }
    }

    def learn_package_closure(path: str) {
        host = self.learner.fallback;
        if host is None {
            return;
        }
        pending = [path];
        while pending {
            current = pending.pop();
            if current in self.closed_packages {
                continue;
            }
            self.closed_packages.add(current);
            self.learn_package(current);
            found = package_scan(host, self.program, self.options, current);
            pending.extend(found.edges);
        }
    }

    def learn_package(path: str) {
        if path in self.merged_packages {
            return;
        }
        self.merged_packages.add(path);
        host = self.learner.fallback;
        if host is None {
            return;
        }
        found = package_scan(host, self.program, self.options, path);
        merge_learned(self.learner.inputs, found.learned);
        for (spec, owner) in found.string_specs {
            self.learn_npm(spec, owner);
        }
    }

    def scan_module(path: str) {
        self.learn_path(path);
        if path.endswith(".jac") {
            self.scan_jac(path);
        } elif path.endswith(".py") {
            self.scan_python(path);
        }
    }

    def scan_jac(path: str) {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven }
        learner = self.learner;
        sources = [path];
        sources.extend(learner.annex_files(path, ".impl.jac"));
        sources.extend(learner.annex_files(path, ".test.jac"));
        arch = learner.wiring_file(path);
        if arch {
            sources.append(arch);
        }
        for source_path in sources {
            self.learn_path(source_path);
            shared = source_path == arch;
            wired = (source_path, os.path.dirname(path));
            if shared and wired in self.wired_dirs {
                continue;
            }
            held = self.wiring_trees.get(source_path) if shared else None;
            tree: uni.Module;
            if held is not None {
                tree = held;
            } else {
                try {
                    text = self.source_of(source_path);
                    (tree, _) = parse_woven(text, source_path, None, []);
                } except Exception {
                    continue;
                }
                if shared {
                    self.wiring_trees[source_path] = tree;
                }
            }
            if shared {
                self.wired_dirs.add(wired);
            }
            self.scan_imports(tree, path);
            self.learn_runtime_imports(tree, source_path);
            self.learn_arch(tree, source_path);
        }
        try {
            import from jaclang.compiler.driver.wiring {
                wiring_annex_for,
                wiring_for_path
            }
            wiring_for_path(path);
            annex = wiring_annex_for(path);
            if annex is not None {
                (tree, _) = parse_woven(annex.source, annex.path, None, []);
                self.scan_imports(tree, path);
            }
        } except Exception {}
    }

    def learn_package_bases(found: str, spec: str) {
        if not found or not spec or spec.startswith(".") {
            return;
        }
        base = found;
        for _ in range(spec.count(".") + 2) {
            base = os.path.dirname(base);
            if not base or base in self.learned {
                continue;
            }
            self.learned.add(base);
            owner = self.learner.project_root(base);
            if owner {
                self.learner.project_facts(owner);
            }
        }
    }

    def learn_runtime_imports(tree: uni.Module, path: str) {
        import from jaclang.compiler.frontend.codeinfo { SHARED_RUNTIME_MODULES }
        if not tree.get_all_sub_nodes(uni.GraphExpr) {
            return;
        }
        for runtime_module in SHARED_RUNTIME_MODULES {
            (resolved, _) = self.learner.resolve_module(runtime_module, path);
            self.follow(resolved);
            self.learn_npm(runtime_module, path);
            self.learner.resolve_module(
                runtime_module, os.path.join(os.path.dirname(path), "")
            );
        }
    }

    def learn_arch(tree: uni.Module, path: str) {
        import from jaclang.compiler.driver.wiring { is_arch_file, wiring_for_path }
        if not is_arch_file(path) {
            return;
        }
        spec = wiring_for_path(path);
        if spec is None {
            return;
        }
        names: list[str] = [];
        for block in tree.get_all_sub_nodes(uni.ImplImport) {
            if block.scope is not None {
                names.append(block.scope_prefix);
            }
        }
        for wire in tree.get_all_sub_nodes(uni.ImportWire) {
            names.append(wire.provider_path);
            names.extend(consumer.dot_path_str for consumer in wire.consumers);
        }
        for name in names {
            spec.module_file(name);
        }
    }

    def scan_python(path: str) {
        if any(marker in path.replace("\\", "/") for marker in THIRD_PARTY_DIRS) {
            return;
        }
        if self.scratch is None {
            self.scratch = JacProgram();
        }
        try {
            (tree, _) = self.learner.parse_python(
                self.source_of(path), path, self.scratch
            );
        } except Exception {
            return;
        }
        self.scan_imports(tree);
    }

    def source_of(path: str) -> str {
        if path == self.entry_path and self.entry_source is not None {
            return self.entry_source;
        }
        return self.learner.read_source(path);
    }

    def scan_imports(tree: uni.Module, base: str = "") {
        learner = self.learner;
        for mod_path in tree.get_all_sub_nodes(uni.ModulePath) {
            owner = mod_path.loc.mod_path if mod_path.loc else "";
            if not owner {
                continue;
            }
            spec = mod_path.string_path_value;
            if spec is not None {
                self.string_specs.add((spec, owner));
                learner.is_path_alias(spec, owner);
            } else {
                spec = mod_path.dot_path_str;
            }
            found = self.resolved(mod_path, None);
            self.follow(found);
            self.learn_package_bases(found, spec);
            self.learn_npm(spec, owner);
            if spec.startswith("@jac/") {
                virtual_path = learner.jac_virtual_module_path(spec);
                if virtual_path {
                    learner.sibling_declaration(virtual_path);
                }
            }
            if spec.startswith("jaclang.") {
                learner.resolve_module(spec, os.path.join(os.path.dirname(owner), ""));
                if base and os.path.dirname(base) != os.path.dirname(owner) {
                    learner.resolve_module(
                        spec, os.path.join(os.path.dirname(base), "")
                    );
                }
            }
        }
        for item in tree.get_all_sub_nodes(uni.ModuleItem) {
            if item.parent is None or not isinstance(item.parent, uni.Import) {
                continue;
            }
            if item.from_parent.from_loc is None {
                continue;
            }
            self.follow(self.resolved(None, item));
        }
    }

    def resolved(
        mod_path: (uni.ModulePath | None), item: (uni.ModuleItem | None)
    ) -> str {
        try {
            if mod_path is not None {
                return mod_path.resolve_relative_path();
            }
            if item is not None {
                return item.resolve_relative_path();
            }
        } except Exception {}
        return "";
    }

    def learn_npm(spec: str, owner: str) {
        if not spec {
            return;
        }
        learner = self.learner;
        for base in (owner, self.entry_path) {
            if learner.has_npm_package(spec, base) {
                learner.resolve_npm_package(spec, base);
                learner.npm_declarations(spec, base);
            }
        }
    }

    def follow(path: str) {
        if path and os.path.isdir(path) {
            self.learn_path(path);
            return;
        }
        if not path or not os.path.isfile(path) {
            return;
        }
        self.learn_path(path);
        if not self.in_scope(path) {
            if is_compiler_source_path(path) and not path.endswith(".pyi") {
                self.package_edges.add(os.path.realpath(path));
                self.package_inits(path);
            }
            return;
        }
        if path.endswith(".jac") or path.endswith(".py") {
            if path not in self.seen {
                self.queue.append(path);
            }
        }
    }

    def in_scope(path: str) -> bool {
        if is_compiler_source_path(path) {
            return False;
        }
        real = os.path.realpath(path);
        return any(real.startswith(top) for top in self.scope);
    }

    def learn_path(path: str) {
        if not path or path in self.learned {
            return;
        }
        self.learned.add(path);
        learner = self.learner;
        owner_root = learner.project_root(path);
        learner.project_facts(path);
        if owner_root {
            learner.project_facts(owner_root);
            learner.project_root(owner_root);
        }
        dir_owner = learner.project_root(os.path.dirname(path));
        if dir_owner {
            learner.project_facts(dir_owner);
        }
        owning = learner.workspace(path);
        if owning is not None and owning.project_root {
            learner.project_facts(owning.project_root);
            learner.project_root(owning.project_root);
        }
        learner.app_for_path(path);
        learner.lint_settings(path);
        learner.native_verdict(path, self.program);
        learner.is_untyped_third_party(path);
        learner.declared_dependencies(path, self.options.target_app or "");
        if path.endswith((".js", ".py")) {
            learner.sibling_declaration(path);
        }
        real = os.path.realpath(path);
        if real != path {
            self.learn_path(real);
        }
        self.learn_package_chain(path);
    }

    def package_inits(path: str) {
        folder = os.path.dirname(os.path.realpath(path));
        while is_compiler_source_path(os.path.join(folder, "__init__.jac")) {
            for name in ("__init__.py", "__init__.jac") {
                init = os.path.join(folder, name);
                if init != path and os.path.isfile(init) {
                    self.package_edges.add(init);
                }
            }
            parent = os.path.dirname(folder);
            if parent == folder {
                return;
            }
            folder = parent;
        }
    }

    def learn_package_chain(path: str) {
        folder = os.path.dirname(os.path.abspath(path));
        for _ in range(PACKAGE_CHAIN_DEPTH) {
            for name in ("__init__.py", "__init__.jac") {
                init = os.path.join(folder, name);
                if init != path and os.path.isfile(init) {
                    self.learn_path(init);
                }
            }
            parent = os.path.dirname(folder);
            if parent == folder {
                return;
            }
            folder = parent;
        }
    }
}

def manifest_sets -> ManifestSets {
    import from jaclang.bootstrap_manifest {
        NATIVE_LOWERED_PATHS,
        NATIVE_ONLY_DIR_REL,
        NATIVE_ONLY_REL,
        SEED_PATHS
    }
    return ManifestSets(
        seed_paths=list(SEED_PATHS),
        native_only_files=list(NATIVE_ONLY_REL),
        native_only_dirs=list(NATIVE_ONLY_DIR_REL),
        native_lowered=list(NATIVE_LOWERED_PATHS)
    );
}

def python_interface(
    path: str, options: CompileOptions, scratch: (JacProgram | None) = None
) -> (PythonInterface | None) {
    import from jaclang.compiler.types.stubcat.writer {
        IncoherentInterface,
        build_module_iface
    }
    resolved = os.path.realpath(path);
    if scratch is None {
        scratch = JacProgram();
    }
    try {
        mod = scratch.compile(resolved, options=options.for_symbols());
        pkg_dir = os.path.dirname(resolved);
        data = build_module_iface(mod, scratch.get_type_evaluator(), pkg_dir);
    } except IncoherentInterface {
        return None;
    }
    return PythonInterface(path=resolved, pkg_dir=pkg_dir, data=data);
}

def interface_dependencies(iface: PythonInterface) -> list[str] {
    import from jaclang.compiler.types.stubcat.format { MOD_EXTERNAL }
    import from jaclang.compiler.types.stubcat.modiface { open_module_iface }
    catalog = open_module_iface(iface.data, iface.pkg_dir);
    if catalog is None {
        return [];
    }
    out: list[str] = [];
    for (_, rel, flags, scope_id, _) in catalog._mod_recs {
        if (flags & MOD_EXTERNAL) != 0 or scope_id < 0 {
            dep = os.path.realpath(catalog.abs_path(rel));
            if dep != iface.path and dep not in out {
                out.append(dep);
            }
        }
    }
    return out;
}

def interface_wanted(path: str) -> bool {
    if not os.path.isfile(path) {
        return False;
    }
    if is_compiler_source_path(path) {
        return path.endswith(".py") or path.endswith(".jac");
    }
    return path.endswith(".py");
}

def file_stamp(path: str) -> str {
    try {
        st = os.stat(path);
    } except OSError {
        return "";
    }
    return f"{st.st_mtime_ns}:{st.st_size}";
}

def interface_cache_file(path: str) -> str {
    import hashlib;
    import from jaclang.compiler.driver.jir {
        get_jir_cache_dir,
        running_compiler_digest
    }
    key = hashlib.sha256(
        (running_compiler_digest() + "\x1f" + path).encode("utf-8")
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "kernel_ifaces", key[:2], key + ".json"
    );
}

def cached_interface(path: str) -> (PythonInterface | None) {
    import base64;
    import json;
    memo = _IFACE_MEMO.get(path);
    if memo is not None and memo[0] == dependency_stamps(memo[1]) {
        return memo[2];
    }
    try {
        with open(interface_cache_file(path), "r", encoding="utf-8") as f {
            record = json.load(f);
        }
    } except (OSError, ValueError) {
        return None;
    }
    deps: list[str] = [str(d) for d in record.get("deps", [])];
    if record.get("stamps") != dependency_stamps(deps) {
        return None;
    }
    iface = PythonInterface(
        path=path,
        pkg_dir=str(record.get("pkg_dir", "")),
        data=base64.b64decode(str(record.get("data", "")))
    );
    _IFACE_MEMO[path] = (record["stamps"], deps, iface);
    return iface;
}

def dependency_stamps(deps: list[str]) -> list[str] {
    return [file_stamp(d) for d in deps];
}

def remember_interface(iface: PythonInterface, deps: list[str]) {
    import base64;
    import json;
    tracked = [iface.path] + deps;
    stamps = dependency_stamps(tracked);
    _IFACE_MEMO[iface.path] = (stamps, tracked, iface);
    target = interface_cache_file(iface.path);
    try {
        os.makedirs(os.path.dirname(target), exist_ok=True);
        scratch_file = target + f".{os.getpid()}.tmp";
        with open(scratch_file, "w", encoding="utf-8") as f {
            json.dump(
                {
                    "deps": tracked,
                    "stamps": stamps,
                    "pkg_dir": iface.pkg_dir,
                    "data": base64.b64encode(iface.data).decode("ascii")
                },
                f
            );
        }
        os.replace(scratch_file, target);
    } except OSError {}
}

def python_interfaces(
    paths: list[str], options: CompileOptions, lazy: bool = False
) -> list[PythonInterface] {
    out: list[PythonInterface] = [];
    queue: list[str] = sorted(os.path.realpath(p) for p in paths);
    queue.reverse();
    asked: set[str] = set(queue);
    done: set[str] = set();
    scratch: (JacProgram | None) = None;
    while queue {
        path = queue.pop();
        if len(done) >= INTERFACE_LIMIT {
            raise KernelAnalysisError(
                f"the Python modules reached from {paths[0] if paths else path} "
                f"need more than {INTERFACE_LIMIT} interfaces"
            );
        }
        if path in done or not interface_wanted(path) {
            continue;
        }
        done.add(path);
        iface = cached_interface(path);
        deps: list[str] = [];
        if iface is None {
            if lazy and path not in asked and is_compiler_source_path(path) {
                continue;
            }
            stamp = file_stamp(path);
            if _IFACE_REFUSED.get(path) == stamp {
                continue;
            }
            if scratch is None {
                scratch = JacProgram();
            }
            iface = python_interface(path, options, scratch);
            if iface is None {
                _IFACE_REFUSED[path] = stamp;
                continue;
            }
            deps = interface_dependencies(iface);
            remember_interface(iface, deps);
        } else {
            deps = interface_dependencies(iface);
        }
        out.append(iface);
        for dep in deps {
            if dep not in done {
                queue.append(dep);
            }
        }
    }
    return out;
}

def snapshot_inputs(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> KernelInputs {
    return snapshot_closure(host, program, path, options, source).learner.inputs;
}

def snapshot_closure(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> ClosureScan {
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.project.modresolver { get_jac_search_paths, get_typeshed_paths }
    import from jaclang.compiler.types.stubcat.locate { catalog_origin }
    catalog_dir = "";
    host.compiler_for(program).ensure_stub_catalog();
    catalog_active = host.has_active_stub_catalog();
    if catalog_active {
        import from jaclang.jac0core.stubcat_hook { active }
        catalog: any = active();
        catalog_dir = str(catalog.pkg_dir) if catalog is not None else "";
    }
    origin = catalog_origin() if catalog_active else None;
    natives = program._natives;
    import from jaclang.compiler.frontend.host { package_root }
    inputs = KernelInputs(
        entry_path=path,
        package_root=package_root(),
        module_projection=options.module_projection(),
        target_app=options.target_app or "",
        request=request_of(options),
        project_defaults=host.project_defaults(),
        host_platform=host.host_platform(),
        ct_environment=host.ct_environment(),
        stub_catalog_active=catalog_active,
        stub_catalog_dir=catalog_dir,
        stub_catalog_file=origin.path if origin is not None else "",
        stub_catalog_offset=origin.offset if origin is not None else 0,
        stub_catalog_length=origin.length if origin is not None else 0,
        typeshed_roots=get_typeshed_paths(),
        search_paths=get_jac_search_paths(os.path.dirname(os.path.abspath(path))),
        native_session_active=natives is not None and natives.session is not None,
        manifest=manifest_sets(),
        layout=host_layout_tables()
    );
    for app in {"", options.target_app or ""} {
        inputs.check_settings[app] = host.check_settings(app);
    }
    inputs.lint_of[""] = host.lint_settings("");
    (inputs.native_pipeline, inputs.native_pipeline_reason) = host.native_pipeline_available();
    inputs.native_pipeline_known = True;
    inputs.target_triple = host.default_target_triple();
    inputs.target_triple_known = True;
    learner = KernelHost(inputs=inputs, fallback=host);
    previous = active_host();
    install_host(learner);
    scan = ClosureScan(
        learner=learner,
        program=program,
        options=options,
        entry_path=path,
        entry_source=source
    );
    try {
        scan.run();
        for stub_root in inputs.typeshed_roots {
            for prelude in PRELUDE_STUBS {
                stub = os.path.join(stub_root, prelude);
                if os.path.isfile(stub) {
                    scan.learn_path(stub);
                }
            }
        }
        for prelude in PRELUDE_STUBS {
            (stub, _) = learner.resolve_module(prelude[:-len(".pyi")], path);
            if stub and os.path.isfile(stub) {
                scan.learn_path(stub);
                scan.learn_path(os.path.realpath(stub));
            }
        }
    } finally {
        install_host(previous);
    }
    inputs.scanned_modules = len(scan.seen);
    return scan;
}

obj KernelSnapshot {
    has scan: ClosureScan,
        host: HostServices,
        options: CompileOptions,
        emit_closure: bool = False,
        answered: set[str] = set(),
        wanted_interfaces: set[str] = set(),
        rounds: int = 0;

    def inputs -> KernelInputs {
        return self.scan.learner.inputs;
    }

    def refresh {
        import from jaclang.jac0core.ext_registry { is_annex }
        scan = self.scan;
        inputs = scan.learner.inputs;
        if self.emit_closure {
            entry_real = os.path.realpath(scan.entry_path);
            inputs.emit_paths = sorted(
                seen
                for seen in scan.seen
                if seen.endswith(".jac")
                    and not is_annex(seen)
                    and os.path.realpath(seen) != entry_real
            );
        }
        for ws in list(inputs.workspaces.values()) {
            for name in ws.apps {
                if name not in inputs.check_settings {
                    inputs.check_settings[name] = self.host.check_settings(name);
                }
            }
        }
        local = [
            p
            for (p, untyped) in inputs.untyped.items()
            if not untyped and not is_compiler_source_path(p)
        ];
        wanted = local + sorted(scan.package_edges) + sorted(self.wanted_interfaces);
        inputs.python_ifaces = python_interfaces(wanted, self.options, lazy=True);
        served = {iface.path for iface in inputs.python_ifaces};
        learn_facts(scan, sorted(served - set(wanted)));
    }

    def text -> str {
        inputs = self.scan.learner.inputs;
        host = self.host;
        if not self.options.no_cgen {
            import from jaclang.client.client_surface { injected_virtual_modules }
            import from jaclang.compiler.backends.es.backends.registry {
                resolve_active_backend
            }
            inputs.osp_core_js = host.client_osp_core_js();
            inputs.client_stub_globals = host.client_stub_globals();
            inputs.client_stub_globals_known = True;
            for module_id in injected_virtual_modules(resolve_active_backend()) {
                if module_id in inputs.virtual_modules {
                    continue;
                }
                virtual_path = host.jac_virtual_module_path(module_id) or "";
                inputs.virtual_modules[module_id] = virtual_path;
                if virtual_path and virtual_path not in inputs.siblings {
                    inputs.siblings[virtual_path] = host.sibling_declaration(
                        virtual_path
                    )
                        or "";
                }
            }
        }
        return inputs.to_json();
    }

    def answer(misses: list[str]) -> bool {
        fresh = [
            miss
            for miss in misses
            if miss not in self.answered
        ];
        if not fresh or self.rounds >= MISS_ROUNDS {
            return False;
        }
        self.rounds += 1;
        scan = self.scan;
        learner = scan.learner;
        acted = False;
        previous = active_host();
        install_host(learner);
        try {
            for miss in fresh {
                self.answered.add(miss);
                if self.answer_one(miss) {
                    acted = True;
                }
            }
            scan.settle();
        } finally {
            install_host(previous);
        }
        if acted {
            self.refresh();
        }
        return acted;
    }

    def answer_one(miss: str) -> bool {
        scan = self.scan;
        learner = scan.learner;
        if host_only_miss(miss) {
            return False;
        }
        (kind, _, key) = miss.partition(": ");
        fields = key.split(" | ");
        if kind == "resolve_module" and len(fields) == 3 {
            base = fields[2];
            (found, _) = learner.resolve_module(
                fields[1], base, string_spec=fields[0] == "1"
            );
            scan.follow(found);
            if os.path.isfile(base) and is_compiler_source_path(base) {
                if self.rounds > DIRECT_MISS_ROUNDS {
                    scan.learn_package_closure(os.path.realpath(base));
                } else {
                    scan.merged_packages.discard(os.path.realpath(base));
                    scan.learn_package(os.path.realpath(base));
                }
            }
            return True;
        }
        if kind == "resolve_local_module" and len(fields) == 2 {
            learner.resolve_local_module(fields[0], fields[1].split("/"));
            return True;
        }
        if kind in PATH_MISSES and key {
            scan.learned.discard(key);
            scan.learn_path(key);
            return True;
        }
        if kind in INTERFACE_MISSES and key {
            module_file = os.path.realpath(key);
            if module_file in self.wanted_interfaces
                or not interface_wanted(module_file) {
                return False;
            }
            self.wanted_interfaces.add(module_file);
            return True;
        }
        if kind == "check_settings" {
            learner.check_settings(key);
            return True;
        }
        if kind == "npm_declarations" and len(fields) == 2 {
            scan.learn_npm(fields[0], fields[1]);
            return True;
        }
        return False;
    }
}

def kernel_snapshot(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    emit_closure: bool = False
) -> KernelSnapshot {
    snapshot = KernelSnapshot(
        scan=snapshot_closure(host, program, path, options, source),
        host=host,
        options=options,
        emit_closure=emit_closure
    );
    snapshot.refresh();
    return snapshot;
}

def kernel_analysis_inputs(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    emit_closure: bool = False
) -> KernelInputs {
    return kernel_snapshot(
        host, program, path, options, source, emit_closure=emit_closure
    ).inputs();
}

def learn_facts(scan: ClosureScan, paths: list[str]) {
    if not paths {
        return;
    }
    previous = active_host();
    install_host(scan.learner);
    try {
        for dep in paths {
            scan.learn_path(dep);
        }
    } finally {
        install_host(previous);
    }
}

obj HostReferenceSession(SessionHooks) {
    has compiler: any,
        entry_path: str,
        task: (ModuleAnalysis | None) = None;

    def enter_compile(ctx: SessionContext) -> CompileFrame {
        return self.compiler.enter_compile(ctx);
    }

    def leave_compile(ctx: SessionContext, frame: CompileFrame) {
        self.compiler.leave_compile(ctx, frame);
    }

    def finish_compile(frame: CompileFrame) {
        self.compiler.finish_compile(frame);
    }

    def check_crash(crash: Exception, file_path: str) {
        self.compiler.check_crash(crash, file_path);
    }

    def closure_options -> (CompileOptions | None) {
        return self.compiler.closure_options();
    }

    def assemble_python(program: JacProgram, module: uni.Module) {
        self.compiler.assemble_python(program, module);
    }

    def assemble_native(program: JacProgram, module: uni.Module, checking: bool) {
        self.compiler.assemble_native(program, module, checking);
    }

    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        if self.task is None and os.path.realpath(file_path) == self.entry_path {
            task = analyze_module(target_program, file_path, options, use_str);
            self.task = task;
            return task.module;
        }
        return self.compiler.run_module(file_path, target_program, use_str, options);
    }
}

def host_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> AnalysisReport {
    session = HostReferenceSession(
        compiler=host.compiler_for(program), entry_path=os.path.realpath(path)
    );
    status = ANALYSIS_OK;
    message = "";
    try {
        compile_in_session(session, path, program, source, options);
    } except Exception as err {
        status = ANALYSIS_CRASHED;
        message = f"{type(err).__name__}: {err}";
    }
    tasks = [session.task] if session.task is not None else [];
    return analysis_report(program, path, tasks, status, message);
}

def kernel_inputs_json(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    emit_closure: bool = False
) -> str {
    return kernel_snapshot(
        host, program, path, options, source, emit_closure=emit_closure
    ).text();
}

obj KernelEntry {
    has call: str,
        take: str;
}

glob ANALYZE_ENTRY: KernelEntry = KernelEntry(
         call="jc_analyze", take="jc_take_analysis"
     ),
     COMPILE_ENTRY: KernelEntry = KernelEntry(
         call="jc_compile", take="jc_take_compile"
     );

def call_kernel(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None)
) -> str {
    import from ctypes { c_int64, c_void_p }
    lib = kernel.lib;
    run = getattr(lib, kind.call);
    run.argtypes = [c_void_p, c_void_p, c_int64] * 3 + [c_int64];
    run.restype = c_int64;
    take = getattr(lib, kind.take);
    take.argtypes = [];
    take.restype = c_void_p;
    handles: list[int] = [];
    args: list[object] = [];
    try {
        for text in (inputs_json, path, source or "") {
            data = text.encode();
            handle = lib.jac_str_new(data, len(data));
            handles.append(handle);
            args.extend([c_void_p(handle), c_void_p(handle), c_int64(len(data))]);
        }
        args.append(c_int64(1 if source is not None else 0));
        run(*args);
    } finally {
        for handle in handles {
            lib.jac_release(handle);
        }
    }
    return kernel._take(take()) or "";
}

def call_kernel_isolated(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None)
) -> str {
    if not hasattr(os, "fork") {
        return call_kernel(kernel, kind, inputs_json, path, source);
    }
    (read_fd, write_fd) = os.pipe();
    pid = os.fork();
    if pid == 0 {
        code = 0;
        try {
            os.close(read_fd);
            payload = call_kernel(kernel, kind, inputs_json, path, source).encode(
                "utf-8"
            );
            sent = 0;
            while sent < len(payload) {
                sent += os.write(write_fd, payload[sent:]);
            }
            os.close(write_fd);
        } except BaseException {
            code = 1;
        } finally {
            os._exit(code);
        }
    }
    os.close(write_fd);
    with os.fdopen(read_fd, "rb") as reader {
        payload = reader.read();
    }
    (_, status) = os.waitpid(pid, 0);
    if os.WIFSIGNALED(status) {
        raise KernelAnalysisError(
            f"the kernel {kind.call} died with signal {os.WTERMSIG(status)}"
        );
    }
    if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0 or not payload {
        raise KernelAnalysisError(f"the kernel {kind.call} exited without a report");
    }
    return payload.decode("utf-8");
}

def native_stdlib_misses(misses: list[str]) -> bool {
    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    stdlib_dir = native_stdlib_root();
    if not misses or not stdlib_dir {
        return False;
    }
    prefix = os.path.join(os.path.realpath(stdlib_dir), "");
    for miss in misses {
        asked = miss.partition(": ")[2];
        if not os.path.realpath(asked).startswith(prefix) {
            return False;
        }
    }
    return True;
}

def host_only_miss(miss: str) -> bool {
    (kind, _, asked) = miss.partition(": ");
    if native_stdlib_misses([miss]) {
        return True;
    }
    normalized = asked.replace("\\", "/");
    return kind == "parse_python"
        and any(marker in normalized for marker in THIRD_PARTY_DIRS);
}

def host_deferred(outcome: AnalysisReport) -> bool {
    if outcome.misses and all(host_only_miss(miss) for miss in outcome.misses) {
        return True;
    }
    return outcome.status == ANALYSIS_CRASHED
        and NATIVE_INT_OVERFLOW in outcome.message;
}

def loaded_kernel(kind: KernelEntry) -> NativeCompiler {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None {
        raise KernelAnalysisError("no native compiler kernel is available");
    }
    if not hasattr(kernel.lib, kind.call) {
        raise KernelAnalysisError(f"the loaded kernel has no {kind.call}");
    }
    return kernel;
}

def kernel_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = False
) -> AnalysisReport {
    snapshot = kernel_snapshot(host, program, path, options, source);
    while True {
        inputs_json = snapshot.text();
        if in_process {
            outcome = run_kernel_analysis(inputs_json, path, source);
        } else {
            kernel = loaded_kernel(ANALYZE_ENTRY);
            call = call_kernel_isolated if isolated else call_kernel;
            outcome = AnalysisReport.from_json(
                call(kernel, ANALYZE_ENTRY, inputs_json, path, source)
            );
        }
        if not outcome.misses
            or host_deferred(outcome)
            or not snapshot.answer(outcome.misses) {
            break;
        }
    }
    if outcome.status == ANALYSIS_CRASHED and not host_deferred(outcome) {
        detail = f" ({outcome.misses[-1]})" if outcome.misses else "";
        raise KernelAnalysisError(outcome.message + detail);
    }
    return outcome;
}

def kernel_census -> HostCensus {
    if not _TOTALS {
        _TOTALS.append(HostCensus());
    }
    return _TOTALS[0];
}

def reset_kernel_census {
    _TOTALS.clear();
}

def record_kernel_session(census: HostCensus, path: str) {
    census.sessions += 1;
    census.entry_path = path;
    kernel_census().merge(census);
    if kernel_host_mode() != "census" {
        return;
    }
    if not _EXIT_REPORT {
        import atexit;
        _EXIT_REPORT.append(True);
        atexit.register(report_kernel_census);
    }
    if census.total_misses() {
        report_stream().write(f"[{path}] {census.summary()}\n");
    }
}

def report_kernel_census {
    report_stream().write(kernel_census().summary() + "\n");
}

def report_stream -> any {
    return sys.__stderr__ or sys.stderr;
}
