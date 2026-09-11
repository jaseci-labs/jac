import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.ir.schema { Module, UniScopeNode, NameAtom, Symbol }
import from jaclang.compiler.analysis.binding.bindings {
    classify_binding,
    classify_storage,
    collect_capture_facts
}

walker BindingFactsPass(ProgramTransform) {
    def transform(ir_in: Module) -> Module {
        nodes = list(ir_in.flatten());
        scopes: list[UniScopeNode] = [
            node
            for node in nodes
            if isinstance(node, UniScopeNode)
        ];
        symbols: set[Symbol] = set();
        for scope in scopes {
            symbols.update(scope.names_in_scope.values());
        }
        collect_capture_facts(ir_in, scopes);
        for name in nodes {
            if isinstance(name, NameAtom) and name.sym is not None {
                symbols.add(name.sym);
            }
        }
        for symbol in symbols {
            symbol.storage = classify_storage(symbol);
            symbol.binding_fact = classify_binding(symbol);
        }
        return ir_in;
    }
}
