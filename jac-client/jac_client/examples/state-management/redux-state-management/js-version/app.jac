
# Pages
cl import from react {useState}
cl import from "react-redux" {Provider, useSelector, useDispatch}
cl import from .reduxExports {
    store,
    increment,
    decrement,
    reset,
    setStep,
    incrementByAmount,
    addTodo,
    toggleTodo,
    deleteTodo,
    setFilter,
    clearCompleted
}

cl {
    # Counter Component
    def CounterSection() -> any {
        let dispatch = useDispatch();
        let counterValue = useSelector(lambda state: any -> any { return state.counter.value; });
        let step = useSelector(lambda state: any -> any { return state.counter.step; });

        let [customAmount, setCustomAmount] = useState("");

        let handleSetStep = lambda e: any -> None {
            let value = Number(e.target.value);
            if Number.isFinite(value) and value > 0 {
                dispatch(setStep(value));
            }
        };

        let handleIncrementByCustom = lambda -> None {
            if customAmount != "" {
                let value = Number(customAmount);
                if Number.isFinite(value) {
                    dispatch(incrementByAmount(value));
                    setCustomAmount("");
                }
            }
        };

        return <div style={{"padding": "20px", "border": "2px solid #3498db", "borderRadius": "10px", "marginBottom": "20px"}}>
            <h2 style={{"color": "#3498db"}}>🔢 Counter</h2>

            <div style={{"fontSize": "48px", "fontWeight": "bold", "textAlign": "center", "margin": "20px 0", "color": "#2c3e50"}}>
                {counterValue}
            </div>

            <div style={{"display": "flex", "gap": "10px", "justifyContent": "center", "marginBottom": "20px"}}>
                <button
                    onClick={lambda e: any -> None { dispatch(decrement()); }}
                    style={{"padding": "10px 20px", "fontSize": "16px", "backgroundColor": "#e74c3c", "color": "white", "border": "none", "borderRadius": "5px", "cursor": "pointer"}}
                >
                    - Decrement
                </button>
                <button
                    onClick={lambda e: any -> None { dispatch(reset()); }}
                    style={{"padding": "10px 20px", "fontSize": "16px", "backgroundColor": "#95a5a6", "color": "white", "border": "none", "borderRadius": "5px", "cursor": "pointer"}}
                >
                    Reset
                </button>
                <button
                    onClick={lambda e: any -> None { dispatch(increment()); }}
                    style={{"padding": "10px 20px", "fontSize": "16px", "backgroundColor": "#27ae60", "color": "white", "border": "none", "borderRadius": "5px", "cursor": "pointer"}}
                >
                    + Increment
                </button>
            </div>

            <div style={{"display": "flex", "gap": "10px", "alignItems": "center", "justifyContent": "center", "marginBottom": "15px"}}>
                <label><strong>Step Size:</strong></label>
                <input
                    type="number"
                    value={step}
                    onChange={handleSetStep}
                    style={{"padding": "8px", "fontSize": "14px", "width": "80px", "borderRadius": "4px", "border": "1px solid #ccc"}}
                />
                <span>Current step: {step}</span>
            </div>

            <div style={{"display": "flex", "gap": "10px", "alignItems": "center", "justifyContent": "center"}}>
                <input
                    type="number"
                    value={customAmount}
                    onChange={lambda e: any -> None { setCustomAmount(e.target.value); }}
                    placeholder="Custom amount"
                    style={{"padding": "8px", "fontSize": "14px", "width": "120px", "borderRadius": "4px", "border": "1px solid #ccc"}}
                />
                <button
                    onClick={handleIncrementByCustom}
                    style={{"padding": "8px 16px", "fontSize": "14px", "backgroundColor": "#9b59b6", "color": "white", "border": "none", "borderRadius": "5px", "cursor": "pointer"}}
                >
                    Add Custom Amount
                </button>
            </div>
        </div>;
    }

    # Todos Component
    def TodosSection() -> any {
        let dispatch = useDispatch();
        let allTodos = useSelector(lambda state: any -> any { return state.todos.items; });
        let filter = useSelector(lambda state: any -> any { return state.todos.filter; });

        let [newTodoText, setNewTodoText] = useState("");

        # Filter todos based on current filter
        let filteredTodos = allTodos;
        if filter == "active" {
            filteredTodos = allTodos.filter(lambda t: any -> bool { return t.completed == false; });
        } elif filter == "completed" {
            filteredTodos = allTodos.filter(lambda t: any -> bool { return t.completed == true; });
        }

        let handleAddTodo = lambda -> None {
            if newTodoText.trim() != "" {
                dispatch(addTodo(newTodoText));
                setNewTodoText("");
            }
        };

        let handleKeyPress = lambda e: any -> None {
            if e.key == "Enter" {
                handleAddTodo();
            }
        };

        let activeCount = allTodos.filter(lambda t: any -> bool { return t.completed == false; }).length;
        let completedCount = allTodos.filter(lambda t: any -> bool { return t.completed == true; }).length;

        return <div style={{"padding": "20px", "border": "2px solid #e67e22", "borderRadius": "10px"}}>
            <h2 style={{"color": "#e67e22"}}>✅ Todo List</h2>

            <div style={{"display": "flex", "gap": "10px", "marginBottom": "20px"}}>
                <input
                    type="text"
                    value={newTodoText}
                    onChange={lambda e: any -> None { setNewTodoText(e.target.value); }}
                    onKeyPress={handleKeyPress}
                    placeholder="What needs to be done?"
                    style={{"flex": "1", "padding": "10px", "fontSize": "14px", "borderRadius": "4px", "border": "1px solid #ccc"}}
                />
                <button
                    onClick={handleAddTodo}
                    style={{"padding": "10px 20px", "fontSize": "14px", "backgroundColor": "#27ae60", "color": "white", "border": "none", "borderRadius": "5px", "cursor": "pointer"}}
                >
                    Add Todo
                </button>
            </div>

            <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px", "justifyContent": "space-between", "alignItems": "center"}}>
                <div style={{"display": "flex", "gap": "5px"}}>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilter("all")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#3498db", "color": "white", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        All ({allTodos.length})
                    </button>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilter("active")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#ecf0f1", "color": "#2c3e50", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        Active ({activeCount})
                    </button>
                    <button
                        onClick={lambda e: any -> None { dispatch(setFilter("completed")); }}
                        style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#ecf0f1", "color": "#2c3e50", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                    >
                        Completed ({completedCount})
                    </button>
                </div>

                <button
                    onClick={lambda e: any -> None { dispatch(clearCompleted()); }}
                    style={{"padding": "6px 12px", "fontSize": "12px", "backgroundColor": "#e74c3c", "color": "white", "border": "none", "borderRadius": "4px", "cursor": "pointer"}}
                >
                    Clear Completed
                </button>
            </div>

            <div style={{"maxHeight": "400px", "overflowY": "auto"}}>
                {filteredTodos.length == 0 && (
                    <p style={{"textAlign": "center", "color": "#95a5a6", "padding": "20px"}}>
                        No todos in this filter. Add some above!
                    </p>
                )}
                {filteredTodos.length > 0 && (
                    filteredTodos.map(lambda todo: any -> any {
                        let textDecoration = "none";
                        let textColor = "#2c3e50";
                        if todo.completed {
                            textDecoration = "line-through";
                            textColor = "#95a5a6";
                        }

                        return <div
                            key={todo.id}
                            style={{"display": "flex", "alignItems": "center", "gap": "10px", "padding": "10px", "marginBottom": "8px", "backgroundColor": "#f8f9fa", "borderRadius": "5px", "border": "1px solid #dee2e6"}}
                        >
                            <input
                                type="checkbox"
                                checked={todo.completed}
                                onChange={lambda e: any -> None { dispatch(toggleTodo(todo.id)); }}
                                style={{"width": "18px", "height": "18px", "cursor": "pointer"}}
                            />
                            <span style={{"flex": "1", "textDecoration": textDecoration, "color": textColor}}>
                                {todo.text}
                            </span>
                            <button
                                onClick={lambda e: any -> None { dispatch(deleteTodo(todo.id)); }}
                                style={{"padding": "4px 8px", "fontSize": "12px", "backgroundColor": "#e74c3c", "color": "white", "border": "none", "borderRadius": "3px", "cursor": "pointer"}}
                            >
                                Delete
                            </button>
                        </div>;
                    })
                )}
            </div>
        </div>;
    }

    # Main App Component (without Provider, we'll wrap it externally)
    def AppContent() -> any {
        return <div style={{"maxWidth": "800px", "margin": "0 auto", "padding": "20px", "fontFamily": "Arial, sans-serif"}}>
            <h1 style={{"textAlign": "center", "color": "#2c3e50", "marginBottom": "10px"}}>
                🔴 Redux State Management in Jac
            </h1>
            <p style={{"textAlign": "center", "color": "#7f8c8d", "marginBottom": "30px"}}>
                Managing state with Redux Toolkit plus React-Redux
            </p>

            <CounterSection />
            <TodosSection />

            <div style={{"marginTop": "20px", "padding": "15px", "backgroundColor": "#ecf0f1", "borderRadius": "8px", "fontSize": "12px", "color": "#7f8c8d"}}>
                <strong>💡 Tip:</strong> Open Redux DevTools in your browser to see all state changes and time-travel debug!
            </div>
        </div>;
    }

    # App with Redux Provider
    def app() -> any {

        return <Provider store={store}>
            <AppContent />
        </Provider>;
    }
}
