import os;
import time;
import from jaclang.compiler.driver.jir {
    DepRow,
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
    read_native_dep_hashes,
    read_section_bytes,
    write_module_cache
}

glob DIAG_SCHEMA: int = 1,
     IFACE_RETAIN_CAP: int = 1024,
     _SYMTAB_PROVIDES_MEMO: list = [],
     _CODEC_MODULES: tuple = (
         "jaclang.compiler.types.type_evaluator",
         "jaclang.compiler.types.stubcat.reader",
         "jaclang.compiler.types.stubcat.writer",
         "jaclang.compiler.types.stubcat.modiface"
     ),
     _CODEC_MEMO: list = [];

obj IfaceCodec {
    has build_module_iface: any,
        open_module_iface: any,
        read_iface_hash: any,
        iface_module: any;
}

def iface_codec -> (IfaceCodec | None) {
    if _CODEC_MEMO {
        return _CODEC_MEMO[0];
    }
    import sys;
    for name in _CODEC_MODULES {
        mod = sys.modules.get(name);
        if mod is None {
            return None;
        }
        spec = mod?.__spec__;
        if spec is not None and bool(getattr(spec, "_initializing", False)) {
            return None;
        }
    }
    modiface = sys.modules[_CODEC_MODULES[-1]];
    try {
        codec = IfaceCodec(
            build_module_iface=modiface.build_module_iface,
            open_module_iface=modiface.open_module_iface,
            read_iface_hash=modiface.read_iface_hash,
            iface_module=modiface.iface_module
        );
    } except AttributeError {
        return None;
    }
    _CODEC_MEMO.append(codec);
    return codec;
}

def iface_verify_enabled -> bool {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    return os.environ.get('JAC_IFACE_VERIFY', '') in truthy;
}

def _symtab_provides -> set[str] {
    if not _SYMTAB_PROVIDES_MEMO {
        import from jaclang.compiler.driver.schedules {
            get_symtab_ir_sched,
            providers_of
        }
        _SYMTAB_PROVIDES_MEMO.append(set(providers_of(get_symtab_ir_sched())));
    }
    return set(_SYMTAB_PROVIDES_MEMO[0]);
}

