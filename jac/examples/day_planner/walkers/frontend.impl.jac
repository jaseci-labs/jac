"""Implementations for the Day Planner frontend."""

impl app.fetchTasks{
    tasksLoading = True;
    result = root spawn ListTasks();
    tasks = result.reports[0] if result.reports else [];
    tasksLoading = False;
}

impl app.addTask{
    if not taskText.strip() {
        return;
    }
    response = root spawn AddTask(title=taskText);
    tasks = tasks + [response.reports[0]];
    taskText = "";
}

impl app.toggleTask(id: str) {
    response = root spawn ToggleTask(task_id=id);
    updated = response.reports[0];
    tasks = [updated if jid(t) == id else t for t in tasks];
}

impl app.deleteTask(id: str) {
    root spawn DeleteTask(task_id=id);
    tasks = [
        t
        for t in tasks
        if jid(t) != id
    ];
}

impl app.handleLogin{
    error = "";
    if not username.strip() or not password {
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

impl app.handleSignup{
    error = "";
    if not username.strip() or not password {
        error = "Please fill in all fields";
        return;
    }
    if len(password) < 4 {
        error = "Password must be at least 4 characters";
        return;
    }
    loading = True;
    result = await jacSignup(username, password);
    if result["success"] {
        # /user/register creates the account but does not return a
        # session token; sign in immediately to establish one.
        logged_in = await jacLogin(username, password);
        loading = False;
        if logged_in {
            isLoggedIn = True;
            username = "";
            password = "";
        } else {
            error = "Account created but sign-in failed";
        }
    } else {
        loading = False;
        error = result["error"] if result["error"] else "Signup failed";
    }
}

impl app.handleLogout{
    jacLogout();
    isLoggedIn = False;
    isSignup = False;
    tasks = [];
    ingredients = [];
}

impl app.handleSubmit(e: FormEvent) {
    e.preventDefault();
    if isSignup {
        await handleSignup();
    } else {
        await handleLogin();
    }
}

impl app.handleTaskKeyPress(e: KeyboardEvent) {
    if e.key == "Enter" {
        addTask();
    }
}

impl app.fetchShoppingList{
    result = root spawn GetShoppingList();
    ingredients = result.reports[0] if result.reports else [];
}

impl app.generateList{
    if not mealText.strip() {
        return;
    }
    generating = True;
    result = root spawn GenerateShoppingList(meal_description=mealText);
    ingredients = result.reports[0] if result.reports else [];
    generating = False;
}

impl app.clearList{
    root spawn ClearShoppingList();
    ingredients = [];
    mealText = "";
}

impl app.handleMealKeyPress(e: KeyboardEvent) {
    if e.key == "Enter" {
        generateList();
    }
}

impl app.getTotal -> float {
    total = 0.0;
    for ing in ingredients {
        total = total + ing.cost;
    }
    return total;
}
