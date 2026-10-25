impl NativeUnitRegistry.postinit {
    self.building = set();
}

impl NativeUnitRegistry.begin_parse(path: str) {
    """A module's parse starts a stretch of allocation. A session settles
    its heap first, so no collection scans more than one module's new
    tree.""";
    if self.session is not None {
        self.session.settle_heap();
    }
    self.note_step("parse", path);
}

impl NativeUnitRegistry.note_step(
    verb: str, path: str = "", detail: str = ""
) -> float {
    if self.progress is not None {
        self.progress_steps += 1;
        label = detail;
        if path {
            import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
            try {
                label = native_unit_identity(path);
            } except Exception {
                label = os.path.basename(path);
            }
        }
        self.progress(f"  [{self.progress_steps:>4}] {verb:<9} {label}");
    }
    return time.perf_counter();
}

impl NativeUnitRegistry.note_slow_step(verb: str, path: str, started: float) {
    elapsed = time.perf_counter() - started;
    if self.progress is not None and elapsed >= SLOW_STEP_SECONDS {
        self.progress(
            f"         {verb} {os.path.basename(path) or 'units'} took {elapsed:.1f}s"
        );
    }
}

impl NativeUnitRegistry.clear {
    self.entries.clear();
    self.not_native.clear();
    self.compiled_paths.clear();
    self.failures.clear();
}

impl NativeUnitRegistry.release_products {
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

impl NativeUnitRegistry.forget(path: str) {
    real = os.path.realpath(path);
    self.entries.pop(real, None);
    self.not_native.pop(real, None);
    self.failures.pop(real, None);
}

impl NativeUnitRegistry.adopt_dep_digests(path: str, digests: dict[str, str]) -> bool {
    real = os.path.realpath(path);
    session = self.session;
    if session is None or real not in session.lowered {
        return False;
    }
    ent = self.entries.get(real);
    if ent is None {
        return False;
    }
    unbound = session.unbound_symbols(real, list(digests.keys()));
    if unbound is None or unbound {
        self._event("native_dep_adopt_refused");
        self._miss(
            real,
            "lowered while a dependency was still being built, and binds "
                + (
                    ", ".join(unbound[:8])
                        if unbound
                        else "symbols this build cannot check"
                )
                + " that the dependency does not define natively"
        );
        return False;
    }
    for (dep, digest) in digests.items() {
        ent.dep_digests[os.path.realpath(dep)] = digest;
    }
    self._event("native_dep_adopt");
    return True;
}

impl NativeUnitRegistry._source_key(path: str) -> (str | None) {
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

impl NativeUnitRegistry._miss(path: str, why: str) {
    if env_na_debug() {
        sys.stderr.write(f"[native cache] miss {path}: {why}\n");
    }
}

impl NativeUnitRegistry._event(name: str) {
    counters = self.prog.analysis.cache_events;
    counters[name] = counters.get(name, 0) + 1;
    stat_note(name);
}

impl NativeUnitRegistry._add_time(name: str, seconds: float) {
    times = self.prog.analysis.phase_time;
    times[name] = times.get(name, 0.0) + seconds;
}

impl NativeUnitRegistry._timed(name: str, started: float) {
    self._add_time(name, time.perf_counter() - started);
}

impl NativeUnitRegistry._timed_unit(name: str, path: str, started: float) {
    elapsed = time.perf_counter() - started;
    self._add_time(name, elapsed);
    self.unit_lower_seconds[path] = self.unit_lower_seconds.get(path, 0.0) + elapsed;
}

impl NativeUnitRegistry.phase_summary -> str {
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
        f"gc settle {times.get('NATIVE_GC_SETTLE', 0.0):.1f}s; "
        f"units analysed/lowered/optimized/emitted "
        f"{events.get('native_unit_analysis', 0)}/"
        f"{events.get('native_unit_lower', 0)}/"
        f"{events.get('native_unit_codegen', 0)}/"
        f"{events.get('native_object_emit', 0)}; "
        f"interface hits {events.get('native_iface_hit', 0)}, "
        f"dependency misses {events.get('native_dep_miss', 0)}, "
        f"lowered inside a consumer {events.get('native_nested_lower', 0)}"
    );
}

impl NativeUnitRegistry.note_codegen(path: str, object_emitted: bool = True) {
    self.compiled_paths.append(os.path.realpath(path));
    self._event("native_unit_codegen");
    if object_emitted {
        self._event("native_object_emit");
    }
}

impl NativeUnitRegistry.note_link(reused: bool) {
    self._event("native_link_hit" if reused else "native_link");
}

impl NativeUnitRegistry._options -> CompileOptions {
    opts = self.prog.options;
    return opts if opts is not None else CompileOptions();
}

impl NativeUnitRegistry.stamp_for(
    options: (CompileOptions | None) = None, path: str = ""
) -> NativeStamp {
    opts = options if options is not None else self._options();
    return current_native_stamp(
        opts.unit_codegen_identity(path),
        opts.effective_triple(),
        native_producer_digest(opts.kernel_build)
    );
}

impl NativeUnitRegistry._carry(resolved: str, stamp: NativeStamp) -> bool {
    carried = carried_native_sections(resolved, stamp.compiler_digest);
    if not carried {
        return False;
    }
    write_module_cache(resolved, None, extra_sections=carried);
    self._event("native_carry");
    return True;
}

impl NativeUnitRegistry._module_jir(
    resolved: str, stamp: (NativeStamp | None) = None
) -> (tuple[bytes, str] | None) {
    try {
        cache_path = get_module_cache_path(resolved);
        why = module_cache_invalid_reason(resolved, cache_path);
        data = b"" if why else read_jir(cache_path);
        if stamp is not None
            and native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp)
                is None
            and self._carry(resolved, stamp) {
            why = module_cache_invalid_reason(resolved, cache_path);
            data = b"" if why else read_jir(cache_path);
        }
        if not why {
            return (data, "", );
        }
        self._miss(resolved, why);
    } except Exception {}
    try {
        return self.prog._get_compiler()._precompiled_jir_data(resolved);
    } except Exception {
        return None;
    }
}

