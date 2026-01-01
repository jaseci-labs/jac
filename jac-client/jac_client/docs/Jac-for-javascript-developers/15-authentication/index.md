# Authentication

JAC-Client built-in auth utilities.

---

## Built-in Functions

```jac
cl import from @jac-client/utils {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn,
    jacFetch
}
```

---

## Login

```jac
def LoginForm() -> any {
    [email, setEmail] = useState("");
    [password, setPassword] = useState("");
    [error, setError] = useState("");

    def handleLogin(e: any) -> None {
        e.preventDefault();

        try {
            jacLogin(email, password);
            # Redirect on success
        } except Exception as err {
            setError("Login failed");
        }
    }

    return (
        <form onSubmit={handleLogin}>
            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
                placeholder="Email"
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { setPassword(e.target.value); }}
                placeholder="Password"
            />
            {error and <p style={{"color": "red"}}>{error}</p>}
            <button type="submit">Login</button>
        </form>
    );
}
```

---

## Signup

```jac
def SignupForm() -> any {
    [email, setEmail] = useState("");
    [password, setPassword] = useState("");

    def handleSignup(e: any) -> None {
        e.preventDefault();
        jacSignup(email, password);
    }

    return (
        <form onSubmit={handleSignup}>
            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { setPassword(e.target.value); }}
            />
            <button type="submit">Sign Up</button>
        </form>
    );
}
```

---

## Logout

```jac
def LogoutButton() -> any {
    def handleLogout() -> None {
        jacLogout();
    }

    return <button onClick={handleLogout}>Logout</button>;
}
```

---

## Check Auth Status

```jac
def AuthStatus() -> any {
    isLoggedIn = jacIsLoggedIn();

    return (
        <div>
            {(isLoggedIn) if (
                <p>You are logged in</p>
            ) else (
                <p>Please login</p>
            )}
        </div>
    );
}
```

---

## Protected Route

```jac
cl import from react-router-dom { Navigate }
cl import from @jac-client/utils { jacIsLoggedIn }

cl {
    def ProtectedRoute(children: any) -> any {
        isLoggedIn = jacIsLoggedIn();

        if not isLoggedIn {
            return <Navigate to="/login" />;
        }

        return children;
    }

    # Usage in routes:
    # <Route path="/dashboard" element={
    #     <ProtectedRoute>
    #         <Dashboard />
    #     </ProtectedRoute>
    # } />
}
```

---

## Auth with Router

```jac
cl import from react { useState }
cl import from react-router-dom { BrowserRouter, Routes, Route, Navigate, useNavigate }
cl import from @jac-client/utils { jacLogin, jacLogout, jacIsLoggedIn }

cl {
    def Login() -> any {
        [email, setEmail] = useState("");
        [password, setPassword] = useState("");
        navigate = useNavigate();

        def handleSubmit(e: any) -> None {
            e.preventDefault();
            jacLogin(email, password);
            navigate("/dashboard");
        }

        return (
            <form onSubmit={handleSubmit}>
                <input
                    value={email}
                    onChange={lambda e: any -> None { setEmail(e.target.value); }}
                />
                <input
                    type="password"
                    value={password}
                    onChange={lambda e: any -> None { setPassword(e.target.value); }}
                />
                <button type="submit">Login</button>
            </form>
        );
    }

    def Dashboard() -> any {
        navigate = useNavigate();

        def handleLogout() -> None {
            jacLogout();
            navigate("/login");
        }

        return (
            <div>
                <h1>Dashboard</h1>
                <button onClick={handleLogout}>Logout</button>
            </div>
        );
    }

    def app() -> any {
        return (
            <BrowserRouter>
                <Routes>
                    <Route path="/login" element={<Login />} />
                    <Route path="/dashboard" element={
                        jacIsLoggedIn() ? <Dashboard /> : <Navigate to="/login" />
                    } />
                </Routes>
            </BrowserRouter>
        );
    }
}
```

---

## Next

- [Appendix](../16-appendix/) - Reference & cheatsheet
