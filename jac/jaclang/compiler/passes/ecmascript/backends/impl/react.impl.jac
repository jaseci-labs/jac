"""ReactBackend implementations — verbatim move from EsastGenPass sites."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
# View IR records are imported lazily inside `lower_view`/`_view_attr_property`
# (see `framework_backend.jac`): a top-level runtime import would re-enter
# `get_compiler()` during the compiler bootstrap.
impl ReactBackend.name -> str {
    return "react";
}

impl ReactBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl ReactBackend.jsx_factory_name -> str {
    return "__jacJsx";
}

impl ReactBackend.import_source(symbol: str) -> str {
    if symbol in {"useRef", "forwardRef"} {
        return "react";
    }
    return "@jac/runtime";
}

impl ReactBackend.required_globals -> list[str] {
    return ["__jacJsx", "__jacSpawn"];
}

"""Basename of the framework-specific client runtime .cl.jac source."""
impl ReactBackend.runtime_source_basename -> str {
    return "client_runtime.cl.jac";
}

"""Vite resolve aliases — React needs no module remapping."""
impl ReactBackend.vite_aliases -> dict[str, str] {
    return {};
}

"""Build the React entry script that mounts an exported `app` component."""
impl ReactBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.react_entry { build_simple_react_entry_script }
    return build_simple_react_entry_script(entry_module, install_global_handlers);
}

"""Build the React file-based-routing entry (`react-dom/client` + react-router-dom);
Preact inherits this and resolves it through `preact/compat` via `vite_aliases`."""
impl ReactBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    import from jaclang.runtimelib.react_entry { build_pages_react_entry_script }
    return build_pages_react_entry_script(entry_module, auth_redirect, has_app_wrapper);
}

"""All React hook names — used by import_source and subclass backends."""
impl ReactBackend._hook_symbols -> set[str] {
    return {
        "useState",
        "useEffect",
        "useRef",
        "useCallback",
        "useMemo",
        "useReducer",
        "useContext",
        "useId",
        "useLayoutEffect",
        "useImperativeHandle",
        "useDebugValue",
        "useDeferredValue",
        "useTransition",
        "useSyncExternalStore",
        "useInsertionEffect"
    };
}

"""Vite plugin for React (import line, plugin call expression)."""
impl ReactBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return ('import react from "@vitejs/plugin-react";', 'react()');
}

"""Generate setter name for reactive variable (count -> setCount)."""
impl ReactBackend._get_setter_name(var_name: str) -> str {
    if not var_name {
        return "";
    }
    return f"set{var_name[0].upper()}{var_name[1:]}";
}

"""Build `<>{children...}</>` — a fragment `<factory>(null, {}, [children])`."""
impl ReactBackend._jsx_fragment(children: list[es.Expression]) -> es.CallExpression {
    return es.CallExpression(
        callee=es.Identifier(name=self.jsx_factory_name()),
        arguments=[
            es.Literal(value=None),
            es.ObjectExpression(properties=[]),
            es.ArrayExpression(elements=children)
        ]
    );
}

"""Runtime symbols required when lowering a reactive state field."""
impl ReactBackend.state_field_symbols(s: StateField) -> list[str] {
    return ["useState"];
}

"""Runtime symbols required when lowering a ref field."""
impl ReactBackend.ref_field_symbols(r: RefField) -> list[str] {
    return ["useRef"];
}

"""Runtime symbols required when lowering an effect."""
impl ReactBackend.effect_symbols(e: Effect) -> list[str] {
    return ["useEffect"];
}

"""Runtime symbols required when lowering an async boundary."""
impl ReactBackend.async_boundary_symbols(a: AsyncBoundary) -> list[str] {
    syms = ["JacAwaiting"];
    if a.except_exprs {
        syms.append("JacClientErrorBoundary");
    }
    return syms;
}

"""Framework view symbols a lowered tree references — none for the JS family.

React/Preact render any lifted `IfChild`/`EachChild` from the carried
`js_fallback` (`?:`/`.map()`), so no `<For>`/`<Show>`-style component import is
needed; Solid overrides this to scan the tree."""
impl ReactBackend.view_runtime_symbols(view: ViewElement) -> list[str] {
    return [];
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
    decl_stmt = es.VariableDeclaration(declarations=[declarator], kind='const');
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

"""Lower a reactive value read — bare identifier on hooks backends.

Addresses issue #6677: `lower_state_read(name: str) -> es.Expression` is the
value-read seam. React/Preact re-render on state change, so a reactive read is
just the variable itself (this no-op keeps their output byte-identical); signals
backends (Solid) override this to wrap the read as `name()`."""
impl ReactBackend.lower_state_read(name: str) -> es.Expression {
    return es.Identifier(name=name);
}

"""Lower a dynamic JSX position — unchanged on hooks backends.

React/Preact re-render, so a dynamic child/attribute value needs no thunk; this
identity no-op keeps their JSX output byte-identical. Signals backends (Solid)
override this to wrap the expression in a thunk (`() => expr`) so the JSX runtime
can re-read it reactively."""
impl ReactBackend.lower_view_expr(expr: es.Expression) -> es.Expression {
    return expr;
}

"""Build one classified attribute's factory-call `Property`.

