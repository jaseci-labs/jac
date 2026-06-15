"""SolidBackend implementations — fine-grained signals lowering (contract §5)."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

impl SolidBackend.name -> str {
    return "solid";
}

"""Names that resolve to the `solid-js` core; everything else stays runtime."""
impl SolidBackend._solid_symbols -> set[str] {
    return {
        "createSignal",
        "createEffect",
        "createMemo",
        "createResource",
        "onMount",
        "onCleanup",
        "on",
        "Show",
        "Suspense",
        "ErrorBoundary"
    };
}

"""Route Solid primitives to `solid-js`; JSX factory / spawn stay on the runtime."""
impl SolidBackend.import_source(symbol: str) -> str {
    if symbol in self._solid_symbols() {
        return "solid-js";
    }
    return "@jac/runtime";
}

"""Hyperscript runtime (`solid-js/h`) needs no JSX-compiler Vite plugin."""
impl SolidBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return None;
}

"""Build the Solid entry script that mounts an exported `app` component."""
impl SolidBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.solid_entry { build_simple_solid_entry_script }
    return build_simple_solid_entry_script(entry_module, install_global_handlers);
}

"""Lower a reactive state field to `const [name, setName] = createSignal(init);`.

Both React (`useState`) and Solid (`createSignal`) destructure `[getter, setter]`,
so the only delta from ReactBackend is the factory name."""
impl SolidBackend.lower_state_field(s: StateField) -> list[es.Statement] {
    setter_name = self._get_setter_name(s.name);
    array_pattern = es.ArrayPattern(
        elements=[es.Identifier(name=s.name), es.Identifier(name=setter_name)]
    );
    create_signal_call = es.CallExpression(
        callee=es.Identifier(name='createSignal'), arguments=[s.init_expr]
    );
    declarator = es.VariableDeclarator(id=array_pattern, init=create_signal_call);
    return [es.VariableDeclaration(declarations=[declarator], kind='const')];
}

"""Lower a ref field to a plain `let name = init;` binding.

Solid has no `useRef`; refs are deferred in v1 (contract §8). A mutable `let`
keeps the name resolvable, but the JSX `ref={el => name = el}` wiring is a
follow-up — a `has r: Ref[T]` field will not yet capture a DOM node on Solid."""
impl SolidBackend.lower_ref_field(r: RefField) -> list[es.Statement] {
    declarator = es.VariableDeclarator(id=es.Identifier(name=r.name), init=r.init_expr);
    return [es.VariableDeclaration(declarations=[declarator], kind='let')];
}

"""Lower a reactive value read to the accessor call `name()` (the call is what
subscribes the surrounding computation under fine-grained reactivity)."""
impl SolidBackend.lower_state_read(name: str) -> es.Expression {
    return es.CallExpression(callee=es.Identifier(name=name), arguments=[]);
}

"""Lower a dynamic JSX position to a thunk `() => expr`.

The component body runs once, so a signal read placed directly in JSX would be
evaluated a single time. Wrapping it in a thunk lets the runtime own a per-node
tracking computation that re-runs `expr` when its signals change."""
impl SolidBackend.lower_view_expr(expr: es.Expression) -> es.Expression {
    return es.ArrowFunctionExpression(
        params=[], body=expr, async_=False, expression=True
    );
}

"""Lower a state update to `setName(value)`.

Augmented updates use the functional updater `setName(prev => prev <op> value)`
rather than `setName(name() + value)`: it reads the previous value without
subscribing the update site to the signal (contract §5.3). Plain self-referential
assigns (`count = count + 1`) flow through the non-aug branch and still emit
`setCount(count() + 1)` — a documented stale-read asymmetry (contract §5.3)."""
impl SolidBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    setter_name = self._get_setter_name(u.name);
    if u.aug_op {
        updater_body = es.BinaryExpression(
            operator=u.aug_op, left=es.Identifier(name='prev'), right=u.value
        );
        updater = es.ArrowFunctionExpression(
            params=[es.Identifier(name='prev')],
            body=updater_body,
            async_=False,
            expression=True
        );
        return es.CallExpression(
            callee=es.Identifier(name=setter_name), arguments=[updater]
        );
    }
    return es.CallExpression(
        callee=es.Identifier(name=setter_name), arguments=[u.value]
    );
}

"""Lower an effect to `createEffect(() => { ... })` / `onCleanup(() => { ... })`.

Entry abilities become `createEffect`; exit (cleanup) abilities become
`onCleanup`. Solid auto-tracks signal reads in the effect body, so the explicit
`deps` list carried by `Effect` is intentionally ignored here — a documented
divergence from React's explicit-dependency contract (contract §5.4 / capability
matrix). Async entries keep the IIFE wrapper used on the React path."""
impl SolidBackend.lower_effect(e: Effect) -> list[es.Statement] {
    if not e.is_entry {
        cleanup_callback = es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=e.body),
            async_=False,
            expression=False
        );
        cleanup_call = es.CallExpression(
            callee=es.Identifier(name='onCleanup'), arguments=[cleanup_callback]
        );
        return [es.ExpressionStatement(expression=cleanup_call)];
    }
    effect_body: list[es.Statement] = [];
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
    effect_callback = es.ArrowFunctionExpression(
        params=[],
        body=es.BlockStatement(body=effect_body),
        async_=False,
        expression=False
    );
    effect_call = es.CallExpression(
        callee=es.Identifier(name='createEffect'), arguments=[effect_callback]
    );
    return [es.ExpressionStatement(expression=effect_call)];
}

"""Lower an async boundary to `<ErrorBoundary fallback={...}>
    <Suspense fallback={...}>{try}</Suspense>
</ErrorBoundary>` using Solid's `Suspense` / `ErrorBoundary`.

Mirrors the React wrapper shape; the framework component names and import source
are the delta. v1 emits a fragment fallback for `ErrorBoundary`; Solid's native
`fallback={(err, reset) => ...}` render-prop signature is a documented follow-up
(contract §5.6). True `createResource`-backed suspension is out of scope — this
lowers the boundary wrapper only (contract §8)."""
impl SolidBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
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
            es.Identifier(name='Suspense'),
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
                es.Identifier(name='ErrorBoundary'),
                es.ObjectExpression(properties=[eb_fallback_prop]),
                es.ArrayExpression(elements=[wrapper])
            ]
        );
    }
    return wrapper;
}

"""Runtime symbols required when lowering a reactive state field."""
impl SolidBackend.state_field_symbols(s: StateField) -> list[str] {
    return ["createSignal"];
}

"""Ref fields are deferred on Solid (contract §8) — a `let` binding needs no import."""
impl SolidBackend.ref_field_symbols(r: RefField) -> list[str] {
    return [];
}

"""Runtime symbols required when lowering an effect."""
impl SolidBackend.effect_symbols(e: Effect) -> list[str] {
    if not e.is_entry {
        return ["onCleanup"];
    }
    return ["createEffect"];
}

"""Runtime symbols required when lowering an async boundary."""
impl SolidBackend.async_boundary_symbols(a: AsyncBoundary) -> list[str] {
    syms = ["Suspense"];
    if a.except_exprs {
        syms.append("ErrorBoundary");
    }
    return syms;
}
