import os;
import sys;
import from contextlib { contextmanager }
import from jaclang.compiler.frontend.host {
    active_host,
    install_host,
    CheckSettings,
    HostPlatform,
    HostServices,
    LintSettings,
    NativeVerdict,
    PathFacts,
    ProjectDefaults,
    ProjectFacts
}
import from jaclang.compiler.frontend.kernel_inputs {
    DeclaredDependencies,
    ImportResolution,
    KernelInputs,
    LocalResolution,
    KEY_SEP,
    NpmAnswer,
    PythonInterface,
    local_key,
    pair_key,
    resolution_key
}
import from jaclang.compiler.frontend.source_layout {
    annex_files_of,
    base_file_of,
    is_annex_path_of,
    list_directory,
    package_init_of,
    path_facts_of
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { package_owned }
import from jaclang.compiler.driver.session_compile { SessionHooks, compile_in_session }
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis, analyze_module }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.types.stubcat.reader { StubCatalog, open_catalog_region }
import from jaclang.compiler.types.stubcat.resolver { CatalogResolver }
import from jaclang.compiler.types.stubcat.modiface { iface_module, open_module_iface }
import from jaclang.compiler.types.types { ClassDetailsShared, ClassType, TypeBase }
import from jaclang.compiler.frontend.unitree { Module, UniScopeNode }
import from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }
import type from jaclang.compiler.types.ct_value { CtEnvironment }
import type from jaclang.compiler.passes.annex_weave { WovenAnnex }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.ifacecache { IfaceRegistry }
import type from jaclang.compiler.driver.nativecache { NativeUnitRegistry }

glob _CATALOGS: dict[str, StubCatalog] = {};

class HostOnlyError(RuntimeError) {}

enum HostEventKind { NOTE = 1, COVERAGE = 2, COLLECT = 3 }

obj HostEvent {
    has kind: HostEventKind,
        path: str = "",
        text: str = "",
        code: str = "",
        detail: str = "";
}

obj HostCensus {
    has trace: bool = False,
        entry_path: str = "",
        sessions: int = 0,
        snapshot_seconds: float = 0.0,
        scanned_modules: int = 0,
        calls: dict[str, int] = {},
        misses: dict[str, int] = {},
        miss_keys: list[str] = [],
        delegated: dict[str, int] = {},
        buffered: dict[str, int] = {};

    def count(method: str) {
        if self.trace {
            sys.stderr.write(f"[kernel host] {method}\n");
            sys.stderr.flush();
        }
        self.calls[method] = self.calls.get(method, 0) + 1;
    }

    def miss(method: str, key: str) {
        self.misses[method] = self.misses.get(method, 0) + 1;
        self.miss_keys.append(method + ": " + key.replace(KEY_SEP, " | "));
    }

    def delegate(method: str) {
        self.delegated[method] = self.delegated.get(method, 0) + 1;
    }

    def buffer(method: str) {
        self.buffered[method] = self.buffered.get(method, 0) + 1;
    }

    def total_misses -> int {
        return sum(self.misses.values());
    }

    def merge(other: HostCensus) {
        self.sessions += other.sessions;
        self.snapshot_seconds += other.snapshot_seconds;
        self.scanned_modules += other.scanned_modules;
        for (name, n) in other.calls.items() {
            self.calls[name] = self.calls.get(name, 0) + n;
        }
        for (name, n) in other.misses.items() {
            self.misses[name] = self.misses.get(name, 0) + n;
        }
        for key in other.miss_keys {
            self.miss_keys.append(
                f"[{other.entry_path}] {key}" if other.entry_path else key
            );
        }
        for (name, n) in other.delegated.items() {
            self.delegated[name] = self.delegated.get(name, 0) + n;
        }
        for (name, n) in other.buffered.items() {
            self.buffered[name] = self.buffered.get(name, 0) + n;
        }
    }

    def summary -> str {
        lines = [
            f"kernel host census: {self.sessions} session(s), "
            f"{sum(self.calls.values())} calls, {self.total_misses()} misses; "
            f"snapshots scanned {self.scanned_modules} modules in "
            f"{self.snapshot_seconds:.2f}s"
        ];
        for name in sorted(self.calls) {
            tags: list[str] = [];
            if name in self.misses {
                tags.append(f"{self.misses[name]} missed");
            }
            if name in self.delegated {
                tags.append(f"{self.delegated[name]} to host");
            }
            if name in self.buffered {
                tags.append(f"{self.buffered[name]} buffered");
            }
            suffix = f" ({', '.join(tags)})" if tags else "";
            lines.append(f"  {name}: {self.calls[name]}{suffix}");
        }
        for key in self.miss_keys {
            lines.append(f"  miss {key}");
        }
        return "\n".join(lines);
    }
}

