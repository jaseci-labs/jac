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
    ir_in.gen.native_iface = self.interface(lowered, deps);
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
            kind="function",
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

impl mir_backend_selected -> bool {
    return os.environ.get("JAC_NATIVE_MIR", "") == "1";
}
