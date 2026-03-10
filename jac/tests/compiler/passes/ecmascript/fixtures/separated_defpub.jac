"""Test multi-file def:pub: server functions called from separate .cl.jac file.

When def:pub functions are defined in main.jac and the frontend is in a
separate .cl.jac file, the compiler must generate __jacCallFunction stubs
in the client bundle so the browser can call the server over HTTP.
"""

node Task {
    has id: str,
        title: str,
        done: bool = False;
}

"""Add a task and return it."""
def:pub add_task(title: str) -> dict {
    task = root ++> Task(id="1", title=title);
    return {"id": task[0].id, "title": task[0].title, "done": task[0].done};
}

"""Get all tasks."""
def:pub get_tasks -> list {
    return [{"id": t.id, "title": t.title, "done": t.done} for t in [root-->](?:Task)];
}

"""Toggle a task's done status."""
def:pub toggle_task(id: str) -> dict {
    for task in [root-->](?:Task) {
        if task.id == id {
            task.done = not task.done;
            return {"id": task.id, "title": task.title, "done": task.done};
        }
    }
    return {};
}

# Client entry point imports from the standalone client module
cl {
    import from separated_defpub_client { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp/>;
    }
}
