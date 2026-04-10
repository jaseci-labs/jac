"""Implementations for the Todo App frontend component."""

impl app.fetchTodos -> None {
    todosLoading = True;
    result = root spawn ListTodos();
    todos = result.reports[0] if result.reports else [];
    todosLoading = False;
}

impl app.addTodo -> None {
    if not newTodoText.trim() {
        return;
    }
    response = root spawn AddTodo(title=newTodoText);
    newTodo = response.reports[0];
    todos = todos.concat(
        [{"id": newTodo.id, "title": newTodo.title, "completed": newTodo.completed}]
    );
    newTodoText = "";
}

impl app.toggleTodo(todoId: str) -> None {
    root spawn ToggleTodo(todo_id=todoId);
    todos = [
        {"id": t.id, "title": t.title, "completed": not t.completed}
            if t.id == todoId
            else t for t in todos
    ];
}

impl app.deleteTodo(todoId: str) -> None {
    root spawn DeleteTodo(todo_id=todoId);
    todos = [
        t
        for t in todos
        if t.id != todoId
    ];
}

impl app.handleLogin -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    loading = True;
    success = await jacLogin(username, password);
    loading = False;
    if success {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = "Invalid username or password";
    }
}

impl app.handleSignup -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    if password.length < 4 {
        error = "Password must be at least 4 characters";
        return;
    }
    loading = True;
    result = await jacSignup(username, password);
    loading = False;
    if result["success"] {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = result["error"] if result["error"] else "Signup failed";
    }
}

impl app.handleLogout -> None {
    jacLogout();
    isLoggedIn = False;
    todos = [];
    username = "";
    password = "";
    error = "";
}

impl app.handleSubmit(e: any) -> None {
    e.preventDefault();
    if isSignup {
        await handleSignup();
    } else {
        await handleLogin();
    }
}

impl app.handleTodoKeyPress(e: any) -> None {
    if e.key == "Enter" {
        addTodo();
    }
}
