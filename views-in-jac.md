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
- **Statement-position `if` / `for` / `match`** - replaces nested ternaries
  and inline comprehensions.
- **`try` / `pending` / `except`** - declarative async/error boundaries that
  replace manual `loading: bool` plumbing.
- **Bare `return;` guard pattern** - clean early-exit without nesting the
  whole body in an `if/else`.
- **Per-element lexical scoping** - locals declared inside an element stay
  scoped to that subtree.
- **Scoped `<style>` blocks** - inline CSS hashed per view.

**Borrowed from tsrx (with Jac voice):**

- `pending` as a `try`-clause keyword.
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

Every Jac control-flow construct (`if`, `for`, `match`, `try`) can now appear
in template position, with branches producing template content.

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

### `for…in`

```jac
view TodoList(items: list[Todo]) {
    for (i, item) in enumerate(items) {
        if item.hidden {
            continue;
        }
        <li key={jid(item)}>{i + 1}. {item.text}</li>
    }
}
```

No new loop syntax - plain Jac `for`. The two list-rendering concerns
borrowed from tsrx are handled with existing tools:

- **Iteration index** - Python/Jac's `enumerate()`.
- **Stable identity for diffing** - a `key=` attribute on the rendered
  element, the same shape every UI target already expects. Use `jid(x)`
  (Jac's built-in identity primitive) for any archetype instance - it's
  stable, unique, and works without the author having to maintain an `id`
  field. Without a stable key, frameworks fall back to array index, which
  causes state on surviving items (focus, scroll, animation) to bind to the
  wrong rows after inserts or deletes.

Inside a template `for`, only `continue` is allowed for control. `break` and
bare `return;` are compile-time errors with a hint pointing at the surrounding
template scope. (Bare `return;` is still valid at the *view top-level* - see
[Guard Returns](#guard-returns).)

### `match`

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

### `try` / `pending` / `except`

Three template-position behaviors bundled in one block:

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
| `try { … }` | normal path |
| `pending { … }` | a child is async/suspended (Suspense-equivalent) |
| `except [name] { … }` | a child raises (ErrorBoundary-equivalent) |

`pending` is a new clause keyword legal only in template-position `try`. The
ordinary Jac `try / except / finally` is unchanged elsewhere. `finally` is
**not** valid in a template `try` - UI cleanup belongs in mount/unmount
hooks.

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
- `return;` inside a template `for` is an error. *"Use `continue`."*

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

Dispatch by value type (already what the per-target lowering does):

| `ref={…}` value type | Lowering |
|----------------------|----------|
| `(T) -> ()` lambda | callback ref |
| `Ref[T]` (from `useRef`) | handle: `r.current = node` (React) / native ref binding (Solid/Vue/Ripple) |
| `T \| None` mutable var | reactive-target only: bind variable to node, trigger on mount/unmount |
| `list[…]` of the above | composite: `mergeRefs(...)` on React, native array `ref={[a,b,c]}` on Solid, compile-error on Vue |

Why one form rather than three: the original draft used `{ref EXPR}` as a
JSX attribute-brace prefix and `ref EXPR` as a general-expression prefix
keyword. Both are *contextual* keywords (since `ref` is a common identifier
we don't want to fully reserve). Two contextual keywords across two
sub-grammars (JSX-attribute mode and the general expression grammar), plus
an attribute-brace form `{KEYWORD EXPR}` that no other JSX dialect uses
and that collides with JSX shorthand `{name}`, costs more parser/LSP/
formatter surface than the composite-array form saves the user. Composite
refs become `ref={[a, b, c]}` - exactly what Solid emits natively, what
React 19 supports, and what the Solid lowering in this doc was already
producing. Passing a binding through a prop becomes ordinary value-passing
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

- **Identical lowering across all targets.** React, Preact, Solid, Vue
  Vapor, and Ripple all consume `<div class="card_a3b9c1d2">` the same
  way. No per-target CSS-engine bridge; Vue's scoped-attr is an
  implementation Vue uses internally, not a requirement Vue imposes on
  consumers.
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
- **Scoped-attr (Vue-style `data-v-*`)** - Vue's *internal* scoping
  mechanism, not a portable emit format. Adopting it would require
  reimplementing Vue's runtime attr-injection on React/Solid for no win.

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
The lowering (per target):

- React/Preact: emit a `useSyncExternalStore` subscription per accessed field.
- Solid/Ripple: wrap the field with the target's signal/tracked primitive.
- Vue Vapor: `shallowRef` on each reactive field.

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
that emits JSX-flavored JS from `.cl.jac` files. The default target stays
the same - `view` compiles through the same pipeline. The new statement-
based body, scoped styles, and boundary clauses are lowered to the JSX-AST
the existing pass already understands.

Beyond the existing default emitter, additional targets can be added later:

| Target | Status | Notes |
|--------|--------|-------|
| react / preact (current default) | exists | via existing ecmascript codegen + `@jac/runtime` |
| solid | proposed | `<Show>` / `<For>` / `<Switch>` / `<Errored>` / `<Suspense>` mapping |
| vue (Vapor) | proposed | `defineVaporComponent`; `pending` blocks compile-fail with hint |
| ripple | proposed | closest semantic match - `try/pending/except` passes through |
| python | proposed | server-side render to `VNode` tree |

A **capability table** in the compiler gates features per target - e.g.
`pending` blocks compile-fail on Vue with a hint. Per-target emitters would
live under `jac/jaclang/compiler/passes/views/` alongside the existing
ecmascript pass.

### JIR Integration

A new TLV section `SEC_VIEW_TARGET = 0x06` caches the per-target emit in the
existing `.jir` (format v8, see `jac/jaclang/jac0core/jir.jac`). Section body
carries `(target_id, emit_source, sourcemap)`. The JIR reader picks the
section matching the active `--view-target`. Multiple targets coexist in one
JIR file - useful when a library is consumed by apps targeting different
runtimes.

## Bundler Integration

A single Vite/Rspack/Turbopack/Bun plugin (`@jaclang/view-plugin`)
parametrized by target:

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import jacView from '@jaclang/vite-plugin-view';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [jacView({ target: 'react' }), react()],
});
```

The plugin shells out to `jac build`, gets back JSON
(`{code, css, sourcemap, diagnostics}`), and hands the result to the
downstream JSX plugin. CSS sidecars are emitted as `.jac.module.css`.

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
- The same file emits to React (`useState` + `useSyncExternalStore`), Solid
  (`createSignal`), Vue Vapor (`shallowRef`), or Ripple (`track`) - chosen at
  build time.

## Static Checks

A new pass `view_body_check` (after typecheck) enforces:

| Rule | Diagnostic |
|------|------------|
| `return expr;` in a view body | E_VIEW_VALUE_RETURN |
| `return;` inside a template `for` | E_VIEW_RETURN_IN_LOOP |
| `break;` in a template `for` | E_VIEW_BREAK_IN_LOOP |
| `try / finally` in a template `try` | E_VIEW_FINALLY_NOT_ALLOWED |
| `{html …}` not sole child (Vue/Solid host-only) | E_VIEW_HTML_NOT_SOLE_CHILD |
| `<@expr />` with non-`str | view`-typed expr | E_VIEW_DYN_TAG_TYPE |
| Composite refs targeting Vue | E_VIEW_COMPOSITE_REF_UNSUPPORTED |
| `pending` block targeting Vue | E_VIEW_PENDING_UNSUPPORTED |

## Phased Implementation Path

Built on top of the existing JSX infrastructure, not parallel to it.

**Phase 1 - `view` declarator + statement-form body**

- Grammar: add `view Name(params) { body }` parsing, sharing the same
  internal AST as the existing `def -> JsxElement` (lowering point: body
  statements wrap into an implicit return-fragment).
- Type checker: reuse existing JSX type rules.
- Codegen: lower to existing ecmascript pass; no new emitter needed.
- Compatibility: existing `def:pub Name -> JsxElement` keeps working.

**Phase 2 - Statement-position control flow**

- Allow `if` / `for` / `match` at view-body statement position to emit
  children directly (instead of having to be wrapped in `{}` as an
  expression).
- `view_body_check` pass with diagnostics for `return value;`,
  `return;` in `for`, `break;` in `for`.
- Bare-return guard pattern.

**Phase 3 - Boundary clauses + scoped styles**

- Template-position `try / pending / except` clauses; lower to existing
  `@jac/runtime` Suspense/ErrorBoundary equivalents.
- `<style>` block parsing; class-name hashing pass; `:global(…)` escape.
- `{style "name"}` attribute form for cross-component class composition.

**Phase 4 - Shared reactivity (`by view`)**

- Extend `by`-clause family. Field codegen wraps reads/writes with the
  runtime subscription primitive.
- `useSyncExternalStore`-based lowering for current React/Preact emit
  pipeline.
- `view_body_check` rejects `by view` outside client-targeted code.

**Phase 5 - Additional targets**

- Solid emitter with `<Show>` / `<For>` / `<Switch>` / `<Suspense>` mapping.
- Ripple emitter (close to direct pass-through).
- Vue Vapor emitter with capability-driven rejections.

**Phase 6 - Advanced**

- Dynamic elements `<@expr />`.
- Lazy loading + Suspense pairing.
- Generic views end-to-end.
- Walker-driven data fetching primitive (`useWalker(MyWalker, …)`).

## Related Documents

For deeper dives on individual sub-features (multi-target capability
tables, per-target lowerings, bundler plugin shapes), see the
feature-by-feature roadmap under [tsrx-in-jac/](./tsrx-in-jac/). That
catalog still uses the original "absorb tsrx wholesale" framing; this
document selects from it and reshapes the result for Jac's existing
foundation.
