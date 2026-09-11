import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.ir.schema { Module, UniScopeNode }
import from jaclang.compiler.session.cache.catalog_reader { CatModule }

walker InterfaceReferenceTypesPass(ProgramTransform) {
    def transform(ir_in: Module) -> Module {
        if not isinstance(ir_in, CatModule) {
            return ir_in;
        }
        registry = self.prog.iface_registry();
        for (path, dotted) in ir_in.cat.external_class_references() {
            if not dotted {
                continue;
            }
            module = registry.resolve_module(path);
            if module is None {
                module = self.prog.get_type_evaluator()._import_module_from_path(path);
            }
            scope: UniScopeNode | None = module;
            parts = dotted.split('.');
            for part in parts[:-1] {
                if scope is not None {
                    scope = scope.find_scope(part);
                }
            }
            if scope is None {
                continue;
            }
            symbol = scope.names_in_scope.get(parts[-1]);
            if symbol is not None and symbol.decl.type is None {
                if symbol.provider is not None {
                    symbol.provider.resolve_type(symbol);
                } else {
                    self.prog.get_type_evaluator().get_type_of_symbol(symbol);
                }
            }
        }
        return ir_in;
    }
}
