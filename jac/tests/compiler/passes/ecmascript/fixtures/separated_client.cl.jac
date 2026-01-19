import from react { useState }

# Import walker from server module
sv import from .separated { create_todo }

def:pub app()  -> any {
    [todos, setTodos] = useState([]);
    [input, setInput] = useState("");

    # Event Handler
    async def addTodo()  -> None {
        if not input.trim() {
            return;
        }
        response = root spawn create_todo(text=input.trim());
        new_todo = response.reports[0][0];
        setTodos(todos.concat([new_todo]));
        setInput("");

        def foo { }
    }

    return <div>
        <h2>
            My Todos
        </h2>
        <input
            value={input}
            onChange={lambda  e: any  -> None{ setInput(e.target.value);} }
            onKeyPress={lambda  e: any  -> None{ if e.key == "Enter" {
                addTodo();
            }} }
        />
        <button
            onClick={addTodo}
        >
            Add Todo
        </button>
        <div>
            {todos.map(
                lambda  todo: any  -> any{ return <div
                    key={todo._jac_id}
                >
                    <span>
                        {todo.text}
                    </span>
                </div>; }
            )}
        </div>
    </div>;
}
