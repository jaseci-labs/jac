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

"""Bare globals the bundler prepends — no `__jacJsx` on the dom-expressions path."""
impl SolidBackend.required_globals -> list[str] {
    return ["__jacSpawn"];
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
        "For",
        "Index",
        "Suspense",
        "ErrorBoundary"
    };
}

"""Route Solid primitives to `solid-js`; JSX factory / spawn stay on the runtime."""
impl SolidBackend.import_source(symbol: str) -> str {
    if symbol == "Dynamic" {
        # `<Dynamic component={…}>` (the JSX lowering of a `<@expr>` dynamic tag)
        # lives in `solid-js/web`, not the `solid-js` core.
        return "solid-js/web";
    }
    if symbol in self._solid_symbols() {
        return "solid-js";
    }
    return "@jac/runtime";
}

"""Solid uses its own framework-free runtime shim (`solid_runtime.cl.jac`),
which re-exports the shared core with no React ecosystem package and no `__jacJsx`
(the JSX path no longer needs a hyperscript factory). Overrides the basename
inherited from ReactBackend."""
impl SolidBackend.runtime_source_basename -> str {
    return "solid_runtime.cl.jac";
}

"""The Solid build uses `vite-plugin-solid` (wraps `babel-plugin-jsx-dom-expressions`),
the same transform the jsdom harness applies via `babel-preset-solid`."""
impl SolidBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return ('import solidPlugin from "vite-plugin-solid";', 'solidPlugin()');
}

"""Build the Solid entry script that mounts an exported `app` component."""
impl SolidBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.solid_entry { build_simple_solid_entry_script }
    return build_simple_solid_entry_script(entry_module, install_global_handlers);
}

"""Build the Solid file-based-routing entry (`solid-js/web` render + the runtime
shim's `@solidjs/router` adapters); pulls in no React-ecosystem package."""
impl SolidBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    import from jaclang.runtimelib.solid_entry { build_pages_solid_entry_script }
    return build_pages_solid_entry_script(entry_module, auth_redirect, has_app_wrapper);
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

# ============================================================================
# View IR → JSX syntax (the dom-expressions path, Branch 3)
# ============================================================================
"""Identity location-stamper — returns the node unchanged (see `_noloc` decl)."""
impl SolidBackend._noloc(es_node: any, jac_node: any = None) -> any {
    return es_node;
}

"""Build a JSX tag-name node from a component reference expression.

`<App>` (lowered to `Identifier('App')`) → `JsxIdentifier('App')`; `<Foo.Bar>` (a
static member chain) → `JsxMemberExpression`. A reference that is neither a plain
identifier nor a static member chain (a computed access, a call, …) cannot name a
JSX tag, so `None` is returned and the caller routes it through `<Dynamic>`."""
impl SolidBackend._jsx_tag_name(
    expr: es.Expression
) -> (es.JsxIdentifier | es.JsxMemberExpression | None) {
    if isinstance(expr, es.Identifier) {
        return es.JsxIdentifier(name=expr.name);
    }
    if isinstance(expr, es.MemberExpression) and not expr.computed {
        obj_node = self._jsx_tag_name(expr.object);
        prop = expr.property;
        if obj_node is not None and isinstance(prop, es.Identifier) {
            return es.JsxMemberExpression(
                object=obj_node, property=es.JsxIdentifier(name=prop.name)
            );
        }
    }
    return None;
}

"""Map a neutral attribute name to its Solid DOM name. The producer preserves the
React-convention `className`; Solid's canonical class prop is `class`. Event/ref
and every other name pass through verbatim — Solid accepts camelCase `onClick`,
`ref`, and inline `style` objects directly (pinned in the Phase 0 spike)."""
impl SolidBackend._map_attr_name(name: str) -> str {
    if name == "className" {
        return "class";
    }
    return name;
}

"""True when a static string attribute value is identical under JS double-quote
escaping and raw JSX `name="…"` syntax — i.e. it contains no `"` (the value
delimiter), backslash, or newline/tab that `gen_literal` would JS-escape but a
raw JSX attribute value would not. Safe values keep the readable `name="value"`
form; the rest are routed through an expression container (`name={"…"}`) so the
emitted JSX parses and matches the React props path (see `_jsx_attr`)."""
impl SolidBackend._jsx_attr_str_safe(value: str) -> bool {
    for ch in value {
        if ch in '"\\\n\r\t' {
            return False;
        }
    }
    return True;
}

