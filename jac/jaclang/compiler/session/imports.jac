import type from jaclang.compiler.session.compiler { JacCompiler }
import from jaclang.compiler.session.options { CompileOptions }
import type from jaclang.project.config { JacConfig }
import from jaclang.compiler.frontend.source_locations { Span }
import from jaclang.compiler.pipeline.pass_base { Alert }
import from jaclang.compiler.session.cache.keys { module_revision }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.session.cache.interop_codec { decode_interop_record }
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.cache.catalog_reader {
    CatalogResolver,
    StubCatalog
}
import from jaclang.compiler.ir.schema { UniScopeNode }
import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, ClassType }
import from jaclang.compiler.session.cache.interface_codec {
    open_module_iface,
    read_iface_hash,
    iface_module
}
import type from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
import from contextlib { contextmanager }
import from collections.abc { Iterator }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }
import os;
import time;
import from jaclang.compiler.session.cache.artifact_codec {
    SEC_CTDEPS,
    SEC_DEPS,
    SEC_DIAG,
    SEC_IFACE,
    SEC_PLACEMENT,
    cache_mode,
    ct_deps_section,
    deps_section,
    get_module_cache_path,
    is_compiler_tree_path,
    is_module_cache_valid,
    is_stub_like_path,
    jir_cacheable_source_path,
    module_cache_key,
    read_dep_hashes,
    read_section_bytes,
    write_module_cache
}

glob DIAG_SCHEMA: int = 2,
     _SYMTAB_PROVIDES_MEMO: list = [];

def iface_verify_enabled -> bool {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    return os.environ.get('JAC_IFACE_VERIFY', '') in truthy;
}

def _symtab_provides -> set[AnalysisFact] {
    if not _SYMTAB_PROVIDES_MEMO {
        import from jaclang.compiler.pipeline.schedule {
            get_symtab_ir_sched,
            providers_of
        }
        _SYMTAB_PROVIDES_MEMO.append(set(providers_of(get_symtab_ir_sched())));
    }
    return set(_SYMTAB_PROVIDES_MEMO[0]);
}

def _span_record(span: Span) -> list {
    return [
        span.mod_path,
        span.first_line,
        span.last_line,
        span.col_start,
        span.col_end,
        span.pos_start,
        span.pos_end,
        span.src_window,
        span.window_offset,
        span.window_line
    ];
}

def _span_from_record(rec: list) -> Span {
    import from jaclang.compiler.frontend.source_locations { Span }
    return Span(
        mod_path=rec[0],
        first_line=rec[1],
        last_line=rec[2],
        col_start=rec[3],
        col_end=rec[4],
        pos_start=rec[5],
        pos_end=rec[6],
        src_window=rec[7],
        window_offset=rec[8],
        window_line=rec[9]
    );
}

def _alert_record(alert: Alert) -> dict {
    related: list = [];
    for (label, span) in (alert.related or []) {
        related.append([label, _span_record(span)]);
    }
    return {
        "msg": alert.msg,
        "owner": alert.owner,
        "code": alert.code.code if alert.code is not None else None,
        "help": alert.help_text,
        "span": _span_record(alert.loc),
        "related": related
    };
}

def _alert_from_record(rec: dict) -> Alert {
    import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
    import from jaclang.compiler.pipeline.pass_base { Alert, Transform }
    code_str: str = str(rec.get("code") or "");
    code = DIAGNOSTICS.get(code_str) if code_str else None;
    related: list = [];
    for pair in (rec.get("related") or []) {
        related.append((pair[0], _span_from_record(list(pair[1])), ));
    }
    span_rec: list = list(rec.get("span") or []);
    help_val: object = rec.get("help");
    return Alert(
        msg=str(rec.get("msg", "")),
        loc=_span_from_record(span_rec),
        from_pass=Transform,
        code=code,
        related=related,
        owner=str(rec.get("owner") or ""),
        help_text=help_val if isinstance(help_val, str) else None
    );
}

obj IfaceEntry {
    has path: str,
        digest: str,
        section: (bytes | None) = None,
        placement: (bytes | None) = None,
        diags: (bytes | None) = None,
        catalog: StubCatalog | None = None,
        module: Module | None = None,
        revision: str = "",
        replayed_token: int = -1;
}

