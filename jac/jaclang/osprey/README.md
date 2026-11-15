# Osprey

A retained, semantic terminal UI framework for Jac.

The live UI is an OSP graph: semantic regions are nodes, and containment,
focus, data feeds, ownership and layers are typed edges. Geometry, cell
buffers, damage and cursor state live in process-local side tables. Osprey
ships a constraint layout solver, a damage-tracked renderer, process and
in-memory terminal hosts, an input normalizer, markdown projection, and an
editor and transcript stack.

## Layout

| Path | Role |
|------|------|
| `ui/` | The framework: model, mutation, bindings, events, terminals, renderer, editor, transcript, layout, markup, focus, gates, widgets |
| `constraints/` | The constraint layout solver |
| `cordis/` | Composition core: revertible effects and reactive coeffects |
| `core/` | Edit and diff kernel |

## Where it lives

Osprey is developed inside the Jac repository at `jac/jaclang/osprey`, where
the `jac hack` workspace is built on it, and is mirrored here with
`git subtree`. Make changes in the Jac repository; from its root:

```bash
# bring changes made here into jac
git subtree pull --prefix=jac/jaclang/osprey https://github.com/chess10kp/osprey.git main --squash
# publish changes made in jac back here
git subtree push --prefix=jac/jaclang/osprey https://github.com/chess10kp/osprey.git main
```

Try the demo from a Jac checkout:

```bash
jac run jac/jaclang/osprey/ui/demo_entry.jac
```

## Acknowledgements

- [Pi](https://pi.dev), whose TUI inspired this one.