"""Lower one classified View IR attribute to a JSX attribute node.

`StaticAttr` → `name="literal"` (a value-less attribute, carried as a `True`
literal by the producer, emits as a bare `name`); `DynamicAttr` → `name={expr}`
(NOT thunked — `babel-plugin-jsx-dom-expressions` tracks the read, so the `() =>`
seam is bypassed on this path); `EventAttr` → `onX={handler}`; `RefAttr` →
`ref={expr}` (the Phase 0 spike confirmed a member-access callback ref registers
the DOM node); `SpreadAttr` → native `{...obj}` (closes the snapshot, TODO #1)."""
impl SolidBackend._jsx_attr(
    attr: any, sync_loc: any
) -> (es.JsxAttribute | es.JsxSpreadAttribute) {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        StaticAttr,
        EventAttr,
        SpreadAttr
    }
    if isinstance(attr, SpreadAttr) {
        return sync_loc(
            es.JsxSpreadAttribute(argument=attr.value), jac_node=attr.jac_node
        );
    }
    name_node = sync_loc(
        es.JsxIdentifier(name=self._map_attr_name(attr.name)), jac_node=attr.jac_node
    );
    if isinstance(attr, StaticAttr) {
        # A value-less attribute (`disabled`) is carried as a `True` literal; emit
        # it with no value.
        if isinstance(attr.value, es.Literal) and attr.value.value is True {
            value: (es.Literal | es.JsxExpressionContainer | None) = None;
        } elif (
            isinstance(attr.value, es.Literal)
            and isinstance(attr.value.value, str)
            and not self._jsx_attr_str_safe(attr.value.value)
        ) {
            # `gen_literal` JS-escapes a string (`"` → `\"`, newline → `\n`,
            # `\` → `\\`), but a raw JSX `name="…"` value is opaque — so a value
            # containing any of those would emit invalid JSX (`class="a\"b"`) and
            # diverge from the React props path. Route it through an expression
            # container instead: `class={"a\"b"}` parses and matches React's value.
            value = sync_loc(
                es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
            );
        } else {
            # A JSX-safe string literal keeps its readable `name="value"` form.
            value = attr.value;
        }
    } elif isinstance(attr, EventAttr) {
        value = sync_loc(
            es.JsxExpressionContainer(expression=attr.handler), jac_node=attr.jac_node
        );
    } else {
        # DynamicAttr | RefAttr — both carry a neutral value expression; no thunk.
        value = sync_loc(
            es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
        );
    }
    return sync_loc(
        es.JsxAttribute(name=name_node, value=value), jac_node=attr.jac_node
    );
}

"""Lower a View IR child list to JSX child nodes, flattening nested fragments.

`TextChild` → `{"text"}` (an expression container around the literal, so the
unparser defers escaping to JS string rules rather than emitting raw JSX text);
`DynamicChild` → `{expr}` (un-thunked); `ElementChild` → the recursively lowered
element; `SlotChild` → `{iife}`. `babel-plugin-jsx-dom-expressions` REJECTS a
`<>…</>` fragment nested under a host element, so a child whose tag is a
`FragmentTag` is *spliced* — its children flatten into this list in place (a
fragment is transparent grouping).

**Gap (contract §8, Solid):** an `unsafe_html(x)` child is NOT rewritten to
`<span innerHTML={x}>` here. The ambient builtin lowers to an opaque raw-text
expression (not a detectable call node), so the JSX path emits it verbatim and the
marker object renders inertly — the hyperscript `__jacJsx` runtime intercepted the
`.__jacUnsafeHtml` sentinel, but dom-expressions has no such interception point.
Closing this honestly needs the builtin to emit a structured marker the producer
can classify, which is upstream of this lowering."""
impl SolidBackend._jsx_child_nodes(children: list, sync_loc: any) -> list {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        TextChild,
        DynamicChild,
        ElementChild,
        FragmentTag,
        IfChild,
        EachChild
    }
    out = [];
    for child in children {
        if isinstance(child, EachChild) {
            out.append(self._jsx_for(child, sync_loc));
            continue;
        }
        if isinstance(child, IfChild) {
            out.append(self._jsx_show(child, sync_loc));
            continue;
        }
        if isinstance(child, TextChild) {
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, DynamicChild) {
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, ElementChild) {
            el = child.element;
            if isinstance(el.tag, FragmentTag) {
                # Splice the fragment's children in place (dom-expressions forbids
                # a nested `<>` under a host element).
                for sub in self._jsx_child_nodes(el.children, sync_loc) {
                    out.append(sub);
                }
            } else {
                out.append(self.lower_view(el, sync_loc));
            }
        } else {
            # SlotChild — the already-built accumulator IIFE, emitted verbatim.
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.expr),
                    jac_node=child.jac_node
                )
            );
        }
    }
    return out;
}