impl NativeUnitRegistry._entry_fresh(ent: NativeUnitEntry) -> bool {
    """Use the shared source key, including annex membership and content.
        A deleted file differs from a unit that never had a source file.""";
    return ent.source_key == NativeUnitRegistry._source_key(ent.path)
        and ct_dep_text_fresh(ent.compile_deps.decode("utf-8"), ent.compile_deps_base);
}

impl NativeUnitRegistry._register(
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

impl NativeUnitRegistry.record(
    path: str,
    iface: NativeIface,
    options: (CompileOptions | None) = None,
    dep_digests: (dict[str, str] | None) = None,
    compile_deps: bytes = b""
) -> NativeUnitEntry {
    resolved = os.path.realpath(path);
    ent = self._register(resolved, iface, self.stamp_for(options, resolved), "compile");
    ent.compile_deps = compile_deps;
    ent.dep_digests = dict(dep_digests or {});
    gen = self._live_gen(resolved);
    if gen is not None {
        ent.object_bytes = gen.native_object;
        ent.bitcode = gen.native_bitcode;
    }
    return ent;
}

impl NativeUnitRegistry.record_module(
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
    import from jaclang.compiler.driver.compile_options { env_na_debug }
    if env_na_debug() {
        self._explain_iface_change(module.loc.mod_path, gen.native_iface, options);
    }
    ent = self.record(
        module.loc.mod_path,
        gen.native_iface,
        options,
        dep_digests=self.dep_digests(list(gen.native_deps or [])),
        compile_deps=module_ct_deps_section(module) or b""
    );
    ent.object_bytes = gen.native_object;
    ent.bitcode = gen.native_bitcode;
    return ent;
}

impl NativeUnitRegistry._explain_iface_change(
    path: str, iface: NativeIface, options: (CompileOptions | None)
) {
    resolved = os.path.realpath(path);
    try {
        data = read_jir(get_module_cache_path(resolved));
    } except Exception {
        return;
    }
    stamp = self.stamp_for(options or self._options(), resolved);
    prior = NativeIface.from_bytes(
        native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp)
    );
    if prior is None or prior.digest() == iface.digest() {
        return;
    }
    changes: list[str] = [];
    import json;
    _interface_changes(
        json.loads(json.dumps(prior.digest_fields())),
        json.loads(json.dumps(iface.digest_fields())),
        "",
        changes
    );
    sys.stderr.write(
        f"[native cache] interface of {resolved} changed: {'; '.join(changes[:8])}"
            + (f" (+{len(changes) - 8} more)" if len(changes) > 8 else "")
            + "\n"
    );
}

