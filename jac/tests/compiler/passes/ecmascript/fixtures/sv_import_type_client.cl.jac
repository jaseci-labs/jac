"""Client that `sv import`s a function *and* the obj type it returns (#6795).

Importing the type (`Todo`) alongside the function must NOT emit an
`async function Todo()` RPC stub: the type already lowers to a wire
`class Todo`, and a second `Todo` declaration collides at bundle time.
"""

sv import from .sv_import_type_provider { Todo, list_todos }

def:pub app -> JsxElement {
    has todos: list[Todo] = [];

    async can with entry {
        todos = await list_todos();
    }

    return <div>
        {[<span key={t.title}>{t.title}</span> for t in todos]}
    </div>;
}
