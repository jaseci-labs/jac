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

An editable install of `jaclang` (which now includes the built-in `scale`
subsystem) is auto-wired by the runner; no manual `JAC_DESKTOP_*` or
`LD_LIBRARY_PATH` setup is needed.

## Backend smoke test (no window)

```bash
jac test jac/examples/todo_app/test_todo.jac -v
```

Boots `main.jac` through `inprocess_dispatch` and exercises create / read /
toggle walkers the same way the embedded host does.

## Desktop plugin capabilities (least privilege)

Desktop SDK capabilities are off by default -- enable only what the app uses
under `[plugins.desktop.plugins]` in `jac.toml`. For example, an app that only
sends an OS notification turns on just that one:

```toml
# Least privilege: only the capabilities the app actually uses are enabled.
# Others (window, path, clipboard, dialog, fs, shell) stay off; fs/shell
# additionally require allow-lists.
[plugins.desktop.plugins]
notification = true
```

Call capabilities through the typed `@jac/desktop` SDK rather than hand-writing
`window.__jac.invoke()` strings -- SDK calls take positional args and return a
promise that rejects with an `Error` carrying the host's `.code`:

```jac
cl import from "@jac/desktop" { notification }

notification.send("Test", "Hello!")
    .then(lambda r: any { msg = "Notification sent!"; })
    .catch(lambda e: any { msg = "Error: " + str(e); });
```