obj HostTurn {
    has host: HostServices,
        previous: (HostServices | None) = None;

    def __enter__ -> HostServices {
        self.previous = active_host();
        install_host(self.host);
        return self.host;
    }

    def __exit__(exc_type: any, exc: any, trace: any) -> bool {
        if self.previous is not None {
            install_host(self.previous);
        }
        return False;
    }
}

obj KernelSession(SessionHooks) {
    has host: KernelHost,
        closure: (CompileOptions | None) = None;

    def closure_options -> (CompileOptions | None) {
        return self.closure;
    }

    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module {
        host = self.host;
        if host.fallback is None {
            host.census.count("run_module");
            task = analyze_module(target_program, file_path, options, use_str);
            host.analyses[os.path.realpath(file_path)] = task;
            return task.module;
        }
        with host.delegating("run_module") as fallback {
            answer = fallback.run_module_pipeline(
                target_program, file_path, use_str, options
            );
        }
        return answer;
    }
}

obj ProgramResolver(CatalogResolver) {
    has program: JacProgram;

    def resolve_module(path: str) -> (Module | None) {
        if not path {
            return None;
        }
        resolved = os.path.realpath(path);
        if not resolved.endswith(".pyi") {
            found = self.program.find_module(resolved);
            if found is not None {
                return found;
            }
        }
        try {
            return self.program.load_dependency_module(resolved);
        } except Exception {
            return None;
        }
    }

    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> (ClassDetailsShared | None) {
        mod = self.resolve_module(module_path);
        if mod is None or not dotted {
            return None;
        }
        parts = dotted.split(".");
        scope: (UniScopeNode | None) = mod;
        for part in parts[:-1] {
            if scope is None {
                return None;
            }
            scope = scope.find_scope(part);
        }
        if scope is None {
            return None;
        }
        sym = scope.names_in_scope.get(parts[-1]);
        if sym is None {
            return None;
        }
        resolved_type: (TypeBase | None) = None;
        try {
            provider = sym.provider;
            if provider is not None {
                resolved_type = provider.resolve_type(sym);
            } else {
                resolved_type = self.program.get_type_evaluator().get_type_of_symbol(
                    sym
                );
            }
        } except Exception {
            return None;
        }
        if isinstance(resolved_type, ClassType) {
            return resolved_type._shared;
        }
        return None;
    }
}

obj ServedInterface {
    has catalog: StubCatalog,
        module: Module;
}

