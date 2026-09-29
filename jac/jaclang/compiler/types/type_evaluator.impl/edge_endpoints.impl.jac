impl TypeEvaluator._edge_endpoint_declared(
    edge_type: ClassType, want_src: bool
) -> TypeBase | None {
    for cls in edge_type.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        endpoint = arch.src_endpoint if want_src else arch.tgt_endpoint;
        if endpoint is not None {
            return self.get_type_of_expression(endpoint);
        }
    }
    return None;
}

impl TypeEvaluator._edge_endpoint_type(
    edge_type: ClassType, edge_dir: EdgeDir
) -> TypeBase | None {
    if edge_dir != EdgeDir.OUT and edge_dir != EdgeDir.IN {
        return None;
    }
    declared = self._edge_endpoint_declared(edge_type, edge_dir == EdgeDir.IN);
    if declared is None or declared.is_any_instance() {
        return None;
    }
    if isinstance(declared, ClassType) {
        return declared;
    }
    if isinstance(declared, UnionType)
        and all(isinstance(m, ClassType) for m in declared.types) {
        return declared;
    }
    return None;
}

impl TypeEvaluator._edge_endpoint_verdict(
    actual: TypeBase, declared: TypeBase
) -> EndpointVerdict {
    if declared.is_any_type() or isinstance(declared, UnknownType) {
        return EndpointVerdict.CONFORMS;
    }
    if actual.is_any_type() or isinstance(actual, UnknownType) {
        return EndpointVerdict.UNPROVEN;
    }
    if isinstance(actual, UnionType) {
        verdicts = [
            self._edge_endpoint_verdict(member, declared) for member in actual.types
        ];
        if EndpointVerdict.VIOLATES in verdicts {
            return EndpointVerdict.VIOLATES;
        }
        if EndpointVerdict.UNPROVEN in verdicts {
            return EndpointVerdict.UNPROVEN;
        }
        return EndpointVerdict.CONFORMS;
    }
    if not isinstance(actual, ClassType) {
        return EndpointVerdict.UNPROVEN;
    }
    declared_inst = self._convert_to_instance(declared);
    if self.assign_type(actual, declared_inst, strict=False) {
        return EndpointVerdict.CONFORMS;
    }
    candidates = declared_inst.types
        if isinstance(declared_inst, UnionType)
        else [declared_inst];
    if any(self.assign_type(member, actual, strict=False) for member in candidates) {
        return EndpointVerdict.UNPROVEN;
    }
    return EndpointVerdict.VIOLATES;
}

impl TypeEvaluator._connected_node_type(operand: TypeBase) -> TypeBase {
    if isinstance(operand, UnionType) {
        return UnionType(types=[self._connected_node_type(m) for m in operand.types]);
    }
    if isinstance(operand, ClassType)
        and operand.is_builtin()
        and operand.shared.class_name in ("list", "tuple", "set", "frozenset") {
        return self._get_iterable_element_type(operand) or AnyType();
    }
    return operand;
}

impl TypeEvaluator._report_endpoint_verdict(
    at: UniNode,
    violation: DiagnosticInfo,
    unproven: DiagnosticInfo,
    edge_type: ClassType,
    side: str,
    actual: TypeBase,
    declared: TypeBase
) -> None {
    if isinstance(actual, ClassType) and not actual.is_instance() {
        return;
    }
    verdict = self._edge_endpoint_verdict(actual, declared);
    if verdict != EndpointVerdict.VIOLATES and verdict != EndpointVerdict.UNPROVEN {
        return;
    }
    self.emit_diag(
        violation if verdict == EndpointVerdict.VIOLATES else unproven,
        at,
        side=side,
        actual=str(actual),
        edge_name=edge_type.shared.class_name,
        declared=str(self._convert_to_instance(declared))
    );
}

impl TypeEvaluator._check_connect_endpoints(
    conn_type: TypeBase,
    edge_dir: EdgeDir,
    left: Expr,
    left_type: TypeBase,
    right: Expr,
    right_type: TypeBase
) -> None {
    if edge_dir == EdgeDir.ANY {
        self._check_connect_endpoints(
            conn_type, EdgeDir.OUT, left, left_type, right, right_type
        );
        self._check_connect_endpoints(
            conn_type, EdgeDir.IN, left, left_type, right, right_type
        );
        return;
    }
    if edge_dir != EdgeDir.OUT and edge_dir != EdgeDir.IN {
        return;
    }
    edge_type = conn_type;
    if isinstance(edge_type, ClassType) {
        edge_type = self._get_type_for_member_lookup(edge_type);
    }
    if not isinstance(edge_type, ClassType) or not edge_type.is_edge_type() {
        return;
    }
    outbound = edge_dir == EdgeDir.OUT;
    for (side, at, operand_type, want_src) in [
        (
            "source",
            left if outbound else right,
            left_type if outbound else right_type,
            True
        ),
        (
            "target",
            right if outbound else left,
            right_type if outbound else left_type,
            False
        )
    ] {
        declared = self._edge_endpoint_declared(edge_type, want_src);
        if declared is None {
            continue;
        }
        self._report_endpoint_verdict(
            at,
            E1136,
            W2081,
            edge_type,
            side,
            self._connected_node_type(operand_type),
            declared
        );
    }
}

impl TypeEvaluator._check_traversal_origin(
    edge_type: ClassType, edge_dir: EdgeDir, origin_type: TypeBase | None, at: UniNode
) -> None {
    if origin_type is None {
        return;
    }
    if edge_dir != EdgeDir.OUT and edge_dir != EdgeDir.IN {
        return;
    }
    want_src = edge_dir == EdgeDir.OUT;
    declared = self._edge_endpoint_declared(edge_type, want_src);
    if declared is None {
        return;
    }
    self._report_endpoint_verdict(
        at,
        E1137,
        W2082,
        edge_type,
        "source" if want_src else "target",
        self._connected_node_type(origin_type),
        declared
    );
}