`{ key: value }` with `key` the attribute name. Dynamic values route through the
view thunk seam (`lower_view_expr`) — identity on React/Preact, `() => value` on
Solid; event handlers, refs, and static values pass through verbatim (thunking a
handler/ref would defer the callback/swallow the element, not a reactive read)."""
impl ReactBackend._view_attr_property(attr: any, sync_loc: any) -> es.Property {
    import from jaclang.compiler.passes.ecmascript.view_ir { DynamicAttr, EventAttr }
    if isinstance(attr, DynamicAttr) {
        name = attr.name;
        value = sync_loc(self.lower_view_expr(attr.value), jac_node=attr.jac_node);
    } elif isinstance(attr, EventAttr) {
        name = attr.name;
        value = attr.handler;
    } else {
        # StaticAttr | RefAttr — both carry a pre-built `value` expression.
        name = attr.name;
        value = attr.value;
    }
    key_expr = sync_loc(es.Literal(value=name), jac_node=attr.jac_node);
    return sync_loc(
        es.Property(
            key=key_expr,
            value=value,
            kind='init',
            method=False,
            shorthand=False,
            computed=False
        ),
        jac_node=attr.jac_node
    );
}

"""Lower a neutral `ViewElement` tree to a `__jacJsx(tag, props, [children])` call.

This is the JS-family view lowering shared by React/Preact/Solid (the factory
name is `__jacJsx` for all three; Solid's runtime shim backs it with `solid-js/h`).
It reproduces the ESTree the old `EsJsxProcessor.element` built directly, with the
two backend-specific transforms now applied here from the neutral tree:
dynamic positions are thunked via `lower_view_expr` (no-op on React/Preact) and
spreads merge through `Object.assign`. `sync_loc` carries each View IR node's
`jac_node` provenance onto the emitted ESTree."""
impl ReactBackend.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        HostTag,
        ComponentTag,
        DynamicTag,
        SpreadAttr,
        TextChild,
        DynamicChild,
        ElementChild,
        IfChild,
        EachChild
    }
    tag = view.tag;
    if isinstance(tag, HostTag) {
        tag_expr: es.Expression = sync_loc(
            es.Literal(value=tag.name), jac_node=tag.jac_node
        );
    } elif isinstance(tag, ComponentTag) {
        tag_expr = tag.ref;
    } elif isinstance(tag, DynamicTag) {
        tag_expr = tag.expr;
    } else {
        # FragmentTag (or nameless element): a null tag.
        tag_expr = sync_loc(es.Literal(value=None), jac_node=tag.jac_node);
    }
    has_spread = `any(isinstance(a, SpreadAttr) for a in view.attrs);
    if not has_spread {
        properties = [self._view_attr_property(a, sync_loc) for a in view.attrs];
        props_expr: es.Expression = sync_loc(
            es.ObjectExpression(properties=properties), jac_node=view.jac_node
        );
    } else {
        # Spread present: merge `Object.assign({}, seg, …)` in source order; a
        # normal attribute contributes a one-property object segment.
        segments: list[es.Expression] = [];
        for a in view.attrs {
            if isinstance(a, SpreadAttr) {
                segments.append(a.value);
            } else {
                segments.append(
                    sync_loc(
                        es.ObjectExpression(
                            properties=[self._view_attr_property(a, sync_loc)]
                        ),
                        jac_node=a.jac_node
                    )
                );
            }
        }
        if segments {
            assign_member = sync_loc(
                es.MemberExpression(
                    object=sync_loc(
                        es.Identifier(name='Object'), jac_node=view.jac_node
                    ),
                    property=sync_loc(
                        es.Identifier(name='assign'), jac_node=view.jac_node
                    ),
                    computed=False,
                    optional=False
                ),
                jac_node=view.jac_node
            );
            props_expr = sync_loc(
                es.CallExpression(
                    callee=assign_member,
                    arguments=[
                        sync_loc(
                            es.ObjectExpression(properties=[]), jac_node=view.jac_node
                        ),
                        *segments
                    ]
                ),
                jac_node=view.jac_node
            );
        } else {
            props_expr = sync_loc(
                es.ObjectExpression(properties=[]), jac_node=view.jac_node
            );
        }
    }
    children_elements: list[es.Expression] = [];
    for child in view.children {
        if isinstance(child, TextChild) {
            children_elements.append(child.value);
        } elif isinstance(child, DynamicChild) {
            children_elements.append(
                sync_loc(self.lower_view_expr(child.value), jac_node=child.jac_node)
            );
        } elif isinstance(child, ElementChild) {
            children_elements.append(self.lower_view(child.element, sync_loc));
        } elif isinstance(child, (IfChild, EachChild)) {
            # Native control flow is Solid/Svelte polish; the JS family renders
            # the already-lowered `?:`/`.map()` expression the producer carried,
            # so React/Preact output is byte-for-byte what it was before lifting.
            children_elements.append(
                sync_loc(
                    self.lower_view_expr(child.js_fallback), jac_node=child.jac_node
                )
            );
        } else {
            # SlotChild — the already-built accumulator IIFE, emitted verbatim.
            children_elements.append(child.expr);
        }
    }
    children_expr = sync_loc(
        es.ArrayExpression(elements=children_elements), jac_node=view.jac_node
    );
    return sync_loc(
        es.CallExpression(
            callee=sync_loc(
                es.Identifier(name=self.jsx_factory_name()), jac_node=view.jac_node
            ),
            arguments=[tag_expr, props_expr, children_expr]
        ),
        jac_node=view.jac_node
    );
}

"""Lower a state update to `setName(value)` (or `setName(name + value)`)."""
impl ReactBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    setter_name = self._get_setter_name(u.name);
    if u.aug_op {
        setter_arg = es.BinaryExpression(
            operator=u.aug_op, left=es.Identifier(name=u.name), right=u.value
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
        callee=es.Identifier(name='useEffect'), arguments=[effect_callback, deps_array]
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
        callee=es.Identifier(name=self.jsx_factory_name()),
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
            callee=es.Identifier(name=self.jsx_factory_name()),
            arguments=[
                es.Identifier(name='JacClientErrorBoundary'),
                es.ObjectExpression(properties=[eb_fallback_prop]),
                es.ArrayExpression(elements=[wrapper])
            ]
        );
    }
    return wrapper;
}