obj KernelHost(HostServices) {
    has inputs: KernelInputs,
        fallback: (HostServices | None) = None,
        closure: (CompileOptions | None) = None,
        census: HostCensus = HostCensus(),
        events: list[HostEvent] = [],
        demoted: dict[str, NativeVerdict] = {},
        _imports: dict[str, ImportResolution] = {},
        _locals: dict[str, LocalResolution] = {},
        _npm: dict[str, NpmAnswer] = {},
        _declared: dict[str, DeclaredDependencies] = {},
        _python: dict[str, PythonInterface] = {},
        _served: dict[str, ServedInterface] = {},
        _catalog: (StubCatalog | None) = None,
        analyses: dict[str, ModuleAnalysis] = {},
        _session: (KernelSession | None) = None;

    def postinit {
        for resolution in self.inputs.imports {
            self._imports[resolution.key()] = resolution;
        }
        for local in self.inputs.local_imports {
            self._locals[local.key()] = local;
        }
        for answer in self.inputs.npm {
            self._npm[answer.key()] = answer;
        }
        for declared in self.inputs.declared {
            self._declared[declared.key()] = declared;
        }
        for iface in self.inputs.python_ifaces {
            self._python[os.path.realpath(iface.path)] = iface;
        }
        self._session = KernelSession(host=self, closure=self.closure);
    }

    def host(method: str = "") -> HostServices {
        if self.fallback is None {
            raise HostOnlyError(
                f"the kernel host has no host to answer {method or 'a question'} "
                "outside its inputs"
            );
        }
        return self.fallback;
    }

    def in_kernel -> bool {
        return self.fallback is None;
    }

    def kernel_only(method: str) -> bool {
        if self.fallback is not None {
            return False;
        }
        self.census.count(method);
        return True;
    }

    def open_stub_catalog -> (StubCatalog | None) {
        if self._catalog is not None {
            return self._catalog;
        }
        inputs = self.inputs;
        if not inputs.stub_catalog_active or not inputs.stub_catalog_file {
            return None;
        }
        key = f"{inputs.stub_catalog_file}:{inputs.stub_catalog_offset}:{inputs.stub_catalog_length}";
        found = _CATALOGS.get(key);
        if found is None {
            found = open_catalog_region(
                inputs.stub_catalog_file,
                inputs.stub_catalog_offset,
                inputs.stub_catalog_length,
                inputs.stub_catalog_dir
            );
            if found is None {
                return None;
            }
            _CATALOGS.clear();
            _CATALOGS[key] = found;
        }
        self._catalog = found;
        return found;
    }

    def python_module(program: JacProgram, file_path: str) -> (Module | None) {
        resolved = os.path.realpath(file_path);
        served = self._served.get(resolved);
        if served is not None {
            return served.module;
        }
        iface = self._python.get(resolved);
        if iface is None {
            return None;
        }
        self.census.count("python_interface");
        catalog = open_module_iface(
            iface.data, iface.pkg_dir, resolver=ProgramResolver(program=program)
        );
        if catalog is None {
            return None;
        }
        mod = iface_module(catalog);
        if mod is None {
            return None;
        }
        self._served[resolved] = ServedInterface(catalog=catalog, module=mod);
        program.stamp_app_facts(mod);
        return mod;
    }

    def host_turn(method: str = "") -> HostTurn {
        return HostTurn(host=self.host(method));
    }

    def missing(method: str, key: str) -> HostTurn {
        self.census.miss(method, key);
        return self.host_turn(method);
    }

    def delegating(method: str) -> HostTurn {
        self.census.count(method);
        self.census.delegate(method);
        return self.host_turn(method);
    }

    def buffer(event: HostEvent, method: str) {
        self.census.count(method);
        self.census.buffer(method);
        self.events.append(event);
    }

    def replay(target: HostServices) {
        pending = list(self.events);
        self.events.clear();
        for event in pending {
            replay_event(target, event);
        }
    }

    @contextmanager
    def session -> Iterator[None] {
        self.census.count("session");
        yield ;
    }

    def project_defaults -> (ProjectDefaults | None) {
        self.census.count("project_defaults");
        return self.inputs.project_defaults;
    }

    def check_settings(target_app: str) -> CheckSettings {
        self.census.count("check_settings");
        found = self.inputs.check_settings.get(target_app);
        if found is not None {
            return found;
        }
        with self.missing("check_settings", target_app) as host {
            answer = host.check_settings(target_app);
        }
        self.inputs.check_settings[target_app] = answer;
        return answer;
    }

    def project_facts(path: str) -> (ProjectFacts | None) {
        self.census.count("project_facts");
        if path in self.inputs.facts_of {
            owner_root = self.inputs.facts_of[path];
            return self.inputs.project_facts.get(owner_root) if owner_root else None;
        }
        with self.missing("project_facts", path) as host {
            answer = host.project_facts(path);
        }
        owner_root = answer.project_root if answer is not None else "";
        self.inputs.facts_of[path] = owner_root;
        if answer is not None {
            self.inputs.project_facts[owner_root] = answer;
        }
        return answer;
    }

    def lint_settings(path: str) -> LintSettings {
        self.census.count("lint_settings");
        found = self.inputs.lint_of.get(path);
        if found is not None {
            return found;
        }
        with self.missing("lint_settings", path) as host {
            answer = host.lint_settings(path);
        }
        self.inputs.lint_of[path] = answer;
        return answer;
    }

    def workspace(path: str) -> (WorkspaceSpec | None) {
        self.census.count("workspace");
        if not path {
            return None;
        }
        if path in self.inputs.workspace_of {
            owner_root = self.inputs.workspace_of[path];
            return self.inputs.workspaces.get(owner_root) if owner_root else None;
        }
        with self.missing("workspace", path) as host {
            answer = host.workspace(path);
        }
        owner_root = answer.project_root if answer is not None else "";
        self.inputs.workspace_of[path] = owner_root;
        if answer is not None {
            self.inputs.workspaces[owner_root] = answer;
        }
        return answer;
    }

    def app_for_path(path: str) -> (AppSpec | None) {
        self.census.count("app_for_path");
        if path in self.inputs.app_of and path in self.inputs.workspace_of {
            name = self.inputs.app_of[path];
            ws = self.inputs.workspaces.get(self.inputs.workspace_of[path]);
            return ws.apps.get(name) if (ws is not None and name) else None;
        }
        with self.missing("app_for_path", path) as host {
            answer = host.app_for_path(path);
        }
        self.inputs.app_of[path] = answer.name if answer is not None else "";
        if path not in self.inputs.workspace_of {
            with self.host_turn() as host {
                ws = host.workspace(path);
            }
            owner_root = ws.project_root if ws is not None else "";
            self.inputs.workspace_of[path] = owner_root;
            if ws is not None {
                self.inputs.workspaces[owner_root] = ws;
            }
        }
        return answer;
    }

    def project_root(path: str) -> (str | None) {
        self.census.count("project_root");
        if path in self.inputs.project_root_of {
            return self.inputs.project_root_of[path] or None;
        }
        with self.missing("project_root", path) as host {
            answer = host.project_root(path);
        }
        self.inputs.project_root_of[path] = answer or "";
        return answer;
    }

    def resolve_module(
        target: str, base_path: str, string_spec: bool = False
    ) -> tuple[str, str] {
        self.census.count("resolve_module");
        key = resolution_key(target, base_path, string_spec);
        found = self._imports.get(key);
        if found is not None {
            return (found.path, found.language);
        }
        with self.missing("resolve_module", key) as host {
            (path, language) = host.resolve_module(
                target, base_path, string_spec=string_spec
            );
        }
        resolution = ImportResolution(
            target=target,
            base_path=base_path,
            string_spec=string_spec,
            path=path,
            language=language
        );
        self._imports[key] = resolution;
        self.inputs.imports.append(resolution);
        return (path, language);
    }

    def resolve_local_module(base: str, parts: list[str]) -> (tuple[str, str] | None) {
        self.census.count("resolve_local_module");
        key = local_key(base, parts);
        found = self._locals.get(key);
        if found is None {
            found = self.learn_local_module(base, parts, key);
        }
        if not found.found {
            return None;
        }
        return (found.path, found.language);
    }

    def learn_local_module(base: str, parts: list[str], key: str) -> LocalResolution {
        with self.missing("resolve_local_module", key) as host {
            answer = host.resolve_local_module(base, parts);
        }
        local = LocalResolution(base=base, parts=list(parts));
        if answer is not None {
            local.found = True;
            local.path = answer[0];
            local.language = answer[1];
        }
        self._locals[key] = local;
        self.inputs.local_imports.append(local);
        return local;
    }

    def jac_virtual_module_path(target: str) -> (str | None) {
        self.census.count("jac_virtual_module_path");
        if target in self.inputs.virtual_modules {
            return self.inputs.virtual_modules[target] or None;
        }
        with self.missing("jac_virtual_module_path", target) as host {
            answer = host.jac_virtual_module_path(target);
        }
        self.inputs.virtual_modules[target] = answer or "";
        return answer;
    }

    def is_path_alias(target: str, base_path: str) -> bool {
        self.census.count("is_path_alias");
        key = pair_key(target, base_path);
        if key in self.inputs.path_aliases {
            return self.inputs.path_aliases[key];
        }
        with self.missing("is_path_alias", key) as host {
            answer = host.is_path_alias(target, base_path);
        }
        self.inputs.path_aliases[key] = answer;
        return answer;
    }

    def is_untyped_third_party(path: str) -> bool {
        self.census.count("is_untyped_third_party");
        if not path.endswith(".py") {
            return False;
        }
        if path in self.inputs.untyped {
            return self.inputs.untyped[path];
        }
        with self.missing("is_untyped_third_party", path) as host {
            answer = host.is_untyped_third_party(path);
        }
        self.inputs.untyped[path] = answer;
        return answer;
    }

    def in_typeshed_tree(path: str) -> bool {
        self.census.count("in_typeshed_tree");
        return "/vendor/typeshed/" in path.replace("\\", "/");
    }

    def sibling_declaration(js_path: str) -> (str | None) {
        self.census.count("sibling_declaration");
        if js_path in self.inputs.siblings {
            return self.inputs.siblings[js_path] or None;
        }
        with self.missing("sibling_declaration", js_path) as host {
            answer = host.sibling_declaration(js_path);
        }
        self.inputs.siblings[js_path] = answer or "";
        return answer;
    }

    def npm_answer(spec: str, base_path: str, method: str) -> NpmAnswer {
        key = pair_key(spec, base_path);
        found = self._npm.get(key);
        if found is not None {
            return found;
        }
        with self.missing(method, key) as host {
            installed = host.has_npm_package(spec, base_path);
        }
        answer = NpmAnswer(spec=spec, base_path=base_path, installed=installed);
        self._npm[key] = answer;
        self.inputs.npm.append(answer);
        return answer;
    }

    def has_npm_package(spec: str, base_path: str) -> bool {
        self.census.count("has_npm_package");
        return self.npm_answer(spec, base_path, "has_npm_package").installed;
    }

    def resolve_npm_package(spec: str, base_path: str) -> (str | None) {
        self.census.count("resolve_npm_package");
        answer = self.npm_answer(spec, base_path, "resolve_npm_package");
        if not answer.entry_known {
            with self.missing(
                "resolve_npm_package", pair_key(spec, base_path)
            ) as host {
                answer.package_entry = host.resolve_npm_package(spec, base_path);
            }
            answer.entry_known = True;
        }
        return answer.package_entry;
    }

    def npm_declarations(spec: str, base_path: str) -> (str | None) {
        self.census.count("npm_declarations");
        answer = self.npm_answer(spec, base_path, "npm_declarations");
        if not answer.declarations_known {
            with self.missing("npm_declarations", pair_key(spec, base_path)) as host {
                answer.declarations = host.npm_declarations(spec, base_path);
            }
            answer.declarations_known = True;
        }
        return answer.declarations;
    }

    def declared_dependencies(
        module_path: str, fallback_app: str
    ) -> (list[str] | None) {
        self.census.count("declared_dependencies");
        key = pair_key(module_path, fallback_app);
        found = self._declared.get(key);
        if found is not None {
            return list(found.names) if found.names is not None else None;
        }
        with self.missing("declared_dependencies", key) as host {
            answer = host.declared_dependencies(module_path, fallback_app);
        }
        declared = DeclaredDependencies(
            module_path=module_path,
            fallback_app=fallback_app,
            names=list(answer) if answer is not None else None
        );
        self._declared[key] = declared;
        self.inputs.declared.append(declared);
        return answer;
    }

    def note(message: str, style: str = "dim") {
        self.buffer(
            HostEvent(kind=HostEventKind.NOTE, text=message, code=style), "note"
        );
    }

    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
        if self.kernel_only("stub_catalog_for") {
            return self.open_stub_catalog();
        }
        with self.delegating("stub_catalog_for") as host {
            answer = host.stub_catalog_for(program);
        }
        return answer;
    }

    def parse_python(
        source_str: str, file_path: str, program: JacProgram
    ) -> tuple[Module, bool] {
        if self.in_kernel() {
            self.census.miss("parse_python", file_path);
            raise HostOnlyError(f"{file_path}: Python sources are parsed by the host");
        }
        with self.delegating("parse_python") as host {
            answer = host.parse_python(source_str, file_path, program);
        }
        return answer;
    }

    def ct_environment -> CtEnvironment {
        self.census.count("ct_environment");
        return self.inputs.ct_environment;
    }

    def path_facts(path: str) -> PathFacts {
        self.census.count("path_facts");
        return path_facts_of(self.inputs.layout, path);
    }

    def host_platform -> HostPlatform {
        self.census.count("host_platform");
        return self.inputs.host_platform;
    }

    def read_source(path: str) -> str {
        self.census.count("read_source");
        text = read_utf8_source(path);
        if text is not None {
            return text;
        }
        with self.missing("read_source", path) as host {
            answer = host.read_source(path);
        }
        return answer;
    }

    def annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
        self.census.count("annex_files");
        return annex_files_of(self.inputs.layout, path, suffix, list_directory);
    }

    def base_file(annex_path: str) -> (str | None) {
        self.census.count("base_file");
        return base_file_of(self.inputs.layout, annex_path);
    }

    def is_annex_path_of(candidate: str, base: str) -> bool {
        self.census.count("is_annex_path_of");
        return is_annex_path_of(self.inputs.layout, candidate, base);
    }

    def package_init(directory: str) -> (str | None) {
        self.census.count("package_init");
        return package_init_of(self.inputs.layout, directory);
    }

    def wiring_file(path: str) -> (str | None) {
        import from jaclang.compiler.driver.wiring { arch_file_for, is_arch_file }
        self.census.count("wiring_file");
        if is_arch_file(path) {
            return None;
        }
        return arch_file_for(path);
    }

    def is_seed_source(rel_path: str) -> bool {
        self.census.count("is_seed_source");
        return self.inputs.manifest.is_seed(rel_path);
    }

    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = ""
    ) -> (tuple[Module, bool] | None) {
        if self.kernel_only("native_parse") {
            return None;
        }
        with self.delegating("native_parse") as host {
            answer = host.native_parse(
                source_str, file_path, program, annexes, early_context
            );
        }
        return answer;
    }

    def drop_python_lane_products(path: str, program: JacProgram) {
        if self.kernel_only("drop_python_lane_products") {
            return;
        }
        with self.delegating("drop_python_lane_products") as host {
            host.drop_python_lane_products(path, program);
        }
    }

    def compiler_for(program: JacProgram) -> JacCompiler {
        with self.delegating("compiler_for") as host {
            answer = host.compiler_for(program);
        }
        return answer;
    }

    def iface_registry_for(program: JacProgram) -> IfaceRegistry {
        with self.delegating("iface_registry_for") as host {
            answer = host.iface_registry_for(program);
        }
        return answer;
    }

    def native_units_for(program: JacProgram) -> NativeUnitRegistry {
        with self.delegating("native_units_for") as host {
            answer = host.native_units_for(program);
        }
        return answer;
    }

    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None) {
        self.census.count("native_session_declares");
        if not self.inputs.native_session_active {
            return None;
        }
        with self.missing(
            "native_session_declares", pair_key(source, element)
        ) as host {
            answer = host.native_session_declares(program, source, element);
        }
        return answer;
    }

    def native_session_active(program: JacProgram) -> bool {
        if self.kernel_only("native_session_active") {
            return False;
        }
        with self.delegating("native_session_active") as host {
            answer = host.native_session_active(program);
        }
        return answer;
    }

    def native_verdict(
        path: str, program: (JacProgram | None) = None
    ) -> (NativeVerdict | None) {
        self.census.count("native_verdict");
        recorded = self.demoted.get(os.path.realpath(path));
        if recorded is not None {
            return recorded;
        }
        if path in self.inputs.verdicts {
            return self.inputs.verdicts[path];
        }
        with self.missing("native_verdict", path) as host {
            answer = host.native_verdict(path, program);
        }
        self.inputs.verdicts[path] = answer;
        return answer;
    }

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    ) {
        self.buffer(
            HostEvent(
                kind=HostEventKind.COVERAGE,
                path=path,
                text=outcome,
                code=code,
                detail=detail
            ),
            "record_native_coverage"
        );
    }

    def record_native_verdict(program: JacProgram, path: str, code: str, detail: str) {
        self.demoted[os.path.realpath(path)] = NativeVerdict(
            demoted=True, code=code, detail=detail
        );
        if self.kernel_only("record_native_verdict") {
            return;
        }
        with self.delegating("record_native_verdict") as host {
            host.record_native_verdict(program, path, code, detail);
        }
    }

    def format_file(file_path: str, auto_lint: bool = False) -> JacProgram {
        with self.delegating("format_file") as host {
            answer = host.format_file(file_path, auto_lint);
        }
        return answer;
    }

    def format_source(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        with self.delegating("format_source") as host {
            answer = host.format_source(source_str, file_path, auto_lint);
        }
        return answer;
    }

    def lint_file(file_path: str) -> JacProgram {
        with self.delegating("lint_file") as host {
            answer = host.lint_file(file_path);
        }
        return answer;
    }

    def native_pipeline_available -> tuple[bool, str] {
        self.census.count("native_pipeline_available");
        if self.inputs.native_pipeline_known {
            return (self.inputs.native_pipeline, self.inputs.native_pipeline_reason);
        }
        with self.missing("native_pipeline_available", "") as host {
            (available, reason) = host.native_pipeline_available();
        }
        self.inputs.native_pipeline = available;
        self.inputs.native_pipeline_reason = reason;
        self.inputs.native_pipeline_known = True;
        return (available, reason);
    }

    def compile_module(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module {
        if self.in_kernel() {
            served = self.python_module(program, file_path);
            if served is not None {
                self.census.count("compile_module");
                return served;
            }
        }
        if program.internal or package_owned(file_path, program, options) {
            if self.in_kernel() {
                self.census.miss("compile_module", file_path);
            }
            with self.delegating("compile_module") as host {
                answer = host.compile_module(program, file_path, use_str, options);
            }
            return answer;
        }
        self.census.count("compile_module");
        assert self._session is not None;
        return compile_in_session(self._session, file_path, program, use_str, options);
    }

    def build_module(
        program: JacProgram, file_path: str, use_str: (str | None)
    ) -> Module {
        self.census.count("build_module");
        return self.compile_module(program, file_path, use_str, CompileOptions());
    }

    def internal_program(program: JacProgram) -> (JacProgram | None) {
        if self.kernel_only("internal_program") {
            return None;
        }
        with self.delegating("internal_program") as host {
            answer = host.internal_program(program);
        }
        return answer;
    }

    def bind_context_program(context_root: JacProgram, program: JacProgram) {
        if self.kernel_only("bind_context_program") {
            return;
        }
        with self.delegating("bind_context_program") as host {
            host.bind_context_program(context_root, program);
        }
    }

    def note_program_dependency(program: JacProgram, resolved_path: str) {
        if self.kernel_only("note_program_dependency") {
            return;
        }
        with self.delegating("note_program_dependency") as host {
            host.note_program_dependency(program, resolved_path);
        }
    }

    def forget_program_products(program: JacProgram, resolved_path: str) {
        if self.kernel_only("forget_program_products") {
            return;
        }
        with self.delegating("forget_program_products") as host {
            host.forget_program_products(program, resolved_path);
        }
    }

    def release_program_products(program: JacProgram, retain_stubs: bool) {
        if self.kernel_only("release_program_products") {
            return;
        }
        with self.delegating("release_program_products") as host {
            host.release_program_products(program, retain_stubs);
        }
    }

    def prepare_interface(program: JacProgram, path: str, module: Module) -> bool {
        if self.kernel_only("prepare_interface") {
            return False;
        }
        with self.delegating("prepare_interface") as host {
            answer = host.prepare_interface(program, path, module);
        }
        return answer;
    }

    def collect_released_memory {
        self.buffer(HostEvent(kind=HostEventKind.COLLECT), "collect_released_memory");
    }

    def load_modules(names: list[str]) {
        self.census.count("load_modules");
    }

    def module_in_flight(names: list[str]) -> str {
        self.census.count("module_in_flight");
        return "";
    }

    def import_in_flight(path: str) -> bool {
        self.census.count("import_in_flight");
        return False;
    }

    def has_active_stub_catalog -> bool {
        self.census.count("has_active_stub_catalog");
        return self.inputs.stub_catalog_active;
    }

    def is_native_only_source(rel: str) -> bool {
        self.census.count("is_native_only_source");
        return self.inputs.manifest.is_native_only(rel);
    }

    def is_native_lowered_source(rel: str) -> bool {
        self.census.count("is_native_lowered_source");
        return self.inputs.manifest.is_native_lowered(rel);
    }

    def host_side -> HostServices {
        return self.fallback if self.fallback is not None else self;
    }

    def default_target_triple -> str {
        self.census.count("default_target_triple");
        if self.inputs.target_triple_known {
            return self.inputs.target_triple;
        }
        with self.missing("default_target_triple", "") as host {
            answer = host.default_target_triple();
        }
        self.inputs.target_triple = answer;
        self.inputs.target_triple_known = True;
        return answer;
    }
}

def read_utf8_source(path: str) -> (str | None) {
    with open(path, "rb") as f {
        data = f.read();
    }
    if data.startswith(b"\xef\xbb\xbf") {
        data = data[3:];
    }
    try {
        text = data.decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    if "\r" in text {
        text = text.replace("\r\n", "\n").replace("\r", "\n");
    }
    return text;
}

def replay_event(target: HostServices, event: HostEvent) {
    if event.kind == HostEventKind.NOTE {
        target.note(event.text, event.code);
    } elif event.kind == HostEventKind.COVERAGE {
        target.record_native_coverage(event.path, event.text, event.code, event.detail);
    } elif event.kind == HostEventKind.COLLECT {
        target.collect_released_memory();
    }
}
