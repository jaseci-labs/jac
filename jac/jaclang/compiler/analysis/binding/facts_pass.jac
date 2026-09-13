import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.ir.schema {
    Module,
    UniNode,
    UniScopeNode,
    NameAtom,
    Symbol
}
import from jaclang.compiler.analysis.binding.bindings {
    classify_binding,
    classify_storage,
    collect_capture_facts
}

walker BindingFactsPass(ProgramTransform) {
    has scopes: list[UniScopeNode] = [],
        symbols: set[Symbol] = set();

    can collect_scope with UniScopeNode entry {
        self.scopes.append(here);
        self.symbols.update(here.names_in_scope.values());
    }

    can collect_name with NameAtom entry {
        if (symbol := here.sym) is not None {
            self.symbols.add(symbol);
        }
    }

    can classify with Symbol entry {
        here.storage = classify_storage(here);
        here.binding_fact = classify_binding(here);
    }

    def transform(ir_in: Module) -> Module {
        scope_nodes: list[UniNode] = [ir_in];
        names: list[UniNode] = [];
        for (kind, nodes) in ir_in._sub_node_tab.items() {
            if issubclass(kind, UniScopeNode) {
                scope_nodes.extend(nodes);
            }
            if issubclass(kind, NameAtom) {
                names.extend(nodes);
            }
        }
        scope_nodes spawn self;
        collect_capture_facts(ir_in, self.scopes);
        if names {
            names spawn self;
        }
        if self.symbols {
            list(self.symbols) spawn self;
        }
        return ir_in;
    }
}
