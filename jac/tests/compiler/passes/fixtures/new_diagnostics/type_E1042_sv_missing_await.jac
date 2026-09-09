"""Client fixture reproducing issue #6236: missing `await` on a bridged call.

`get_tasks` is a server `def:pub`; imported into client context the import
is a CLIENT_BRIDGE and the name lowers to an async RPC stub returning a
coroutine. Calling it without `await` silently assigns a coroutine to
`tasks: list[Task]` and crashes at runtime (`tasks is not iterable`). The
type checker must raise E1042 here.
"""


import from type_E1042_sv_missing_await_server { Task, get_tasks }

def:pub app -> JsxElement {
    has tasks: list[Task] = [];

    async can with entry {
        tasks = get_tasks();  # E1042: should be `await get_tasks()`
    }

    return <ul>{[<li key={t.id}>{t.title}</li> for t in tasks]}</ul>;
}
