"""sv->sv consumer for the E1042 context-sensitivity regression.

This is a *server* module (`.jac`) that consumes another server via a
relative `sv import`. Unlike the cl->sv case, an sv->sv import lowers to a
synchronous `def` stub (the runtime spawns the provider as its own process
and routes the call), so `get_tasks()` returns the bare `list[Task]`
synchronously -- no `await`, and binding it to a concrete type must NOT
raise E1042.

The mirror cl->sv fixture (type_E1042_sv_missing_await.cl.jac) imports the
SAME provider and MUST still raise E1042, proving the check is sensitive to
the importing module's context, not just the `sv import` keyword.
"""

sv import from type_E1042_sv_missing_await_server { Task, get_tasks }

def:pub gather -> list[Task] {
    # sv->sv: synchronous call, no `await`. Must type-check cleanly.
    tasks: list[Task] = get_tasks();
    return tasks;
}
