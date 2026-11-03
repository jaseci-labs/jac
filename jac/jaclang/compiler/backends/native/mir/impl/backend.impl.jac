impl mir_runtime_unit_paths -> list[str] {
    pkg = jaclang_pkg_root();
    return [os.path.realpath(os.path.join(pkg, rel)) for rel in MIR_RUNTIME_UNITS];
}

impl MirNativePass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
}

impl MirNativePass._run_impl(ir_in: uni.Module) -> uni.Module {
    path = ir_in.loc.mod_path;
    if not ModuleFacts.has_native_context_stmts(ir_in) {
        return ir_in;
    }
    mir = MirModule(path=path, prefix=native_unit_prefix(path));
    lowering = MirLowering(prog=self.prog, module=ir_in, mir=mir);
    try {
        lowered = lowering.lower();
    } except Exception as exc {
        self.report_crash(lowering, exc);
        return ir_in;
    }
    self.report_c_conflicts(lowering);
    runtime = mir_runtime_unit_paths();
    here = os.path.realpath(path);
    if self.native_required(path) {
        self.report_refusals(lowering);
        if self.ctx.errors_had {
            return ir_in;
        }
    } elif ir_in.gen.placement_mode == "inferred"
        and not native_placement_hard(self.prog, path) {
        if self.settle_soft(lowering) {
            return ir_in;
        }
        if ir_in.decided_codespace == "native" {
            self.note_demotions(lowering, ir_in.gen.native_iface);
        }
    } else {
        if self.refuse_events(lowering) {
            return ir_in;
        }
        self.note_demotions(lowering, ir_in.gen.native_iface);
    }
    lowering.current = os.path.basename(path);
    lowering.state = None;
    deps: list[str] = [];
    triple = "";
    try {
        for fn in lowered.functions {
            mir_insert_rc(fn);
        }
        mir_lower_generators(lowered);
        for binding in lowering.bindings {
            ir_in.gen.interop_manifest.bindings[binding.name] = binding;
        }
        later: list[str] = [];
        if here in runtime {
            later = runtime[runtime.index(here):];
            runtime = runtime[:runtime.index(here)];
        }
        deps = [
            unit
            for unit in runtime + lowered.deps
            if unit != here and unit not in later
        ];
        target = active_host().native_fact(
            FACT_TARGET, self.prog.options.native_target or ""
        ).split(
            FACT_SEP
        );
        triple = target[1]
            if len(target) > 1 and target[1]
            else self.prog.options.effective_triple();
        ir_in.gen.llvm_ir = emit_mir_module(
            lowered, triple, bool(self.prog.options.native_tls), target[0]
        );
    } except Exception as exc {
        self.report_crash(lowering, exc);
        return ir_in;
    }
    ir_in.gen.native_deps = list(deps);
    ir_in.gen.native_layout = self.layout(lowering, lowered);
    ir_in.gen.native_iface = self.interface(lowered, deps, triple);
    ir_in.gen.native_iface.layout = ir_in.gen.native_layout;
    return ir_in;
}

impl MirNativePass.native_required(path: str) -> bool {
    options = self.prog.options;
    return options.native_required_for(path)
        or bool(options.kernel_build)
        or is_kernel_unit_path(path)
        or os.path.realpath(path) in mir_runtime_unit_paths();
}

impl MirNativePass.report_crash(lowering: MirLowering, exc: Exception) {
    name = lowering.current or os.path.basename(lowering.module.loc.mod_path);
    if lowering.state is not None {
        name = lowering.state.fn.name;
    }
    kind = "module"
        if name == os.path.basename(lowering.module.loc.mod_path)
        else "function";
    site: uni.UniNode = lowering.module;
    for decl in lowering.decls.values() {
        if not decl.event and lowering.decl_label(decl) == name {
            site = decl.ability;
            break;
        }
    }
    self.ctx.emit(
        E9003,
        node_override=site,
        kind=kind,
        name=name,
        details=f"{type(exc).__name__}: {exc}"
    );
}

impl MirNativePass.report_c_conflicts(lowering: MirLowering) {
    for (site, name, reason) in lowering.c_conflicts {
        self.ctx.emit(E1158, node_override=site, name=name, reason=reason);
    }
}

