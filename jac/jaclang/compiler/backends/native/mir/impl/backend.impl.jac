impl mir_backend_selected -> bool {
    return os.environ.get("JAC_NATIVE_MIR", "") == "1";
}

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
    self.report_refusals(lowering);
    if self.ctx.errors_had {
        return ir_in;
    }
    deps = [
        unit
        for unit in mir_runtime_unit_paths()
        if unit != os.path.realpath(path)
    ];
    ir_in.gen.llvm_ir = emit_mir_module(lowered, self.prog.options.effective_triple());
    ir_in.gen.native_deps = list(deps);
    ir_in.gen.native_iface = self.interface(lowered, deps);
    return ir_in;
}

impl MirNativePass.report_refusals(lowering: MirLowering) {
    for (name, refusals) in lowering.refusals.items() {
        for refusal in refusals {
            self.ctx.emit(
                E5092,
                node_override=refusal.site or self.module,
                kind=refusal.kind,
                name=refusal.name,
                help_text=refusal.help
            );
        }
    }
}

impl MirNativePass.interface(mir: MirModule, deps: list[str]) -> NativeIface {
    exports: dict[str, NativeExport] = {};
    for fn in mir.functions {
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
        deps=list(deps)
    );
}