def _span_record(span: any) -> list {
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

def _span_from_record(rec: list) -> any {
    import from jaclang.compiler.frontend.srcloc { Span }
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

def _alert_record(alert: any) -> dict {
    related: list = [];
    for (label, span) in (alert.related or []) {
        related.append([label, _span_record(span)]);
    }
    return {
        "msg": alert.msg,
        "code": alert.code.code if alert.code is not None else None,
        "help": alert.help_text,
        "span": _span_record(alert.loc),
        "related": related
    };
}

def _alert_from_record(rec: dict) -> any {
    import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
    import from jaclang.compiler.passes.transform { Alert, Transform }
    code_str: str = str(rec.get("code") or "");
    code = DIAGNOSTICS.get(code_str) if code_str else None;
    related: list = [];
    for pair in (rec.get("related") or []) {
        related.append((pair[0], _span_from_record(list(pair[1])), ));
    }
    span_rec: list = list(rec.get("span") or []);
    help_val: any = rec.get("help");
    return Alert(
        msg=str(rec.get("msg", "")),
        loc=_span_from_record(span_rec),
        from_pass=Transform,
        code=code,
        related=related,
        help_text=help_val if isinstance(help_val, str) else None
    );
}

obj IfaceEntry {
    has path: str,
        digest: str,
        section: (bytes | None) = None,
        placement: (bytes | None) = None,
        diags: (bytes | None) = None,
        catalog: any = None,
        module: any = None,
        stamp: float = 0.0,
        replayed_token: int = -1;
}

obj IfaceRegistry {
    has prog: any,
        entries: dict[str, IfaceEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        frames: list[str] postinit,
        direct_deps: dict[str, dict[str, str]] = {},
        _iface_bytes: dict[str, tuple[str, bytes, str]] = {},
        verifying: bool = False,
        closure_token: int = 0,
        _pkg_dir_memo: str = "";

    def postinit {
        self.building = set();
        self.checking = set();
        self.frames = [];
    }

    def on_closure_release {
        self.closure_token += 1;
        for ent in self.entries.values() {
            ent.module = None;
            ent.catalog = None;
        }
        cap = IFACE_RETAIN_CAP;
        if len(self._iface_bytes) > cap {
            stale = list(self._iface_bytes.keys())[:len(self._iface_bytes) - cap];
            for key in stale {
                del self._iface_bytes[key];
            }
        }
        if len(self.entries) > cap {
            doomed: list[str] = [];
            excess = len(self.entries) - cap;
            for key in self.entries.keys() {
                if len(doomed) >= excess {
                    break;
                }
                doomed.append(key);
            }
            for key in doomed {
                del self.entries[key];
            }
        }
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
    }

    def _pkg_dir -> str {
        if not self._pkg_dir_memo {
            import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
            self._pkg_dir_memo = jaclang_pkg_dir();
        }
        return self._pkg_dir_memo;
    }

    def forget(resolved_path: str) {
        real = os.path.realpath(resolved_path);
        if real in self.entries {
            del self.entries[real];
        }
        if real in self.direct_deps {
            del self.direct_deps[real];
        }
        if real in self._iface_bytes {
            del self._iface_bytes[real];
        }
    }

    def clear {
        self.entries.clear();
        self.direct_deps.clear();
        self._iface_bytes.clear();
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
                import from jaclang.compiler.driver.jir { compute_stub_module_key }
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

    def _client_edges(mod: any) -> set[str] {
        import jaclang.compiler.frontend.unitree as uni;
        import from jaclang.compiler.frontend.constant { CodeContext }
        out: set[str] = set();
        try {
            for imp in mod.get_all_sub_nodes(uni.Import) {
                if imp.from_loc is None or imp.is_virtual_jac {
                    continue;
                }
                if imp.code_context != CodeContext.CLIENT {
                    continue;
                }
                try {
                    target = imp.from_loc.resolve_relative_path();
                } except Exception {
                    continue;
                }
                if isinstance(target, str) and target.endswith(".jac") {
                    out.add(os.path.realpath(target));
                }
            }
        } except Exception {}
        return out;
    }

    """The dependency rows of one importer.

    The native column is filled from the program's native unit registry for
    every dependency that is a native unit with a record in hand; a direct
    native edge the IR generator reported (`native_edges`) joins the rows even
    when the type-interface layer never noted it, so the link plan can walk
    `SEC_DEPS` native edges alone.
    """
    def dep_rows(
        resolved_path: str, mod: any, native_edges: (list[str] | None) = None
    ) -> list[DepRow] {
        bucket = self.direct_deps.get(resolved_path, {});
        client = self._client_edges(mod) if mod is not None else set();
        natives = self.prog.native_units();
        out: list[DepRow] = [];
        seen: set[str] = set();
        edges: set[str] = set(os.path.realpath(e) for e in (native_edges or []));
        for (path, digest) in bucket.items() {
            seen.add(path);
            flags = "c" if path in client else "";
            ndigest = natives.known_digest(path);
            if path in edges {
                flags += "n";
            }
            out.append(
                DepRow(path=path, digest=digest, flags=flags, native_digest=ndigest)
            );
        }
        for path in sorted(edges) {
            if path in seen {
                continue;
            }
            out.append(
                DepRow(
                    path=path,
                    digest="",
                    flags="n",
                    native_digest=natives.known_digest(path)
                )
            );
        }
        return out;
    }

    def _entry_fresh(ent: IfaceEntry) -> bool {
        import from jaclang.compiler.driver.bccache { discover_annex_files }
        try {
            if os.path.getmtime(ent.path) > ent.stamp {
                return False;
            }
            for related in discover_annex_files(ent.path) {
                if os.path.getmtime(related) > ent.stamp {
                    return False;
                }
            }
            return True;
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
            stamp=time.time()
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

    def _module_jir(resolved: str) -> (tuple[bytes, str] | None) {
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
        codec = iface_codec();
        found = self._module_jir(resolved);
        if codec is None or found is None {
            return None;
        }
        (data, base_dir) = found;
        section = read_section_bytes(data, SEC_IFACE);
        digest = codec.read_iface_hash(section);
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

    """Freshness of the native side of an entry: every recorded native digest
    must equal the dependency's current one, recursively through the native
    unit registry's `ensure`."""
    def _ndeps_match(data: bytes, base_dir: str = "") -> bool {
        natives = self.prog.native_units();
        for (dep, recorded) in read_native_dep_hashes(data, base_dir) {
            ent = natives.ensure(dep, compile_on_miss=False);
            if ent is None or ent.digest != recorded {
                return False;
            }
        }
        return True;
    }

    def _deps_match(data: bytes, base_dir: str = "") -> bool {
        import from jaclang.compiler.driver.jir { read_dep_rows }
        for row in read_dep_rows(data, base_dir) {
            (dep, recorded) = (row.path, row.digest);
            if not recorded {
                if "n" in row.flags {
                    continue;
                }
                return False;
            }
            if is_stub_like_path(dep) {
                try {
                    import from jaclang.compiler.driver.jir { compute_stub_module_key }
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

    def ensure(path: str, compile_on_miss: bool = True) -> (IfaceEntry | None) {
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
            import from jaclang.compiler.driver.compile_options { CompileOptions }
            self.prog.compile(
                resolved,
                options=CompileOptions(no_cgen=True, symtab_ir_only=True, iface_ok=True)
            );
        } except Exception {} finally {
            self.building.discard(resolved);
        }
        return self.entries.get(resolved);
    }

    def _materialize(ent: IfaceEntry) -> any {
        if ent.module is not None {
            return ent.module;
        }
        if ent.section is None {
            return None;
        }
        codec = iface_codec();
        if codec is None {
            return None;
        }
        catalog = codec.open_module_iface(ent.section, self._pkg_dir(), resolver=self);
        if catalog is None {
            return None;
        }
        mod = codec.iface_module(catalog);
        if mod is None {
            return None;
        }
        ent.catalog = catalog;
        ent.module = mod;
        return mod;
    }

    def _restore_placement(ent: IfaceEntry) {
        if ent.placement is None {
            return;
        }
        try {
            import from jaclang.compiler.placement.placement {
                summary_from_bytes,
                summary_store
            }
            restored = summary_from_bytes(ent.placement);
            if restored is not None {
                summary_store(self.prog)[os.path.abspath(ent.path)] = restored;
            }
        } except Exception {}
    }

    def _prepare(ent: IfaceEntry, mod: any) {
        self._restore_placement(ent);
        self.prog.analysis.analyses_run.mark(mod, _symtab_provides());
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

    def _replay_records(prof: dict, err0: int, warn0: int) {
        def key_of(alert: any) -> tuple {
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
        live_errs = {key_of(a) for a in self.prog.errors_had[err0:]};
        live_warns = {key_of(a) for a in self.prog.warnings_had[warn0:]};
        for rec in (prof.get("errors") or []) {
            if rec_key(rec) in live_errs {
                continue;
            }
            self.prog.errors_had.append(_alert_from_record(rec));
        }
        for rec in (prof.get("warnings") or []) {
            if rec_key(rec) in live_warns {
                continue;
            }
            self.prog.warnings_had.append(_alert_from_record(rec));
        }
    }

    def eligible(compiler: any, resolved: str, options: any) -> bool {
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
        return iface_codec() is not None;
    }

    def serve(compiler: any, resolved: str, options: any) -> any {
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

    def _serve_symtab(resolved: str, profile_key: (str | None)) -> any {
        err0 = len(self.prog.errors_had);
        warn0 = len(self.prog.warnings_had);
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
            self._replay_records(prof, err0, warn0);
            ent.replayed_token = self.closure_token;
        }
        self._event("dep_hydrate");
        if self.verifying is False and iface_verify_enabled() {
            self._verify_iface(resolved, ent);
        }
        return mod;
    }

    def _serve_analysis(compiler: any, resolved: str, options: any) -> any {
        err0 = len(self.prog.errors_had);
        warn0 = len(self.prog.warnings_had);
        codec = iface_codec();
        found = self._module_jir(resolved);
        if codec is None or found is None {
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
        digest = codec.read_iface_hash(section);
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
        self._replay_records(prof, err0, warn0);
        ent.replayed_token = self.closure_token;
        self._event("analysis_replay");
        if self.verifying is False and iface_verify_enabled() {
            self._verify_analysis(resolved, options, prof);
        }
        return mod;
    }

    def analysis_profile(options: any) -> str {
        import hashlib;
        import json;
        import from jaclang.compiler.driver.pass_driver { diagnostic_policy_for }
        config: any = None;
        try {
            import from jaclang.project.config { get_config }
            config = get_config();
        } except Exception {
            config = None;
        }
        pol = diagnostic_policy_for(config, list(options.suppress_codes or []));
        ident = json.dumps(
            {
                "no_cgen": bool(options.no_cgen),
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

    def _ensure_flow_graph(mod: any) -> None {
        if getattr(mod, "stub_only", False)
            or getattr(mod, "is_raised_from_py", False) {
            return;
        }
        ledger = self.prog.analysis.analyses_run;
        if ledger.provides(mod, "CfgSucc") {
            return;
        }
        import from jaclang.compiler.driver.pass_driver { run_pass }
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        run_pass(CFGBuildPass, mod, self.prog);
        for tag in CFGBuildPass.PROVIDES {
            ledger.provided(mod).add(tag);
        }
        self._event("iface_cfg");
    }

    def _encode_iface(codec: IfaceCodec, mod: any) -> (bytes | None) {
        import from jaclang.compiler.types.stubcat.modiface { IncoherentInterface }
        self._event("iface_encode");
        self._ensure_flow_graph(mod);
        try {
            return codec.build_module_iface(
                mod, self.prog.get_type_evaluator(), self._pkg_dir()
            );
        } except IncoherentInterface {
            self._event("iface_incoherent");
            return None;
        }
    }

    def persist_after_compile(
        resolved: str, mod: any, options: any, err_start: int, warn_start: int
    ) -> None {
        import json;
        if mod is None or mod.parse_failed {
            return;
        }
        codec = iface_codec();
        if codec is None {
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
        frontier = self._closure_is_frontier(options);
        memo = self._iface_bytes.get(resolved);
        payload: (bytes | None) = None;
        if inferred or not frontier {
            digest = self._disk_iface_digest(resolved);
        } elif modkey and memo is not None and memo[0] == modkey {
            payload = memo[1];
            digest = memo[2];
        } else {
            encoded = self._encode_iface(codec, mod);
            if encoded is None {
                return;
            }
            payload = encoded;
            digest = codec.read_iface_hash(encoded) or "";
            if modkey {
                self._iface_bytes[resolved] = (modkey, encoded, digest, );
            }
        }
        if payload is not None {
            sections[SEC_IFACE] = payload;
        }
        sections[SEC_DEPS] = deps_section(
            self.dep_rows(resolved, mod, list(mod.gen.native_deps or []))
        );
        try {
            import from jaclang.compiler.placement.placement {
                get_module_summary,
                summary_to_bytes
            }
            sections[SEC_PLACEMENT] = summary_to_bytes(
                get_module_summary(mod, self.prog)
            );
        } except Exception {}
        if mod.ct_file_deps {
            sections[SEC_CTDEPS] = ct_deps_section(mod.ct_file_deps, mod.ct_body_deps);
        }
        if not options.symtab_ir_only {
            try {
                import from jaclang.compiler.driver.jir { SEC_INTEROP }
                interop_dict = self.prog._get_compiler()._build_interop_dict(mod);
                sections[SEC_INTEROP] = json.dumps(interop_dict).encode("utf-8");
            } except Exception {}
        }
        if options.no_cgen {
            profiles = self._existing_profiles(resolved);
            errors: list = [];
            for alert in self.prog.errors_had[err_start:] {
                errors.append(_alert_record(alert));
            }
            warnings: list = [];
            for alert in self.prog.warnings_had[warn_start:] {
                warnings.append(_alert_record(alert));
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

    def _closure_is_frontier(options: any) -> bool {
        root_opts: any = None;
        try {
            root_opts = self.prog._get_compiler()._closure_opts;
        } except Exception {
            root_opts = None;
        }
        if root_opts is None {
            root_opts = options;
        }
        return bool(root_opts.no_cgen or root_opts.symtab_ir_only);
    }

    def _disk_iface_digest(resolved: str) -> str {
        codec = iface_codec();
        found = self._module_jir(resolved);
        if codec is None or found is None {
            return "";
        }
        return codec.read_iface_hash(read_section_bytes(found[0], SEC_IFACE)) or "";
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
        import from jaclang.compiler.driver.jir { SEC_INTEROP }
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
                manifest = self.prog._get_compiler()._deserialize_interop_table(
                    interop
                );
            } except Exception {
                return None;
            }
            import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
            carrier = self.prog.hub.artifacts.get(resolved);
            if carrier is None {
                carrier = CodeGenTarget();
                self.prog.hub.artifacts[resolved] = carrier;
            }
            carrier.interop_manifest = manifest;
        }
        edges: list[str] = [];
        import from jaclang.compiler.driver.jir { read_dep_rows }
        for row in read_dep_rows(data, base_dir) {
            if "c" in row.flags {
                edges.append(row.path);
            }
        }
        self._event("boundary_facts");
        return edges;
    }

    def resolve_module(path: str) -> any {
        if not path {
            return None;
        }
        resolved = os.path.realpath(path);
        if not is_stub_like_path(resolved) {
            found = self.prog.find_module(resolved);
            if found is not None {
                return found;
            }
        }
        try {
            return self.prog.load_dependency_module(resolved);
        } except Exception {
            return None;
        }
    }

    def resolve_shared(module_path: str, dotted: str, class_name: str) -> any {
        mod = self.resolve_module(module_path);
        if mod is None or not dotted {
            return None;
        }
        parts = dotted.split(".");
        scope: any = mod;
        for part in parts[:-1] {
            scope = scope.find_scope(part);
            if scope is None {
                return None;
            }
        }
        sym = scope.names_in_scope.get(parts[-1]);
        if sym is None {
            return None;
        }
        resolved_type: any = None;
        provider = sym.provider;
        try {
            if provider is not None {
                resolved_type = provider.resolve_type(None, sym);
            } else {
                resolved_type = self.prog.get_type_evaluator().get_type_of_symbol(sym);
            }
        } except Exception {
            return None;
        }
        shared = resolved_type?._shared;
        if shared is not None {
            return shared;
        }
        return None;
    }

    def _fresh_verify_program -> any {
        import from jaclang.compiler.driver.program { JacProgram }
        return JacProgram();
    }

    def _verify_iface(resolved: str, ent: IfaceEntry) -> None {
        self.verifying = True;
        try {
            import from jaclang.compiler.driver.compile_options { CompileOptions }
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
            codec = iface_codec();
            assert codec is not None;
            fresh_digest = codec.read_iface_hash(
                codec.build_module_iface(
                    fresh, prog2.get_type_evaluator(), self._pkg_dir()
                )
            )
                or "";
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

    def _verify_analysis(resolved: str, options: any, prof: dict) {
        self.verifying = True;
        try {
            import from jaclang.compiler.driver.compile_options { CompileOptions }
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

            def digestible(alert: any) -> tuple {
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
            fresh_errs = sorted(digestible(a) for a in prog2.errors_had);
            fresh_warns = sorted(digestible(a) for a in prog2.warnings_had);
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
}

def seed_dep_edges(prog: any, root_dir: str, limit: int = 5000) -> int {
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
                cache_path = get_module_cache_path(full);
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
