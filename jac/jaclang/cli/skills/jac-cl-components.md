---
name: jac-cl-components
description: Write Jac client components with reactive state, typed props, JSX, and effects. Use when creating components or fixing client binding errors.
---

# Client components

Use typed Jac functions returning `JsxElement`, reactive `has` state, and `can with entry` effects. JSX makes the component client-placed. Read `jac-cl-routing` only when adding routes, and `jac-cl-auth` when adding authentication.

```jac
def:pub Counter -> JsxElement {
    has count: int = 0;
    def increment { count = count + 1; }
    <button onClick={increment}>{count}</button>
}
```

## Rules that affect generated code

- Component `has` state is accessed by its bare name, without `self`. Rebind collections to fresh values when updating them; in-place mutation retains the same reference and may not render. Plain locals and `glob` are not reactive state.
- Annotate props and callback contracts. Jac lambdas use `lambda (x: T) { ... }`, not JavaScript arrow syntax.
- Type event parameters for the event being handled, such as `e: ChangeEvent`. Capture domain values in a closure rather than mistaking the event argument for an item ID. Check the event table for specialized event types.
- Await server calls in async handlers or effects. A synchronous render body must not start unawaited bridge work and treat the result as a value.
- `JsxElement` and supported browser/event types are ambient in client code. Import runtime functions according to their actual exports.
- Effects with dependencies can rerun. Their exit cleanup uses the entry execution's closure; capture the resource being cleaned up rather than relying on a later mutable ref.
- JSX comments use `{#* comment *#}`. Keep significant spaces as explicit string children such as `{" "}`.
- Use a component's declared props. Inspect an imported component before inventing callback names or assuming it forwards every HTML attribute.

## Retrieve the needed pattern

The complete examples and exception tables are bundled separately:

```bash
jac guide reference/agent-patterns/jac-cl-components --sections
jac guide reference/agent-patterns/jac-cl-components --section props
```

Read **Effects** for subscriptions or cleanup, **Statement slots** for control flow inside JSX, **Imports** for runtime exports, and **Pitfalls** for handler binding, scope, and rendering errors. Use the exact slugs printed by `--sections`.

Run `jac check` on the component or app, then test the affected interaction in the running app. Type-checking alone does not verify event binding or effect cleanup.
