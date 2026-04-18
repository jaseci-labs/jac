"""Todo App - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import from .components.TodoItem { TodoItem }
import from .components.AuthForm { AuthForm }

sv import from endpoints { AddTodo, ListTodos, ToggleTodo, DeleteTodo }

def:pub app -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        todos: list[dict] = [],
        newTodoText: str = "",
        todosLoading: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchTodos();
        }
    }

    async def fetchTodos -> None;
    async def addTodo -> None;
    async def toggleTodo(todoId: str) -> None;
    async def deleteTodo(todoId: str) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: FormEvent) -> None;
    def handleTodoKeyPress(e: KeyboardEvent) -> None;

    # Loading screen
    if checkingAuth {
        return
            <div
                style={{
                    "display": "flex",
                    "justifyContent": "center",
                    "alignItems": "center",
                    "height": "100vh",
                    "fontFamily": "system-ui, -apple-system, sans-serif",
                    "color": "#666"
                }}
            >
                Loading...
            </div>;
    }

    # Logged in - Show Todo List
    if isLoggedIn {
        return
            <div
                style={{
                    "maxWidth": "600px",
                    "margin": "2rem auto",
                    "padding": "2rem",
                    "fontFamily": "system-ui, -apple-system, sans-serif"
                }}
            >
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "marginBottom": "1.5rem"
                    }}
                >
                    <h1 style={{"margin": "0", "color": "#1a1a2e"}}>My Todos</h1>
                    <button
                        onClick={lambda _e: MouseEvent { handleLogout();}}
                        style={{
                            "padding": "0.5rem 1rem",
                            "fontSize": "0.9rem",
                            "backgroundColor": "#f8f9fa",
                            "color": "#666",
                            "border": "1px solid #ddd",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Log Out
                    </button>
                </div>
                <div
                    style={{
                        "display": "flex",
                        "gap": "0.5rem",
                        "marginBottom": "1.5rem"
                    }}
                >
                    <input
                        type="text"
                        value={newTodoText}
                        onChange={lambda e: ChangeEvent { newTodoText = e.target.value;}}
                        onKeyPress={handleTodoKeyPress}
                        placeholder="What needs to be done?"
                        style={{
                            "flex": "1",
                            "padding": "0.75rem 1rem",
                            "fontSize": "1rem",
                            "border": "2px solid #e0e0e0",
                            "borderRadius": "8px",
                            "outline": "none"
                        }}
                    />
                    <button
                        onClick={lambda _e: MouseEvent { addTodo();}}
                        style={{
                            "padding": "0.75rem 1.5rem",
                            "fontSize": "1rem",
                            "backgroundColor": "#4CAF50",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "8px",
                            "cursor": "pointer"
                        }}
                    >
                        Add
                    </button>
                </div>
                {(
                    <div style={{"color": "#666", "textAlign": "center"}}>
                        Loading todos...
                    </div>
                )
                    if todosLoading
                    else None}
                {(
                    <div>
                        {(
                            <p
                                style={{
                                    "color": "#888",
                                    "textAlign": "center",
                                    "padding": "2rem"
                                }}
                            >
                                No todos yet. Add one above!
                            </p>
                        )
                            if len(todos) == 0
                            else None}{[
                            <TodoItem
                                key={todo["id"]}
                                todo={todo}
                                onToggle={toggleTodo}
                                onDelete={deleteTodo}
                            /> for todo in todos
                        ]}
                    </div>
                )
                    if not todosLoading
                    else None}
                <div
                    style={{
                        "marginTop": "2rem",
                        "paddingTop": "1rem",
                        "borderTop": "1px solid #eee",
                        "color": "#888",
                        "fontSize": "0.9rem"
                    }}
                >
                    {len(
                        [
                            t
                            for t in todos
                            if not t["completed"]
                        ]
                    )} items left
                </div>
            </div>;
    }

    # Not logged in - Show Auth Form
    return
        <AuthForm
            isSignup={isSignup}
            username={username}
            password={password}
            error={error}
            loading={loading}
            onUsernameChange={lambda e: ChangeEvent { username = e.target.value;}}
            onPasswordChange={lambda e: ChangeEvent { password = e.target.value;}}
            onSubmit={handleSubmit}
            onToggleMode={lambda _e: MouseEvent {
                isSignup = not isSignup;
                error = "";
            }}
        />;
}