impl MirNativePass.report_refusals(lowering: MirLowering) {
    here = os.path.realpath(lowering.module.loc.mod_path);
    for (name, refusals) in lowering.refusals.items() {
        for refusal in refusals {
            site = refusal.site;
            shown = refusal.name;
            if site is not None and os.path.realpath(site.loc.mod_path) != here {
                shown = f"{refusal.name} (at {site.loc.mod_path}:{site.loc.first_line}, reached from {mir_demoted_name(
                    lowering.mir, name
                )})";
                site = None;
            }
            self.ctx.emit(
                E5092,
                node_override=site or lowering.module,
                kind=refusal.kind,
                name=shown,
                help_text=refusal.help
            );
        }
    }
}

impl MirNativePass.settle_soft(lowering: MirLowering) -> bool {
    module = lowering.module;
    mir = lowering.mir;
    here = os.path.realpath(module.loc.mod_path);
    whole = module.decided_codespace == "native";
    owners: dict[str, uni.UniNode] = {};
    events: set[str] = set();
    for decl in lowering.decls.values() {
        owners.setdefault(decl.symbol, decl.ability);
        if decl.event {
            events.add(decl.symbol);
        }
    }
    for elem in module.body {
        if isinstance(elem, uni.ModuleCode) {
            owners.setdefault(native_entry_name(module.loc.mod_path), elem);
        } elif isinstance(elem, uni.GlobalVars) {
            owners.setdefault(native_glob_init_name(module.loc.mod_path), elem);
        }
    }
    reported = False;
    for (key, refusals) in lowering.refusals.items() {
        for refusal in refusals {
            site = refusal.site;
            if site is module
                or (site is not None and os.path.realpath(site.loc.mod_path) != here) {
                site = None;
            }
            anchor = site or owners.get(key);
            if not mir_soft_blocks(
                mir_top_element(module, anchor), whole, key in events
            ) {
                continue;
            }
            self.ctx.emit(
                E5092,
                node_override=anchor or module,
                kind=refusal.kind,
                name=refusal.name,
                help_text=refusal.help
            );
            reported = True;
        }
    }
    for (symbol, reason) in mir.demoted.items() {
        anchor = owners.get(symbol);
        if symbol in lowering.refusals or anchor is None {
            continue;
        }
        if not mir_soft_blocks(
            mir_top_element(module, anchor), whole, symbol in events
        ) {
            continue;
        }
        self.ctx.emit(
            E5092,
            node_override=anchor,
            kind="function",
            name=mir_demoted_name(mir, symbol),
            help_text=f"It {reason}, so it cannot run natively."
        );
        reported = True;
    }
    if not reported {
        return False;
    }
    settle_native_module(module, self.prog, self.ctx.errors_had, self.ctx.warnings_had);
    return True;
}

impl MirNativePass.refuse_events(lowering: MirLowering) -> bool {
    refused = False;
    for decl in lowering.decls.values() {
        if not decl.event or decl.symbol not in lowering.mir.demoted {
            continue;
        }
        found = lowering.refusals.get(decl.symbol, []);
        why = found[0].headline() if found else lowering.mir.demoted[decl.symbol];
        hint = found[0].help if found and found[0].help else "";
        self.ctx.emit(
            E5092,
            node_override=decl.ability,
            kind="event ability",
            name=lowering.decl_label(decl),
            help_text=(hint + " " if hint else "")
                + f"This ability could not be lowered ({why}). A walker runs its abilities through the native graph engine, which has no caller to refuse, so the module cannot stay native with it."
        );
        refused = True;
    }
    return refused;
}

impl MirNativePass.note_demotions(lowering: MirLowering, prior: (NativeIface | None)) {
    mir = lowering.mir;
    noted = set(prior.demoted) if prior is not None else set();
    if not mir.demoted {
        return;
    }
    here = os.path.realpath(mir.path);
    shown = self.prog.native_units().noted_demotions;
    options = self.prog.options;
    debug = bool(options.na_debug);
    warn = debug or bool(options.native_debug);
    if not warn {
        defaults = active_host().project_defaults();
        warn = defaults.check.warn_native_seams if defaults is not None else True;
    }
    if not warn {
        return;
    }
    for (symbol, reason) in sorted(mir.demoted.items()) {
        name = mir_demoted_name(mir, symbol);
        if name in noted or shown.get(f"{here}:{name}") == reason {
            continue;
        }
        shown[f"{here}:{name}"] = reason;
        found = lowering.refusals.get(symbol, []);
        why = "; ".join(refusal.located() for refusal in found) if found else reason;
        if debug {
            sys.stderr.write(f"NA_DEBUG demote {name}\n");
            for refusal in found {
                sys.stderr.write(f"NA_DEBUG   {refusal.full()}\n");
            }
        }
        active_host().note(
            f"native seam -- demoting {name} to Python-only (un-lowerable): {why}",
            style="warning"
        );
    }
}

