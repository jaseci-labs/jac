node Todo {
    has title: str;
}

def:pub add_todo(title: str) -> Todo {
    todo = Todo(title=title);
    root ++> todo;
    return todo;
}

def:pub get_todos -> list[Todo] {
    return [root-->][?:Todo];
}

def:pub todo_app -> JsxElement {
    has todos: list[Todo] = [];

    async can with entry {
        todos = await get_todos();
    }

    return <ul>{[<li key={jid(t)}>{t.title}</li> for t in todos]}</ul>;
}