"""A neutral child list as a single JSX expression.

A lone element child lowers to its element directly (the `<For>` callback returns
one node; a `<Show>` fallback is one node); any other shape (multiple children, a
dynamic/text child) is grouped in a `<>…</>` fragment so the result is a single
renderable expression."""
impl SolidBackend._view_children_as_expr(
    children: list, sync_loc: any
) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir { ElementChild, FragmentTag }
    if (
        len(children) == 1
        and isinstance(children[0], ElementChild)
        and not isinstance(children[0].element.tag, FragmentTag)
    ) {
        return self.lower_view(children[0].element, sync_loc);
    }
    return sync_loc(
        es.JsxFragment(children=self._jsx_child_nodes(children, sync_loc)),
        jac_node=None
    );
}

"""Lower an `EachChild` to `<For each={items}>{(item) => body}</For>`.

Solid's `<For>` is keyed by item identity (the lifted `key=` is dropped from the
body — Solid does not consume it), and the dom-expressions compiler owns the
reactive read of `each={items}`, so no thunk is applied. The single render-prop
child is the `(item) => …` callback returning the body element."""
impl SolidBackend._jsx_for(child: any, sync_loc: any) -> es.JsxElement {
    each_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="each"), jac_node=child.jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=child.items),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    arrow = sync_loc(
        es.ArrowFunctionExpression(
            params=[es.Identifier(name=child.item)],
            body=self._view_children_as_expr(child.body, sync_loc),
            async_=False,
            expression=True
        ),
        jac_node=child.jac_node
    );
    callback = sync_loc(
        es.JsxExpressionContainer(expression=arrow), jac_node=child.jac_node
    );
    name_node = sync_loc(es.JsxIdentifier(name="For"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node, [each_attr], [callback], child.jac_node, sync_loc
    );
}

"""Lower an `IfChild` to `<Show when={test} fallback={alt}>consequent</Show>`.

`when={test}` is tracked by the dom-expressions compiler (no thunk); the
`fallback` attribute is emitted only when the ternary had an `else <B/>` arm (an
`… else None` lift carries no `alternate`)."""
impl SolidBackend._jsx_show(child: any, sync_loc: any) -> es.JsxElement {
    when_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="when"), jac_node=child.jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=child.test),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    attrs = [when_attr];
    if child.alternate is not None {
        fallback_attr = sync_loc(
            es.JsxAttribute(
                name=sync_loc(
                    es.JsxIdentifier(name="fallback"), jac_node=child.jac_node
                ),
                value=sync_loc(
                    es.JsxExpressionContainer(
                        expression=self._view_children_as_expr(
                            child.alternate, sync_loc
                        )
                    ),
                    jac_node=child.jac_node
                )
            ),
            jac_node=child.jac_node
        );
        attrs.append(fallback_attr);
    }
    name_node = sync_loc(es.JsxIdentifier(name="Show"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node,
        attrs,
        self._jsx_child_nodes(child.consequent, sync_loc),
        child.jac_node,
        sync_loc
    );
}

