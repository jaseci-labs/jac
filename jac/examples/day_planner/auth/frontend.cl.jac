"""AI Day Planner -- Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

sv import from main {
    Task,
    ShoppingItem,
    get_tasks,
    add_task,
    toggle_task,
    delete_task,
    generate_list,
    get_shopping_list,
    clear_shopping_list
}

import "./styles.css";

def:pub app -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        tasks: list[Task] = [],
        taskText: str = "",
        tasksLoading: bool = True,
        mealText: str = "",
        ingredients: list[ShoppingItem] = [],
        generating: bool = False;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchTasks();
            fetchShoppingList();
        }
    }

    # Method declarations -- bodies are in frontend.impl.jac
    async def fetchTasks;
    async def addTask;
    async def toggleTask(id: str);
    async def deleteTask(id: str);
    async def handleLogin;
    async def handleSignup;
    def handleLogout;
    async def handleSubmit(e: FormEvent);
    def handleTaskKeyPress(e: KeyboardEvent);
    async def fetchShoppingList;
    async def generateList;
    async def clearList;
    def handleMealKeyPress(e: KeyboardEvent);
    def getTotal -> float;

    if checkingAuth {
        return
            <div class="auth-loading">Loading...</div>;
    }

    if isLoggedIn {
        totalCost = getTotal();
        remaining = len(
            [
                t
                for t in tasks
                if not t.done
            ]
        );
        return
            <div class="container">
                <div class="header">
                    <div>
                        <h1>AI Day Planner</h1>
                        <p class="subtitle">
                            Task management with AI-powered meal planning
                        </p>
                    </div>
                    <button class="btn-signout" onClick={handleLogout}>Sign Out</button>
                </div>
                <div class="two-column">
                    <div class="column">
                        <h2>Today's Tasks</h2>
                        <div class="input-row">
                            <input
                                class="input"
                                value={taskText}
                                onChange={lambda e: ChangeEvent { taskText = e.target.value;}}
                                onKeyPress={handleTaskKeyPress}
                                placeholder="What needs to be done today?"
                            />
                            <button class="btn-add" onClick={lambda { addTask();}}>
                                Add
                            </button>
                        </div>
                        {(<div class="loading-msg">Loading tasks...</div>)
                            if tasksLoading
                            else (
                                <div>
                                    {(
                                        <div class="empty-msg">
                                            No tasks yet. Add one above!
                                        </div>
                                    )
                                        if len(tasks) == 0
                                        else (
                                            <div>
                                                {[
                                                    <div key={jid(t)} class="task-item">
                                                        <input
                                                            type="checkbox"
                                                            checked={t.done}
                                                            onChange={lambda { toggleTask(
                                                                jid(t)
                                                            );}}
                                                        />
                                                        <span
                                                            class={"task-title " + (
                                                                "task-done"
                                                                    if t.done
                                                                    else ""
                                                            )}
                                                        >
                                                            {t.title}
                                                        </span>
                                                        {(
                                                            <span class="category">
                                                                {t.category}
                                                            </span>
                                                        )
                                                            if t.category
                                                            and t.category != "other"
                                                            else None}
                                                        <button
                                                            class="btn-delete"
                                                            onClick={lambda { deleteTask(
                                                                jid(t)
                                                            );}}
                                                        >
                                                            X
                                                        </button>
                                                    </div> for t in tasks
                                                ]}
                                            </div>
                                        )}
                                </div>
                            )}
                        <div class="count">
                            {remaining} {(
                                "task" if remaining == 1 else "tasks"
                            )} remaining
                        </div>
                    </div>
                    <div class="column">
                        <h2>Meal Shopping List</h2>
                        <div class="input-row">
                            <input
                                class="input"
                                value={mealText}
                                onChange={lambda e: ChangeEvent { mealText = e.target.value;}}
                                onKeyPress={handleMealKeyPress}
                                placeholder="e.g. 'chicken stir fry for 4'"
                            />
                            <button
                                class="btn-generate"
                                onClick={lambda { generateList();}}
                                disabled={generating}
                            >
                                {("Generating..." if generating else "Generate")}
                            </button>
                        </div>
                        {(<div class="generating-msg">Generating with AI...</div>)
                            if generating
                            else (
                                <div>
                                    {(
                                        <div class="empty-msg">
                                            Enter a meal above to generate ingredients.
                                        </div>
                                    )
                                        if len(ingredients) == 0
                                        else (
                                            <div>
                                                {[
                                                    <div
                                                        key={ing.name}
                                                        class="ingredient-item"
                                                    >
                                                        <div class="ing-info">
                                                            <span class="ing-name">
                                                                {ing.name}
                                                            </span>
                                                            <span class="ing-qty">
                                                                {ing.quantity} {ing.unit}
                                                            </span>
                                                        </div>
                                                        <div class="ing-meta">
                                                            {(
                                                                <span
                                                                    class="carb-badge"
                                                                >
                                                                    Carbs
                                                                </span>
                                                            )
                                                                if ing.carby
                                                                else None}
                                                            <span class="ing-cost">
                                                                ${f"{ing.cost:.2f}"}
                                                            </span>
                                                        </div>
                                                    </div> for ing in ingredients
                                                ]}
                                                <div class="shopping-footer">
                                                    <span class="total">
                                                        Total: ${f"{totalCost:.2f}"}
                                                    </span>
                                                    <button
                                                        class="btn-clear"
                                                        onClick={lambda { clearList();}}
                                                    >
                                                        Clear
                                                    </button>
                                                </div>
                                            </div>
                                        )}
                                </div>
                            )}
                    </div>
                </div>
            </div>;
    }

    return
        <div class="auth-container">
            <div class="auth-card">
                <h1 class="auth-title">AI Day Planner</h1>
                <p class="auth-subtitle">
                    {("Create your account" if isSignup else "Welcome back")}
                </p>
                {(<div class="auth-error">{error}</div>) if error else None}
                <form onSubmit={handleSubmit}>
                    <div class="form-field">
                        <label class="form-label">Username</label>
                        <input
                            type="text"
                            value={username}
                            onChange={lambda e: ChangeEvent { username = e.target.value;}}
                            placeholder="Enter username"
                            class="auth-input"
                        />
                    </div>
                    <div class="form-field">
                        <label class="form-label">Password</label>
                        <input
                            type="password"
                            value={password}
                            onChange={lambda e: ChangeEvent { password = e.target.value;}}
                            placeholder="Enter password"
                            class="auth-input"
                        />
                    </div>
                    <button type="submit" disabled={loading} class="auth-submit">
                        {(
                            "Processing..."
                                if loading
                                else ("Create Account" if isSignup else "Sign In")
                        )}
                    </button>
                </form>
                <div class="auth-toggle">
                    <span class="auth-toggle-text">
                        {(
                            "Already have an account? "
                                if isSignup
                                else "Don't have an account? "
                        )}
                    </span>
                    <button
                        type="button"
                        onClick={lambda {
                            isSignup = not isSignup;
                            error = "";
                        }}
                        class="auth-toggle-btn"
                    >
                        {("Sign In" if isSignup else "Sign Up")}
                    </button>
                </div>
            </div>
        </div>;
}
