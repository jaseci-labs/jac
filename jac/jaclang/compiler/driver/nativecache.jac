import os;
import time;
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { NativeVerdict }
import type from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.jir {
    PRECOMPILE_SENTINEL,
    compute_content_sha256,
    NativeStamp,
    SEC_NCTDEPS,
    ct_deps_section,
    ct_dep_text_fresh,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_PLACEMENT,
    cache_mode,
    current_native_stamp,
    get_module_cache_path,
    is_module_cache_valid,
    jir_cacheable_source_path,
    module_cache_key,
    native_section_payload,
    read_native_dep_hashes,
    read_section_bytes
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.native_iface { NativeIface }

obj NativeUnitEntry {
    has path: str,
        digest: str,
        iface: NativeIface,
        stamp: NativeStamp,
        source: str = "",
        source_key: (str | None) = None,
        object_bytes: (bytes | None) = None,
        bitcode: (bytes | None) = None,
        compile_deps: bytes = b"",
        compile_deps_base: str = "",
        dep_digests: dict[str, str] = {};
}

obj NativeUnitRegistry {
    has prog: JacProgram,
        session: (NativeBuildSession | None) = None,
        _spans: list[list[float]] = [],
        slowest_codegen: list[tuple[float, str]] = [],
        entries: dict[str, NativeUnitEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        not_native: dict[str, str] = {},
        failures: dict[str, str] = {},
        compiled_paths: list[str] = [],
        verdicts: dict[str, tuple[str, NativeVerdict]] = {};

    def postinit {
        self.building = set();
        self.checking = set();
    }

    def clear {
        self.entries.clear();
        self.not_native.clear();
        self.verdicts.clear();
        self.compiled_paths.clear();
        self.failures.clear();
    }

    def release_products {
        """Between the compiles of one program the interfaces stay, each
        checked against its source key on its next use; the products and the
        per-compile bookkeeping go.""";
        for ent in self.entries.values() {
            ent.object_bytes = None;
            ent.bitcode = None;
        }
        self.failures.clear();
        self.compiled_paths.clear();
    }

    def forget(path: str) {
        real = os.path.realpath(path);
        self.entries.pop(real, None);
        self.not_native.pop(real, None);
        self.failures.pop(real, None);
    }

    def adopt_dep_digests(path: str, digests: dict[str, str]) -> bool {
        real = os.path.realpath(path);
        session = self.session;
        if session is None or real not in session.lowered {
            return False;
        }
        ent = self.entries.get(real);
        if ent is None {
            return False;
        }
        for (dep, digest) in digests.items() {
            ent.dep_digests[os.path.realpath(dep)] = digest;
        }
        self._event("native_dep_adopt");
        return True;
    }

    static def _source_key(path: str) -> (str | None) {
        import from jaclang.compiler.driver.compilation_context { cache_scope }
        import from jaclang.compiler.frontend.codeinfo {
            get_effective_default_codespace_override,
            set_effective_default_codespace
        }
        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }

        prior_codespace = get_effective_default_codespace_override();
        target_token = push_native_target('');
        try {
            set_effective_default_codespace('native');
            with cache_scope() {
                return module_cache_key(path);
            }
        } except OSError {
            return None;
        } finally {
            set_effective_default_codespace(prior_codespace);
            pop_native_target(target_token);
        }
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
    }

    def _add_time(name: str, seconds: float) {
        times = self.prog.analysis.phase_time;
        times[name] = times.get(name, 0.0) + seconds;
    }

    def _span_begin -> float {
        self._spans.append([0.0]);
        return time.perf_counter();
    }

    def _span_end(name: str, started: float) {
        total = time.perf_counter() - started;
        nested = self._spans.pop()[0] if self._spans else 0.0;
        self._add_time(name, total - nested);
        if self._spans {
            self._spans[-1][0] += total;
        }
    }

    def _span_depth -> int {
        return len(self._spans);
    }

    def _span_unwind(depth: int) {
        while len(self._spans) > depth {
            self._spans.pop();
        }
    }

    def phase_summary -> str {
        times = self.prog.analysis.phase_time;
        events = self.prog.analysis.cache_events;
        frontend = ", ".join(
            f"{phase.lower()} {times.get('NATIVE_FRONTEND_' + phase, 0.0):.1f}"
            for phase in ("PARSE", "IR", "PLACEMENT", "ANALYSIS", "BOUNDARIES")
        );
        return (
            f"  Kernel phases: analysis {times.get('NATIVE_ANALYSIS', 0.0):.1f}s "
            f"({frontend}), lowering {times.get('NATIVE_LOWER', 0.0):.1f}s, "
            f"optimize {times.get('NATIVE_OPTIMIZE', 0.0):.1f}s, "
            f"emit {times.get('NATIVE_EMIT', 0.0):.1f}s, "
            f"settle {times.get('NATIVE_SETTLE', 0.0):.1f}s, "
            f"persist {times.get('NATIVE_PERSIST', 0.0):.1f}s; "
            f"units analysed/lowered/optimized/emitted "
            f"{events.get('native_unit_analysis', 0)}/"
            f"{events.get('native_unit_lower', 0)}/"
            f"{events.get('native_unit_codegen', 0)}/"
            f"{events.get('native_object_emit', 0)}; "
            f"interface hits {events.get('native_iface_hit', 0)}, "
            f"dependency misses {events.get('native_dep_miss', 0)}"
            + self._slowest_summary()
        );
    }

    def _slowest_summary -> str {
        if not self.slowest_codegen {
            return "";
        }
        parts = [
            f"{os.path.basename(path)} {seconds:.1f}s"
            for (seconds, path) in self.slowest_codegen
        ];
        return "; slowest codegen " + ", ".join(parts);
    }

    def note_codegen(path: str, object_emitted: bool = True) {
        self.compiled_paths.append(os.path.realpath(path));
        self._event("native_unit_codegen");
        if object_emitted {
            self._event("native_object_emit");
        }
    }

    def note_link(reused: bool) {
        self._event("native_link_hit" if reused else "native_link");
    }

    def _options -> CompileOptions {
        opts = self.prog.options;
        return opts if opts is not None else CompileOptions();
    }

    def stamp_for(
        options: (CompileOptions | None) = None, path: str = ""
    ) -> NativeStamp {
        opts = options if options is not None else self._options();
        return current_native_stamp(
            opts.unit_codegen_identity(path), opts.effective_triple()
        );
    }

    def _module_jir(resolved: str) -> (tuple[bytes, str] | None) {
        try {
            cache_path = get_module_cache_path(resolved);
            if is_module_cache_valid(resolved, cache_path) {
                return (cache_path.read_bytes(), "", );
            }
        } except Exception {}
        try {
            return self.prog._get_compiler()._precompiled_jir_data(resolved);
        } except Exception {
            return None;
        }
    }

    def _entry_fresh(ent: NativeUnitEntry) -> bool {
        """Use the shared source key, including annex membership and content.
        A deleted file differs from a unit that never had a source file.""";
        return ent.source_key == NativeUnitRegistry._source_key(ent.path)
            and ct_dep_text_fresh(
                ent.compile_deps.decode("utf-8"), ent.compile_deps_base
            );
    }

    def _register(
        resolved: str, iface: NativeIface, stamp: NativeStamp, source: str
    ) -> NativeUnitEntry {
        ent = NativeUnitEntry(
            path=resolved,
            digest=iface.digest(),
            iface=iface,
            stamp=stamp,
            source=source,
            source_key=NativeUnitRegistry._source_key(resolved)
        );
        self.entries[resolved] = ent;
        return ent;
    }

    def record(
        path: str,
        iface: NativeIface,
        options: (CompileOptions | None) = None,
        dep_digests: (dict[str, str] | None) = None,
        compile_deps: bytes = b""
    ) -> NativeUnitEntry {
        resolved = os.path.realpath(path);
        ent = self._register(
            resolved, iface, self.stamp_for(options, resolved), "compile"
        );
        ent.compile_deps = compile_deps;
        ent.dep_digests = dict(dep_digests or {});
        gen = self._live_gen(resolved);
        if gen is not None {
            ent.object_bytes = gen.native_object;
            ent.bitcode = gen.native_bitcode;
        }
        return ent;
    }

    def record_module(
        module: Module, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        """A module this process just lowered enters the registry with the
        digests of the dependencies it was lowered against, which are the
        entries those dependencies registered before it.""";
        if not (module?.loc and module.loc.mod_path) {
            return None;
        }
        gen = module.gen;
        if gen.native_iface is None {
            return None;
        }
        ent = self.record(
            module.loc.mod_path,
            gen.native_iface,
            options,
            dep_digests=self.dep_digests(list(gen.native_deps or [])),
            compile_deps=ct_deps_section(module.ct_file_deps, module.ct_body_deps)
        );
        ent.object_bytes = gen.native_object;
        ent.bitcode = gen.native_bitcode;
        return ent;
    }

    def recorded_native_deps(
        path: str, options: (CompileOptions | None) = None
    ) -> list[tuple[str, str]] {
        resolved = os.path.realpath(path);
        live = self.entries.get(resolved);
        stamp = self.stamp_for(options, resolved);
        if live is not None and live.stamp.matches(stamp) {
            return sorted(live.dep_digests.items());
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        return read_native_dep_hashes(found[0], stamp, found[1], resolved);
    }

    def _deps_match(
        data: bytes,
        stamp: NativeStamp,
        base_dir: str,
        anchor: str = "",
        options: (CompileOptions | None) = None
    ) -> bool {
        for (dep, recorded) in read_native_dep_hashes(data, stamp, base_dir, anchor) {
            ent = self.ensure(dep, compile_on_miss=False, options=options);
            if ent is None or ent.digest != recorded {
                return False;
            }
        }
        return True;
    }

    def dep_digests(paths: list[str]) -> dict[str, str] {
        out: dict[str, str] = {};
        for p in paths {
            real = os.path.realpath(p);
            out[real] = self.known_digest(real);
        }
        return out;
    }

    def _read_from_disk(
        resolved: str,
        stamp: NativeStamp,
        check_deps: bool,
        options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
        iface = NativeIface.from_bytes(payload);
        if iface is None {
            return None;
        }
        compile_deps = native_section_payload(
            read_section_bytes(data, SEC_NCTDEPS), stamp
        );
        if compile_deps is None
            or not ct_dep_text_fresh(compile_deps.decode("utf-8"), base_dir) {
            self._event("native_comptime_miss");
            return None;
        }
        iface.resolve_deps(resolved);
        if check_deps
            and not self._deps_match(data, stamp, base_dir, resolved, options) {
            self._event("native_dep_miss");
            return None;
        }
        ent = self._register(resolved, iface, stamp, "disk");
        ent.compile_deps = compile_deps;
        ent.compile_deps_base = base_dir;
        ent.dep_digests = dict(read_native_dep_hashes(data, stamp, base_dir, resolved));
        ent.object_bytes = native_section_payload(
            read_section_bytes(data, SEC_NOBJ), stamp
        );
        ent.bitcode = native_section_payload(
            read_section_bytes(data, SEC_NBITCODE), stamp
        );
        return ent;
    }

    def ensure(
        path: str,
        compile_on_miss: bool = True,
        options: (CompileOptions | None) = None,
        check_deps: bool = True,
        products: bool = True
    ) -> (NativeUnitEntry | None) {
        options = options if options is not None else self._options();
        resolved = os.path.realpath(path);
        if not jir_cacheable_source_path(resolved) {
            return None;
        }
        stamp = self.stamp_for(options, resolved);
        ent = self.entries.get(resolved);
        if ent is not None and ent.stamp.matches(stamp) and self._entry_fresh(ent) {
            return ent;
        }
        if ent is not None {
            del self.entries[resolved];
        }
        if resolved in self.building {
            return None;
        }
        if resolved in self.checking and not options.no_ir_cache {
            return self._read_from_disk(
                resolved, stamp, check_deps=False, options=options
            );
        }
        (rebuild, _) = cache_mode();
        if not rebuild and not options.no_ir_cache {
            self.checking.add(resolved);
            try {
                found = self._read_from_disk(
                    resolved, stamp, check_deps=check_deps, options=options
                );
            } finally {
                self.checking.discard(resolved);
            }
            if found is not None {
                self._event("native_iface_hit");
                return found;
            }
        }
        if not compile_on_miss or not os.path.isfile(resolved) {
            return None;
        }
        if self.not_native.get(resolved) == NativeUnitRegistry._source_key(resolved) {
            return None;
        }
        return self.compile_unit(resolved, options, products=products);
    }

    def known_native_deps(path: str, options: CompileOptions) -> list[str] {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        stamp = self.stamp_for(options, resolved);
        if ent is not None and ent.stamp.matches(stamp) {
            return sorted(os.path.realpath(d) for d in ent.iface.deps);
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        (data, base_dir) = found;
        payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
        if payload is not None {
            iface = NativeIface.from_bytes(payload);
            if iface is not None {
                iface.resolve_deps(resolved);
                return sorted(os.path.realpath(d) for d in iface.deps);
            }
        }
        import from jaclang.compiler.driver.jir { read_dep_rows }
        import from jaclang.compiler.placement.placement_facts { native_unit }
        out: list[str] = [];
        for row in read_dep_rows(data, base_dir) {
            dep = os.path.realpath(row.path);
            if dep.endswith(".jac")
                and os.path.isfile(dep)
                and native_unit(dep, options.native_unit, self.prog) {
                out.append(dep);
            }
        }
        return sorted(set(out));
    }

    def product_sections(path: str) -> dict[int, bytes] {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is None {
            return {};
        }
        import from jaclang.compiler.driver.jir {
            SEC_NDEPS,
            native_deps_section,
            absolutize_ct_deps_section
        }
        stamp = ent.stamp;
        sections: dict[int, bytes] = {
            SEC_NCTDEPS: stamp.pack(
                absolutize_ct_deps_section(ent.compile_deps, ent.compile_deps_base)
            ),
            SEC_NIFACE: stamp.pack(ent.iface.to_bytes()),
            SEC_NDEPS: stamp.pack(native_deps_section(ent.dep_digests))
        };
        if ent.object_bytes is not None {
            sections[SEC_NOBJ] = stamp.pack(ent.object_bytes);
        }
        if ent.bitcode is not None {
            sections[SEC_NBITCODE] = stamp.pack(ent.bitcode);
        }
        return sections;
    }

    def compile_unit(
        path: str,
        options: (CompileOptions | None) = None,
        use_str: (str | None) = None,
        products: bool = True
    ) -> (NativeUnitEntry | None) {
        """Lower a unit and, when `products` is set, optimize, emit and persist
        its products. An analysis-only consumer needs the interface and
        layouts that lowering records; a build that later needs the products
        compiles the unit again through `bitcode_for` or `object_for`.""";
        if self.session is not None {
            return self.session.lower(path, use_str);
        }
        import from jaclang.compiler.backends.native.link_plan { build_link_plan }
        opts = options if options is not None else self._options();
        resolved = os.path.realpath(path);
        session = NativeBuildSession(registry=self, options=opts);
        self.session = session;
        self.forget(resolved);
        try {
            if use_str is not None and session.lower(resolved, use_str) is None {
                return None;
            }
            plan = build_link_plan(self.prog, [resolved], opts);
            if not products {
                self._event("native_unit_analysis_only");
                return self.entries.get(resolved);
            }
            session.finish([unit.path for unit in plan.units]);
            return self.entries.get(resolved);
        } except Exception as exc {
            self.failures[resolved] = f"{type(exc).__name__}: {exc}";
            return None;
        } finally {
            self.session = None;
            session.close();
        }
    }

    def _stash_products(resolved: str, gen: CodeGenTarget) {
        ent = self.entries.get(resolved);
        if ent is not None {
            ent.object_bytes = gen.native_object;
            ent.bitcode = gen.native_bitcode;
        }
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
        carrier = self.prog.hub.artifacts.get(resolved);
        if carrier is None {
            carrier = CodeGenTarget();
            self.prog.hub.artifacts[resolved] = carrier;
        }
        carrier.native_iface = gen.native_iface;
        carrier.native_object = gen.native_object;
        carrier.native_bitcode = gen.native_bitcode;
        carrier.native_layout = gen.native_layout;
        carrier.native_deps = list(gen.native_deps or []);
    }

    def known_digest(path: str) -> str {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None {
            return ent.digest;
        }
        found = self._module_jir(resolved);
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if found is None {
            if env_na_debug() {
                import sys;
                sys.stderr.write(
                    f"NA_DEBUG known_digest {resolved}: no valid module cache entry\n"
                );
            }
            return "";
        }
        raw = read_section_bytes(found[0], SEC_NIFACE);
        stamp = self.stamp_for(None, resolved);
        payload = native_section_payload(raw, stamp);
        if payload is None and env_na_debug() {
            import sys;
            sys.stderr.write(
                f"NA_DEBUG known_digest {resolved}: no native interface for {stamp.key()}\n"
            );
        }
        return NativeIface.verified_digest(payload) or "";
    }

    def objects_for(
        paths: list[str], options: (CompileOptions | None) = None
    ) -> dict[str, (bytes | None)] {
        import from jaclang.compiler.backends.native.na_compile_pass {
            codegen_units_parallel
        }
        import from jaclang.compiler.driver.jir { write_module_cache }
        out: dict[str, (bytes | None)] = {};
        jobs: list[tuple[str, bytes]] = [];
        for path in paths {
            ent = self.ensure(path, options=options, check_deps=False);
            if ent is not None and ent.object_bytes is None and ent.bitcode is None {
                ent = self.compile_unit(path, options);
            }
            if ent is None {
                out[path] = None;
            } elif ent.object_bytes is not None {
                out[path] = ent.object_bytes;
            } elif ent.bitcode is not None {
                jobs.append((path, ent.bitcode));
            } else {
                out[path] = None;
            }
        }
        if jobs {
            opts = options if options is not None else self._options();
            started = self._span_begin();
            try {
                products = codegen_units_parallel(jobs, opts, 0, True);
            } finally {
                self._span_end("NATIVE_EMIT", started);
            }
            for (path, _) in jobs {
                ent = self.entries.get(os.path.realpath(path));
                (_, object_bytes) = products[path];
                if ent is None or object_bytes is None {
                    out[path] = None;
                    continue;
                }
                ent.object_bytes = object_bytes;
                self._event("native_object_emit");
                write_module_cache(
                    ent.path, None, extra_sections=self.product_sections(ent.path)
                );
                out[path] = object_bytes;
            }
        }
        return out;
    }

    def object_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        ent = self.ensure(path, options=options, check_deps=False);
        if ent is not None and ent.object_bytes is None {
            if ent.bitcode is None {
                ent = self.compile_unit(path, options);
            }
            if ent is not None and ent.bitcode is not None {
                import from jaclang.compiler.backends.native.na_compile_pass {
                    emit_unit_object
                }
                import from jaclang.compiler.driver.jir { write_module_cache }
                opts = options if options is not None else self._options();
                started = self._span_begin();
                try {
                    ent.object_bytes = emit_unit_object(ent.bitcode, opts);
                } finally {
                    self._span_end("NATIVE_EMIT", started);
                }
                self._event("native_object_emit");
                write_module_cache(
                    ent.path, None, extra_sections=self.product_sections(ent.path)
                );
            }
        }
        return ent.object_bytes if ent is not None else None;
    }

    def bitcode_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        ent = self.ensure(path, options=options, check_deps=False);
        if ent is not None and ent.bitcode is None {
            ent = self.compile_unit(path, options);
        }
        return ent.bitcode if ent is not None else None;
    }

    def _live_gen(resolved: str) -> (CodeGenTarget | None) {
        mod = self.prog.find_module(resolved);
        if mod is not None
            and mod.gen is not None
            and mod.gen.native_iface is not None {
            return mod.gen;
        }
        return self.prog.hub.artifacts.get(resolved);
    }

    def verdict_for(path: str) -> (NativeVerdict | None) {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._source_key(resolved);
        cached = self.verdicts.get(resolved);
        if cached is not None {
            if cached[0] == key and verdict_deps_fresh(cached[1].deps) {
                return cached[1];
            }
            del self.verdicts[resolved];
            if cached[0] == key {
                return None;
            }
        }
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        verdict = verdict_from_jir(found[0], found[1]);
        if verdict is not None and key is not None {
            self.verdicts[resolved] = (key, verdict, );
        }
        return verdict;
    }

    def is_demoted(path: str) -> bool {
        v = self.verdict_for(path);
        return v is not None and v.demoted;
    }

    def demoted_code(path: str) -> str {
        v = self.verdict_for(path);
        return v.code if v is not None else "";
    }

    def record_verdict(path: str, code: str, detail: str) {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._source_key(resolved);
        deps = native_verdict_dep_rows(resolved);
        if key is not None {
            self.verdicts[resolved] = (
                key,
                NativeVerdict(demoted=True, code=code, detail=detail, deps=deps),

            );
        }
        import from jaclang.compiler.placement.placement { note_native_verdict }
        note_native_verdict(self.prog, resolved, code, detail, deps);
        self.entries.pop(resolved, None);
    }
}

obj NativeBuildSession {
    has registry: NativeUnitRegistry,
        options: CompileOptions,
        prog: JacProgram postinit,
        lowered: dict[str, Module] = {},
        analyzed: dict[str, Module] = {},
        source_keys: dict[str, str | None] = {};

    def postinit {
        import from jaclang.compiler.driver.program { JacProgram }
        self.prog = JacProgram();
        self.prog.options = self.options.clone_for_native_import();
        self.prog._natives = self.registry;
    }

    def lower(path: str, use_str: (str | None) = None) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        if resolved in self.registry.building {
            return None;
        }
        self.registry.building.add(resolved);
        import from jaclang.compiler.frontend.codeinfo {
            set_native_unit_compile,
            reset_native_unit_compile,
            get_effective_default_codespace_override,
            set_effective_default_codespace
        }
        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }
        span_depth = self.registry._span_depth();
        unit_token = set_native_unit_compile(self.options.native_unit);
        target_token = push_native_target(self.options.native_target or "");
        prior_codespace = get_effective_default_codespace_override();
        prior_options = self.prog.options;
        errors_before = len(self.prog.errors_had);
        try {
            opts = self.options.clone_for_native_import();
            mod = self.lowered.get(resolved) or self.analyzed.get(resolved);
            if mod is None {
                self.source_keys[resolved] = NativeUnitRegistry._source_key(resolved);
                opts.no_cgen = True;
                started = self.registry._span_begin();
                mod = self.prog.compile(resolved, use_str=use_str, options=opts);
                self.registry._span_end("NATIVE_ANALYSIS", started);
                self.registry._event("native_unit_analysis");
            }
            if len(self.prog.errors_had) > errors_before {
                return None;
            }
            opts.no_cgen = False;
            self.prog.options = opts;
            set_effective_default_codespace("native");
            import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
            import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
            completed = self.prog.analysis.completed_passes.get(id(mod));
            if completed is not None {
                completed.discard("NaIRGenPass");
                completed.discard("NativeCompilePass");
            }
            import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
            tasks = self.prog.analysis.product_tasks.get(id(mod));
            if tasks is not None {
                tasks.pop(CompilationProduct.NATIVE_IR, None);
            }
            mod.gen.llvm_ir = None;
            mod.gen.native_iface = None;
            mod.gen.native_bitcode = None;
            mod.gen.native_object = None;
            started = self.registry._span_begin();
            self.prog.run_schedule(mod, [RcFactsPass, NaIRGenPass]);
            self.registry._span_end("NATIVE_LOWER", started);
            self.registry._event("native_unit_lower");
            if len(self.prog.errors_had) > errors_before
                or mod.gen.native_iface is None {
                return None;
            }
            import from jaclang.compiler.backends.native.na_compile_pass {
                settle_unit_ir
            }
            settle_unit_ir(mod);
            self.lowered[resolved] = mod;
            ent = self.registry.record_module(mod, opts);
            self.registry._stash_products(resolved, mod.gen);
            return ent;
        } except Exception {
            import traceback;
            self.registry.failures[resolved] = traceback.format_exc();
            import from jaclang.compiler.driver.compile_options { env_na_debug }
            if env_na_debug() {
                import sys;
                sys.stderr.write(self.registry.failures[resolved]);
            }
            return None;
        } finally {
            if len(self.prog.errors_had) > errors_before {
                self.registry.failures[resolved] = "\n".join(
                    alert.pretty_print()
                    for alert in self.prog.errors_had[errors_before:]
                );
            }
            self.registry._span_unwind(span_depth);
            self.registry.building.discard(resolved);
            self.prog.options = prior_options;
            set_effective_default_codespace(prior_codespace);
            pop_native_target(target_token);
            reset_native_unit_compile(unit_token);
        }
    }

    def analyze_closure(roots: list[str]) -> dict[str, list[str]] {
        import from jaclang.compiler.frontend.codeinfo {
            set_native_unit_compile,
            reset_native_unit_compile
        }
        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }
        opts = self.options.clone_for_native_import();
        opts.no_cgen = True;
        edges: dict[str, list[str]] = {};
        queue = [os.path.realpath(r) for r in roots];
        unit_token = set_native_unit_compile(self.options.native_unit);
        target_token = push_native_target(self.options.native_target or "");
        try {
            self._analyze_queue(queue, edges, opts);
        } finally {
            pop_native_target(target_token);
            reset_native_unit_compile(unit_token);
        }
        return edges;
    }

    def _analyze_queue(
        queue: list[str], edges: dict[str, list[str]], opts: CompileOptions
    ) {
        import from jaclang.compiler.placement.placement_facts { native_unit }
        import jaclang.compiler.frontend.unitree as uni;
        while queue {
            path = queue.pop(0);
            if path in edges {
                continue;
            }
            deps: list[str] = [];
            edges[path] = deps;
            mod = self.lowered.get(path) or self.analyzed.get(path);
            if mod is None {
                if not os.path.isfile(path) {
                    continue;
                }
                self.source_keys[path] = NativeUnitRegistry._source_key(path);
                started = self.registry._span_begin();
                mod = self.prog.compile(path, options=opts);
                self.registry._span_end("NATIVE_ANALYSIS", started);
                self.registry._event("native_unit_analysis");
                self.analyzed[path] = mod;
            }
            for imp in mod.get_all_sub_nodes(uni.Import) {
                targets: list[uni.ModulePath] = [];
                if imp.from_loc is not None {
                    targets.append(imp.from_loc);
                } else {
                    for item in imp.items {
                        if isinstance(item, uni.ModulePath) {
                            targets.append(item);
                        }
                    }
                }
                for mp in targets {
                    try {
                        dep = os.path.realpath(mp.resolve_relative_path());
                    } except Exception {
                        continue;
                    }
                    if dep == path
                        or not dep.endswith(".jac")
                        or not os.path.isfile(dep) {
                        continue;
                    }
                    if dep in deps
                        or not native_unit(dep, self.options.native_unit, self.prog) {
                        continue;
                    }
                    deps.append(dep);
                    queue.append(dep);
                }
            }
        }
    }

    def lower_all_parallel(roots: list[str], workers: int) -> int {
        import multiprocessing;
        import from jaclang.compiler.driver.dependency_graph { dependency_groups }
        import from jaclang.compiler.frontend.codeinfo {
            KERNEL_UNIT_REL,
            kernel_unit_path
        }
        edges = self.analyze_closure(roots);
        if len(edges) < 2 * workers {
            return 0;
        }
        for rel in KERNEL_UNIT_REL {
            kpath = os.path.realpath(kernel_unit_path(rel));
            if kpath in edges and kpath not in self.lowered {
                self.lower(kpath);
            }
        }
        groups = dependency_groups(edges, [os.path.realpath(r) for r in roots]);
        level_of: dict[str, int] = {};
        levels: list[list[list[str]]] = [];
        for group in groups {
            members = set(group);
            depth = 0;
            for member in group {
                for dep in edges.get(member, []) {
                    if dep not in members {
                        depth = max(depth, level_of.get(dep, 0) + 1);
                    }
                }
            }
            for member in group {
                level_of[member] = depth;
            }
            while len(levels) <= depth {
                levels.append([]);
            }
            levels[depth].append(list(group));
        }
        lowered_before = len(self.lowered);
        for level in levels {
            pending = [
                g
                for g in level
                if any(p not in self.lowered for p in g)
            ];
            if not pending {
                continue;
            }
            todo = [
                p for g in pending
                for p in g
                if p not in self.lowered
            ];
            if len(todo) <= 1 or workers <= 1 {
                for path in todo {
                    self.lower(path);
                }
                continue;
            }
            cyclic = [
                p
                for g in pending
                if len(g) > 1 for p in g
            ];
            self._lower_round(todo, cyclic, workers, False);
            stale = list(cyclic);
            rounds = 0;
            while stale and rounds < 5 {
                self._lower_round(stale, [], workers, True);
                rounds += 1;
                stale = self._stale_members(cyclic);
            }
        }
        return len(self.lowered) - lowered_before;
    }

    def _stale_members(paths: list[str]) -> list[str] {
        out: list[str] = [];
        for path in paths {
            ent = self.registry.entries.get(path);
            if ent is None {
                continue;
            }
            for (dep, recorded) in ent.dep_digests.items() {
                if recorded and recorded != self.registry.known_digest(dep) {
                    out.append(path);
                    break;
                }
            }
        }
        return out;
    }

    def _lower_round(paths: list[str], mask: list[str], workers: int, relower: bool) {
        import multiprocessing;
        jobs = max(1, min(workers, len(paths)));
        batches: list[list[str]] = [[] for _ in range(jobs)];
        for (i, path) in enumerate(paths) {
            batches[i % jobs].append(path);
        }
        _PARALLEL_SESSION.clear();
        _PARALLEL_SESSION.append(self);
        started = self.registry._span_begin();
        try {
            context = multiprocessing.get_context("fork");
            with context.Pool(processes=jobs) as pool {
                results = pool.starmap(
                    _lower_batch_in_child, [(b, mask, relower) for b in batches]
                );
            }
        } finally {
            self.registry._span_end("NATIVE_LOWER", started);
            _PARALLEL_SESSION.clear();
        }
        for batch in results {
            for rec in batch {
                self._absorb_lowered(rec, relower);
            }
        }
    }

    def _absorb_lowered(rec: dict[str, any], replace: bool = False) {
        import from jaclang.compiler.backends.native.na_compile_pass {
            install_unit_ir_text
        }
        path = str(rec["path"]);
        if path in self.lowered and not replace {
            return;
        }
        failure = rec.get("failure");
        if failure {
            if path not in self.lowered {
                self.registry.failures[path] = str(failure);
            }
            return;
        }
        mod = self.analyzed.get(path) or self.lowered.get(path);
        if mod is None {
            return;
        }
        iface = NativeIface.from_bytes(rec.get("iface"));
        if iface is None {
            self.registry.failures[path] = "the worker returned no native interface";
            return;
        }
        iface.resolve_deps(path);
        install_unit_ir_text(mod, str(rec.get("ir") or ""));
        mod.gen.native_iface = iface;
        mod.gen.native_deps = list(rec.get("deps") or []);
        mod.gen.native_layout = rec.get("layout");
        mod.gen._clib_paths = list(rec.get("clib_paths") or []);
        mod.gen._clib_symbol_lib = dict(rec.get("clib_symbol_lib") or {});
        mod.gen._exported_symbols = list(rec.get("exports") or []);
        self.lowered[path] = mod;
        self.registry._event("native_unit_lower");
        self.registry.record_module(mod, self.options.clone_for_native_import());
        self.registry._stash_products(path, mod.gen);
    }

    def finish(paths: list[str], emit_objects: bool = False) {
        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }
        token = push_native_target(self.options.native_target or "");
        try {
            self._finish(paths, emit_objects);
        } finally {
            pop_native_target(token);
        }
    }

    def _pending_products(paths: list[str]) -> list[tuple[str, Module]] {
        pending: list[tuple[str, Module]] = [];
        for path in paths {
            mod = self.lowered.get(path);
            if mod is None {
                known = self.registry.entries.get(path);
                if known is None or known.bitcode is not None {
                    continue;
                }
                if self.lower(path) is None {
                    raise RuntimeError(
                        f"native unit lost its products and could not be lowered: {path}"
                    );
                }
                mod = self.lowered.get(path);
                if mod is None {
                    continue;
                }
            }
            pending.append((path, mod));
        }
        return pending;
    }

    def _parallel_codegen_ok -> bool {
        opts = self.prog.options;
        return (opts.aot_mode or opts.skip_native_engine)
            and not opts.native_debug
            and not opts.dump_ir_path;
    }

    def _codegen_parallel(pending: list[tuple[str, Module]], emit_objects: bool) {
        import from jaclang.compiler.backends.native.na_compile_pass {
            codegen_unit_seconds,
            codegen_units_parallel,
            require_native_ir,
            unit_ir_bitcode
        }
        opts = self.prog.options;
        opt_level = int(opts.opt_level or 0);
        jobs: list[tuple[str, bytes]] = [];
        for (path, mod) in pending {
            if mod.gen.llvm_ir is None {
                continue;
            }
            if opts.native_required_for(path) {
                require_native_ir(str(mod.gen.llvm_ir));
            }
            cached = self.registry.entries.get(path);
            if cached is not None and cached.bitcode is not None {
                mod.gen.native_bitcode = cached.bitcode;
                mod.gen.native_object = cached.object_bytes;
                continue;
            }
            jobs.append((path, unit_ir_bitcode(mod)));
        }
        products = codegen_units_parallel(jobs, opts, opt_level, emit_objects);
        self.registry.slowest_codegen = codegen_unit_seconds([p for (p, _) in jobs])[:3];
        for (path, mod) in pending {
            found = products.get(path);
            if found is None {
                continue;
            }
            (bitcode, object_bytes) = found;
            mod.gen.native_bitcode = bitcode;
            mod.gen.native_object = object_bytes;
            self.registry.note_codegen(path, object_bytes is not None);
        }
    }

    def _finish(paths: list[str], emit_objects: bool = False) {
        """Optimize and persist only after every consumed interface agrees.
        Cyclic interface settlement reuses the analyzed trees and never emits
        optimized products for an intermediate state.""";
        import from jaclang.compiler.backends.native.na_compile_pass {
            NativeCompilePass,
            emit_unit_object
        }
        self.prog.options = self.options.clone_for_native_import();
        for path in paths {
            if path in self.source_keys
                and self.source_keys[path] != NativeUnitRegistry._source_key(path) {
                raise RuntimeError(f"native source changed during analysis: {path}");
            }
        }
        pending = self._pending_products(paths);
        errors_before = len(self.prog.errors_had);
        started = self.registry._span_begin();
        try {
            if self._parallel_codegen_ok() {
                self._codegen_parallel(pending, emit_objects);
            } else {
                for (path, mod) in pending {
                    self.prog.run_schedule(mod, [NativeCompilePass]);
                    bitcode = mod.gen.native_bitcode;
                    if emit_objects
                        and bitcode is not None
                        and mod.gen.native_object is None {
                        mod.gen.native_object = emit_unit_object(
                            bitcode, self.prog.options
                        );
                        self.registry._event("native_object_emit");
                    }
                }
            }
        } finally {
            self.registry._span_end("NATIVE_OPTIMIZE", started);
        }
        if len(self.prog.errors_had) > errors_before {
            raise RuntimeError("native product emission failed");
        }
        started = self.registry._span_begin();
        try {
            for (path, mod) in pending {
                if mod.gen.native_bitcode is None {
                    raise RuntimeError(f"native product emission failed for {path}");
                }
                self.registry.record_module(mod, self.prog.options);
                self.registry._stash_products(path, mod.gen);
                self.prog._get_compiler()._persist_native_unit(path, mod, self.prog);
            }
        } finally {
            self.registry._span_end("NATIVE_PERSIST", started);
        }
    }

    def close {
        for (phase, seconds) in self.prog.analysis.phase_time.items() {
            self.registry._add_time("NATIVE_FRONTEND_" + phase, seconds);
        }
        self.lowered.clear();
        self.source_keys.clear();
        self.prog._natives = None;
        self.prog.release_compile_closure();
    }
}

