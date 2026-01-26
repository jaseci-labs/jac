# Todo App
node Todo {
    has text: str,
        done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}

walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with exit {
        report here;
    }
}

cl {
    def:pub app -> any {
        has todos: list = [],
            inputValue: str = "",
            filter: str = "all";

        async can with entry {
            result = root spawn read_todos();
            todos = result.reports;
        }

        # Add a new todo
        async def addTodo -> None {
            if not inputValue.trim() {
                return;
            }
            newTodo = {"id": Date.now(), "text": inputValue.trim(), "done": False};
            response = root spawn create_todo(text=inputValue.trim());
            newTodos = todos.concat([response.reports[0][0]]);
            todos = newTodos;
            inputValue = "";
        }

        # Toggle todo completion status
        async def toggleTodo(id: any) -> None {
            console.log("toggleTodo", id);
            id spawn toggle_todo();
            todos = todos.map(
                lambda todo: any  -> any { if todo._jac_id == id {
                    updatedTodo = {
                        "_jac_id": todo._jac_id,
                        "text": todo.text,
                        "done": not todo.done,
                        "id": todo.id
                    };
                    return updatedTodo;
                }return todo; }
            );
        }

        # Delete a todo
        def deleteTodo(id: any) -> None {
            todos = todos.filter(lambda todo: any  -> bool { return todo.id != id; });
        }

        # Clear all completed todos
        def clearCompleted -> None {
            todos = todos.filter(lambda todo: any  -> bool { return not todo.done; });
        }

        # Filter todos based on current filter
        def getFilteredTodos -> list {
            if filter == "active" {
                return todos.filter(
                    lambda todo: any  -> bool { return not todo.done; }
                );
            } elif filter == "completed" {
                return todos.filter(lambda todo: any  -> bool { return todo.done; });
            }
            return todos;
        }

        # Count active todos
        activeCount = todos.filter(lambda todo: any  -> bool { return not todo.done; }).length;

        filteredTodos = getFilteredTodos();

        return
            <div
                style={{
                    "maxWidth": "600px",
                    "margin": "40px auto",
                    "padding": "24px",
                    "fontFamily": "system-ui, -apple-system, sans-serif",
                    "background": "#f9fafb",
                    "minHeight": "100vh"
                }}
            >
                <h1
                    style={{
                        "textAlign": "center",
                        "color": "#1f2937",
                        "marginBottom": "32px",
                        "fontSize": "2.5rem",
                        "fontWeight": "700"
                    }}
                >
                    📝 My Todo App
                </h1>
                # Add todo form
                <div
                    style={{
                        "display": "flex",
                        "gap": "8px",
                        "marginBottom": "24px",
                        "background": "#ffffff",
                        "padding": "16px",
                        "borderRadius": "12px",
                        "boxShadow": "0 1px 3px rgba(0,0,0,0.1)"
                    }}
                >
                    <input
                        type="text"
                        value={inputValue}
                        onChange={lambda e: any  -> None { inputValue = e.target.value;}}
                        onKeyPress={lambda e: any  -> None { if e.key == "Enter" {
                            addTodo();
                        }}}
                        placeholder="What needs to be done?"
                        style={{
                            "flex": "1",
                            "padding": "12px 16px",
                            "border": "1px solid #e5e7eb",
                            "borderRadius": "8px",
                            "fontSize": "16px",
                            "outline": "none"
                        }}
                    />
                    <button
                        onClick={addTodo}
                        style={{
                            "padding": "12px 24px",
                            "background": "#3b82f6",
                            "color": "#ffffff",
                            "border": "none",
                            "borderRadius": "8px",
                            "fontSize": "16px",
                            "fontWeight": "600",
                            "cursor": "pointer",
                            "transition": "background 0.2s"
                        }}
                    >
                        Add
                    </button>
                </div>
                # Filter buttons
                <div
                    style={{
                        "display": "flex",
                        "gap": "8px",
                        "marginBottom": "24px",
                        "justifyContent": "center"
                    }}
                >
                    <button
                        onClick={lambda -> None { filter = "all";}}
                        style={{
                            "padding": "8px 16px",
                            "background": ("#3b82f6" if filter == "all" else "#ffffff"),
                            "color": ("#ffffff" if filter == "all" else "#3b82f6"),
                            "border": "1px solid #3b82f6",
                            "borderRadius": "6px",
                            "fontSize": "14px",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        All
                    </button>
                    <button
                        onClick={lambda -> None { filter = "active";}}
                        style={{
                            "padding": "8px 16px",
                            "background": (
                                "#3b82f6" if filter == "active" else "#ffffff"
                            ),
                            "color": ("#ffffff" if filter == "active" else "#3b82f6"),
                            "border": "1px solid #3b82f6",
                            "borderRadius": "6px",
                            "fontSize": "14px",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        Active
                    </button>
                    <button
                        onClick={lambda -> None { filter = "completed";}}
                        style={{
                            "padding": "8px 16px",
                            "background": (
                                "#3b82f6" if filter == "completed" else "#ffffff"
                            ),
                            "color": (
                                "#ffffff" if filter == "completed" else "#3b82f6"
                            ),
                            "border": "1px solid #3b82f6",
                            "borderRadius": "6px",
                            "fontSize": "14px",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        Completed
                    </button>
                </div>
                # Todo list
                <div
                    style={{
                        "background": "#ffffff",
                        "borderRadius": "12px",
                        "boxShadow": "0 1px 3px rgba(0,0,0,0.1)",
                        "overflow": "hidden"
                    }}
                >
                    {(
                        <div
                            style={{
                                "padding": "40px",
                                "textAlign": "center",
                                "color": "#9ca3af"
                            }}
                        >
                            {(
                                "No todos yet. Add one above!"
                                if filter == "all"
                                else (
                                    "No active todos!"
                                    if filter == "active"
                                    else "No completed todos!"
                                )
                            )}
                        </div>
                    )
                    if filteredTodos.length == 0
                    else (
                        filteredTodos.map(
                            lambda todo: any  -> any { return
                                <div
                                    key={todo._jac_id}
                                    style={{
                                        "display": "flex",
                                        "alignItems": "center",
                                        "gap": "12px",
                                        "padding": "16px",
                                        "borderBottom": "1px solid #e5e7eb",
                                        "transition": "background 0.2s"
                                    }}
                                >
                                    <input
                                        type="checkbox"
                                        checked={todo.done}
                                        onChange={lambda -> None { toggleTodo(
                                            todo._jac_id
                                        );}}
                                        style={{
                                            "width": "20px",
                                            "height": "20px",
                                            "cursor": "pointer"
                                        }}
                                    />
                                    <span
                                        style={{
                                            "flex": "1",
                                            "textDecoration": (
                                                "line-through" if todo.done else "none"
                                            ),
                                            "color": (
                                                "#9ca3af" if todo.done else "#1f2937"
                                            ),
                                            "fontSize": "16px"
                                        }}
                                    >
                                        {todo.text}
                                    </span>
                                    <button
                                        onClick={lambda -> None { deleteTodo(
                                            todo.__jac_id
                                        );}}
                                        style={{
                                            "padding": "6px 12px",
                                            "background": "#ef4444",
                                            "color": "#ffffff",
                                            "border": "none",
                                            "borderRadius": "6px",
                                            "fontSize": "14px",
                                            "fontWeight": "500",
                                            "cursor": "pointer",
                                            "transition": "background 0.2s"
                                        }}
                                    >
                                        Delete
                                    </button>
                                </div>; }
                        )
                    )}
                </div>
                # Stats and clear completed button
                {(
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "marginTop": "24px",
                            "padding": "16px",
                            "background": "#ffffff",
                            "borderRadius": "12px",
                            "boxShadow": "0 1px 3px rgba(0,0,0,0.1)"
                        }}
                    >
                        <span style={{"color": "#6b7280", "fontSize": "14px"}}>
                            {activeCount}{"item" if activeCount == 1 else "items"}left
                        </span>
                        {(
                            <button
                                onClick={clearCompleted}
                                style={{
                                    "padding": "8px 16px",
                                    "background": "#ef4444",
                                    "color": "#ffffff",
                                    "border": "none",
                                    "borderRadius": "6px",
                                    "fontSize": "14px",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                Clear Completed
                            </button>
                        )
                        if todos.some(lambda todo: any  -> bool { return todo.done; })
                        else None}
                    </div>
                )
                if todos.length > 0
                else None}
            </div>;
    }
}
