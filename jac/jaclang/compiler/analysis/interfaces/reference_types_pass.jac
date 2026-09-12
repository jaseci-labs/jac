import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.ir.schema { Module, UniScopeNode }
import from jaclang.compiler.session.cache.catalog_reader { CatModule }

walker InterfaceReferenceTypesPass(ProgramTransform) {
    def transform(ir_in: Module) -> Module {
        self._prepare(ir_in, set());
        return ir_in;
    }

    def _prepare(module: Module | None, seen: set[int]) -> None {
        if not isinstance(module, CatModule) or id(module) in seen {
            return;
        }
        seen.add(id(module));
        registry = self.prog.iface_registry();
        references = module.cat.external_class_references();
        for reference in references {
            if not reference.qualified_name {
                continue;
            }
            target = registry.resolve_module(reference.module_path);
            if target is None {
                target = self.prog.get_type_evaluator()._import_module_from_path(
                    reference.module_path
                );
            }
            self._prepare(target, seen);
            scope: UniScopeNode | None = target;
            parts = reference.qualified_name.split('.');
            for part in parts[:-1] {
                if scope is not None {
                    scope = scope.find_scope(part);
                }
            }
            if scope is None {
                continue;
            }
            symbol = scope.lookup_local(parts[-1]);
            if symbol is not None and symbol.decl.type is None {
                if symbol.provider is not None {
                    symbol.provider.resolve_type(symbol);
                } else {
                    self.prog.get_type_evaluator().get_type_of_symbol(symbol);
                }
            }
        }

        for reference in references {
            module.cat.shared_of(reference.shared_id);
        }
    }
}
