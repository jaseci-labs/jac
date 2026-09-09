"""Same-app server consumer for the E1042 context-sensitivity regression.

This is a *server* module (`.jac`) that imports another server module of
the same (implicit) app. That is a LOCAL import, not a bridge: there is no
app boundary between the two files, so `get_tasks()` is a plain call that
returns the bare `list[Task]` synchronously -- no `await`, and binding it
to a concrete type must NOT raise E1042. (A server consumer that crosses an
app boundary is a SERVICE_BRIDGE and its stub IS a coroutine; that case
lives in tests/compiler/test_cross_app_import.jac.)

The mirror client fixture (type_E1042_sv_missing_await.jac) imports the
SAME provider and MUST still raise E1042, proving the check is sensitive to
the importing module's context, not to the import statement's shape.
"""

import from type_E1042_sv_missing_await_server { Task, get_tasks }

def:pub gather -> list[Task] {
    # same app, server to server: a plain synchronous call, no `await`.
    tasks: list[Task] = get_tasks();
    return tasks;
}