impl NativeUnitRegistry.recorded_native_deps(
    path: str, options: (CompileOptions | None) = None
) -> list[tuple[str, str]] {
    resolved = os.path.realpath(path);
    live = self.entries.get(resolved);
    stamp = self.stamp_for(options, resolved);
    if live is not None and live.stamp.matches(stamp) {
        return sorted(live.dep_digests.items());
    }
    found = self._module_jir(resolved, stamp);
    if found is None {
        return [];
    }
    return read_native_dep_hashes(found[0], stamp, found[1], resolved);
}

impl NativeUnitRegistry._deps_match(
    dep_digests: list[tuple[str, str]], options: (CompileOptions | None) = None
) -> bool {
    """Whether each direct dependency still has the interface the unit was
    lowered against. A dependency counts as it stands, its own
    dependencies unchecked: a dependency that is stale may lower to the
    same interface, so judging its consumers by its staleness would
    rebuild everything above it. The link plan lowers dependencies before
    their consumers and settles cycle peers once their interfaces are
    final.""";
    for (dep, recorded) in dep_digests {
        ent = self.ensure(
            dep, compile_on_miss=False, options=options, check_deps=False
        );
        if ent is None or ent.digest != recorded {
            return False;
        }
    }
    return True;
}

impl NativeUnitRegistry.dep_digests(paths: list[str]) -> dict[str, str] {
    out: dict[str, str] = {};
    for p in paths {
        real = os.path.realpath(p);
        out[real] = self.known_digest(real);
    }
    return out;
}

impl NativeUnitRegistry._dep_miss(resolved: str) {
    self._event("native_dep_miss");
    self._miss(resolved, "a dependency's native interface changed");
}

impl NativeUnitRegistry._read_from_disk(
    resolved: str,
    stamp: NativeStamp,
    check_deps: bool,
    options: (CompileOptions | None) = None
) -> (NativeUnitEntry | None) {
    found = self._module_jir(resolved, stamp);
    if found is None {
        return None;
    }
    (data, base_dir) = found;
    payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
    iface = NativeIface.from_bytes(payload);
    if iface is None {
        self._miss(resolved, "no native products for this codegen");
        return None;
    }
    compile_deps = native_section_payload(read_section_bytes(data, SEC_NCTDEPS), stamp);
    if compile_deps is None {
        self._event("native_comptime_miss");
        self._miss(resolved, "no comptime dependency record for this codegen");
        return None;
    }
    if not ct_dep_text_fresh(compile_deps.decode("utf-8"), base_dir) {
        self._event("native_comptime_miss");
        self._miss(
            resolved,
            "comptime dependency changed: "
                + ", ".join(stale_ct_dep_rows(compile_deps.decode("utf-8"), base_dir))
        );
        return None;
    }
    iface.resolve_deps(resolved);
    dep_digests = read_native_dep_hashes(data, stamp, base_dir, resolved);
    if check_deps and not self._deps_match(dep_digests, options) {
        self._dep_miss(resolved);
        return None;
    }
    ent = self._register(resolved, iface, stamp, "disk");
    ent.compile_deps = compile_deps;
    ent.compile_deps_base = base_dir;
    ent.dep_digests = dict(dep_digests);
    ent.deps_checked = check_deps;
    ent.object_bytes = native_section_payload(
        read_section_bytes(data, SEC_NOBJ), stamp
    );
    ent.bitcode = native_section_payload(read_section_bytes(data, SEC_NBITCODE), stamp);
    return ent;
}

