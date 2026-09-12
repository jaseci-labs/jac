import from jaclang.compiler.ir.identity { Multiplicity }
import from jaclang.compiler.ir.identity { GraphNode }
import from jaclang.compiler.ir.base { UniNode }

def validate_connection(source: object, relation: type, target: object) {
    import from jaclang.compiler.ir.schema { relation_spec }
    spec = relation_spec(relation);
    if not isinstance(source, spec.source_types) {
        raise TypeError(
            f"{spec.schema_id} has an invalid source: {type(source).__name__}"
        );
    }
    if not isinstance(target, spec.target_types) {
        raise TypeError(
            f"{spec.schema_id} has an invalid target: {type(target).__name__}"
        );
    }
}

def validate_relations(source: GraphNode) {
    import from jaclang.compiler.ir.schema { relation_catalog }
    relations = relation_catalog();
    outgoing: dict[type, list[GraphNode]] = {};
    anchor = source.__jac__;
    if anchor.out_light is not None {
        for (relation, targets) in anchor.out_light.items() {
            outgoing[relation] = list(targets);
        }
    }
    for edge in anchor.edges {
        if edge.source is anchor and edge.target is not None {
            outgoing.setdefault(type(edge.archetype), []).append(edge.target.archetype);
        }
    }
    for (relation, targets) in outgoing.items() {
        spec = relations.get(relation);
        if spec is None {
            raise ValueError(f"Unregistered compiler relation: {relation.__name__}");
        }
        if spec.multiplicity == Multiplicity.OPTIONAL and len(targets) > 1 {
            raise ValueError(f"{spec.schema_id} permits at most one target");
        }
        for target in targets {
            validate_connection(source, relation, target);
        }
    }
    if isinstance(source, UniNode) {
        for (relation, shape) in (source._role_shapes or {}).items() {
            targets = outgoing.get(relation, []);
            if shape == "none" and targets {
                raise ValueError(f"{relation.__name__} has targets in an empty slot");
            }
            if shape == "one" and len(targets) != 1 {
                raise ValueError(f"{relation.__name__} requires one target");
            }
        }
    }
}

walker ValidateGraph {
    has seen: set[int] = set();

    can check with GraphNode entry {
        self.seen.add(id(here));
        validate_relations(here);
        # Multiple relations may reach one node; validate all relations but
        # enqueue each endpoint only once.
        pending: list[GraphNode] = [];
        for target in [here-->] {
            if id(target) not in self.seen {
                self.seen.add(id(target));
                pending.append(target);
            }
        }
        visit pending;
    }
}

def validate_graph(origin: GraphNode) {
    origin spawn ValidateGraph();
}
