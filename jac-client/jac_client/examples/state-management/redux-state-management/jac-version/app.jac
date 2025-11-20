# Currently, Redux jac version does not work
# Need to fix syntex issues on createSlice and configureStore jac implementations


cl import from react { useState }
cl import from "react-redux" { Provider, useSelector, useDispatch }
cl import from .store { store, addTodo, toggleTodo, deleteTodo, setFilter, clearCompleted }

cl {
    def TodoApp() -> any {
        let dispatch = useDispatch();
        let allTodos = useSelector(lambda state: any -> any { return state.todos.items; });
        let filter = useSelector(lambda state: any -> any { return state.todos.filter; });
        let [input, setInput] = useState("");

        # Get all action creators
        let addTodoAction = addTodo();
        let toggleTodoAction = toggleTodo();
        let deleteTodoAction = deleteTodo();
        let setFilterAction = setFilter();
        let clearCompletedAction = clearCompleted();

        # Filter todos based on current filter
        let filteredTodos = allTodos;
        if filter == "active" {
            filteredTodos = allTodos.filter(lambda t: any -> bool { return t.completed == false; });
        } elif filter == "completed" {
            filteredTodos = allTodos.filter(lambda t: any -> bool { return t.completed == true; });
        }

        let handleAdd = lambda -> None {
            if input.trim() != "" {
                dispatch(addTodoAction(input));
                setInput("");
            }
        };

        let handleKeyPress = lambda e: any -> None {
            if e.key == "Enter" {
                handleAdd();
            }
        };

        let activeCount = allTodos.filter(lambda t: any -> bool { return t.completed == false; }).length;
        let completedCount = allTodos.filter(lambda t: any -> bool { return t.completed == true; }).length;

        return <div style={{"padding": "20px", "fontFamily": "Arial", "maxWidth": "600px", "margin": "0 auto"}}>
            <h1 style={{"textAlign": "center", "color": "#2c3e50"}}>🎯 Redux Todo App (Pure .jac)</h1>
            <p style={{"textAlign": "center", "color": "#7f8c8d", "marginBottom": "30px"}}>
                Redux slices created entirely in .jac files!
            </p>

            <div style={{"marginBottom": "20px", "display": "flex", "gap": "10px"}}>
                <input
                    value={input}
                    onChange={lambda e: any -> None { setInput(e.target.value); }}
                    onKeyPress={handleKeyPress}
                    placeholder="What needs to be done?"
                    style={{"flex": "1", "padding": "10px", "fontSize": "14px", "borderRadius": "4px", "border": "1px solid #ccc"}}
                />
                <button
                    onClick={handleAdd}
                    style={{"padding": "10px 20px", "fontSize": "14px", "backgroundColor": "#27ae60", "color": "white", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                >
                    Add
                </button>
            </div>

            <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px", "justifyContent": "space-between", "alignItems": "center"}}>
                <div style={{"display": "flex", "gap": "5px"}}>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilterAction("all")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#3498db", "color": "white", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        All ({allTodos.length})
                    </button>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilterAction("active")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#ecf0f1", "color": "#2c3e50", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        Active ({activeCount})
                    </button>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilterAction("completed")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#ecf0f1", "color": "#2c3e50", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        Completed ({completedCount})
                    </button>
                </div>

                {completedCount > 0 && (
                    <button
                        onClick={lambda e: any -> None { dispatch(clearCompletedAction()); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#e74c3c", "color": "white", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        Clear Completed
                    </button>
                )}
            </div>

            <div>
                {filteredTodos.length == 0 && (
                    <p style={{"textAlign": "center", "color": "#95a5a6", "padding": "40px 20px"}}>
                        No todos in this filter. Add some above!
                    </p>
                )}
                {filteredTodos.map(lambda todo: any -> any {
                    let textDecoration = "none";
                    let textColor = "#2c3e50";
                    if todo.completed {
                        textDecoration = "line-through";
                        textColor = "#95a5a6";
                    }

                    return <div
                        key={todo.id}
                        style={{"display": "flex", "alignItems": "center", "gap": "10px", "padding": "12px", "marginBottom": "8px", "backgroundColor": "#f8f9fa", "borderRadius": "5px", "border": "1px solid #dee2e6"}}
                    >
                        <input
                            type="checkbox"
                            checked={todo.completed}
                            onChange={lambda e: any -> None { dispatch(toggleTodoAction(todo.id)); }}
                            style={{"width": "18px", "height": "18px", "cursor": "pointer"}}
                        />
                        <span style={{"flex": "1", "textDecoration": textDecoration, "color": textColor}}>
                            {todo.text}
                        </span>
                        <button
                            onClick={lambda e: any -> None { dispatch(deleteTodoAction(todo.id)); }}
                            style={{"padding": "4px 12px", "fontSize": "12px", "backgroundColor": "#e74c3c", "color": "white", "border": "none", "borderRadius": "3px", "cursor": "pointer"}}
                        >
                            Delete
                        </button>
                    </div>;
                })}
            </div>

            <div style={{"marginTop": "30px", "padding": "15px", "backgroundColor": "#d4edda", "borderRadius": "8px", "border": "1px solid #c3e6cb"}}>
                <strong style={{"color": "#155724"}}>✅ Success!</strong>
                <p style={{"margin": "5px 0 0 0", "fontSize": "12px", "color": "#155724"}}>
                    Redux slices, store, and actions all created in .jac files using the wrapper function pattern!
                </p>
            </div>
        </div>;
    }

    def app() -> any {
        # Call store() to get the actual Redux store object
        let storeInstance = store();

        return <Provider store={storeInstance}>
            <TodoApp />
        </Provider>;
    }
}
