impl EsastGenPass._place_accessors(place: es.Expression) -> es.Expression | None {
    if isinstance(place, es.MemberExpression) {
        if place.object is None or place.property is None {
            return None;
        }
        owner = es.Identifier(name="$jacOwner");
        key = es.Identifier(name="$jacKey");
        member = es.MemberExpression(
            object=owner,
            property=key if place.computed else place.property,
            computed=place.computed
        );
        pair = _place_pair(member);
        return es.CallExpression(
            callee=es.ArrowFunctionExpression(
                params=[owner, key] if place.computed else [owner],
                body=pair,
                expression=True
            ),
            arguments=[place.object, place.property]
                if place.computed
                else [place.object]
        );
    }
    if isinstance(place, es.Identifier) {
        return _place_pair(place);
    }
    return None;
}

impl EsastGenPass._lower_place_builtin(nd: uni.FuncCall) -> es.Expression | None {
    if nd.call_kind != "builtin"
        or not isinstance(nd.target, uni.Name)
        or nd.target.sym_name not in ("take", "swap") {
        return None;
    }
    operation = nd.target.sym_name;
    pairs: list[es.Expression | es.SpreadElement] = [];
    for param in (nd.params or []) {
        place = param.operand if isinstance(param, uni.UnaryExpr) else param;
        if not isinstance(place, uni.Expr) or place.gen.es_ast is None {
            return None;
        }
        pair = self._place_accessors(cast(es.Expression, place.gen.es_ast));
        if pair is None {
            return None;
        }
        pairs.append(pair);
    }
    if len(pairs) != (1 if operation == "take" else 2) {
        return None;
    }
    a = es.Identifier(name="$jacA");
    b = es.Identifier(name="$jacB");
    old = es.Identifier(name="$jacOld");
    read_a = es.CallExpression(
        callee=es.MemberExpression(
            object=a, property=es.Literal(value=0), computed=True
        ),
        arguments=[]
    );
    write_a = es.MemberExpression(
        object=a, property=es.Literal(value=1), computed=True
    );
    body: list[es.Statement] = [
        es.VariableDeclaration(
            kind="const", declarations=[es.VariableDeclarator(id=old, init=read_a)]
        )
    ];
    if operation == "take" {
        body.append(
            es.ExpressionStatement(
                expression=es.CallExpression(
                    callee=write_a, arguments=[es.Literal(value=None)]
                )
            )
        );
        body.append(es.ReturnStatement(argument=old));
    } else {
        read_b = es.CallExpression(
            callee=es.MemberExpression(
                object=b, property=es.Literal(value=0), computed=True
            ),
            arguments=[]
        );
        write_b = es.MemberExpression(
            object=b, property=es.Literal(value=1), computed=True
        );
        body.append(
            es.ExpressionStatement(
                expression=es.CallExpression(callee=write_a, arguments=[read_b])
            )
        );
        body.append(
            es.ExpressionStatement(
                expression=es.CallExpression(callee=write_b, arguments=[old])
            )
        );
        body.append(es.ReturnStatement(argument=es.Literal(value=None)));
    }
    return self.sync_loc(
        es.CallExpression(
            callee=es.ArrowFunctionExpression(
                params=[a] if operation == "take" else [a, b],
                body=es.BlockStatement(body=body),
                expression=False
            ),
            arguments=pairs
        ),
        jac_node=nd
    );
}


def _place_pair(place: es.Expression) -> es.ArrayExpression {
    value = es.Identifier(name="$jacValue");
    return es.ArrayExpression(
        elements=[
            es.ArrowFunctionExpression(params=[], body=place, expression=True),
            es.ArrowFunctionExpression(
                params=[value],
                expression=True,
                body=es.AssignmentExpression(left=place, right=value)
            )
        ]
    );
}