"""The `solid-js` view components a lowered tree references — `For` for an
`EachChild`, `Show` for an `IfChild` — gathered by a recursive scan so the pass
injects the imports. Recurses into nested elements and control-flow bodies (a
`<For>` inside a `<Show>`, a comprehension nested in a list element); the import
injector dedupes, so revisiting is harmless."""
impl SolidBackend.view_runtime_symbols(view: ViewElement) -> list[str] {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        ElementChild,
        IfChild,
        EachChild
    }
    syms = [];
    stack = list(view.children);
    while stack {
        child = stack.pop();
        if isinstance(child, EachChild) {
            syms.append("For");
            stack.extend(child.body);
        } elif isinstance(child, IfChild) {
            syms.append("Show");
            stack.extend(child.consequent);
            if child.alternate is not None {
                stack.extend(child.alternate);
            }
        } elif isinstance(child, ElementChild) {
            stack.extend(child.element.children);
        }
    }
    return syms;
}

"""Assemble a JSX element from a tag-name node, attributes, and children. An
element with no children is self-closing (`<tag … />`); otherwise it gets a
matching closing tag."""
impl SolidBackend._jsx_element(
    name_node: any, attrs: list, children: list, jac_node: any, sync_loc: any
) -> es.JsxElement {
    self_closing = len(children) == 0;
    opening = sync_loc(
        es.JsxOpeningElement(
            name=name_node, attributes=attrs, selfClosing=self_closing
        ),
        jac_node=jac_node
    );
    if self_closing {
        return sync_loc(es.JsxElement(openingElement=opening), jac_node=jac_node);
    }
    closing = sync_loc(es.JsxClosingElement(name=name_node), jac_node=jac_node);
    return sync_loc(
        es.JsxElement(
            openingElement=opening, children=children, closingElement=closing
        ),
        jac_node=jac_node
    );
}

"""Lower a runtime/dynamic tag to Solid's `<Dynamic component={expr} …>`.

Used for `<@expr …>` (`DynamicTag`) and for a component reference that is not a
plain name (a computed access, a call). `Dynamic` is imported from `solid-js/web`
in `EsastGenPass.exit_jsx_element` when a dynamic tag is seen on this backend."""
impl SolidBackend._jsx_dynamic(
    component_expr: es.Expression,
    attrs: list,
    children: list,
    jac_node: any,
    sync_loc: any
) -> es.JsxElement {
    comp_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="component"), jac_node=jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=component_expr), jac_node=jac_node
            )
        ),
        jac_node=jac_node
    );
    name_node = sync_loc(es.JsxIdentifier(name="Dynamic"), jac_node=jac_node);
    return self._jsx_element(
        name_node, [comp_attr] + attrs, children, jac_node, sync_loc
    );
}