glob _PARALLEL_SESSION: list[NativeBuildSession] = [];

def native_lower_workers -> int {
    raw = os.environ.get("JAC_NATIVE_LOWER_JOBS", "").strip();
    if raw {
        try {
            return max(1, int(raw));
        } except ValueError {}
    }
    if not hasattr(os, "fork") {
        return 1;
    }
    return max(1, min(8, os.cpu_count() or 1));
}

def _lower_batch_in_child(
    paths: list[str], mask: list[str], relower: bool
) -> list[dict[str, any]] {
    session = _PARALLEL_SESSION[0];
    before = set(session.lowered.keys());
    wanted = set(paths);
    out: list[dict[str, any]] = [];
    for path in paths {
        if path in session.lowered and not relower {
            continue;
        }
        masked = [
            m
            for m in mask
            if m != path and m not in session.lowered
        ];
        session.registry.building.update(masked);
        try {
            session.lower(path);
        } finally {
            session.registry.building.difference_update(masked);
        }
    }
    for (resolved, mod) in session.lowered.items() {
        if resolved in before and (resolved not in wanted or not relower) {
            continue;
        }
        iface = mod.gen.native_iface;
        out.append(
            {
                "path": resolved,
                "ir": str(mod.gen.llvm_ir) if mod.gen.llvm_ir is not None else None,
                "iface": iface.to_bytes() if iface is not None else None,
                "deps": list(mod.gen.native_deps or []),
                "layout": mod.gen.native_layout,
                "clib_paths": list(mod.gen._clib_paths),
                "clib_symbol_lib": dict(mod.gen._clib_symbol_lib),
                "exports": list(mod.gen._exported_symbols)
            }
        );
    }
    for path in paths {
        if path not in session.lowered {
            out.append(
                {
                    "path": path,
                    "failure": session.registry.failures.get(path)
                        or "the worker could not lower this unit"
                }
            );
        }
    }
    return out;
}

