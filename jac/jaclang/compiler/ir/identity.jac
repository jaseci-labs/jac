type GraphId := int;
type NodeId := int;
type SourceId := str;
type RevisionId := str;
type ProductVersion := int;

glob SCHEMA_VERSION: int = 26;

obj NodeIdentity {
    has graph_id: GraphId,
        node_id: NodeId;
}

enum RelationFamily {
    STRUCTURE = "structure",
    BINDING = "binding",
    TYPES = "types",
    FLOW = "flow",
    PLACEMENT = "placement"
}

enum Multiplicity { OPTIONAL = "optional", MANY = "many", SLOT = "slot" }

enum RelationLifetime { SYNTAX = "syntax", ANALYSIS = "analysis" }

def bundled_stdlib_module_of(file_path: str) -> (str | None) {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return None;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    native_root = os.path.join(pkg, "runtime", "na_stdlib") + os.sep;
    stub_root = os.path.join(pkg, "vendor", "typeshed", "stdlib") + os.sep;
    if ap.startswith(native_root) and ap.endswith(".jac") {
        rel = ap[len(native_root):-len(".jac")];
        parts = rel.split(os.sep);

        parts[-1] = parts[-1].split(".")[0];
        return ".".join(parts);
    }
    if ap.startswith(stub_root) and ap.endswith(".pyi") {
        rel = ap[len(stub_root):-len(".pyi")];
        parts = rel.split(os.sep);
        if parts[-1] == "__init__" {
            parts = parts[:-1];
        }
        return ".".join(parts) if parts else None;
    }
    return None;
}


def relation_bit(family: RelationFamily) -> int {
    if family == RelationFamily.STRUCTURE {
        return 1;
    }
    if family == RelationFamily.BINDING {
        return 2;
    }
    if family == RelationFamily.TYPES {
        return 4;
    }
    if family == RelationFamily.FLOW {
        return 8;
    }
    if family == RelationFamily.PLACEMENT {
        return 16;
    }
    raise ValueError("Unknown relation family");
}

obj MutationPermit {
    has mask: int = 0,
        generation: int = 0;

    def require(family: RelationFamily) {
        if not (self.mask & relation_bit(family)) {
            raise PermissionError(
                f"The active producer cannot mutate {family.value} relations"
            );
        }
    }
}

obj MutationScope {
    has permit: MutationPermit,
        mask: int,
        previous: int = 0;

    def __enter__ -> MutationScope {
        self.previous = self.permit.mask;
        self.permit.mask = self.mask;
        return self;
    }

    def __exit__(exc_type: object, exc: object, tb: object) -> bool {
        self.permit.mask = self.previous;
        return False;
    }
}

node GraphNode {
    has relation_generation: int = 0,
        mutation_permit: MutationPermit | None = None;

    def changed_relations(family: RelationFamily = RelationFamily.TYPES) {
        if self.mutation_permit is not None {
            self.mutation_permit.require(family);
            self.mutation_permit.generation += 1;
        }
        self.relation_generation += 1;
    }

    def _unclaimed_nodes(permit: MutationPermit) -> list[GraphNode] {
        if self.mutation_permit is permit {
            return [];
        }
        if self.mutation_permit is not None {
            raise ValueError(
                "Mutable compiler graphs cannot be shared across contexts"
            );
        }
        if not [self-->] {
            return [self];
        }
        collect = CollectUnclaimed(permit);
        self spawn collect;
        return collect.nodes;
    }

    def attach_permit(permit: MutationPermit) {
        for current in self._unclaimed_nodes(permit) {
            current.mutation_permit = permit;
        }
    }

    def check_connection(target: GraphNode, family: RelationFamily) {
        if not isinstance(target, GraphNode) {
            raise TypeError("Compiler relations require a graph node target");
        }
        permit = self.mutation_permit or target.mutation_permit;
        if permit is not None {
            permit.require(family);
            if self.mutation_permit is not permit {
                self._unclaimed_nodes(permit);
            }
            if target.mutation_permit is not permit {
                target._unclaimed_nodes(permit);
            }
        }
    }

    def __jac_validate_relation__(relation: type, target: GraphNode) {
        import from jaclang.compiler.ir.schema { relation_spec }
        spec = relation_spec(relation);
        if spec.multiplicity == Multiplicity.OPTIONAL and [self->:relation:->] {
            raise ValueError(f"{spec.schema_id} permits at most one target");
        }
        self.prepare_connection(target, spec.family);
    }

    def prepare_connection(target: GraphNode, family: RelationFamily) {
        if not isinstance(target, GraphNode) {
            raise TypeError("Compiler relations require a graph node target");
        }
        permit = self.mutation_permit or target.mutation_permit;
        if permit is not None {
            permit.require(family);
            if self.mutation_permit is not permit
                or target.mutation_permit is not permit {
                unclaimed = self._unclaimed_nodes(permit)
                    + target._unclaimed_nodes(permit);
                for current in unclaimed {
                    current.mutation_permit = permit;
                }
            }
            permit.generation += 1;
        }
        self.relation_generation += 1;
    }
}

walker CollectUnclaimed {
    has permit: MutationPermit,
        nodes: list[GraphNode] = [],
        seen: set[int] = set();

    can collect with GraphNode entry {
        if here.mutation_permit is self.permit or id(here) in self.seen {
            return;
        }
        if here.mutation_permit is not None {
            raise ValueError(
                "Mutable compiler graphs cannot be shared across contexts"
            );
        }
        self.seen.add(id(here));
        self.nodes.append(here);
        visit [here-->];
    }
}
