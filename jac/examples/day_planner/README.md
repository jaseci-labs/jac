# AI Day Planner -- three variants

A small full-stack day planner with AI-powered task categorization and a meal-to-shopping-list generator. The same UI is implemented three ways so you can compare the architectural styles side by side. All three variants are built end-to-end in the [Build an AI Day Planner](../../../docs/docs/tutorials/first-app/build-ai-day-planner.md) tutorial.

| Variant | Backend style | Auth | Layout |
|---------|---------------|------|--------|
| [basic/](basic/) | `def:pub` functions, single file | none (shared graph) | `main.jac` + `styles.css` |
| [auth/](auth/) | `def:priv` functions, declaration/implementation split | username/password, per-user graph | `main.jac` + `frontend.cl.jac` + `frontend.impl.jac` + `styles.css` |
| [walkers/](walkers/) | `walker:priv` with object-spatial abilities | username/password, per-user graph | same file split as `auth/` |

The behavior is identical across variants -- what changes is *how* the server is written and how the client invokes it.

## Run any variant

Each variant is a standalone Jac project. Set your Anthropic API key once, then `cd` into the variant you want and start the dev server:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
cd basic            # or auth/  or walkers/
jac start main.jac
```

Open http://localhost:8000 to use the app, http://localhost:8000/docs for the OpenAPI/Swagger UI, and http://localhost:8000/graph for a live visualization of the persisted node graph.

## What each variant teaches

**`basic/`** -- the full-stack mental model in one file. AI-typed enums (`Category`, `Unit`) and `obj Ingredient` shape both the LLM output and the client-server contract. `def:pub` exposes endpoints; the `cl def:pub app` component holds reactive `has` state and re-renders on assignment. Everyone shares the same `root` graph.

**`auth/`** -- same app, but private. Switching the endpoints from `def:pub` to `def:priv` gives every authenticated user their own `root` and complete data isolation, with no changes to business logic. The frontend is split into `frontend.cl.jac` (declarations + render tree) and `frontend.impl.jac` (`impl app.method { ... }` bodies). `to cl:` / `to sv:` headers in `main.jac` keep server and client in one entry point.

**`walkers/`** -- the object-spatial reimplementation. Instead of functions reaching into the graph, `walker:priv` agents traverse it with `visit [-->]`, `here`, `report`, and `disengage`. The frontend spawns walkers (`root spawn AddTask(title=...)`) instead of calling functions. `GenerateShoppingList` shows the multi-step pattern: queue traversal of existing items, generate new ones, and let `with ShoppingItem entry` clean up the old set as a side-effect of the visit.

## Tutorial mapping

- `basic/` corresponds to Parts 3-5 of the tutorial (the linear single-file build).
- `auth/` corresponds to Part 6 (auth + multi-file split).
- `walkers/` corresponds to Part 7 (OSP).