"""Lower a neutral `ViewElement` tree to JSX estree nodes (the dom-expressions
path). Instead of the JS-family `__jacJsx(tag, props, [children])` hyperscript
call, this builds the ESTree-JSX nodes the unparser prints as JSX *text*
(`<div class="x">{count()}</div>`), which `vite-plugin-solid` then compiles to
fine-grained reactive DOM. Dynamic positions are NOT thunked (the dom-expr
compiler owns the reactive read); spreads are native `{...obj}` (closes the
`Object.assign` snapshot, TODO #1); the event/ref/component-vs-host classification
is already settled in the producer (TODO #2). `sync_loc` carries provenance."""
impl SolidBackend.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        HostTag,
        ComponentTag,
        FragmentTag
    }
    tag = view.tag;
    children_nodes = self._jsx_child_nodes(view.children, sync_loc);
    # A fragment in a position where it is legal (root / attribute value / a
    # component child) → `<>…</>`. Fragments nested under a host element are
    # spliced by the parent's `_jsx_child_nodes` and never reach here.
    if isinstance(tag, FragmentTag) {
        return sync_loc(es.JsxFragment(children=children_nodes), jac_node=tag.jac_node);
    }
    attr_nodes = [self._jsx_attr(a, sync_loc) for a in view.attrs];
    if isinstance(tag, HostTag) {
        name_node = sync_loc(es.JsxIdentifier(name=tag.name), jac_node=tag.jac_node);
    } elif isinstance(tag, ComponentTag) {
        resolved = self._jsx_tag_name(tag.ref);
        # The producer builds a `ComponentTag.ref` only from `element_name`, which
        # always yields a plain `Identifier` (a Capitalized name) or a non-computed
        # `MemberExpression` (a dotted name) — never a computed access or a call. So
        # `_jsx_tag_name` always resolves it to a JSX tag name. A `None` here means
        # that producer invariant changed; we must NOT silently route to `<Dynamic>`,
        # because the `Dynamic` import is injected only for a `<@expr>` `DynamicTag`
        # (see `EsastGenPass.exit_jsx_element`), so a ComponentTag-routed `<Dynamic>`
        # would reference an unimported name. Fail loudly instead.
        assert resolved is not None , "ComponentTag.ref did not resolve to a JSX tag name (producer invariant broken)";
        name_node = sync_loc(resolved, jac_node=tag.jac_node);
    } else {
        # DynamicTag `<@expr …>` → `<Dynamic component={expr}>`.
        return self._jsx_dynamic(
            tag.expr, attr_nodes, children_nodes, view.jac_node, sync_loc
        );
    }
    return self._jsx_element(
        name_node, attr_nodes, children_nodes, view.jac_node, sync_loc
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

Built as neutral `ViewElement` `ComponentTag`s and lowered through `lower_view`
(View IR plan soundness item 2) so the async boundary rides the **same** JSX path
as every other element rather than being a per-backend hyperscript island — this
is what lets a future Svelte backend reuse the shape. The `try`/`awaiting`/
`except` clauses are already-built `es.Expression`s, carried as a `DynamicChild`
(`try`) and `DynamicAttr` `fallback` values: a single `awaiting`/`except`
expression rides directly; multiple `except` handlers fold into a `<>…</>`
fragment (one renderable node, matching the React path — not a bare array);
an absent `awaiting` fallback is `null`. Solid's native render-prop
`fallback={(err, reset) => …}` and `createResource`-backed suspension stay
follow-ups (contract §5.6 / §8). `lower_async_boundary` is invoked without the
pass's `sync_loc`, so `_noloc` keeps the `lower_view` call uniform."""
impl SolidBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        ViewElement,
        ComponentTag,
        FragmentTag,
        DynamicAttr,
        DynamicChild,
        ElementChild
    }
    # These `ViewElement`s are *synthesized* — there is no originating Jac node
    # for the `Suspense`/`ErrorBoundary` wrapper (`a` carries only already-built
    # `es.Expression`s, never a `uni` node), so provenance is `None`. `_noloc`
    # ignores it anyway, and the real `sync_loc` reads `None` as "use cur_node".
    jn = None;
    awaiting_fallback: es.Expression = a.awaiting_expr
        if a.awaiting_expr is not None
        else es.Literal(value=None, raw='null');
    suspense_view = ViewElement(
        tag=ComponentTag(ref=es.Identifier(name='Suspense'), jac_node=jn),
        attrs=[DynamicAttr(name='fallback', value=awaiting_fallback, jac_node=jn)],
        children=[DynamicChild(value=a.try_expr, jac_node=jn)],
        jac_node=jn
    );
    if not a.except_exprs {
        return self.lower_view(suspense_view, self._noloc);
    }
    if len(a.except_exprs) == 1 {
        except_fallback: es.Expression = a.except_exprs[0];
    } else {
        # Multiple `except` handlers: Solid's `<ErrorBoundary fallback={…}>` takes a
        # single renderable node (or a `(err, reset) => node` render-prop, deferred
        # — contract §5.6/§8), NOT a bare array. A `fallback={[a, b]}` would diverge
        # from the React path, which wraps the handlers in a fragment. Fold them into
        # a `<>…</>` fragment lowered through the same JSX seam, so the fallback is
        # one node.
        except_fragment = ViewElement(
            tag=FragmentTag(jac_node=jn),
            attrs=[],
            children=[DynamicChild(value=ex, jac_node=jn) for ex in a.except_exprs],
            jac_node=jn
        );
        except_fallback = self.lower_view(except_fragment, self._noloc);
    }
    error_view = ViewElement(
        tag=ComponentTag(ref=es.Identifier(name='ErrorBoundary'), jac_node=jn),
        attrs=[DynamicAttr(name='fallback', value=except_fallback, jac_node=jn)],
        children=[ElementChild(element=suspense_view, jac_node=jn)],
        jac_node=jn
    );
    return self.lower_view(error_view, self._noloc);
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
