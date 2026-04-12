"""{{name}} - Entry Point.

Combines server-side endpoints with client-side UI.
"""

# Import server-side data models and walkers
sv {
    import from endpoints { Todo, AddTodo, ListTodos, ToggleTodo, DeleteTodo }
}

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp/>;
    }
}
