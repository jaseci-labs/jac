"""Fixture: SV function returns a typed obj to CL.

Tests that when a def:pub function returns a user-defined obj,
the compiler can generate JS class stubs and hydration wrappers.
"""

obj Todo {
    has title: str,
        done: bool = False;
}

def:pub create_todo(title: str) -> Todo {
    return Todo(title=title);
}

def:pub get_todos -> list[Todo] {
    return [Todo(title="a"), Todo(title="b", done=True)];
}

cl {
    sv import from .typed_return_obj { create_todo, get_todos }

    def:pub app -> JsxElement {
        has todos: list = [];

        async can with entry {
            todos = await get_todos();
        }

        async def addTodo(title: str) -> None {
            todo = await create_todo(title);
            todos = todos + [todo];
        }

        return <div>
            {[<span key={t.title}>{t.title} - {t.done}</span> for t in todos]}
        </div>;
    }
}
