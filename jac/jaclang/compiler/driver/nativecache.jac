import os;
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.jir {
    NativeStamp,
    SEC_NCTDEPS,
    ct_deps_section,
    ct_dep_text_fresh,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_MODKEY,
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

obj NativeVerdict {
    has demoted: bool = False,
        code: str = "",
        detail: str = "";
}

obj NativeUnitRegistry {
    has prog: JacProgram,
        session: (NativeBuildSession | None) = None,
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

    def forget(path: str) {
        real = os.path.realpath(path);
        self.entries.pop(real, None);
        self.not_native.pop(real, None);
        self.failures.pop(real, None);
    }

    static def _source_key(path: str) -> (str | None) {
        try {
            return module_cache_key(path);
        } except OSError {
            return None;
        }
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
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

    def stamp_for(options: (CompileOptions | None) = None) -> NativeStamp {
        opts = options if options is not None else self._options();
        return current_native_stamp(opts.codegen_identity(), opts.effective_triple());
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
        ent = self._register(resolved, iface, self.stamp_for(options), "compile");
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
        if live is not None and live.stamp.matches(self.stamp_for(options)) {
            return sorted(live.dep_digests.items());
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        return read_native_dep_hashes(
            found[0], self.stamp_for(options), found[1], resolved
        );
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
        check_deps: bool = True
    ) -> (NativeUnitEntry | None) {
        options = options if options is not None else self._options();
        resolved = os.path.realpath(path);
        if not jir_cacheable_source_path(resolved) {
            return None;
        }
        stamp = self.stamp_for(options);
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
        return self.compile_unit(resolved, options);
    }

    def known_native_deps(path: str, options: CompileOptions) -> list[str] {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None and ent.stamp.matches(self.stamp_for(options)) {
            return sorted(os.path.realpath(d) for d in ent.iface.deps);
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        (data, base_dir) = found;
        payload = native_section_payload(
            read_section_bytes(data, SEC_NIFACE), self.stamp_for(options)
        );
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
        if ent.source_key is not None {
            sections[SEC_MODKEY] = ent.source_key.encode("utf-8");
        }
        if ent.object_bytes is not None {
            sections[SEC_NOBJ] = stamp.pack(ent.object_bytes);
        }
        if ent.bitcode is not None {
            sections[SEC_NBITCODE] = stamp.pack(ent.bitcode);
        }
        return sections;
    }

    def compile_unit(
        path: str, options: (CompileOptions | None) = None, use_str: (str | None) = None
    ) -> (NativeUnitEntry | None) {
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
        payload = native_section_payload(raw, self.stamp_for());
        if payload is None and env_na_debug() {
            import sys;
            sys.stderr.write(
                f"NA_DEBUG known_digest {resolved}: no native interface for {self.stamp_for().key()}\n"
            );
        }
        return NativeIface.read_digest(payload) or "";
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
                ent.object_bytes = emit_unit_object(ent.bitcode, opts);
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
            if cached[0] == key {
                return cached[1];
            }
            del self.verdicts[resolved];
        }
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        verdict = verdict_from_jir(found[0]);
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
        if key is not None {
            self.verdicts[resolved] = (
                key,
                NativeVerdict(demoted=True, code=code, detail=detail),

            );
        }
        import from jaclang.compiler.placement.placement { note_native_verdict }
        note_native_verdict(self.prog, resolved, code, detail);
        self.entries.pop(resolved, None);
    }
}

obj NativeBuildSession {
    has registry: NativeUnitRegistry,
        options: CompileOptions,
        prog: JacProgram postinit,
        lowered: dict[str, Module] = {},
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
        unit_token = set_native_unit_compile(self.options.native_unit);
        target_token = push_native_target(self.options.native_target or "");
        prior_codespace = get_effective_default_codespace_override();
        prior_options = self.prog.options;
        errors_before = len(self.prog.errors_had);
        try {
            opts = self.options.clone_for_native_import();
            mod = self.lowered.get(resolved);
            if mod is None {
                self.source_keys[resolved] = NativeUnitRegistry._source_key(resolved);
                opts.no_cgen = True;

                mod = self.prog.compile(resolved, use_str=use_str, options=opts);
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
            mod.gen.llvm_ir = None;
            mod.gen.native_iface = None;
            mod.gen.native_bitcode = None;
            mod.gen.native_object = None;
            self.prog.run_schedule(mod, [RcFactsPass, NaIRGenPass]);
            self.registry._event("native_unit_lower");
            if len(self.prog.errors_had) > errors_before
                or mod.gen.native_iface is None {
                return None;
            }
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
            self.registry.building.discard(resolved);
            self.prog.options = prior_options;
            set_effective_default_codespace(prior_codespace);
            pop_native_target(target_token);
            reset_native_unit_compile(unit_token);
        }
    }

    def finish(paths: list[str]) {
        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }
        token = push_native_target(self.options.native_target or "");
        try {
            self._finish(paths);
        } finally {
            pop_native_target(token);
        }
    }

    def _finish(paths: list[str]) {
        """Optimize and persist only after every consumed interface agrees.
        Cyclic interface settlement reuses the analyzed trees and never emits
        optimized products for an intermediate state.""";
        import from jaclang.compiler.backends.native.na_compile_pass {
            NativeCompilePass
        }
        self.prog.options = self.options.clone_for_native_import();
        for path in paths {
            if path in self.source_keys
                and self.source_keys[path] != NativeUnitRegistry._source_key(path) {
                raise RuntimeError(f"native source changed during analysis: {path}");
            }
        }
        for path in paths {
            mod = self.lowered.get(path);
            if mod is None {
                continue;
            }
            errors_before = len(self.prog.errors_had);
            self.prog.run_schedule(mod, [NativeCompilePass]);
            if len(self.prog.errors_had) > errors_before
                or mod.gen.native_bitcode is None {
                raise RuntimeError(f"native product emission failed for {path}");
            }
            self.registry.record_module(mod, self.prog.options);
            self.registry._stash_products(path, mod.gen);
            self.prog._get_compiler()._persist_native_unit(path, mod, self.prog);
        }
    }

    def close {
        self.lowered.clear();
        self.source_keys.clear();
        self.prog._natives = None;
        self.prog.release_compile_closure();
    }
}

def verdict_from_jir(data: bytes) -> (NativeVerdict | None) {
    raw = read_section_bytes(data, SEC_PLACEMENT);
    if raw is None {
        return None;
    }
    import from jaclang.compiler.placement.placement { summary_from_bytes }
    summary = summary_from_bytes(raw);
    if summary is None or not summary.native_verdict {
        return None;
    }
    return NativeVerdict(
        demoted=True, code=summary.native_verdict_code, detail=summary.native_verdict
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
