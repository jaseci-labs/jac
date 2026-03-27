"""Client module for typed_return_obj - separate file pattern.

Tests that typed obj returns work across separate .cl.jac / .jac files.
"""

sv import from .typed_return_obj { create_todo, get_todos }

def:pub app -> JsxElement {
    has todos: list = [],
        loading: bool = True;

    async can with entry {
        todos = await get_todos();
        loading = False;
    }

    async def addTodo(title: str) -> None {
        todo = await create_todo(title);
        todos = todos + [todo];
    }

    return <div>
        {[<div key={t.title}>
            <span>{t.title}</span>
            <span>{t.done}</span>
          </div> for t in todos]}
    </div>;
}
