import os;
import sys;
import from contextlib { contextmanager }
import from jaclang.compiler.frontend.host {
    kernel_host_mode,
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
    NpmAnswer,
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
import from jaclang.compiler.driver.session_compile { SessionHooks, compile_in_session }
import from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import type from jaclang.compiler.types.ct_value { CtEnvironment }
import type from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.passes.annex_weave { WovenAnnex }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.ifacecache { IfaceRegistry }
import type from jaclang.compiler.driver.nativecache { NativeUnitRegistry }

glob _TOTALS: list[HostCensus] = [];

enum HostEventKind {
    NOTE,
    COVERAGE,
    VERDICT,
    DEPENDENCY,
    FORGET,
    RELEASE,
    COLLECT,
    DROP_PYTHON_LANE
}

obj HostEvent {
    has kind: HostEventKind,
        program: (JacProgram | None) = None,
        path: str = "",
        text: str = "",
        code: str = "",
        detail: str = "",
        flag: bool = False;
}

obj HostCensus {
    has sessions: int = 0,
        calls: dict[str, int] = {},
        misses: dict[str, int] = {},
        miss_keys: list[str] = [],
        delegated: dict[str, int] = {},
        buffered: dict[str, int] = {};

    def count(method: str) {
        self.calls[method] = self.calls.get(method, 0) + 1;
    }

    def miss(method: str, key: str) {
        self.misses[method] = self.misses.get(method, 0) + 1;
        self.miss_keys.append(f"{method}: {key}");
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
        for (name, n) in other.calls.items() {
            self.calls[name] = self.calls.get(name, 0) + n;
        }
        for (name, n) in other.misses.items() {
            self.misses[name] = self.misses.get(name, 0) + n;
        }
        self.miss_keys.extend(other.miss_keys);
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
            f"{sum(self.calls.values())} calls, {self.total_misses()} misses"
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
        import from jaclang.compiler.driver.pipeline_runner { compile_module }
        compiler = self.host.compiler_for(target_program);
        return compile_module(compiler, target_program, file_path, options, use_str);
    }
}

obj KernelHost(HostServices) {
    has inputs: KernelInputs,
        fallback: (HostServices | None) = None,
        learn: bool = False,
        closure: (CompileOptions | None) = None,
        census: HostCensus = HostCensus(),
        events: list[HostEvent] = [],
        demoted: dict[str, NativeVerdict] = {},
        _imports: dict[str, ImportResolution] = {},
        _locals: dict[str, LocalResolution] = {},
        _npm: dict[str, NpmAnswer] = {},
        _declared: dict[str, DeclaredDependencies] = {},
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
        self._session = KernelSession(host=self, closure=self.closure);
    }

    def host -> HostServices {
        if self.fallback is None {
            raise RuntimeError(
                "the kernel host has no host to answer a question outside its inputs"
            );
        }
        return self.fallback;
    }

    def missed(method: str, key: str) -> HostServices {
        self.census.miss(method, key);
        return self.host();
    }

    def delegated(method: str) -> HostServices {
        self.census.count(method);
        self.census.delegate(method);
        return self.host();
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
        answer = self.missed("check_settings", target_app).check_settings(target_app);
        if self.learn {
            self.inputs.check_settings[target_app] = answer;
        }
        return answer;
    }

    def project_facts(path: str) -> (ProjectFacts | None) {
        self.census.count("project_facts");
        if path in self.inputs.facts_of {
            owner_root = self.inputs.facts_of[path];
            return self.inputs.project_facts.get(owner_root) if owner_root else None;
        }
        answer = self.missed("project_facts", path).project_facts(path);
        if self.learn {
            owner_root = answer.project_root if answer is not None else "";
            self.inputs.facts_of[path] = owner_root;
            if answer is not None {
                self.inputs.project_facts[owner_root] = answer;
            }
        }
        return answer;
    }

    def lint_settings(path: str) -> LintSettings {
        self.census.count("lint_settings");
        found = self.inputs.lint_of.get(path);
        if found is not None {
            return found;
        }
        answer = self.missed("lint_settings", path).lint_settings(path);
        if self.learn {
            self.inputs.lint_of[path] = answer;
        }
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
        answer = self.missed("workspace", path).workspace(path);
        if self.learn {
            owner_root = answer.project_root if answer is not None else "";
            self.inputs.workspace_of[path] = owner_root;
            if answer is not None {
                self.inputs.workspaces[owner_root] = answer;
            }
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
        answer = self.missed("app_for_path", path).app_for_path(path);
        if self.learn {
            self.inputs.app_of[path] = answer.name if answer is not None else "";
            if path not in self.inputs.workspace_of {
                ws = self.host().workspace(path);
                owner_root = ws.project_root if ws is not None else "";
                self.inputs.workspace_of[path] = owner_root;
                if ws is not None {
                    self.inputs.workspaces[owner_root] = ws;
                }
            }
        }
        return answer;
    }

    def project_root(path: str) -> (str | None) {
        self.census.count("project_root");
        if path in self.inputs.project_root_of {
            return self.inputs.project_root_of[path] or None;
        }
        answer = self.missed("project_root", path).project_root(path);
        if self.learn {
            self.inputs.project_root_of[path] = answer or "";
        }
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
        (path, language) = self.missed("resolve_module", key).resolve_module(
            target, base_path, string_spec=string_spec
        );
        if self.learn {
            resolution = ImportResolution(
                target=target,
                base_path=base_path,
                string_spec=string_spec,
                path=path,
                language=language
            );
            self._imports[key] = resolution;
            self.inputs.imports.append(resolution);
        }
        return (path, language);
    }

    def resolve_local_module(base: str, parts: list[str]) -> (tuple[str, str] | None) {
        self.census.count("resolve_local_module");
        key = local_key(base, parts);
        found = self._locals.get(key);
        if found is not None {
            return (found.path, found.language) if found.found else None;
        }
        answer = self.missed("resolve_local_module", key).resolve_local_module(
            base, parts
        );
        if self.learn {
            local = LocalResolution(
                base=base,
                parts=list(parts),
                found=answer is not None,
                path=answer[0] if answer is not None else "",
                language=answer[1] if answer is not None else ""
            );
            self._locals[key] = local;
            self.inputs.local_imports.append(local);
        }
        return answer;
    }

    def is_path_alias(target: str, base_path: str) -> bool {
        self.census.count("is_path_alias");
        key = pair_key(target, base_path);
        if key in self.inputs.path_aliases {
            return self.inputs.path_aliases[key];
        }
        answer = self.missed("is_path_alias", key).is_path_alias(target, base_path);
        if self.learn {
            self.inputs.path_aliases[key] = answer;
        }
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
        answer = self.missed("is_untyped_third_party", path).is_untyped_third_party(
            path
        );
        if self.learn {
            self.inputs.untyped[path] = answer;
        }
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
        answer = self.missed("sibling_declaration", js_path).sibling_declaration(
            js_path
        );
        if self.learn {
            self.inputs.siblings[js_path] = answer or "";
        }
        return answer;
    }

    def npm_answer(spec: str, base_path: str, method: str) -> NpmAnswer {
        key = pair_key(spec, base_path);
        found = self._npm.get(key);
        if found is not None {
            return found;
        }
        host = self.missed(method, key);
        answer = NpmAnswer(
            spec=spec,
            base_path=base_path,
            installed=host.has_npm_package(spec, base_path)
        );
        if self.learn {
            self._npm[key] = answer;
            self.inputs.npm.append(answer);
        }
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
            answer.package_entry = self.missed(
                "resolve_npm_package", pair_key(spec, base_path)
            ).resolve_npm_package(
                spec, base_path
            );
            answer.entry_known = self.learn;
        }
        return answer.package_entry;
    }

    def npm_declarations(spec: str, base_path: str) -> (str | None) {
        self.census.count("npm_declarations");
        answer = self.npm_answer(spec, base_path, "npm_declarations");
        if not answer.declarations_known {
            answer.declarations = self.missed(
                "npm_declarations", pair_key(spec, base_path)
            ).npm_declarations(
                spec, base_path
            );
            answer.declarations_known = self.learn;
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
        answer = self.missed("declared_dependencies", key).declared_dependencies(
            module_path, fallback_app
        );
        if self.learn {
            declared = DeclaredDependencies(
                module_path=module_path,
                fallback_app=fallback_app,
                names=list(answer) if answer is not None else None
            );
            self._declared[key] = declared;
            self.inputs.declared.append(declared);
        }
        return answer;
    }

    def note(message: str, style: str = "dim") {
        self.buffer(
            HostEvent(kind=HostEventKind.NOTE, text=message, code=style), "note"
        );
    }

    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
        return self.delegated("stub_catalog_for").stub_catalog_for(program);
    }

    def parse_python(
        source_str: str, file_path: str, program: JacProgram
    ) -> tuple[Module, bool] {
        return self.delegated("parse_python").parse_python(
            source_str, file_path, program
        );
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
        import from jaclang.project.textio { read_file_with_encoding }
        self.census.count("read_source");
        return read_file_with_encoding(path);
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
        return self.delegated("native_parse").native_parse(
            source_str, file_path, program, annexes, early_context
        );
    }

    def drop_python_lane_products(path: str, program: JacProgram) {
        self.buffer(
            HostEvent(kind=HostEventKind.DROP_PYTHON_LANE, program=program, path=path),
            "drop_python_lane_products"
        );
    }

    def compiler_for(program: JacProgram) -> JacCompiler {
        return self.delegated("compiler_for").compiler_for(program);
    }

    def iface_registry_for(program: JacProgram) -> IfaceRegistry {
        return self.delegated("iface_registry_for").iface_registry_for(program);
    }

    def native_units_for(program: JacProgram) -> NativeUnitRegistry {
        return self.delegated("native_units_for").native_units_for(program);
    }

    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None) {
        self.census.count("native_session_declares");
        if not self.inputs.native_session_active {
            return None;
        }
        return self.missed(
            "native_session_declares", pair_key(source, element)
        ).native_session_declares(
            program, source, element
        );
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
        answer = self.missed("native_verdict", path).native_verdict(path, program);
        if self.learn {
            self.inputs.verdicts[path] = answer;
        }
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
        import from jaclang.compiler.placement.placement { note_native_verdict }
        resolved = os.path.realpath(path);
        self.demoted[resolved] = NativeVerdict(demoted=True, code=code, detail=detail);
        note_native_verdict(program, resolved, code, detail);
        self.buffer(
            HostEvent(
                kind=HostEventKind.VERDICT,
                program=program,
                path=path,
                code=code,
                detail=detail
            ),
            "record_native_verdict"
        );
    }

    def format_file(file_path: str, auto_lint: bool = False) -> JacProgram {
        return self.delegated("format_file").format_file(file_path, auto_lint);
    }

    def format_source(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        return self.delegated("format_source").format_source(
            source_str, file_path, auto_lint
        );
    }

    def lint_file(file_path: str) -> JacProgram {
        return self.delegated("lint_file").lint_file(file_path);
    }

    def native_pipeline_available -> tuple[bool, str] {
        self.census.count("native_pipeline_available");
        if self.inputs.native_pipeline_known {
            return (self.inputs.native_pipeline, self.inputs.native_pipeline_reason);
        }
        (available, reason) = self.missed(
            "native_pipeline_available", ""
        ).native_pipeline_available();
        if self.learn {
            self.inputs.native_pipeline = available;
            self.inputs.native_pipeline_reason = reason;
            self.inputs.native_pipeline_known = True;
        }
        return (available, reason);
    }

    def compile_module(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module {
        self.census.count("compile_module");
        if program.internal {
            self.census.delegate("compile_module");
            return self.host().compile_module(program, file_path, use_str, options);
        }
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
        return self.delegated("internal_program").internal_program(program);
    }

    def bind_context_program(context_root: JacProgram, program: JacProgram) {
        self.delegated("bind_context_program").bind_context_program(
            context_root, program
        );
    }

    def note_program_dependency(program: JacProgram, resolved_path: str) {
        self.buffer(
            HostEvent(
                kind=HostEventKind.DEPENDENCY, program=program, path=resolved_path
            ),
            "note_program_dependency"
        );
    }

    def forget_program_products(program: JacProgram, resolved_path: str) {
        self.buffer(
            HostEvent(kind=HostEventKind.FORGET, program=program, path=resolved_path),
            "forget_program_products"
        );
    }

    def release_program_products(program: JacProgram, retain_stubs: bool) {
        self.buffer(
            HostEvent(kind=HostEventKind.RELEASE, program=program, flag=retain_stubs),
            "release_program_products"
        );
    }

    def prepare_interface(program: JacProgram, path: str, module: Module) -> bool {
        return self.delegated("prepare_interface").prepare_interface(
            program, path, module
        );
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

    def default_target_triple -> str {
        self.census.count("default_target_triple");
        if self.inputs.target_triple_known {
            return self.inputs.target_triple;
        }
        answer = self.missed("default_target_triple", "").default_target_triple();
        if self.learn {
            self.inputs.target_triple = answer;
            self.inputs.target_triple_known = True;
        }
        return answer;
    }
}

def replay_event(target: HostServices, event: HostEvent) {
    kind = event.kind;
    if kind == HostEventKind.NOTE {
        target.note(event.text, event.code);
    } elif kind == HostEventKind.COVERAGE {
        target.record_native_coverage(event.path, event.text, event.code, event.detail);
    } elif kind == HostEventKind.VERDICT and event.program is not None {
        target.record_native_verdict(
            event.program, event.path, event.code, event.detail
        );
    } elif kind == HostEventKind.DEPENDENCY and event.program is not None {
        target.note_program_dependency(event.program, event.path);
    } elif kind == HostEventKind.FORGET and event.program is not None {
        target.forget_program_products(event.program, event.path);
    } elif kind == HostEventKind.RELEASE and event.program is not None {
        target.release_program_products(event.program, event.flag);
    } elif kind == HostEventKind.COLLECT {
        target.collect_released_memory();
    } elif kind == HostEventKind.DROP_PYTHON_LANE and event.program is not None {
        target.drop_python_lane_products(event.path, event.program);
    }
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
    kernel_census().merge(census);
    if kernel_host_mode() == "census" {
        sys.stderr.write(f"[{path}] {census.summary()}\n");
    }
}
