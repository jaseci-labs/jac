# ============================================================================
# BACKEND: Data Models and Walkers
# ============================================================================
node Todo {
    has text: str,
        done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}

# ============================================================================
# FRONTEND: Components, State, and Events
# ============================================================================
cl import from react {
    useState
}

cl {
    def app -> any {
        has todos: list = [],
            input: str = "";

        # Event Handler
        async def addTodo -> None {
            if not input.trim() {
                return;
            }
            response = root spawn create_todo(text=input.trim());
            new_todo = response.reports[0][0];
            todos = todos.concat([new_todo]);
            input = "";
        }

        return
            <div>
                <h2>
                    My Todos
                </h2>
                <input
                    value={input}
                    onChange={lambda e: any  -> None { input = e.target.value;}}
                    onKeyPress={lambda e: any  -> None { if e.key == "Enter" {
                        addTodo();
                    }}}
                />
                <button onClick={addTodo}>
                    Add Todo
                </button>
                <div>
                    {todos.map(
                        lambda todo: any  -> any { return
                            <div key={todo._jac_id}>
                                <span>
                                    {todo.text}
                                </span>
                            </div>; }
                    )}
                </div>
            </div>;
    }
}