impl mir_demoted_name(mir: MirModule, symbol: str) -> str {
    prefix = mir.prefix + ".";
    return symbol[len(prefix):] if symbol.startswith(prefix) else symbol;
}

impl mir_soft_blocks(top: (uni.UniNode | None), whole: bool, event: bool) -> bool {
    if isinstance(top, uni.ContextAwareNode)
        and top.code_context != CodeContext.NATIVE {
        return False;
    }
    if not whole or event or top is None {
        return True;
    }
    return isinstance(top, (uni.ModuleCode, uni.GlobalVars));
}

impl mir_top_element(
    module: uni.Module, nd: (uni.UniNode | None)
) -> (uni.UniNode | None) {
    cur = nd;
    while cur is not None and cur.parent is not None and cur.parent is not module {
        cur = cur.parent;
    }
    if cur is None or cur.parent is not module {
        return None;
    }
    return cur;
}

impl mir_clib_path(spec: tuple[str, list[str], int], triple: str) -> str {
    (kind, parts, level) = spec;
    if kind == "raw" {
        return parts[0];
    }
    lowered = triple.lower();
    prefix = "lib";
    ext = ".so";
    origin = "$ORIGIN";
    if any(word in lowered for word in ("darwin", "apple", "macos", "ios")) {
        ext = ".dylib";
        origin = "@loader_path";
    } elif any(word in lowered for word in ("windows", "win32", "mingw", "msvc")) {
        prefix = "";
        ext = ".dll";
        origin = ".";
    }
    filename = prefix + parts[-1] + ext;
    if len(parts) > 1 or level > 0 {
        return origin + "/" + "/".join(parts[:-1] + [filename]);
    }
    return filename;
}

impl MirNativePass.interface(
    mir: MirModule, deps: list[str], triple: str = ""
) -> NativeIface {
    exports: dict[str, NativeExport] = {};
    for fn in mir.functions {
        if fn.linkage == "internal" {
            continue;
        }
        held = exports.get(fn.name);
        if held is not None
            and held.symbol in (f"{mir.prefix}.{fn.name}", fn.name)
            and fn.symbol != held.symbol {
            continue;
        }
        exports[fn.name] = NativeExport(
            name=fn.name,
            symbol=fn.symbol,
            kind="test" if fn.name.startswith("__jac_test_") else "function",
            is_pub=fn.symbol in mir.public and fn.symbol not in mir.demoted,
            param_defaults=list(mir.defaults.get(fn.symbol, [])),
            param_names=[p.name for p in fn.params],
            param_types=[p.value.type.render() for p in fn.params],
            ret_type=fn.ret.render()
        );
    }
    return NativeIface(
        module=native_module_key(mir.path),
        prefix=mir.prefix,
        exports=exports,
        deps=list(deps),
        demoted=sorted(
            {
                mir_demoted_name(mir, symbol)
                for symbol in mir.demoted
                if symbol.startswith(mir.prefix + ".") or "." not in symbol
            }
        ),
        python_imports=sorted(mir.python_imports),
        clib_paths=[mir_clib_path(spec, triple) for spec in mir.clib_specs],
        clib_symbol_lib={
            symbol: mir_clib_path(mir.clib_specs[index], triple)
            for (symbol, index) in mir.clib_symbols.items()
        },
        init_symbol=native_glob_init_name(mir.path)
            if mir.function(native_glob_init_name(mir.path)) is not None
            else "",
        entry_symbol=native_entry_name(mir.path)
            if mir.function(native_entry_name(mir.path)) is not None
            else ""
    );
}

impl native_coverage(prog: JacProgram) -> dict[str, dict[str, any]] {
    findings: dict[str, dict[str, any]] = {};
    for module in list(prog.mod.hub.values()) {
        path = module.loc.mod_path if module.loc else "";
        if not path.endswith(".jac") {
            continue;
        }
        lowering = MirLowering(
            prog=prog,
            module=module,
            mir=MirModule(path=path, prefix=native_unit_prefix(path))
        );
        lowered = lowering.lower();
        if not lowered.demoted {
            findings[os.path.realpath(path)] = {
                "outcome": "native",
                "code": "",
                "detail": "",
                "demoted": {}
            };
            continue;
        }
        named = {
            mir_demoted_name(lowered, symbol): reason
            for (symbol, reason) in lowered.demoted.items()
        };
        (first, reason) = sorted(named.items())[0];
        findings[os.path.realpath(path)] = {
            "outcome": "demoted",
            "code": "E5092",
            "detail": f"{first}: {reason}",
            "demoted": named
        };
    }
    return findings;
}

