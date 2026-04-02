node Todo {
    has title: str,
        category: str = "other",
        done: bool = False;
}

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

def categorize(title: str) -> Category by llm();

def:pub add_todo(title: str) -> Todo {
    category = str(categorize(title)).split(".")[-1].lower();
    return (root() ++> Todo(title=title, category=category))[0];
}

def:pub get_todos -> list[Todo] {
    return [root()-->][?:Todo];
}

cl def:pub app -> JsxElement {
    has todos: list[Todo] = [],
        text: str = "";

    async can with entry {
        todos = await get_todos();
    }

    async def add {
        if text.strip() {
            todo = await add_todo(text.strip());
            todos = todos + [todo];
            text = "";
        }
    }

    return
        <div>
            <input
                value={text}
                onChange={lambda e: ChangeEvent { text = e.target.value;}}
                onKeyPress={lambda e: KeyboardEvent { if e.key == "Enter" {
                    add();
                }}}
                placeholder="Add a todo..."
            />
            <button onClick={add}>
                Add
            </button>
            {[
                <p key={jid(t)}>
                    {t.title} ({t.category})
                </p> for t in todos
            ]}
        </div>;
}
