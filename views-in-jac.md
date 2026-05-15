# Views: Reactive UI as a First-Class Jac Concept

## Motivation

Jac already has a working JSX flavor. Components are declared as functions
returning `JsxElement`, with `has`-fields auto-wired to `useState`, nested
`def`s for handlers, and an `@jac/runtime` baked into every compiled
`.cl.jac`. See [day_planner](../jac/examples/day_planner/) for a real example:

```jac
def:pub TasksColumn -> JsxElement {
    has tasks: list[Task] = [],
        taskText: str = "";

    async can with entry {
        tasks = await get_tasks();
    }

    async def addTask {
        if taskText.strip() {
            task = await add_task(taskText.strip());
            tasks = tasks + [task];
            taskText = "";
        }
    }

    return
        <div class="column">
            <h2>Today's Tasks</h2>
            <input value={taskText}
                   onChange={lambda e: ChangeEvent { taskText = e.target.value; }} />
            {[<TaskItem key={jid(t)} task={t}
                        onToggle={lambda { toggle(jid(t)); }} />
              for t in tasks]}
        </div>;
}
```

This works. The infrastructure is there - JSX AST, type checker, ecmascript
codegen, `.cl.jac`/`.sv.jac` split-compile, walker spawning, auto-`useState`
for `has`-fields. But the pattern has known pain points that grow with app
complexity:

- **Nested ternaries** for conditional UI:
  `{(<div>Loading</div>) if loading else (<div>Done</div>)}`
- **Manual loading flags** (`tasksLoading: bool`) instead of declarative
  suspense boundaries.
- **CSS lives in a sibling file** - no per-component scoping.
- **Single return-expression body** - no per-element lexical scoping,
  no mid-template computations, no clean early-exit pattern.
- **List rendering via inline comprehension** inside a `{}` expression
  is dense for non-trivial children.