obj InterfaceSnapshot {
    has cache_key: str,
        section: bytes,
        digest: str,
        dependency_section: bytes;
}

obj IfaceRegistry(CatalogResolver) {
    has prog: JacProgram,
        entries: dict[str, IfaceEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        frames: list[str] postinit,
        direct_deps: dict[str, dict[str, str]] = {},
        _interfaces: dict[str, InterfaceSnapshot] = {},
        _incoherent: set[str] = set(),
        verifying: bool = False,
        closure_token: int = 0,
        package_directory_memo: str = "";

    def postinit {
        self.building = set();
        self.checking = set();
        self.frames = [];
    }

    def on_closure_release {
        self.closure_token += 1;
        self.clear();
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
    }

    def package_directory -> str {
        if not self.package_directory_memo {
            import from jaclang.compiler.session.cache.catalog_paths { jaclang_pkg_dir }
            self.package_directory_memo = jaclang_pkg_dir();
        }
        return self.package_directory_memo;
    }

    def forget(resolved_path: str) {
        real = os.path.realpath(resolved_path);
        self._incoherent.discard(real);
        if real in self.entries {
            del self.entries[real];
        }
        if real in self.direct_deps {
            del self.direct_deps[real];
        }
        if real in self._interfaces {
            del self._interfaces[real];
        }
    }

    def clear {
        self._incoherent.clear();
        self.entries.clear();
        self.direct_deps.clear();
        self._interfaces.clear();
        self.building.clear();
        self.checking.clear();
        self.frames.clear();
    }

    def frame_push(resolved_path: str) {
        self.frames.append(resolved_path);
        self.direct_deps[resolved_path] = {};
    }

    def frame_pop {
        if self.frames {
            self.frames.pop();
        }
    }

    def note_dep(dep_path: str) {
        if not self.frames {
            return;
        }
        importer = self.frames[-1];
        real = os.path.realpath(dep_path);

        if real == importer or is_compiler_tree_path(real) {
            return;
        }
        if not jir_cacheable_source_path(real) {
            return;
        }
        digest = "";
        if is_stub_like_path(real) {
            try {
                import from jaclang.compiler.session.cache.artifact_codec {
                    compute_stub_module_key
                }
                digest = compute_stub_module_key(real);
            } except Exception {
                digest = "";
            }
        } else {
            ent = self.entries.get(real);
            digest = ent.digest if ent is not None else "";
        }
        bucket = self.direct_deps.get(importer);
        if bucket is None {
            bucket = {};
            self.direct_deps[importer] = bucket;
        }
        bucket[real] = digest;
    }

    def dep_rows(resolved_path: str) -> list[tuple[str, str, str]] {
        bucket = self.direct_deps.get(resolved_path, {});
        import from jaclang.compiler.ir.enums { CodeContext }
        flags: dict[str, set[str]] = {};
        for edge in self.prog.deps.imports.get(resolved_path, []) {
            flags.setdefault(edge.target, set()).add(
                ('c' if edge.context == CodeContext.CLIENT else '')
                    + ('n' if edge.context == CodeContext.NATIVE else '')
                    + ('j' if edge.jac else '')
                    + ('t' if edge.top_level else '')
                    + ('k' if edge.is_comptime else '')
                    + ('m' if edge.from_import else '')
            );
        }
        out: list[tuple[str, str, str]] = [];
        for (path, digest) in bucket.items() {
            for role in sorted(flags.get(path, {''})) {
                out.append((path, digest, role));
            }
        }
        return out;
    }

    def _entry_fresh(ent: IfaceEntry) -> bool {
        try {
            return module_revision(ent.path) == ent.revision;
        } except OSError {
            return False;
        }
    }

    def _register(
        resolved: str,
        digest: str,
        section: (bytes | None),
        placement: (bytes | None),
        diags: (bytes | None) = None,
        remember: bool = True
    ) -> IfaceEntry {
        ent = IfaceEntry(
            path=resolved,
            digest=digest,
            section=section,
            placement=placement,
            diags=diags,
            revision=module_revision(resolved)
        );
        prev = self.entries.get(resolved);
        if prev is not None and prev.digest == digest {
            ent.module = prev.module;
            ent.catalog = prev.catalog;
            ent.replayed_token = prev.replayed_token;
        }
        if remember {
            self.entries[resolved] = ent;
        }
        return ent;
    }

    @contextmanager
    def _compilation_scope -> Iterator[None] {
        import from jaclang.compiler.session.context {
            compilation_scope,
            context_identity
        }
        identity = ''
            if self.prog.is_bootstrap()
            else self.prog.context_key or context_identity(self.prog.options);
        with compilation_scope(identity, self.prog.options, self.prog) {
            yield ;
        }
    }

    def _module_jir(resolved: str) -> tuple[bytes, str] | None {
        with self._compilation_scope() {
            return self._module_jir_in_context(resolved);
        }
    }

    def ensure(path: str, compile_on_miss: bool = True) -> IfaceEntry | None {
        with self._compilation_scope() {
            return self._ensure_in_context(path, compile_on_miss);
        }
    }

    def serve(
        compiler: JacCompiler, resolved: str, options: CompileOptions
    ) -> Module | None {
        with self._compilation_scope() {
            return self._serve_in_context(compiler, resolved, options);
        }
    }

    def persist_after_compile(
        resolved: str,
        mod: Module,
        options: CompileOptions,
        err_start: int,
        warn_start: int
    ) {
        with self._compilation_scope() {
            self._persist_in_context(resolved, mod, options, err_start, warn_start);
        }
    }

    def _module_jir_in_context(resolved: str) -> (tuple[bytes, str] | None) {
        try {
            cache_path = get_module_cache_path(resolved);
            if is_module_cache_valid(resolved, cache_path) {
                return (cache_path.read_bytes(), "", );
            }
        } except Exception {}
        try {
            return self.prog._get_compiler()._sealed_jir_data(resolved);
        } except Exception {
            return None;
        }
    }

    def _register_from_disk(resolved: str, check_deps: bool) -> (IfaceEntry | None) {
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        section = read_section_bytes(data, SEC_IFACE);
        digest = read_iface_hash(section);
        if digest is None {
            return None;
        }
        if check_deps and not self._deps_match(data, base_dir) {
            return None;
        }
        return self._register(
            resolved,
            digest,
            section,
            read_section_bytes(data, SEC_PLACEMENT),
            diags=read_section_bytes(data, SEC_DIAG),
            remember=check_deps
        );
    }

    def _deps_match(data: bytes, base_dir: str = "") -> bool {
        for (dep, recorded) in read_dep_hashes(data, base_dir) {
            if not recorded {
                return False;
            }
            if is_stub_like_path(dep) {
                try {
                    import from jaclang.compiler.session.cache.artifact_codec {
                        compute_stub_module_key
                    }
                    if compute_stub_module_key(dep) != recorded {
                        return False;
                    }
                } except Exception {
                    return False;
                }
                continue;
            }
            ent = self.ensure(dep);
            if ent is None or ent.digest != recorded {
                return False;
            }
        }
        return True;
    }

    def _ensure_in_context(
        path: str, compile_on_miss: bool = True
    ) -> (IfaceEntry | None) {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None and self._entry_fresh(ent) {
            return ent;
        }
        if ent is not None {
            del self.entries[resolved];
        }
        if resolved in self.building or resolved in self.checking {
            return self._register_from_disk(resolved, check_deps=False);
        }
        (rebuild, _) = cache_mode();
        if not rebuild {
            self.checking.add(resolved);
            try {
                found = self._register_from_disk(resolved, check_deps=True);
            } finally {
                self.checking.discard(resolved);
            }
            if found is not None {
                return found;
            }
        }
        if (
            not compile_on_miss
            or not jir_cacheable_source_path(resolved)
            or is_stub_like_path(resolved)
        ) {
            return None;
        }
        if not os.path.isfile(resolved) {
            return None;
        }
        self.building.add(resolved);
        try {
            self._event("dep_miss_compile");
            import from jaclang.compiler.session.options { CompileOptions }
            before_errors = len(self.prog.errors_had);
            before_warnings = len(self.prog.warnings_had);
            options = self.prog.options.for_symbols();
            options.force_target_program = True;
            module = self.prog.compile(resolved, options=options);
            import from jaclang.compiler.pipeline.products { require_product }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            if require_product(self.prog, module, CompilationProduct.INTERFACE) {
                self.persist_after_compile(
                    resolved, module, options, before_errors, before_warnings
                );
            }
        } except Exception {} finally {
            self.building.discard(resolved);
        }
        return self.entries.get(resolved);
    }

    def _materialize(ent: IfaceEntry) -> Module | None {
        if ent.module is not None {
            return ent.module;
        }
        if ent.section is None {
            return None;
        }
        catalog = ent.catalog;
        if catalog is None {
            catalog = open_module_iface(
                ent.section, self.package_directory(), resolver=self
            );
        }
        if catalog is None {
            return None;
        }
        ent.catalog = catalog;
        import from jaclang.compiler.ir.identity { MutationScope }
        with MutationScope(self.prog.analysis.mutations, 7) {
            mod = iface_module(catalog);
        }
        if mod is None {
            return None;
        }
        ent.catalog = catalog;
        ent.module = mod;
        found = self._module_jir(ent.path);
        if found is not None {
            import from jaclang.compiler.session.cache.artifact_codec { read_dep_rows }
            self.prog.deps.restore_imports(ent.path, read_dep_rows(found[0], found[1]));
        }
        return mod;
    }

    def _restore_placement(ent: IfaceEntry) {
        if ent.placement is None {
            return;
        }
        try {
            import from jaclang.compiler.analysis.placement.summary {
                summary_from_bytes
            }
            import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
            restored = summary_from_bytes(ent.placement);
            if restored is not None {
                self.prog.analysis.publish(ent.path, PLACEMENT_SUMMARY, restored);
            }
        } except Exception {}
    }

    def _prepare(ent: IfaceEntry, mod: Module) {
        import from jaclang.compiler.pipeline.executor { run_utility }
        import from jaclang.compiler.pipeline.contracts { UtilityProduct }
        run_utility(UtilityProduct.INTERFACE_CONTEXT, mod, self.prog);
        self._restore_placement(ent);
        self.prog.analysis.mark(mod, _symtab_provides());
    }

    def _profiles_of(diag_bytes: (bytes | None)) -> (dict | None) {
        import json;
        if diag_bytes is None {
            return None;
        }
        try {
            payload = json.loads(diag_bytes.decode("utf-8"));
        } except Exception {
            return None;
        }
        if payload.get("schema") != DIAG_SCHEMA {
            return None;
        }
        return payload.get("profiles", {}) or {};
    }

    def _replay_records(prof: dict) {
        def key_of(alert: Alert) -> tuple {
            return (
                alert.loc.mod_path,
                alert.loc.first_line,
                alert.loc.col_start,
                alert.code.code if alert.code is not None else None,
                alert.msg
            );
        }

        def rec_key(rec: dict) -> tuple {
            span = rec.get("span") or ["", 0, 0, 0];
            return (span[0], span[1], span[3], rec.get("code"), rec.get("msg", ""));
        }
        live_errs = {key_of(a) for a in self.prog.errors_had};
        live_warns = {key_of(a) for a in self.prog.warnings_had};
        for rec in (prof.get("errors") or []) {
            if rec_key(rec) in live_errs {
                continue;
            }
            self.prog.errors_had.append(_alert_from_record(rec));
            live_errs.add(rec_key(rec));
        }
        for rec in (prof.get("warnings") or []) {
            if rec_key(rec) in live_warns {
                continue;
            }
            self.prog.warnings_had.append(_alert_from_record(rec));
            live_warns.add(rec_key(rec));
        }
    }

    def eligible(
        compiler: JacCompiler, resolved: str, options: CompileOptions
    ) -> bool {
        if options.aot_mode
            or bool(options.force_codespace)
            or bool(options.default_codespace) {
            return False;
        }
        if not jir_cacheable_source_path(resolved) or is_stub_like_path(resolved) {
            return False;
        }
        if compiler.stub_catalog_disabled {
            return False;
        }
        return True;
    }

    def ready -> bool {
        return True;
    }

    def _serve_in_context(
        compiler: JacCompiler, resolved: str, options: CompileOptions
    ) -> Module | None {
        if not options.iface_ok or options.need_full_ast or not self.ready() {
            return None;
        }
        if resolved in self.building {
            return None;
        }
        (rebuild, _) = cache_mode();
        if rebuild {
            return None;
        }
        if resolved in self.prog.mod.hub and self.prog.is_hub_entry_fresh(resolved) {
            return None;
        }
        if options.symtab_ir_only {
            return self._serve_symtab(resolved, self.analysis_profile(options));
        }
        if options.no_cgen {
            return self._serve_analysis(compiler, resolved, options);
        }
        return None;
    }

    def _serve_symtab(resolved: str, profile_key: (str | None)) -> Module | None {
        ent = self.ensure(resolved, compile_on_miss=False);
        if ent is None {
            return None;
        }
        prof: (dict | None) = None;
        if profile_key is not None {
            profiles = self._profiles_of(ent.diags);
            prof = profiles.get(profile_key) if profiles is not None else None;
            if prof is None {
                self._event("dep_profile_miss");
                return None;
            }
            if prof.get("errors") {
                self._event("dep_error_profile");
                return None;
            }
        }
        mod = self._materialize(ent);
        if mod is None {
            return None;
        }
        self._prepare(ent, mod);
        if prof is not None and ent.replayed_token != self.closure_token {
            self._replay_records(prof);
            ent.replayed_token = self.closure_token;
        }
        self._event("dep_hydrate");
        if self.verifying is False and iface_verify_enabled() {
            self._verify_iface(resolved, ent);
        }
        return mod;
    }

    def _serve_analysis(
        compiler: JacCompiler, resolved: str, options: CompileOptions
    ) -> Module | None {
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        profiles = self._profiles_of(read_section_bytes(data, SEC_DIAG));
        if profiles is None {
            return None;
        }
        prof = profiles.get(self.analysis_profile(options));
        if prof is None {
            self._event("replay_profile_miss");
            return None;
        }
        if prof.get("errors") {
            self._event("replay_error_profile");
            if self.verifying is False and iface_verify_enabled() {
                raise RuntimeError(
                    f"analysis cache for {resolved} carries error records; a "
                    "failed analysis is never persisted, so this cache entry is "
                    "corrupted or predates that policy"
                );
            }
            return None;
        }
        if not self._deps_match(data, base_dir) {
            self._event("replay_dep_miss");
            return None;
        }
        section = read_section_bytes(data, SEC_IFACE);
        digest = read_iface_hash(section);
        if digest is None {
            return None;
        }
        ent = self._register(
            resolved,
            digest,
            section,
            read_section_bytes(data, SEC_PLACEMENT),
            diags=read_section_bytes(data, SEC_DIAG)
        );
        mod = self._materialize(ent);
        if mod is None {
            return None;
        }
        self._prepare(ent, mod);
        self._replay_records(prof);
        self.direct_deps[resolved] = dict(read_dep_hashes(data, base_dir));
        ent.replayed_token = self.closure_token;
        self._event("analysis_replay");
        if self.verifying is False and iface_verify_enabled() {
            self._verify_analysis(resolved, options, prof);
        }
        return mod;
    }

    def analysis_profile(options: CompileOptions) -> str {
        import hashlib;
        import json;
        import from jaclang.compiler.session.diagnostics {
            config_for_app,
            diagnostic_policy_for
        }
        config: JacConfig | None = None;
        try {
            import from jaclang.project.config { get_config }
            config = get_config();
        } except Exception {
            config = None;
        }
        config = config_for_app(config, getattr(options, 'target_app', '') or '');
        pol = diagnostic_policy_for(config, list(options.suppress_codes or []));
        ident = json.dumps(
            {
                "no_cgen": bool(options.no_cgen),
                "app": str(getattr(options, "target_app", "") or ""),
                "app_kind": str(getattr(options, "app_kind", "") or ""),
                "symtab": bool(options.symtab_ir_only),
                "native_parity": bool(options.native_parity),
                "suppress": sorted(pol.suppress_codes),
                "categories": sorted(pol.suppress_categories),
                "lint": [
                    bool(pol.lint_active),
                    sorted(pol.lint_select),
                    sorted(pol.lint_ignore)
                ]
            },
            sort_keys=True
        );
        return hashlib.sha256(ident.encode()).hexdigest()[:16];
    }

    def _persist_in_context(
        resolved: str,
        mod: Module,
        options: CompileOptions,
        err_start: int,
        warn_start: int
    ) -> None {
        import json;

        if mod is None or mod.parse_failed or resolved in self._incoherent {
            return;
        }
        sections: dict[int, bytes] = {};
        modkey = "";
        try {
            modkey = module_cache_key(resolved);
        } except Exception {
            modkey = "";
        }
        inferred = bool(getattr(mod, "codespace_inferred", False));
        memo = self._interfaces.get(resolved);
        payload: (bytes | None) = None;
        if inferred {
            digest = self._disk_iface_digest(resolved);
        } elif modkey and memo is not None and memo.cache_key == modkey {
            payload = memo.section;
            digest = memo.digest;
            sections[SEC_DEPS] = memo.dependency_section;
        } else {
            digest = self._disk_iface_digest(resolved);
        }
        if payload is not None {
            sections[SEC_IFACE] = payload;
        }
        if not digest {
            sections[SEC_DEPS] = deps_section(self.dep_rows(resolved));
        }
        try {
            import from jaclang.compiler.analysis.placement.summary { summary_to_bytes }
            summary = self.prog.analysis.lookup(mod.loc.mod_path, PLACEMENT_SUMMARY);
            if summary is not None {
                sections[SEC_PLACEMENT] = summary_to_bytes(summary);
            }
        } except Exception {}
        if mod.ct_file_deps {
            sections[SEC_CTDEPS] = ct_deps_section(mod.ct_file_deps, mod.ct_body_deps);
        }
        if not options.symtab_ir_only {
            try {
                import from jaclang.compiler.session.cache.artifact_codec {
                    SEC_INTEROP
                }
                import from jaclang.compiler.session.cache.interop_codec {
                    interop_record
                }
                interop_dict = interop_record(artifact_for(mod).interop_manifest);
                sections[SEC_INTEROP] = json.dumps(interop_dict).encode("utf-8");
            } except Exception {}
        }
        if options.no_cgen {
            profiles = self._existing_profiles(resolved);
            errors: list = [];
            for alert in self.prog.errors_had[err_start:] {
                if self.prog.diags._owned(alert, resolved) {
                    errors.append(_alert_record(alert));
                }
            }
            warnings: list = [];
            for alert in self.prog.warnings_had[warn_start:] {
                if self.prog.diags._owned(alert, resolved) {
                    warnings.append(_alert_record(alert));
                }
            }
            _prof_key = self.analysis_profile(options);
            if errors {
                profiles.pop(_prof_key, None);
            } else {
                profiles[_prof_key] = {"errors": [], "warnings": warnings};
            }
            sections[SEC_DIAG] = json.dumps(
                {"schema": DIAG_SCHEMA, "profiles": profiles}
            ).encode(
                "utf-8"
            );
        }
        if write_module_cache(resolved, None, extra_sections=sections) {
            self._event("iface_persist");
        }
        if payload is not None and digest {
            self._register(
                resolved,
                digest,
                sections.get(SEC_IFACE),
                sections.get(SEC_PLACEMENT),
                diags=sections.get(SEC_DIAG)
            );
        }
        if digest {
            for frame in self.frames {
                bucket = self.direct_deps.get(frame);
                if bucket is not None and resolved in bucket {
                    bucket[resolved] = digest;
                }
            }
        }
    }

    def _disk_iface_digest(resolved: str) -> str {
        found = self._module_jir(resolved);
        if found is None {
            return "";
        }
        return read_iface_hash(read_section_bytes(found[0], SEC_IFACE)) or "";
    }

    def _existing_profiles(resolved: str) -> dict {
        import json;
        found = self._module_jir(resolved);
        if found is None {
            return {};
        }
        try {
            diag_bytes = read_section_bytes(found[0], SEC_DIAG);
            if diag_bytes is None {
                return {};
            }
            payload = json.loads(diag_bytes.decode("utf-8"));
            if payload.get("schema") != DIAG_SCHEMA {
                return {};
            }
            return payload.get("profiles", {}) or {};
        } except Exception {
            return {};
        }
    }

    def client_boundary_facts(dep_path: str) -> (list[str] | None) {
        import json;
        resolved = os.path.realpath(dep_path);
        (rebuild, _) = cache_mode();
        if rebuild or not jir_cacheable_source_path(resolved) {
            return None;
        }
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        import from jaclang.compiler.session.cache.artifact_codec { SEC_INTEROP }
        interop_bytes = read_section_bytes(data, SEC_INTEROP);
        if interop_bytes is None {
            return None;
        }
        try {
            interop = json.loads(interop_bytes.decode("utf-8"));
        } except Exception {
            return None;
        }
        if interop.get("bindings") {
            try {
                manifest = decode_interop_record(interop);
            } except Exception {
                return None;
            }
            import from jaclang.compiler.backends.common.artifacts { NodeArtifacts }
            carrier = self.prog.hub.artifacts.get(resolved);
            if carrier is None {
                carrier = NodeArtifacts();
                self.prog.hub.artifacts[resolved] = carrier;
            }
            carrier.interop_manifest = manifest;
        }
        edges: list[str] = [];
        import from jaclang.compiler.session.cache.artifact_codec { read_dep_rows }
        for (dep, _digest, flags) in read_dep_rows(data, base_dir) {
            if "c" in flags {
                edges.append(dep);
            }
        }
        self._event("boundary_facts");
        return edges;
    }

    def resolve_module(path: str) -> Module | None {
        if not path {
            return None;
        }
        resolved = os.path.realpath(path);
        if is_stub_like_path(resolved) {
            catalog = self.prog.stub_catalog();
            cached_stub = catalog.module_for_path(resolved)
                if catalog is not None
                else None;
            if cached_stub is not None {
                return cached_stub;
            }
        }
        found = self.prog.find_module(resolved);
        if found is not None {
            return found;
        }
        cached = self.entries.get(resolved);
        return self._materialize(cached) if cached is not None else None;
    }

    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> ClassDetailsShared | None {
        mod = self.resolve_module(module_path);
        if mod is None or not dotted {
            return None;
        }
        parts = dotted.split(".");
        scope: UniScopeNode = mod;
        for part in parts[:-1] {
            child_scope = scope.find_scope(part);
            if child_scope is None {
                return None;
            }
            scope = child_scope;
        }
        sym = scope.names_in_scope.get(parts[-1]);
        if sym is None {
            return None;
        }

        resolved_type = sym.decl.type;
        if resolved_type is None and sym.provider is not None {
            resolved_type = sym.provider.resolve_type(sym);
        }
        if isinstance(resolved_type, ClassType) {
            return resolved_type.shared;
        }
        return None;
    }

    def _fresh_verify_program -> JacProgram {
        import from jaclang.compiler.session.session { JacProgram }
        return JacProgram();
    }

    def _verify_iface(resolved: str, ent: IfaceEntry) -> None {
        self.verifying = True;
        try {
            import from jaclang.compiler.session.options { CompileOptions }
            prog2 = self._fresh_verify_program();
            fresh = prog2.compile(
                resolved,
                options=CompileOptions(
                    symtab_ir_only=True,
                    no_cgen=True,
                    force_target_program=True,
                    need_full_ast=True
                )
            );
            served = ent.module;
            if served is None or fresh is None {
                return;
            }
            got = set(served.names_in_scope.keys());
            want = set(fresh.names_in_scope.keys());
            if got != want {
                missing = sorted(want - got);
                extra = sorted(got - want);
                raise RuntimeError(
                    f"analysis-cache verify failed for {resolved}: hydrated "
                    f"interface names diverge from source (missing={missing}, "
                    f"extra={extra})"
                );
            }
            import from jaclang.compiler.pipeline.products { require_product }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            require_product(prog2, fresh, CompilationProduct.INTERFACE);
            encoded = prog2.iface_registry()._interfaces.get(resolved);
            fresh_digest = encoded.digest if encoded is not None else '';
            if fresh_digest != ent.digest {
                raise RuntimeError(
                    f"analysis-cache verify failed for {resolved}: the served "
                    f"interface digest {ent.digest[:12]} differs from a fresh "
                    f"source compile's {fresh_digest[:12]}"
                );
            }
        } finally {
            self.verifying = False;
        }
    }

    def _verify_analysis(resolved: str, options: CompileOptions, prof: dict) {
        self.verifying = True;
        try {
            import from jaclang.compiler.session.options { CompileOptions }
            prog2 = self._fresh_verify_program();
            try {
                prog2.compile(
                    resolved,
                    options=CompileOptions(
                        no_cgen=options.no_cgen,
                        native_parity=options.native_parity,
                        force_target_program=True,
                        suppress_codes=list(options.suppress_codes or []),
                        need_full_ast=True
                    )
                );
            } except Exception {}

            def digestible(alert: Alert) -> tuple {
                return (
                    os.path.realpath(alert.loc.mod_path),
                    alert.loc.first_line,
                    alert.loc.col_start,
                    alert.code.code if alert.code is not None else None,
                    alert.msg
                );
            }

            def rec_digestible(rec: dict) -> tuple {
                span = rec.get("span") or ["", 0, 0, 0];
                return (span[0], span[1], span[3], rec.get("code"), rec.get("msg", ""));
            }
            fresh_errs = sorted(
                digestible(a)
                for a in prog2.errors_had
                if prog2.diags._owned(a, resolved)
            );
            fresh_warns = sorted(
                digestible(a)
                for a in prog2.warnings_had
                if prog2.diags._owned(a, resolved)
            );
            replay_errs = sorted(rec_digestible(r) for r in (prof.get("errors") or []));
            replay_warns = sorted(
                rec_digestible(r) for r in (prof.get("warnings") or [])
            );
            if fresh_errs != replay_errs or fresh_warns != replay_warns {
                raise RuntimeError(
                    f"analysis-cache verify failed for {resolved}: replayed "
                    f"diagnostics diverge from a fresh compile "
                    f"(replayed {len(replay_errs)}E/{len(replay_warns)}W, "
                    f"fresh {len(fresh_errs)}E/{len(fresh_warns)}W)"
                );
            }
        } finally {
            self.verifying = False;
        }
    }

    def interface_cacheable(path: str, mod: Module) -> bool {
        return not mod.parse_failed
            and not mod.codespace_inferred
            and jir_cacheable_source_path(path)
            and os.path.isfile(path);
    }

    def interface_is_current(path: str) -> bool {
        with self._compilation_scope() {
            memo = self._interfaces.get(path);
            return memo is not None and memo.cache_key == module_cache_key(path);
        }
    }

    def cached_interface(path: str) -> bytes | None {
        if not self.interface_is_current(path) {
            return None;
        }
        return self._interfaces[path].section;
    }

    def reject_interface(path: str) {
        self._incoherent.add(path);
        self._event("iface_incoherent");
    }

    def publish_interface(path: str, encoded: bytes) {
        import from jaclang.compiler.session.cache.interface_codec { read_iface_hash }
        with self._compilation_scope() {
            self._incoherent.discard(path);
            self._interfaces[path] = InterfaceSnapshot(
                cache_key=module_cache_key(path),
                section=encoded,
                digest=read_iface_hash(encoded) or '',
                dependency_section=deps_section(self.dep_rows(path))
            );
            self._event("iface_encode");
        }
    }
}

def seed_dep_edges(prog: JacProgram, root_dir: str, limit: int = 5000) -> int {
    import from jaclang.compiler.session.context { artifact_cache_path }
    seeded = 0;
    scanned = 0;
    skip_dirs = {".git", ".jac", "node_modules", "__pycache__", ".venv", "venv"};
    for (walk_dir, dirs, files) in os.walk(root_dir) {
        dirs[:] = [
            d
            for d in dirs
            if not d.startswith(".") and d not in skip_dirs
        ];
        for name in files {
            if not name.endswith(".jac") {
                continue;
            }
            scanned += 1;
            if scanned > limit {
                return seeded;
            }
            full = os.path.realpath(os.path.join(walk_dir, name));
            try {
                cache_path = artifact_cache_path(full, prog);
                if not cache_path.exists() {
                    continue;
                }
                data: bytes = cache_path.read_bytes();
            } except Exception {
                continue;
            }
            for (dep, _digest) in read_dep_hashes(data) {
                prog.deps.record(full, dep);
                seeded += 1;
            }
        }
    }
    return seeded;
}
