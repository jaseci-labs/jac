cl import from "@reduxjs/toolkit" { configureStore }
cl import from .slice { getTodoActions, getTodoReducer }

cl {
    let todoReducer = getTodoReducer();
    let todoActions = getTodoActions();

    # Use different names for internal variables
    let _store = configureStore({
        "reducer": {
            "todos": todoReducer
        }
    });

    # Extract all actions
    let _addTodo = todoActions.addTodo;
    let _toggleTodo = todoActions.toggleTodo;
    let _deleteTodo = todoActions.deleteTodo;
    let _setFilter = todoActions.setFilter;
    let _clearCompleted = todoActions.clearCompleted;

    # Export store
    def store() -> any {
        return _store;
    }

    # Export all todo actions
    def addTodo() -> any {
        return _addTodo;
    }

    def toggleTodo() -> any {
        return _toggleTodo;
    }

    def deleteTodo() -> any {
        return _deleteTodo;
    }

    def setFilter() -> any {
        return _setFilter;
    }

    def clearCompleted() -> any {
        return _clearCompleted;
    }
}