[tsrx](https://tsrx.dev) demonstrated that a small, well-chosen set of
primitives - *statement-based templates*, *lexical scoping*, *boundary blocks
for errors and async* - addresses each of these. This document proposes
**`view`** as a new declarator that absorbs those primitives **on top of**
Jac's existing JSX foundation. The goal is evolution, not replacement:
`def:pub Name -> JsxElement` keeps working, `view Name { … }` is the
opinionated statement-form for new code.

## What's Already in Jac, What `view` Adds, What's Reused As-Is

**Already in Jac (no change):**

- `JsxElement` type, AST, type-checker, and ecmascript codegen.
- `has`-fields auto-wired to `useState` in client modules.
- camelCase JSX attributes (`onClick`, `onChange`, …).
- `jid(item)` for stable keys.
- Block lambdas: `lambda { … }` and `lambda e: T { … }`.
- Nested `def` for event handlers (sync and `async`).
- `can with entry` for component mount.
- `.cl.jac` / `.sv.jac` / `to cl:` split-compile pipeline.
- Walker spawning (`root spawn ListTasks()`) for data flow.
- `@jac/runtime` auto-import.

**What `view` adds:**

- **Statement-body** - no `return <jsx>;` boilerplate; JSX statements
  contribute to the rendered output directly.
- **Statement-position control flow** - every block-bodied Jac construct
  (`if`, `for`, `while`, `match`, `switch`, `with`, `try`) yields content
  directly, replacing nested ternaries and inline comprehensions.
- **`try` / `pending` / `except`** - declarative async/error boundaries that
  replace manual `loading: bool` plumbing. `pending` is keyed on Jac's
  `flow` / `wait` concurrency primitive, so it carries to `sv` and `na`
  (see [Control Flow](#try--pending--except--else)), not just the client.
- **Bare `return;` guard pattern** - clean early-exit without nesting the
  whole body in an `if/else`.
- **Per-element lexical scoping** - locals declared inside an element stay
  scoped to that subtree.
- **Scoped `<style>` blocks** - inline CSS hashed per view.

**Borrowed from tsrx (with Jac voice):**

- `pending` as a `try`-clause keyword (here generalized to Jac's
  `flow` / `wait`, rather than tied to JS Suspense).
- Scoped `<style>` blocks (and `:global(…)` escape hatch).
- `<@expr />` for dynamic tags.

**Not borrowed:**

- The `component Name({ x }: T) { … }` form - Jac uses flat params.
- A `<tsrx>` vs `<tsx>` distinction - Jac has one JSX kind.
- The `"string"` mandatory quoted-text rule - Jac's existing JSX already
  accepts bare text in child positions, which we keep.
- "Lazy destructure" `&{…}` / `&[…]` - covered by Jac's existing `has`-field
  auto-reactivity.

## The `view` Declarator

```jac
"""A reusable button view."""
view Button(label: str, onClick: Callable[[], None]) {
    <button class="btn" {onClick}>{label}</button>
    <style>
        .btn { padding: 0.5rem 1rem; }
    </style>
}
```

A `view` is sugar over `def:pub Name(...) -> JsxElement { ... }`. Same return
type, same callsite, same compile pipeline. The differences are in the body:

- The body is **statements**, not a single `return <jsx>;`.
- Each top-level JSX statement contributes a child to the rendered output.
- A `<style>` block is recognized at the syntactic level and hashed per view.
- `try` clauses may carry `pending` and `except` branches in template position.
- A bare `return;` terminates the render with whatever was emitted so far.

When called as `<Button label="Hi" onClick={…} />`, a view returns a
`JsxElement` - exactly as `def:pub Button(...) -> JsxElement` would. Existing
components, existing imports, and existing type-checker rules see no
difference.

### Anatomy

```jac
[access] view Name[generic_params](params) {
    has_field*        // optional: same auto-reactive has-fields as today
    can_with_entry?   // optional: same mount-lifecycle as today
    handler_def*      // optional: nested `def` event handlers
    body_statement*   // template statements + ordinary statements interleaved
}
```

- `access` - Jac's existing `:pub:` / `:priv:` modifiers.
- `generic_params` - same syntax as `obj[T]`, `walker[T]`.
- `params` - flat function-style parameters.
- `has`-fields inside a view are auto-wired to `useState` by the existing
  ecmascript codegen - no change. Assignments to a `has` field rewrite to
  `setX(...)` calls automatically.
- The body emits template content; the view returns `JsxElement` to its caller.

## Templates as Statements

Today's pattern (one `return` expression):

```jac
def:pub Greeting(name: str) -> JsxElement {
    return
        <div>
            <h1>Hello, {name}</h1>
            <p>Welcome to Jac.</p>
        </div>;
}
```

`view` form (each JSX is a statement):

```jac
view Greeting(name: str) {
    <h1>Hello, {name}</h1>
    <p>Welcome to Jac.</p>
}
```

Top-level JSX statements are collected into a fragment as the view's
returned `JsxElement`. The statement form is what enables everything below -
per-element lexical scoping, mid-template `let`, early `return;`,
hook-isolation, scoped `<style>` blocks - to compose cleanly without one giant
expression.

### Text & Expressions

Same as Jac's existing JSX - no new rules:

| Form | Meaning |
|------|---------|
| `<p>Hello</p>` | static text (Jac's existing JSX accepts bare text) |
| `<p>{expr}</p>` | embedded expression |
| `<p>{text expr}</p>` | HTML-escaped text - *new contextual keyword* |
| `<p>{html expr}</p>` | raw HTML - *new contextual keyword* |

`text` and `html` are contextual: only special as the first token inside a
`{ … }` JSX child. Outside JSX they remain plain identifiers.

## Lexical Scoping (the Quiet Superpower)

Every element introduces a **child scope** for declarations inside it. This
mirrors Jac's existing `{ }` block scoping - the only change is that opening
a template tag also opens a scope.

```jac
view Receipt(items: list[Item]) {
    total = 0.0;                     # visible in whole view body
    <div>
        subtotal = sum(it.price for it in items);
        tax = subtotal * 0.08;
        total = subtotal + tax;      # ok - outer `total` reassignment
        <p>Subtotal: ${subtotal}</p>
        <p>Tax: ${tax}</p>
    </div>
    <p>Total: ${total}</p>           # `subtotal` and `tax` NOT in scope here
}
```

The compile error for using `subtotal` after the `</div>` is the same error a
user gets today when reaching outside a Jac block - no new diagnostic
machinery needed.

## Control Flow That Yields Content

Rather than bless a fixed list of "template-aware" constructs, `view` applies
**one rule**:

> Any control-flow construct whose body is a `{ }` block may appear in
> template position. **Each block yields a fragment** - the JSX statements
> inside it contribute children to the rendered output, exactly as the view
> body itself does.

This is not new machinery. A `view` body already *is* a block that yields a
fragment (see [Lexical Scoping](#lexical-scoping-the-quiet-superpower));
nesting another block-bodied construct inside it just nests fragments. So
`if`, `for` (both forms), `while`, `match`, `switch`, `with`, and `try` all
work in template position with no per-construct grammar change. The
*restrictions* are the short, explicit list - enumerated below and enforced
by [`view_body_check`](#static-checks) - not the permissions.

### `if` / `elif` / `else`

```jac
view Auth(user: User | None) {
    if user is None {
        <p>Please sign in.</p>
    } elif user.isAdmin {
        <AdminPanel />
    } else {
        <h1>Welcome, {user.name}</h1>
    }
}
```

Reuses Jac's existing `if` chain. Each branch is its own scope (see
[Lexical Scoping](#lexical-scoping-the-quiet-superpower)).

### `for` - both loop forms

Plain Jac `for`, in either of the language's two loop syntaxes:

```jac
view TodoList(items: list[Todo]) {
    # for-in
    for (i, item) in enumerate(items) {
        if item.hidden {
            continue;
        }
        <li key={jid(item)}>{i + 1}. {item.text}</li>
    }
    # for-to-by
    for n = 0 to n < 3 by n += 1 {
        <Placeholder key={n} />
    }
}
```

No new loop syntax. The two list-rendering concerns borrowed from tsrx are
handled with existing tools:

- **Iteration index** - Python/Jac's `enumerate()`.
- **Stable identity for diffing** - a `key=` attribute on the rendered
  element, the same shape every UI target already expects. Use `jid(x)`
  (Jac's built-in identity primitive) for any archetype instance - it's
  stable, unique, and works without the author having to maintain an `id`
  field. Without a stable key, frameworks fall back to array index, which
  causes state on surviving items (focus, scroll, animation) to bind to the
  wrong rows after inserts or deletes.

Inside any template loop, only `continue` is allowed for control. `break`,
`skip`, and bare `return;` are compile-time errors with a hint pointing at
the surrounding template scope. (Bare `return;` is still valid at the *view
top-level* - see [Guard Returns](#guard-returns).)

### `while`

`while` is a block-bodied construct, so it yields content like any loop:

```jac
view Countdown(from_: int) {
    n = from_;
    while n > 0 {
        <Tick key={n} value={n} />
        n -= 1;
    }
}
```

It carries the same `key=` discipline as `for`, and `view_body_check` warns
when a `while` emits keyless JSX. Prefer a data-driven `for` over a
collection where you can - a `while` whose bound is not derived from data is
a common source of unbounded re-render - but the construct is not
special-cased away.

### `match` and `switch`

Jac's existing `match` works in template position with no syntactic change:

```jac
view Status(status: Literal["loading", "ok", "error"]) {
    match status {
        case "loading": <Spinner />
        case "ok": <CheckIcon />
        case "error": <ErrorIcon />
    }
}
```

Patterns can destructure, guard, and OR-match - strictly more powerful than
tsrx's `switch`:

```jac
match action {
    case {"type": "edit", "id": id}: <Editor {id} />
    case {"type": "view", "id": id}: <Viewer {id} />
    case _: <NotFound />
}
```

Jac's C-style `switch` works the same way for the simple case-on-value form;
reach for `match` when you need destructuring or guards.

### `with` - context boundaries

A `with` block in template position wraps its child fragment in a context
boundary - the natural Jac spelling of a context provider:

```jac
view ThemedPage(dark: bool) {
    with theme(dark=dark) as t {
        <Header />
        <Content />          # `t` is in scope for the whole subtree
    }
}
```

The context manager's entry value is lexically scoped to the block, the same
as any Jac `with`. It lowers to the runtime's provider primitive
(React `<Context.Provider>`).

### `try` / `pending` / `except` / `else`

A template `try` is the **three-state form of an asynchronous result** -
*Pending*, *Resolved*, *Failed* - materialized as content:

```jac
view UserCard(userId: int) {
    try {
        <UserProfile id={userId} />
    } pending {
        <p>Loading…</p>
    } except err {
        <p>Couldn't load: {str(err)}</p>
    }
}
```

| Clause | Renders when |
|--------|--------------|
| `try { … }` | the async work in the block has **resolved** |
| `pending { … }` | the work has been **dispatched but not yet joined** |
| `except [name] { … }` | the work **raised** (ErrorBoundary-equivalent) |
| `else { … }` | optional: `try` completed with no `except` match (ordinary Jac `try…else`) |

`finally` is **not** valid in a template `try` - UI cleanup belongs in
mount/unmount hooks.

**What `pending` is keyed on.** `pending` is not a JS-Suspense-specific
concept. It is defined against Jac's existing concurrency primitive,
`flow` / `wait`: a `flow`-dispatched task - or an `await`, which is
`flow`+`wait` fused - that has not yet been joined is *pending*. The
`pending` clause holds the content valid in the window between **dispatch**
and **join**. Because `flow`/`wait` exists on every Jac target, `pending` is
portable; what differs is only whether that window is observable in a given
target's execution model:

| Target | `flow` lowers to | `pending` is |
|--------|------------------|--------------|
| `cl` | a microtask/Promise; window observed via the render loop | a Suspense placeholder |
| `sv` | a task/thread; window observed by a *remote* client | the early chunk of a streaming response (chunked / SSE), flushed before the resolved content - or, in a walker ability, a progressive `report`: report the partial, then the final |
| `na` | an OS thread; window observed by the calling thread | the value held on the calling thread until `wait` joins |

Because the construct is keyed on `flow`/`wait` and not on rendering,
`try / pending / except` is not template-only. As an ordinary expression it
is a tri-state join:

```jac
value = try { wait task } pending { default } except e { fallback };
```

Before the join the expression's value is the `pending` branch; after a
clean join, the `try` branch; on failure, the `except` branch. Inside a
`view` the branches yield content; outside, they yield values.

**Reachability.** `pending` requires the `try` block to actually contain an
`await` or a `wait` of a `flow` task. If it does not, the `pending` branch
is unreachable and `view_body_check` reports it (see
[Static Checks](#static-checks)) - a semantic check that replaces the old
"pending unsupported on target X" capability gate.

### Guard Returns

A bare `return;` (no value) at view top-level terminates the render with the
template content emitted *so far*:

```jac
view Welcome(user: User | None) {
    if user is None {
        <p>Please sign in.</p>
        return;
    }
    <h1>Welcome, {user.name}</h1>
    <Dashboard {user} />
}
```

Constraints:

- `return value;` (with a value) is an error inside a view body. *"Views
  emit template content; they do not return values."*
- `return;` inside a template loop (`for` or `while`) is an error.
  *"Use `continue`."*

## Refs

One attribute, `ref={EXPR}`. The compiler dispatches on the value's type;
no contextual keyword, no new attribute-brace form.

```jac
view RefDemo() {
    # 1. Callback ref - lambda value
    <input ref={lambda n: HtmlInputElement { n.focus(); }} />

    # 2. Handle ref - Ref[T] value from useRef()
    inputRef = useRef[HtmlInputElement]();
    <input ref={inputRef} />

    # 3. Mutable variable (reactive targets only) - T | None value
    let input: HtmlInputElement | None = None;
    <input ref={input} />

    # 4. Composite - list of any of the above
    <input ref={[inputRef, a, b]} />

    # 5. Pass a ref binding through a prop - just pass the Ref[T]
    <Child myRef={inputRef} />
}
```

Dispatch by value type:

| `ref={…}` value type | Lowering |
|----------------------|----------|
| `(T) -> ()` lambda | callback ref |
| `Ref[T]` (from `useRef`) | handle ref: `r.current = node` |
| `T \| None` mutable var | bind variable to node, trigger on mount/unmount |
| `list[…]` of the above | composite: `mergeRefs(...)` |

Why one form rather than three: the original draft used `{ref EXPR}` as a
JSX attribute-brace prefix and `ref EXPR` as a general-expression prefix
keyword. Both are *contextual* keywords (since `ref` is a common identifier
we don't want to fully reserve). Two contextual keywords across two
sub-grammars (JSX-attribute mode and the general expression grammar), plus
an attribute-brace form `{KEYWORD EXPR}` that no other JSX dialect uses
and that collides with JSX shorthand `{name}`, costs more parser/LSP/
formatter surface than the composite-array form saves the user. Composite
refs become `ref={[a, b, c]}` - what React 19 supports directly. Passing a
binding through a prop becomes ordinary value-passing
(`<Child myRef={inputRef} />`) typed at the receiving boundary.

## Scoped Styles

```jac
view Card(title: str) {
    <div class="card">
        <h2>{title}</h2>
        <Badge className={style "highlight"} />
    </div>
    <style>
        .card { padding: 1.5rem; border: 1px solid #ddd; }
        h2 { color: #333; }
        .highlight { background: #e8f5e9; }
        :global(.tooltip) { z-index: 9999; }
    </style>
}
```

Three primitives:

- `<style>` block - class/id selectors get hashed per view. Multiple `<style>`
  blocks in one view share the scope.
- `:global(…)` - escape hatch; selector passes through un-hashed.
- `{style "name"}` - resolves to the hashed name, passable to children as a
  string prop.

Hash function: `blake2s(module_path + view_name + ord)[:8]`. Stable across
builds, so generated CSS class names diff cleanly.

### Emit Format: pre-hashed plain CSS, side-effect imported

Because the compiler hashes class names at compile time, the *emit* step
needs no CSS-Modules / scoped-attr / CSS-in-JS infrastructure. For each
view (or each `.cl.jac` module that contains views), the styling pass:

1. Rewrites the captured `<style>` body so every class/ID selector carries
   its hashed suffix; selectors inside `:global(…)` lose the wrapper but
   keep their original names.
2. Rewrites every `class="foo"` and `{style "foo"}` reference in the JSX
   to the hashed string directly (no `styles.foo` indirection).
3. Emits the rewritten CSS as a sibling `<view>.css` file and adds a
   side-effect `import "./<view>.css";` to the compiled `.cl.jac` output.

Properties of this choice:

- **Framework-agnostic emit.** The output is a plain
  `<div class="card_a3b9c1d2">` plus a plain `.css` file - no CSS-engine
  bridge, no CSS-in-JS runtime. This keeps the styling layer target-neutral
  even though the only shipped emitter is react/preact, so the SSR path and
  any future emitter consume it unchanged.
- **No bundler config.** `.css` side-effect imports work in Vite, webpack,
  Rspack, Turbopack, Bun, Parcel, esbuild without any plugin. CSS Modules
  would require the loader to recognize `.module.css` and emit a JS export
  object; we don't need that because we're not deferring hashing to the
  loader.
- **SSR-friendly.** The bundler emits the CSS as part of the asset graph,
  so SSR setups inject `<link>` tags automatically.
- **Bundler-free dev mode works.** A plain `<link rel="stylesheet">` is
  enough; no module-loader runtime required.

Rejected alternatives:

- **CSS Modules** (`<view>.module.css` + `import s from "./..."` + `s.foo`
  references) - strict superset of what we need; the loader-config and
  indirection buy nothing once hashing is the compiler's job.
- **Runtime `<style>` injection** - FOUC on hydration, double-injection
  risk in SSR, runtime cost on every module load.
- **CSS-in-JS** - the JS ecosystem is migrating away (Next.js dropped
  styled-components support; React docs warn against runtime CSS-in-JS
  for RSC); locking the emit format to a model that's losing momentum
  would age badly.
- **Scoped-attr (Vue-style `data-v-*`)** - a framework-internal scoping
  mechanism, not a portable emit format. Adopting it would mean
  reimplementing runtime attr-injection for no win over compile-time hashing.

## Dynamic Tags

```jac
view Box(as_: str | type, children: any) {
    <@as_ class="box">{children}</@as_>
}

view Demo() {
    <Box as_="article">Inside an article element</Box>
    <Box as_={Section}>Inside Section view</Box>
}
```

`<@expr />` accepts a string (host tag), a view reference, or a value of type
`str | type`. The compiler skips attribute type-checking inside dynamic
elements - the tag is unknown.

`as_` (not `as`) - `as` is reserved in Jac for import aliases.

## Props & Attributes

Attributes use **camelCase** - same convention as the existing Jac JSX (which
this compiles into) and same as React/Solid/Vue.

```jac
view Form(name: str, onSubmit: Callable[[], None]) {
    # Shorthand: {name} → name={name}
    <input {name} onChange={lambda e: ChangeEvent { /* … */ }} />

    # Children passed positionally inside the tag:
    <Card>
        <h2>Title</h2>
        <p>Body</p>
    </Card>

    # Or via explicit prop:
    <List children={[renderItem(it) for it in items]} />

    # Spread (Python style):
    <input {**rest} />
}
```

For values needed as a template *value* (prop, variable, match branch
result), use the existing expression-form JSX:

```jac
view Header(brand: str) {
    title = (<span>Welcome to {brand}</span>);   # ordinary expression JSX
    <Banner title={title} />
}
```

No new "island" syntax is needed - `view` adds a *statement* form; the
existing *expression* form continues to work for values.

## State: Three Layers

Jac's existing client-side codegen already gives `has`-fields automatic
`useState` wiring inside components. `view` keeps that and adds two opt-in
patterns for state that lives outside the view.

### Layer 1 - View-local state (existing, no change)

`has`-fields declared inside a view body are component-local and reactive by
the existing codegen - assignment is rewritten to the generated setter.

```jac
view Toggle() {
    has open: bool = False;

    def flip {
        open = not open;     # already rewrites to setOpen(not open) at compile
    }

    <button onClick={flip}>{"Open" if open else "Closed"}</button>
    if open {
        <div class="panel">Contents…</div>
    }
}
```

This is what `day_planner` already does. No new primitive needed.

### Layer 2 - Shared `obj` state (new: `by view`)

When several views need to observe the same state, you can't put it in any
one view's `has`-fields. Today this means passing setters around. The
`by view` clause on an `obj` field opts that field into the same
reactivity machinery, but **on the obj instance itself** rather than on a
single view:

```jac
obj Cart {
    has items: list[Item] = [] by view;
    has taxRate: float = 0.08 by view;

    has version: int = 0;          # plain field - not tracked
}

view CartView(cart: Cart) {
    <p>Items: {len(cart.items)}</p>
    <p>Tax: {cart.taxRate * 100}%</p>
}

view CartActions(cart: Cart) {
    <button onClick={lambda { cart.items = cart.items + [Item()]; }}>
        Add item
    </button>
}
```

Pass the same `Cart` instance to both views and they observe the same fields.
The lowering emits a `useSyncExternalStore` subscription per accessed field
on the react/preact target.

**Mutation rule: reassign, don't mutate in place.** Tracking is keyed on the
field reference, so `cart.items = cart.items + [x]` triggers re-render,
while `cart.items.append(x)` does **not** - the list object is the same. The
`view_body_check` pass lints `.append` / `.pop` / `.clear` / `del cart.items[i]`
/ etc. on `by view` fields and suggests the reassignment form. No
`ReactiveList` wrapper; the cost is verbosity, the benefit is one obvious
mental model with no `isinstance` / equality / third-party-function surprises.

### Derivations: plain `def` is enough

Computed values that depend on `by view` fields are just regular methods:

```jac
obj Cart {
    has items: list[Item] = [] by view;
    has taxRate: float = 0.08 by view;

    def subtotal -> float {
        return sum(it.price for it in self.items);
    }

    def total -> float {
        return self.subtotal * (1 + self.taxRate);
    }
}

view CartView(cart: Cart) {
    <p>Subtotal: ${cart.subtotal}</p>
    <p>Total: ${cart.total}</p>
}
```

No `by computed` / `useMemo` / `createMemo` needed. The subscription tracker
sees reads of `cart.items` and `cart.taxRate` happen *during render*
(transitively, through the method calls) and subscribes the view to both.
When either changes, the view re-renders and the methods recompute against
fresh values.

If a derivation is genuinely expensive and you need caching, hold a `has
cached: T | None = None` field and invalidate it explicitly - at that point
you usually want the explicitness anyway, because cache invalidation needs
careful thought.

### Summary

| Where the state lives | How to declare it |
|-----------------------|-------------------|
| One view | `has x: T = …` inside the `view` body (existing auto-`useState`) |
| One shared `obj` | `has x: T = … by view` on the obj |
| Derived from `by view` state | plain `def f -> T { … }` on the obj |

## Compilation Targets

Jac already has an ecmascript codegen pass
([esast_gen_pass.jac](../jac/jaclang/compiler/passes/ecmascript/esast_gen_pass.jac))
that emits JSX-flavored JS from `.cl.jac` files. `view` compiles through that
same pipeline - the new statement-based body, scoped styles, and boundary
clauses are lowered to the JSX-AST the existing pass already understands.

**One client emitter: react/preact.** `view` does not ship emitters for
other JS frameworks (Solid, Vue, Ripple). The existing ecmascript codegen +
`@jac/runtime` is the single client target. A multi-framework emitter zoo is
a large, speculative maintenance surface - a whole codegen pass, runtime
mapping, and capability gating per target - for no current user. It is
explicitly out of scope.

What *is* preserved is the *option*. The `view` lowering stays target-neutral
where that costs nothing: the scoped-CSS emit is plain pre-hashed CSS (see
[Scoped Styles](#scoped-styles)) and the intermediate form is not
gratuitously React-shaped. A future emitter remains possible without a
rewrite; it is simply not built now.

**Server-side rendering is a different axis.** Rendering a `view` on the
server is not "another framework target" - it is the `sv` half of Jac's
existing `cl` / `sv` split-compile. The Python SSR path renders a view to a
`VNode` tree in a `to sv:` context, and is where the `pending` clause lowers
to streaming SSR (see [Control Flow](#try--pending--except--else)). It is in
scope as part of the cl/sv story, not as a competing backend.

| Path | Status | Notes |
|------|--------|-------|
| react / preact (`cl`) | exists | existing ecmascript codegen + `@jac/runtime` |
| Python SSR (`sv`) | proposed | server-side render of a view to a `VNode` tree; `pending` streams |

## Bundler Integration

A single Vite/Rspack/Turbopack/Bun plugin, `@jaclang/vite-plugin-view`:

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import jacView from '@jaclang/vite-plugin-view';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [jacView(), react()],
});
```

The plugin shells out to `jac build`, gets back JSON
(`{code, css, sourcemap, diagnostics}`), and hands the result to the
downstream JSX plugin. CSS sidecars are emitted as plain `.css` files (see
[Scoped Styles](#scoped-styles)).

## Worked Example: Todo App

A `.cl.jac` file using the existing client-side compile pipeline. Shows
view-local state (`has` in a view), shared state (`by view` on an obj),
plain-method derivations, control flow as content, scoped styles, and a
suspense boundary.

```jac
"""A minimal todo app - view declarator on Jac's existing JSX foundation."""

sv import from .types { Todo, TodoStore, get_tasks, save_task, delete_task }

obj TodoStore {
    has items: list[Todo] = [] by view;
    has filter_: Literal["all", "active", "done"] = "all" by view;

    def visible -> list[Todo] {
        match self.filter_ {
            case "all":    return self.items;
            case "active": return [t for t in self.items if not t.done];
            case "done":   return [t for t in self.items if t.done];
        }
    }

    async def add(text: str) {
        task = await save_task(text);
        self.items = self.items + [task];
    }

    async def remove(id: str) {
        await delete_task(id);
        self.items = [t for t in self.items if jid(t) != id];
    }
}

view FilterBar(store: TodoStore) {
    for f in ["all", "active", "done"] {
        <button key={f}
                onClick={lambda { store.filter_ = f; }}
                class={"active" if store.filter_ == f else ""}>
            {f}
        </button>
    }
    <style>
        button { margin-right: 0.5rem; }
        button.active { font-weight: bold; }
    </style>
}

view TodoItem(todo: Todo, onDelete: Callable[[str], None]) {
    <li class={"done" if todo.done else ""}>
        <input type="checkbox"
               checked={todo.done}
               onChange={lambda { todo.done = not todo.done; }} />
        <span>{todo.text}</span>
        <button onClick={lambda { onDelete(jid(todo)); }}>X</button>
    </li>
    <style>
        li.done span { text-decoration: line-through; opacity: 0.6; }
    </style>
}

view TodoApp(store: TodoStore) {
    has draft: str = "";          # view-local, auto-reactive (existing useState wiring)

    async def submit {
        if draft.strip() {
            await store.add(draft);
            draft = "";
        }
    }

    <main>
        <h1>Todos</h1>
        <form onSubmit={submit}>
            <input value={draft}
                   onChange={lambda e: ChangeEvent { draft = e.target.value; }} />
            <button type="submit">Add</button>
        </form>

        <FilterBar {store} />

        try {
            if not store.visible {
                <p class="empty">Nothing to show.</p>
                return;
            }
            <ul>
                for t in store.visible {
                    <TodoItem key={jid(t)} todo={t}
                              onDelete={lambda id: str { store.remove(id); }} />
                }
            </ul>
        } pending {
            <p>Loading…</p>
        } except err {
            <p class="error">Couldn't load: {str(err)}</p>
        }
    </main>

    <style>
        main { max-width: 32rem; margin: 2rem auto; }
        .empty { color: #999; font-style: italic; }
        .error { color: #c00; }
    </style>
}

with entry {
    import from "@jac/runtime" { mount }
    mount(TodoApp(store=TodoStore()));
}
```

What's worth pointing out:

- **`has draft: str = "";` inside `TodoApp`** - the existing auto-`useState`
  codegen takes care of reactivity. Assigning `draft = ""` rewrites to the
  generated setter.
- **`by view` fields on `TodoStore`** - `items` and `filter_` are shared
  across `FilterBar`, `TodoApp`, etc. Mutating from anywhere triggers
  re-render everywhere.
- **`visible` is a plain `def`** - the subscription tracker sees the reads of
  `items` and `filter_` during render and subscribes accordingly; no
  explicit memoization needed.
- **Statement-form body** - no big `return`, no nested ternaries, no manual
  loading flag. The `try/pending/except` block makes the loading/error
  branches explicit.
- **Early `return;`** - clean empty-state guard inside the `try`.
- **All lambdas use block-body** - Jac's existing `lambda { … }` form, no
  new closure syntax invented.
- **Reactive wiring is the existing client codegen** - `has`-fields use
  `useState`, `by view` fields use `useSyncExternalStore`. The same file can
  also render server-side via the Python SSR path.

## Static Checks

A new pass `view_body_check` (after typecheck) enforces:

| Rule | Diagnostic |
|------|------------|
| `return expr;` in a view body | E_VIEW_VALUE_RETURN |
| `return;` inside a template loop (`for` / `while`) | E_VIEW_RETURN_IN_LOOP |
| `break;` / `skip;` in a template loop | E_VIEW_BREAK_IN_LOOP |
| `try / finally` in a template `try` | E_VIEW_FINALLY_NOT_ALLOWED |
| `pending` clause whose `try` block has no `await` / `wait` | E_VIEW_PENDING_UNREACHABLE |
| `while` emitting keyless JSX | W_VIEW_WHILE_KEYLESS (warning) |
| `{html …}` not sole child (host element only) | E_VIEW_HTML_NOT_SOLE_CHILD |
| `<@expr />` with non-`str | view`-typed expr | E_VIEW_DYN_TAG_TYPE |

## Implementation Plan

The whole design lands in **three phases**, each ending in a single,
independently-mergeable pull request. The ordering is chosen so that every
PR is shippable on its own: PR 1 makes `view` usable, PR 2 completes the
single-target feature surface, PR 3 generalizes across runtimes. Throughout,
`def:pub Name -> JsxElement` keeps working unchanged - `view` is additive.

The work builds on the existing pipeline (parser at
[jac/jaclang/jac0core/parser/](../jac/jaclang/jac0core/parser/), ecmascript
codegen at
[esast_gen_pass.jac](../jac/jaclang/compiler/passes/ecmascript/esast_gen_pass.jac),
runtime at
[jac_runtime_js.jac](../jac/jaclang/compiler/passes/ecmascript/jac_runtime_js.jac)),
not parallel to it.

### Phase 1 - Declarator, statement templates, control flow

The structural core: a `view` is parsed, type-checked, and lowered as a
`def:pub -> JsxElement` whose body is statements instead of one `return`.

- **Grammar / parser** - add `[access] view Name[generics](params) { body }`,
  reusing the existing archetype/`def` parse path so the result shares the
  internal AST with `def -> JsxElement`. Body statements lower into an
  implicit return-fragment.
- **Statement-position control flow** - implement the inverted rule: every
  block-bodied construct (`if/elif/else`, both `for` forms, `while`,
  `match`, `switch`, `with`) emits its block as a fragment in template
  position. `with` lowers to the default target's context-provider
  primitive.
- **Per-element lexical scoping** - reuse Jac's existing `{ }` block
  scoping; opening a template tag opens a scope.
- **`{text …}` / `{html …}`** contextual keywords in JSX child position.
- **`view_body_check` pass** (after typecheck) - guard-return rules and the
  loop diagnostics: `E_VIEW_VALUE_RETURN`, `E_VIEW_RETURN_IN_LOOP`,
  `E_VIEW_BREAK_IN_LOOP`, `W_VIEW_WHILE_KEYLESS`.
- **Codegen** - lower to the existing ecmascript pass; no new emitter.
- **Tests** - parser tests for the declarator; golden ecmascript output for
  each control-flow construct; `view_body_check` diagnostic tests.

> **PR 1** - `view` is a drop-in for `def:pub -> JsxElement` with
> statement bodies, control flow, and lexical scoping, emitting to the
> current react/preact default target. Acceptance: a `view` port of an
> existing `day_planner` component compiles and renders identically.

### Phase 2 - Boundaries, scoped styles, refs, dynamic tags

Completes the single-target feature surface from the design.

- **`try / pending / except / else`** - template-position clauses.
  `pending` is keyed on `flow`/`wait` (see
  [Control Flow](#try--pending--except--else)); the cl lowering targets the
  `@jac/runtime` Suspense/ErrorBoundary equivalents. Implement the tri-state
  *expression* form too, since it is language-level, not view-only.
  Diagnostics: `E_VIEW_FINALLY_NOT_ALLOWED`, `E_VIEW_PENDING_UNREACHABLE`.
- **Scoped `<style>`** - syntactic `<style>`-block capture, `blake2s`
  class-name hashing, `:global(…)` escape, `{style "name"}` attribute form,
  and the pre-hashed-CSS sidecar emit with a side-effect `import`.
- **`ref={EXPR}`** - single attribute, dispatch by value type
  (callback / `Ref[T]` / mutable var / composite list).
- **`<@expr />`** dynamic tags, with `E_VIEW_DYN_TAG_TYPE`.
- **Tests** - boundary-clause golden output and runtime behavior; CSS
  hashing stability across builds; ref dispatch per value type; dynamic-tag
  type checks.

> **PR 2** - the full `view` feature set on the default target: async/error
> boundaries, scoped styles, refs, dynamic tags. Acceptance: the
> [Todo App worked example](#worked-example-todo-app) compiles, renders, and
> passes its suspense/error paths.

### Phase 3 - Shared reactivity, SSR, and tooling

Completes the design: shared state across views, server-side rendering, and
toolchain integration. There are no multi-framework emitters - react/preact
stays the single client target (see
[Compilation Targets](#compilation-targets)).

- **`by view` shared state** - extend the `by`-clause family on `obj`
  fields; field codegen wraps reads/writes with `useSyncExternalStore`.
  `view_body_check` lints in-place mutation of `by view` fields and rejects
  `by view` outside client-targeted code.
- **Python SSR** - render a `view` to a `VNode` tree in a `to sv:` context;
  this is where the `pending` clause lowers to streaming SSR.
- **Bundler plugin** - `@jaclang/vite-plugin-view`.
- **Advanced** - generic views end-to-end, lazy loading + Suspense pairing,
  and the `useWalker(MyWalker, …)` data-fetching primitive.
- **Tests** - `by view` subscription and mutation-lint tests; SSR
  round-trip; bundler-plugin integration smoke test.

> **PR 3** - shared reactivity, server-side rendering, and bundler
> integration on the single react/preact target. Acceptance: the
> [Todo App worked example](#worked-example-todo-app) runs with `by view`
> shared state and renders server-side via the SSR path.