impl NativeUnitRegistry.ensure(
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
    stale_deps = False;
    if ent is not None and ent.stamp.matches(stamp) and self._entry_fresh(ent) {
        """An entry read for a consumer's check is unchecked itself; a
        caller that asks for checked dependencies checks them before
        relying on it.""";
        if not check_deps or ent.deps_checked {
            return ent;
        }
        if self._deps_match(sorted(ent.dep_digests.items()), options) {
            ent.deps_checked = True;
            return ent;
        }
        self._dep_miss(resolved);
        stale_deps = True;
    }
    if ent is not None {
        del self.entries[resolved];
    }
    if resolved in self.building {
        return None;
    }
    (rebuild, _) = cache_mode();
    if not stale_deps and not rebuild and not options.no_ir_cache and not self.cold {
        found = self._read_from_disk(
            resolved, stamp, check_deps=check_deps, options=options
        );
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

impl NativeUnitRegistry.dep_iface(
    path: str, options: CompileOptions, products: bool = True
) -> (NativeIface | None) {
    """The interface a unit being lowered consumes from a dependency.
        While a session discovers a unit's dependencies, a dependency with no
        entry yet is recorded for the session to lower first instead of being
        lowered inside the consumer's pass: a nested lowering keeps every
        consumer's partial IR alive down the whole import chain.""";
    resolved = os.path.realpath(path);
    session = self.session;
    if session is not None and resolved in session.unlowerable {
        return None;
    }
    if session is not None and session.discovering() {
        ent = self.ensure(
            resolved,
            compile_on_miss=False,
            options=options,
            check_deps=False,
            products=products
        );
        if ent is not None {
            return ent.iface;
        }
        if resolved not in self.building
            and os.path.isfile(resolved)
            and self.not_native.get(resolved)
                != NativeUnitRegistry._source_key(resolved) {
            session.defer(resolved);
        }
        return None;
    }
    ent = self.ensure(
        resolved,
        compile_on_miss=True,
        options=options,
        check_deps=False,
        products=products
    );
    return ent.iface if ent is not None else None;
}

impl NativeUnitRegistry.dep_discovery_open -> bool {
    return self.session is not None and self.session.discovering();
}

impl NativeUnitRegistry.close_dep_deferral -> bool {
    """End dependency discovery for the unit being lowered; True when it
        deferred a dependency, so its lowering stops before emitting code.""";
    return self.session.close_discovery() if self.session is not None else False;
}

impl NativeUnitRegistry.known_native_deps(
    path: str, options: CompileOptions
) -> list[str] {
    resolved = os.path.realpath(path);
    ent = self.entries.get(resolved);
    stamp = self.stamp_for(options, resolved);
    if ent is not None and ent.stamp.matches(stamp) {
        return sorted(os.path.realpath(d) for d in ent.iface.deps);
    }
    found = self._module_jir(resolved, stamp);
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

impl NativeUnitRegistry.product_sections(path: str) -> dict[int, bytes] {
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

impl NativeUnitRegistry.compile_unit(
    path: str,
    options: (CompileOptions | None) = None,
    use_str: (str | None) = None,
    products: bool = True
) -> (NativeUnitEntry | None) {
    """Lower a unit and, when `products` is set, optimize, emit and persist
        its products. An analysis-only consumer needs the interface and
        layouts that lowering records; a build that later needs the products
        gets them through `bitcode_for` or `object_for`.""";
    if self.session is not None {
        if self.session.discovery_open {
            self._event("native_nested_lower");
        }
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

impl NativeUnitRegistry.adopt_lowered(
    path: str,
    ir_text: str,
    iface_text: str,
    layout_json: str,
    deps: list[str],
    compile_deps: bytes,
    options: (CompileOptions | None) = None
) -> (NativeUnitEntry | None) {
    import json;
    opts = options if options is not None else self._options();
    resolved = os.path.realpath(path);
    iface = NativeIface.from_bytes(iface_text.encode("utf-8"));
    if iface is None {
        self.failures[resolved] = (
            "the kernel returned a native interface that does not decode"
        );
        return None;
    }
    iface.resolve_deps(resolved);
    fallbacks = native_fallbacks_in_ir(ir_text);
    if opts.native_required_for(resolved) {
        fallbacks.require();
    }
    if opts.debug_ir {
        import from jaclang.compiler.frontend.host { active_host }
        active_host().save_native_debug_ir(resolved, ir_text);
    }
    debug = bool(opts.native_debug);
    bitcode = optimize_unit_ir(ir_text, opts, 0 if debug else int(opts.opt_level or 0));
    carrier = self.prog.hub.artifacts.get(resolved);
    if carrier is None {
        carrier = CodeGenTarget();
        self.prog.hub.artifacts[resolved] = carrier;
    }
    carrier.llvm_ir = ir_text;
    carrier.native_fallbacks = fallbacks;
    carrier.native_iface = iface;
    carrier.native_bitcode = bitcode;
    carrier.native_object = emit_unit_object(bitcode, opts) if debug else None;
    carrier.native_layout = native_layout_from_dict(json.loads(layout_json))
        if layout_json
        else None;
    carrier.native_deps = list(deps);
    ent = self.record(
        resolved,
        iface,
        opts,
        dep_digests=self.dep_digests(list(deps)),
        compile_deps=compile_deps
    );
    ent.bitcode = bitcode;
    ent.object_bytes = carrier.native_object;
    self.note_codegen(resolved, debug);
    return ent;
}

impl NativeUnitRegistry._stash_products(resolved: str, gen: CodeGenTarget) {
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

impl NativeUnitRegistry.known_digest(path: str) -> str {
    resolved = os.path.realpath(path);
    ent = self.entries.get(resolved);
    if ent is not None {
        return ent.digest;
    }
    stamp = self.stamp_for(None, resolved);
    found = self._module_jir(resolved, stamp);
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
    payload = native_section_payload(raw, stamp);
    if payload is None and env_na_debug() {
        import sys;
        sys.stderr.write(
            f"NA_DEBUG known_digest {resolved}: no native interface for {stamp.key()}\n"
        );
    }
    return NativeIface.verified_digest(payload) or "";
}

impl NativeUnitRegistry._with_products(
    path: str, options: (CompileOptions | None) = None
) -> (NativeUnitEntry | None) {
    """The unit's entry with its products. Products a closure release
    dropped come back from the module cache while it holds the entry's
    interface; a unit with none there is compiled again.""";
    ent = self.ensure(path, options=options, check_deps=False);
    if ent is None or ent.bitcode is not None or ent.object_bytes is not None {
        return ent;
    }
    found = self._module_jir(ent.path, ent.stamp);
    if found is not None {
        data = found[0];
        cached = native_section_payload(
            read_section_bytes(data, SEC_NIFACE), ent.stamp
        );
        if NativeIface.verified_digest(cached) == ent.digest {
            ent.bitcode = native_section_payload(
                read_section_bytes(data, SEC_NBITCODE), ent.stamp
            );
            ent.object_bytes = native_section_payload(
                read_section_bytes(data, SEC_NOBJ), ent.stamp
            );
        }
    }
    if ent.bitcode is None and ent.object_bytes is None {
        return self.compile_unit(path, options);
    }
    return ent;
}

impl NativeUnitRegistry.emit_objects(
    paths: list[str], options: (CompileOptions | None) = None
) {
    pending: list[NativeUnitEntry] = [];
    bitcodes: list[bytes] = [];
    for path in paths {
        ent = self._with_products(path, options);
        if ent is not None and ent.object_bytes is None and ent.bitcode is not None {
            pending.append(ent);
            bitcodes.append(ent.bitcode);
        }
    }
    if len(pending) < 2 {
        return;
    }
    import from jaclang.compiler.backends.native.na_compile_pass { emit_unit_objects }
    import from jaclang.compiler.driver.jir { write_module_cache }
    opts = options if options is not None else self._options();
    started = self.note_step("emit", detail=f"{len(pending)} objects in parallel");
    objects = emit_unit_objects(bitcodes, opts);
    self._timed("NATIVE_EMIT", started);
    self.note_slow_step("emitting", "", started);
    for (ent, object_bytes) in zip(pending, objects) {
        ent.object_bytes = object_bytes;
        self._event("native_object_emit");
        write_module_cache(
            ent.path, None, extra_sections=self.product_sections(ent.path)
        );
    }
}

impl NativeUnitRegistry.object_for(
    path: str, options: (CompileOptions | None) = None
) -> (bytes | None) {
    ent = self._with_products(path, options);
    if ent is not None and ent.object_bytes is None {
        if ent is not None and ent.bitcode is not None {
            import from jaclang.compiler.backends.native.na_compile_pass {
                emit_unit_object
            }
            import from jaclang.compiler.driver.jir { write_module_cache }
            opts = options if options is not None else self._options();
            started = self.note_step("emit", ent.path);
            ent.object_bytes = emit_unit_object(ent.bitcode, opts);
            self._timed("NATIVE_EMIT", started);
            self.note_slow_step("emitting", ent.path, started);
            self._event("native_object_emit");
            write_module_cache(
                ent.path, None, extra_sections=self.product_sections(ent.path)
            );
        }
    }
    return ent.object_bytes if ent is not None else None;
}

impl NativeUnitRegistry.bitcode_for(
    path: str, options: (CompileOptions | None) = None
) -> (bytes | None) {
    ent = self._with_products(path, options);
    if ent is not None and ent.bitcode is None {
        ent = self.compile_unit(path, options);
    }
    return ent.bitcode if ent is not None else None;
}

impl NativeUnitRegistry._live_gen(resolved: str) -> (CodeGenTarget | None) {
    mod = self.prog.find_module(resolved);
    if mod is not None and mod.gen is not None and mod.gen.native_iface is not None {
        return mod.gen;
    }
    return self.prog.hub.artifacts.get(resolved);
}

impl SessionHeap.take -> bool {
    if self.held {
        return True;
    }
    if self.declined {
        return False;
    }
    if _HEAP_HELD[0]
        or not gc.isenabled()
        or os.environ.get("JAC_GC_NO_COMPILE_BOOST")
        or gc.get_freeze_count() > 0 {
        self.declined = True;
        return False;
    }
    _HEAP_HELD[0] = True;
    self.held = True;
    import from jaclang.compiler.driver.compiler { COMPILE_GC_THRESHOLDS }
    self.thresholds = gc.get_threshold();
    if self.thresholds[0] < COMPILE_GC_THRESHOLDS[0] {
        gc.set_threshold(*COMPILE_GC_THRESHOLDS);
    }
    return True;
}

impl SessionHeap.settle -> float {
    if not self.held {
        return 0.0;
    }
    started = time.perf_counter();
    gc.collect();
    gc.freeze();
    return time.perf_counter() - started;
}

impl SessionHeap.release {
    if not self.held {
        return;
    }
    self.held = False;
    _HEAP_HELD[0] = False;
    gc.unfreeze();
    gc.set_threshold(*self.thresholds);
}

impl NativeBuildSession.discovering -> bool {
    return bool(self.discovery_open) and self.discovery_open[-1];
}

impl NativeBuildSession.defer(path: str) {
    self.deferred[-1].add(path);
}

impl NativeBuildSession.close_discovery -> bool {
    if not self.discovering() {
        return False;
    }
    self.discovery_open[-1] = False;
    return bool(self.deferred[-1]);
}

impl NativeBuildSession.postinit {
    self.prog = JacProgram();
    self.prog.options = self.options.clone_for_native_import();
    self.prog._natives = self.registry;
    if self.registry.cold {
        self.prog.iface_registry().cold = True;
    }
}

impl NativeBuildSession.settle_heap {
    if self.heap.held and not self.discovery_open {
        self.registry._add_time("NATIVE_GC_SETTLE", self.heap.settle());
    }
}

impl NativeBuildSession.lower(
    path: str, use_str: (str | None) = None
) -> (NativeUnitEntry | None) {
    resolved = os.path.realpath(path);
    if resolved in self.registry.building {
        return None;
    }
    self.heap.take();
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
            started = self.registry.note_step("analyze", resolved);
            mod = self.prog.compile(resolved, use_str=use_str, options=opts);
            self.registry._timed("NATIVE_ANALYSIS", started);
            self.registry._event("native_unit_analysis");
            self.registry.note_slow_step("analyzing", resolved, started);
            self.settle_heap();
        }
        if len(self.prog.errors_had) > errors_before {
            return None;
        }
        opts.no_cgen = False;
        self.prog.options = opts;
        set_effective_default_codespace("native");
        import from jaclang.compiler.driver.pipeline { invalidate, require }
        import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
        discover = True;
        attempted: set[str] = set();
        while True {
            invalidate(self.prog, mod, CompilationProduct.NATIVE_LOWER);
            warnings_before = len(self.prog.warnings_had);
            started = self.registry.note_step("lower", resolved);
            self.deferred.append(set());
            self.discovery_open.append(discover);
            try {
                require(self.prog, mod, CompilationProduct.NATIVE_LOWER);
            } finally {
                pending = self.deferred.pop();
                self.discovery_open.pop();
            }
            self.registry._timed_unit("NATIVE_LOWER", resolved, started);
            if not pending {
                break;
            }
            del self.prog.errors_had[errors_before:];
            del self.prog.warnings_had[warnings_before:];
            invalidate(self.prog, mod, CompilationProduct.NATIVE_LOWER);
            lowered_any = False;
            for dep in sorted(pending - attempted) {
                attempted.add(dep);
                if self.registry.ensure(
                    dep, compile_on_miss=False, options=opts, check_deps=False
                )
                    is not None
                    or self.lower(dep) is not None {
                    lowered_any = True;
                } else {
                    self.unlowerable.add(dep);
                }
            }
            discover = lowered_any;
        }
        self.registry._event("native_unit_lower");
        self.registry.note_slow_step("lowering", resolved, started);
        if len(self.prog.errors_had) > errors_before or mod.gen.native_iface is None {
            if mod.gen.native_refusal {
                self.registry.failures[resolved] = mod.gen.native_refusal;
            } elif mod.gen.native_iface is None {
                self.registry.failures[resolved] = (
                    "lowering produced no native interface: the module has "
                    "no native code of its own, so it is not a link unit"
                );
            }
            return None;
        }
        import from jaclang.compiler.backends.native.na_compile_pass {
            settle_unit_ir,
            unit_function_counts
        }
        settle_unit_ir(mod);
        self.registry.unit_functions[resolved] = unit_function_counts(mod.gen.llvm_ir);
        self.lowered[resolved] = mod;
        ent = self.registry.record_module(mod, opts);
        self.registry._stash_products(resolved, mod.gen);
        self.settle_heap();
        self.registry.lowered_units += 1;
        if 0 < self.registry.stop_after <= self.registry.lowered_units {
            raise NativeBuildStopped();
        }
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
                alert.pretty_print() for alert in self.prog.errors_had[errors_before:]
            );
        }
        self.registry.building.discard(resolved);
        self.prog.options = prior_options;
        set_effective_default_codespace(prior_codespace);
        pop_native_target(target_token);
        reset_native_unit_compile(unit_token);
    }
}

impl NativeBuildSession.unbound_symbols(
    path: str, deps: list[str]
) -> (list[str] | None) {
    consumer = self.lowered.get(os.path.realpath(path));
    if consumer is None {
        return None;
    }
    bound = _ir_symbols(consumer.gen.llvm_ir);
    if bound is None {
        return None;
    }
    declared = bound[1];
    unbound: set[str] = set();
    for dep in deps {
        real = os.path.realpath(dep);
        provider = self.lowered.get(real);
        ent = self.registry.entries.get(real);
        provided = _ir_symbols(provider.gen.llvm_ir if provider is not None else None);
        if provided is None or ent is None {
            return None;
        }
        defined = provided[0];
        prefix = f"{ent.iface.prefix}." if ent.iface.prefix else "";
        for symbol in declared {
            if symbol not in defined
                and (
                    (prefix and symbol.startswith(prefix))
                    or (symbol + DEMOTED_SYMBOL_SUFFIX) in defined
                ) {
                unbound.add(symbol);
            }
        }
    }
    if unbound {
        used = _ir_referenced_symbols(consumer.gen.llvm_ir);
        unbound = {
            symbol
            for symbol in unbound
            if symbol in used
        };
    }
    return sorted(unbound);
}

impl NativeBuildSession.finish(paths: list[str]) {
    token = push_native_target(self.options.native_target or "");
    try {
        self._finish(paths);
    } finally {
        pop_native_target(token);
    }
}

impl NativeBuildSession._optimize_in_parallel(paths: list[str]) -> set[str] {
    """Ahead-of-time units with no cached bitcode are optimized together
        on a thread pool; each worker parses into its own LLVM context.""";
    opts = self.prog.options;
    if opts.native_debug
        or opts.dump_ir_path
        or not (opts.aot_mode or opts.skip_native_engine) {
        return set();
    }
    todo: list[tuple[str, Module]] = [];
    for path in paths {
        mod = self.lowered.get(path);
        if mod is None or mod.gen.llvm_ir is None {
            continue;
        }
        cached = self.registry.ensure(path, compile_on_miss=False, options=opts);
        if cached is not None and cached.bitcode is not None {
            continue;
        }
        if opts.native_required_for(path) {
            unit_fallbacks(mod.gen).require();
        }
        todo.append((path, mod));
    }
    if len(todo) < 2 {
        return set();
    }
    started = self.registry.note_step(
        "optimize", detail=f"{len(todo)} units in parallel"
    );
    bitcodes = optimize_unit_bitcodes(
        [unit_bitcode(mod.gen.llvm_ir) for (_, mod) in todo],
        opts,
        int(opts.opt_level or 0)
    );
    self.registry._timed("NATIVE_OPTIMIZE", started);
    self.registry.note_slow_step("optimizing", "", started);
    for ((path, mod), bitcode) in zip(todo, bitcodes) {
        mod.gen.native_bitcode = bitcode;
        self.registry.note_codegen(path, False);
    }
    return {path for (path, _) in todo};
}

impl NativeBuildSession._finish(paths: list[str]) {
    """Optimize and persist only after every consumed interface agrees.
        Cyclic interface settlement reuses the analyzed trees and never emits
        optimized products for an intermediate state.""";
    import from jaclang.compiler.driver.pipeline { require }
    import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
    self.prog.options = self.options.clone_for_native_import();
    for path in paths {
        if path in self.source_keys
            and self.source_keys[path] != NativeUnitRegistry._source_key(path) {
            raise RuntimeError(f"native source changed during analysis: {path}");
        }
    }
    optimized = self._optimize_in_parallel(paths);
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
        errors_before = len(self.prog.errors_had);
        if path not in optimized {
            started = self.registry.note_step("optimize", path);
            require(self.prog, mod, CompilationProduct.NATIVE_OBJECT);
            self.registry._timed("NATIVE_OPTIMIZE", started);
            self.registry.note_slow_step("optimizing", path, started);
        }
        if len(self.prog.errors_had) > errors_before
            or mod.gen.native_bitcode is None {
            reasons = "\n".join(
                str(err) for err in self.prog.errors_had[errors_before:]
            );
            raise RuntimeError(
                f"native product emission failed for {path}"
                    + (f":\n{reasons}" if reasons else "")
            );
        }
        self.registry.record_module(mod, self.prog.options);
        self.registry._stash_products(path, mod.gen);
        self.prog._get_compiler()._persist_native_unit(path, mod, self.prog);
    }
}

impl NativeBuildSession.close {
    try {
        for (phase, seconds) in self.prog.analysis.phase_time.items() {
            self.registry._add_time("NATIVE_FRONTEND_" + phase, seconds);
        }
        self.lowered.clear();
        self.source_keys.clear();
        self.prog._natives = None;
        self.prog.release_compile_closure();
    } finally {
        self.heap.release();
    }
}

impl _ir_symbols(unit_ir: any) -> (tuple[set[str], set[str]] | None) {
    if unit_ir is None
        or not hasattr(unit_ir, "functions")
        or not hasattr(unit_ir, "global_variables") {
        return None;
    }
    defined: set[str] = set();
    declared: set[str] = set();
    for value in list(unit_ir.functions) + list(unit_ir.global_variables) {
        if value.is_declaration {
            declared.add(str(value.name));
        } else {
            defined.add(str(value.name));
        }
    }
    return (defined, declared);
}

impl _ir_referenced_symbols(unit_ir: any) -> set[str] {
    import re;
    used: set[str] = set();
    for line in str(unit_ir).splitlines() {
        if line.startswith("declare ") {
            continue;
        }
        for (quoted, bare) in re.findall(
            r'@(?:"([^"]+)"|([-a-zA-Z$._][-a-zA-Z$._0-9]*))', line
        ) {
            used.add(quoted or bare);
        }
    }
    return used;
}

impl _interface_changes(before: any, after: any, path: str, out: list[str]) {
    if before == after {
        return;
    }
    if isinstance(before, dict) and isinstance(after, dict) {
        for key in sorted(set(before.keys()) | set(after.keys()), key=str) {
            where = f"{path}.{key}" if path else str(key);
            if key not in before {
                out.append(f"{where}: added");
            } elif key not in after {
                out.append(f"{where}: removed");
            } else {
                _interface_changes(before[key], after[key], where, out);
            }
        }
        return;
    }
    if isinstance(before, list)
        and isinstance(after, list)
        and len(before) == len(after) {
        for (index, (item_before, item_after)) in enumerate(zip(before, after)) {
            _interface_changes(item_before, item_after, f"{path}[{index}]", out);
        }
        return;
    }
    out.append(f"{path}: {str(before)[:60]} -> {str(after)[:60]}");
}