glob _closure_memo:
         dict[str, tuple[tuple[(tuple[int, int] | None), ...], list[str], list[str]]] = {},
     _dep_digest_memo: dict[str, tuple[tuple[int, int], str]] = {},
     VERDICT_CLOSURE_LIMIT: int = 4096;

def _stat_key(path: str) -> (tuple[int, int] | None) {
    try {
        st = os.stat(path);
        return (st.st_mtime_ns, st.st_size);
    } except OSError {
        return None;
    }
}

def _module_files_and_imports(path: str) -> tuple[list[str], list[str]] {
    import from jaclang.compiler.driver.bccache { discover_annex_files }
    files = [path]
        + discover_annex_files(path, '.impl.jac')
        + discover_annex_files(path, '.test.jac');
    fresh = tuple(_stat_key(f) for f in files);
    cached = _closure_memo.get(path);
    if cached is not None and cached[0] == fresh {
        return (cached[1], cached[2]);
    }
    import from jaclang.project.textio { read_file_with_encoding }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.parser.frontend { parse as rd_parse }
    import from jaclang.compiler.placement.placement { jac_import_targets }
    imports: list[str] = [];
    for f in files {
        try {
            (mod, _had_err) = rd_parse(
                read_file_with_encoding(f), f, prog=JacProgram()
            );
        } except Exception {
            continue;
        }
        for target in jac_import_targets(mod) {
            if target not in imports {
                imports.append(target);
            }
        }
    }
    _closure_memo[path] = (fresh, files, imports);
    return (files, imports);
}

