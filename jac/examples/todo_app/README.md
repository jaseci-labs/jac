# Todo desktop example

A runnable Jac desktop app adapted from
[`jac-client/jac_client/templates/fullstack`](../../../jac-client/jac_client/templates/fullstack).
Same todo UI (add, toggle, filter, delete) with walkers running in-process via
the native desktop host (#6596).

## Run the app

```bash
cd jac/examples/todo_app
jac start --client desktop
```

Editable installs of `jaclang` and `jac-scale` are auto-wired by
the runner; no manual `JAC_DESKTOP_*` or `LD_LIBRARY_PATH` setup is needed.

## Backend smoke test (no window)

```bash
jac test jac/examples/todo_app/test_todo.jac -v
```

Boots `main.jac` through `inprocess_dispatch` and exercises create / read /
toggle walkers the same way the embedded host does.
