"""AI Day Planner -- top-level client app composes feature components."""

import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.AuthForm { AuthForm }
import from .components.Header { Header }
import from .components.TasksPanel { TasksPanel }
import from .components.ShoppingPanel { ShoppingPanel }

def:pub app -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    def handleAuth {
        isLoggedIn = True;
    }

    def handleLogout {
        jacLogout();
        isLoggedIn = False;
    }

    if checkingAuth {
        return
            <div class="auth-loading">Loading...</div>;
    }

    if isLoggedIn {
        return
            <div class="container">
                <Header onLogout={handleLogout}/>
                <div class="two-column">
                    <TasksPanel/>
                    <ShoppingPanel/>
                </div>
            </div>;
    }

    return
        <AuthForm onAuth={handleAuth}/>;
}