def native_verdict_closure(path: str) -> list[str] {
    start = os.path.realpath(path);
    seen: set[str] = {start};
    queue: list[str] = list(_module_files_and_imports(start)[1]);
    out: list[str] = [];
    while queue and len(seen) < VERDICT_CLOSURE_LIMIT {
        dep = queue.pop(0);
        if dep in seen {
            continue;
        }
        seen.add(dep);
        (files, imports) = _module_files_and_imports(dep);
        out.extend(files);
        queue.extend(
            i
            for i in imports
            if i not in seen
        );
    }
    return sorted(set(out));
}

def _file_digest(path: str) -> str {
    key = _stat_key(path);
    if key is None {
        return "";
    }
    cached = _dep_digest_memo.get(path);
    if cached is not None and cached[0] == key {
        return cached[1];
    }
    try {
        digest = compute_content_sha256(path);
    } except OSError {
        return "";
    }
    _dep_digest_memo[path] = (key, digest);
    return digest;
}

def native_verdict_dep_rows(path: str) -> list[list[str]] {
    try {
        return [[f, _file_digest(f)] for f in native_verdict_closure(path)];
    } except Exception {
        return [];
    }
}

def verdict_deps_fresh(rows: list[list[str]], base_dir: str = "") -> bool {
    prefix = PRECOMPILE_SENTINEL + "/";
    for row in rows {
        path = row[0];
        if path.startswith(prefix) {
            if not base_dir {
                continue;
            }
            path = os.path.normpath(os.path.join(base_dir, path[len(prefix):]));
        }
        if _file_digest(path) != row[1] {
            return False;
        }
    }
    return True;
}

def verdict_from_jir(data: bytes, base_dir: str = "") -> (NativeVerdict | None) {
    raw = read_section_bytes(data, SEC_PLACEMENT);
    if raw is None {
        return None;
    }
    import from jaclang.compiler.placement.placement_export { summary_from_bytes }
    summary = summary_from_bytes(raw);
    if summary is None or not summary.native_verdict {
        return None;
    }
    if not verdict_deps_fresh(summary.native_verdict_deps, base_dir) {
        return None;
    }
    return NativeVerdict(
        demoted=True,
        code=summary.native_verdict_code,
        detail=summary.native_verdict,
        deps=summary.native_verdict_deps
    );
}

def read_native_verdict(path: str) -> (NativeVerdict | None) {
    resolved = os.path.realpath(path);
    try {
        cache_path = get_module_cache_path(resolved);
        if not is_module_cache_valid(resolved, cache_path) {
            return None;
        }
        return verdict_from_jir(cache_path.read_bytes());
    } except Exception {
        return None;
    }
}
