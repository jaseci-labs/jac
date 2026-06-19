"""Server provider for `sv_import_type_client.cl.jac` (regression for #6795).

`list_todos` is a public HTTP endpoint; `Todo` is the obj it returns. The
client imports BOTH names in one `sv import`.
"""

obj Todo {
    has title: str;
}

def:pub list_todos -> list[Todo] {
    return [Todo(title="a"), Todo(title="b")];
}
