import from jaclang.compiler.ir.identity { Multiplicity }
import from jaclang.compiler.ir.identity { GraphNode, MutationPermit }
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
    anchor = source.__jac__;
    outgoing: dict[type, list[GraphNode]] = anchor.out_light or {};
    if anchor.edges {
        outgoing = {
            relation: list(targets) for (relation, targets) in outgoing.items()
        };
        for edge in anchor.edges {
            if edge.source is anchor and edge.target is not None {
                outgoing.setdefault(type(edge.archetype), []).append(
                    edge.target.archetype
                );
            }
        }
    }
    if not outgoing and not (isinstance(source, UniNode) and source._role_shapes) {
        return;
    }
    relations = relation_catalog();
    for (relation, targets) in outgoing.items() {
        spec = relations.get(relation);
        if spec is None {
            raise ValueError(f"Unregistered compiler relation: {relation.__name__}");
        }
        if spec.multiplicity == Multiplicity.OPTIONAL and len(targets) > 1 {
            raise ValueError(f"{spec.schema_id} permits at most one target");
        }
        if targets and not isinstance(source, spec.source_types) {
            raise TypeError(
                f"{spec.schema_id} has an invalid source: {type(source).__name__}"
            );
        }
        for target in targets {
            if not isinstance(target, spec.target_types) {
                raise TypeError(
                    f"{spec.schema_id} has an invalid target: {type(target).__name__}"
                );
            }
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
    has permit: MutationPermit | None = None,
        nodes: list[GraphNode] = [],
        seen: set[int] = set();

    can check with GraphNode entry {
        self.seen.add(id(here));
        validate_relations(here);
        if self.permit is not None {
            if here.mutation_permit is not None
                and here.mutation_permit is not self.permit {
                raise ValueError(
                    "Mutable compiler graphs cannot be shared across contexts"
                );
            }
            self.nodes.append(here);
        }

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

def validate_graph(origin: GraphNode, permit: MutationPermit | None = None) {
    validation = ValidateGraph(permit=permit);
    origin spawn validation;
    for element in validation.nodes {
        element.mutation_permit = permit;
    }
}
