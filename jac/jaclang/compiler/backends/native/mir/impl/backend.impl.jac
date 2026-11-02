impl mir_runtime_unit_paths -> list[str] {
    pkg = jaclang_pkg_root();
    return [os.path.realpath(os.path.join(pkg, rel)) for rel in MIR_RUNTIME_UNITS];
}

impl MirNativePass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
}

impl MirNativePass._run_impl(ir_in: uni.Module) -> uni.Module {
    path = ir_in.loc.mod_path;
    mir = MirModule(path=path, prefix=native_unit_prefix(path));
    lowering = MirLowering(prog=self.prog, module=ir_in, mir=mir);
    lowered = lowering.lower();
    runtime = mir_runtime_unit_paths();
    here = os.path.realpath(path);
    if self.prog.options.native_required_for(path)
        or self.prog.options.force_codespace == "native"
        or here in runtime {
        self.report_refusals(lowering);
        if self.ctx.errors_had {
            return ir_in;
        }
    }
    for fn in lowered.functions {
        mir_insert_rc(fn);
    }
    mir_lower_generators(lowered);
    for binding in lowering.bindings {
        ir_in.gen.interop_manifest.bindings[binding.name] = binding;
    }
    if here in runtime {
        runtime = runtime[:runtime.index(here)];
    }
    deps = [
        unit
        for unit in runtime + lowered.deps
        if unit != here
    ];
    target = active_host().native_fact(
        FACT_TARGET, self.prog.options.native_target or ""
    ).split(FACT_SEP);
    ir_in.gen.llvm_ir = emit_mir_module(
        lowered,
        target[1] if len(target) > 1 and target[1] else self.prog.options.effective_triple(),
        bool(self.prog.options.native_tls),
        target[0]
    );
    ir_in.gen.native_deps = list(deps);
    ir_in.gen.native_layout = self.layout(lowering, lowered);
    ir_in.gen.native_iface = self.interface(lowered, deps);
    ir_in.gen.native_iface.layout = ir_in.gen.native_layout;
    return ir_in;
}

impl MirNativePass.report_refusals(lowering: MirLowering) {
    here = os.path.realpath(lowering.module.loc.mod_path);
    for (name, refusals) in lowering.refusals.items() {
        for refusal in refusals {
            site = refusal.site;
            shown = refusal.name;
            if site is not None and os.path.realpath(site.loc.mod_path) != here {
                shown = f"{refusal.name} (at {site.loc.mod_path}:{site.loc.first_line}, reached from {name})";
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

impl MirNativePass.interface(mir: MirModule, deps: list[str]) -> NativeIface {
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
        demoted=sorted(mir.demoted),
        python_imports=sorted(mir.python_imports),
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
        (first, reason) = sorted(lowered.demoted.items())[0];
        findings[os.path.realpath(path)] = {
            "outcome": "demoted",
            "code": "E5092",
            "detail": f"{first}: {reason}",
            "demoted": dict(lowered.demoted)
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
                )
                for member in obj_def.fields
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
        family = {MirKind.LIST: "List", MirKind.DICT: "Dict", MirKind.SET: "Set"}[t.kind];
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