impl MirNativePass.layout(lowering: MirLowering, mir: MirModule) -> NativeModuleLayout {
    made = NativeModuleLayout(str_headerless=False);
    for (name, obj_def) in mir.objects.items() {
        if not obj_def.local {
            continue;
        }
        made.structs[name] = NativeStructLayout(
            name=name,
            fields=[
                NativeFieldInfo(
                    name=member.name,
                    llvm_type=mir_layout_type(member.type),
                    index=member.index,
                    enum_type=member.type.name
                        if member.type.kind == MirKind.ENUM
                        else None
                ) for member in obj_def.fields
            ],
            has_vtable=bool(obj_def.vtable_symbol)
        );
    }
    owners: dict[str, str] = {};
    for decl in lowering.decls.values() {
        if decl.event {
            continue;
        }
        if decl.owner is None {
            owners.setdefault(decl.symbol, "");
        } elif decl.self_type is not None {
            owners.setdefault(decl.symbol, decl.self_type.name);
        }
    }
    for fn in mir.functions {
        owner = owners.get(fn.symbol);
        if fn.linkage == "internal" or fn.symbol in mir.demoted or owner is None {
            continue;
        }
        params = [param.value.type for param in fn.params];
        names = [param.name for param in fn.params];
        ret = fn.ret;
        record = NativeFuncLayout(
            name=fn.symbol,
            param_types=[mir_layout_type(param) for param in params],
            param_names=names,
            ret_type=mir_layout_type(ret),
            ret_struct_name=ret.name
                if ret.kind == MirKind.OBJ and ret.name != "*"
                else None,
            ret_enum_type=mir_layout_enum(ret),
            ret_elem_keys=[mir_layout_key(arg) for arg in ret.args]
                if ret.kind in (MirKind.LIST, MirKind.DICT, MirKind.SET)
                else None
        );
        if owner {
            made.methods[f"{owner}.{fn.name}"] = record;
        } else {
            made.functions[fn.name] = record;
        }
    }
    return made;
}

impl mir_layout_type(t: MirType) -> str {
    if t.kind == MirKind.BOOL {
        return "i1";
    }
    if t.kind == MirKind.INT {
        return f"i{t.width}";
    }
    if t.kind == MirKind.ENUM {
        return "i64";
    }
    if t.kind == MirKind.FLOAT {
        return "f32" if t.width == 32 else "f64";
    }
    if t.kind in (MirKind.NONE, MirKind.VOID) {
        return "void";
    }
    if t.kind == MirKind.STR {
        return "jacstr3";
    }
    if t.kind in (MirKind.OPT, MirKind.OPT_REF) {
        return "opt." + mir_layout_type(t.payload());
    }
    if t.kind == MirKind.TUPLE {
        return "Tuple";
    }
    if t.kind == MirKind.ANY {
        return "JacVal";
    }
    if t.kind == MirKind.OBJ and t.name != "*" {
        return f"{t.name}*";
    }
    if t.kind in (MirKind.LIST, MirKind.DICT, MirKind.SET) {
        family = {MirKind.LIST: "List", MirKind.DICT: "Dict", MirKind.SET: "Set"}[
            t.kind
        ];
        return ".".join([family] + [mir_layout_key(arg) for arg in t.args]) + "*";
    }
    return "i8*";
}

impl mir_layout_key(t: MirType) -> str {
    if t.kind == MirKind.INT and not t.is_sized() {
        return "int";
    }
    if t.kind == MirKind.FLOAT and t.width == 64 {
        return "float";
    }
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        return "str";
    }
    if t.kind in (MirKind.BOOL, MirKind.ANY) {
        return t.kind.value;
    }
    if t.name {
        return t.name;
    }
    return t.render();
}

impl mir_layout_enum(t: MirType) -> (str | None) {
    if t.kind == MirKind.ENUM {
        return t.name;
    }
    if t.kind == MirKind.OPT and t.payload().kind == MirKind.ENUM {
        return t.payload().name;
    }
    return None;
}
