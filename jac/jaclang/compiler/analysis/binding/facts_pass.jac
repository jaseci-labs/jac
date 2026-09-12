import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.ir.schema { Module, UniScopeNode, NameAtom, Symbol }
import from jaclang.compiler.analysis.binding.bindings {
    classify_binding,
    classify_storage,
    collect_capture_facts
}

walker BindingFactsPass(ProgramTransform) {
    def transform(ir_in: Module) -> Module {
        scopes: list[UniScopeNode] = [ir_in];
        symbols: set[Symbol] = set();
        for (kind, candidates) in ir_in._sub_node_tab.items() {
            if issubclass(kind, UniScopeNode) {
                scopes.extend(
                    node
                    for node in candidates
                    if isinstance(node, UniScopeNode)
                );
            }
            if issubclass(kind, NameAtom) {
                for name in candidates {
                    if isinstance(name, NameAtom)
                        and (symbol := name.sym) is not None {
                        symbols.add(symbol);
                    }
                }
            }
        }
        for scope in scopes {
            symbols.update(scope.names_in_scope.values());
        }
        collect_capture_facts(ir_in, scopes);
        for symbol in symbols {
            symbol.storage = classify_storage(symbol);
            symbol.binding_fact = classify_binding(symbol);
        }
        return ir_in;
    }
}
