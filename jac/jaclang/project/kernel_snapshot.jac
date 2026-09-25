import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host { HostServices, active_host, install_host }
import from jaclang.compiler.frontend.kernel_inputs { KernelInputs, ManifestSets }
import from jaclang.compiler.frontend.kernel_host { KernelHost }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }

glob SCAN_LIMIT: int = 4000,
     THIRD_PARTY_DIRS: tuple[str, ...] = ("/site-packages/", "/dist-packages/");

obj ClosureScan {
    has learner: KernelHost,
        program: JacProgram,
        options: CompileOptions,
        entry_path: str,
        entry_source: (str | None) = None,
        scratch: (JacProgram | None) = None,
        scope: list[str] = [],
        seen: set[str] = set(),
        learned: set[str] = set(),
        queue: list[str] = [];

    def run {
        owner = self.learner.project_root(self.entry_path);
        top = owner or os.path.dirname(os.path.abspath(self.entry_path));
        self.scope.append(os.path.join(os.path.realpath(top), ""));
        self.queue.append(self.entry_path);
        while self.queue and len(self.seen) < SCAN_LIMIT {
            path = self.queue.pop();
            if path in self.seen {
                continue;
            }
            self.seen.add(path);
            self.scan_module(path);
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
        import from jaclang.compiler.frontend.parser.frontend { parse }
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
            try {
                text = self.source_of(source_path);
                (tree, _) = parse(text, source_path);
            } except Exception {
                continue;
            }
            self.scan_imports(tree);
        }
        try {
            import from jaclang.compiler.driver.wiring { wiring_for_path }
            wiring_for_path(path);
        } except Exception {}
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

    def scan_imports(tree: uni.Module) {
        learner = self.learner;
        for mod_path in tree.get_all_sub_nodes(uni.ModulePath) {
            owner = mod_path.loc.mod_path if mod_path.loc else "";
            if not owner {
                continue;
            }
            spec = mod_path.string_path_value;
            if spec is not None {
                learner.is_path_alias(spec, owner);
            } else {
                spec = mod_path.dot_path_str;
            }
            self.follow(self.resolved(mod_path, None));
            self.learn_npm(spec, owner);
            if spec.startswith("jaclang.") {
                learner.resolve_module(spec, os.path.join(os.path.dirname(owner), ""));
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
        if not path or not os.path.isfile(path) {
            return;
        }
        self.learn_path(path);
        if not self.in_scope(path) {
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
        learner.workspace(path);
        learner.app_for_path(path);
        learner.lint_settings(path);
        learner.native_verdict(path, self.program);
        learner.is_untyped_third_party(path);
        learner.declared_dependencies(path, self.options.target_app or "");
        if path.endswith(".js") {
            learner.sibling_declaration(path);
        }
        real = os.path.realpath(path);
        if real != path {
            self.learn_path(real);
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

def snapshot_inputs(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> KernelInputs {
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.project.modresolver { get_jac_search_paths, get_typeshed_paths }
    catalog_dir = "";
    if host.has_active_stub_catalog() {
        import from jaclang.jac0core.stubcat_hook { active }
        catalog: any = active();
        catalog_dir = str(catalog.pkg_dir) if catalog is not None else "";
    }
    natives = program._natives;
    inputs = KernelInputs(
        entry_path=path,
        module_projection=options.module_projection(),
        target_app=options.target_app or "",
        project_defaults=host.project_defaults(),
        host_platform=host.host_platform(),
        ct_environment=host.ct_environment(),
        stub_catalog_active=host.has_active_stub_catalog(),
        stub_catalog_dir=catalog_dir,
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
    } finally {
        install_host(previous);
    }
    inputs.scanned_modules = len(scan.seen);
    return inputs;
}
