import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.enums { CodeContext }

walker ClientDependenciesPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.pipeline.products { require_product }
        import from jaclang.compiler.pipeline.contracts { CompilationProduct }
        import from jaclang.compiler.session.options { CompileOptions }
        if not ir_in.loc.mod_path {
            return ir_in;
        }
        seen: set[str] = set();
        root_path = os.path.realpath(ir_in.loc.mod_path);
        pending: list[str] = [root_path];
        options = self.prog.options;
        dependency_options = CompileOptions(
            no_cgen=True, force_target_program=True, cancel_token=options.cancel_token
        );
        registry = self.prog.iface_registry();
        try {
            while pending {
                path = pending.pop();
                if path in seen {
                    continue;
                }
                seen.add(path);
                module = self.prog.find_module(path);
                manifest = artifact_for(module).interop_manifest
                    if module is not None
                    else None;
                if not (manifest and manifest.bindings) and path != root_path {
                    cached = registry.client_boundary_facts(path);
                    if cached is not None {
                        pending.extend(cached);
                        continue;
                    }
                    if self.prog.has_failed_parse(path) {
                        continue;
                    }
                    module = self.prog.compile(path, options=dependency_options);
                }
                if module is not None {
                    require_product(self.prog, module, CompilationProduct.IMPORTS);
                    pending.extend(
                        edge.target
                        for edge in self.prog.deps.imports.get(path, [])
                        if edge.context == CodeContext.CLIENT
                            and edge.target.endswith('.jac')
                    );
                }
            }
        } finally {
            self.prog.options = options;
        }
        return ir_in;
    }
}
