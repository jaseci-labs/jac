"""ReactBackend implementations — verbatim move from EsastGenPass sites."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import from jaclang.compiler.passes.ecmascript.framework_backend { BackendCaps }

impl ReactBackend.name -> str {
    return "react";
}

impl ReactBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl ReactBackend.capabilities -> BackendCaps {
    return BackendCaps();
}

impl ReactBackend.jsx_factory_name -> str {
    return "__jacJsx";
}

impl ReactBackend.import_source(symbol: str) -> str {
    if symbol == "useRef" {
        return "react";
    }
    return "@jac/runtime";
}

impl ReactBackend.required_globals -> list[str] {
    return ["__jacJsx", "__jacSpawn"];
}

"""Generate setter name for reactive variable (count -> setCount)."""
impl ReactBackend._get_setter_name(var_name: str) -> str {
    if not var_name {
        return "";
    }
    return f"set{var_name[0].upper()}{var_name[1:]}";
}

"""Build `<>{children...}</>` — a fragment `__jacJsx(null, {}, [children])`."""
impl ReactBackend._jsx_fragment(
    children: list[es.Expression]
) -> es.CallExpression {
    return es.CallExpression(
        callee=es.Identifier(name='__jacJsx'),
        arguments=[
            es.Literal(value=None),
            es.ObjectExpression(properties=[]),
            es.ArrayExpression(elements=children)
        ]
    );
}

"""Lower a reactive state field to `const [name, setName] = useState(init);`."""
impl ReactBackend.lower_state_field(s: StateField) -> list[es.Statement] {
    setter_name = self._get_setter_name(s.name);
    array_pattern = es.ArrayPattern(
        elements=[es.Identifier(name=s.name), es.Identifier(name=setter_name)]
    );
    use_state_call = es.CallExpression(
        callee=es.Identifier(name='useState'), arguments=[s.init_expr]
    );
    declarator = es.VariableDeclarator(id=array_pattern, init=use_state_call);
    decl_stmt = es.VariableDeclaration(
        declarations=[declarator], kind='const'
    );
    return [decl_stmt];
}

"""Lower a ref field to `const name = useRef(init);`."""
impl ReactBackend.lower_ref_field(r: RefField) -> list[es.Statement] {
    use_ref_call = es.CallExpression(
        callee=es.Identifier(name='useRef'), arguments=[r.init_expr]
    );
    ref_declarator = es.VariableDeclarator(
        id=es.Identifier(name=r.name), init=use_ref_call
    );
    return [es.VariableDeclaration(declarations=[ref_declarator], kind='const')];
}

"""Lower a state update to `setName(value)` (or `setName(name + value)`)."""
impl ReactBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    setter_name = self._get_setter_name(u.name);
    if u.aug_op {
        setter_arg = es.BinaryExpression(
            operator=u.aug_op,
            left=es.Identifier(name=u.name),
            right=u.value
        );
    } else {
        setter_arg = u.value;
    }
    return es.CallExpression(
        callee=es.Identifier(name=setter_name), arguments=[setter_arg]
    );
}

"""Lower an effect to `useEffect(() => { ... }, [deps]);`."""
impl ReactBackend.lower_effect(e: Effect) -> list[es.Statement] {
    effect_body: list[es.Statement] = [];
    if e.is_entry {
        if e.is_async {
            async_arrow = es.ArrowFunctionExpression(
                params=[],
                body=es.BlockStatement(body=e.body),
                async_=True,
                expression=False
            );
            iife_call = es.CallExpression(callee=async_arrow, arguments=[]);
            effect_body.append(es.ExpressionStatement(expression=iife_call));
        } else {
            effect_body = e.body;
        }
    } else {
        cleanup_arrow = es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=e.body),
            async_=False,
            expression=False
        );
        effect_body.append(es.ReturnStatement(argument=cleanup_arrow));
    }
    effect_callback = es.ArrowFunctionExpression(
        params=[],
        body=es.BlockStatement(body=effect_body),
        async_=False,
        expression=False
    );
    deps_array = es.ArrayExpression(elements=e.deps);
    use_effect_call = es.CallExpression(
        callee=es.Identifier(name='useEffect'),
        arguments=[effect_callback, deps_array]
    );
    return [es.ExpressionStatement(expression=use_effect_call)];
}

"""Lower an async boundary to `<JacClientErrorBoundary fallback={...}>
    <JacAwaiting fallback={...}>{try_iife}</JacAwaiting>
</JacClientErrorBoundary>`."""
impl ReactBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
    awaiting_children: list[es.Expression] = [];
    if a.awaiting_expr is not None {
        awaiting_children.append(a.awaiting_expr);
    }
    fallback_prop = es.Property(
        key=es.Literal(value='fallback'),
        value=self._jsx_fragment(awaiting_children),
        kind='init',
        method=False,
        shorthand=False,
        computed=False
    );
    wrapper = es.CallExpression(
        callee=es.Identifier(name='__jacJsx'),
        arguments=[
            es.Identifier(name='JacAwaiting'),
            es.ObjectExpression(properties=[fallback_prop]),
            es.ArrayExpression(elements=[a.try_expr])
        ]
    );
    if a.except_exprs {
        eb_fallback_prop = es.Property(
            key=es.Literal(value='fallback'),
            value=self._jsx_fragment(a.except_exprs),
            kind='init',
            method=False,
            shorthand=False,
            computed=False
        );
        wrapper = es.CallExpression(
            callee=es.Identifier(name='__jacJsx'),
            arguments=[
                es.Identifier(name='JacClientErrorBoundary'),
                es.ObjectExpression(properties=[eb_fallback_prop]),
                es.ArrayExpression(elements=[wrapper])
            ]
        );
    }
    return wrapper;
}
