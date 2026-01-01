# Routing

React Router in JAC-Client.

---

## Setup

```jac
cl import from react-router-dom { BrowserRouter, Routes, Route, Link }

cl {
    def Home() -> any {
        return <h1>Home Page</h1>;
    }

    def About() -> any {
        return <h1>About Page</h1>;
    }

    def app() -> any {
        return (
            <BrowserRouter>
                <nav>
                    <Link to="/">Home</Link>
                    <Link to="/about">About</Link>
                </nav>
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/about" element={<About />} />
                </Routes>
            </BrowserRouter>
        );
    }
}
```

---

## useNavigate

Programmatic navigation:

```jac
cl import from react-router-dom { useNavigate }

cl {
    def LoginButton() -> any {
        navigate = useNavigate();

        def handleLogin() -> None {
            # After login logic
            navigate("/dashboard");
        }

        return <button onClick={handleLogin}>Login</button>;
    }
}
```

---

## Route Parameters

```jac
cl import from react-router-dom { useParams }

cl {
    def UserProfile() -> any {
        params = useParams();
        userId = params["id"];

        return <h1>User ID: {userId}</h1>;
    }

    # Route: <Route path="/user/:id" element={<UserProfile />} />
}
```

---

## useLocation

Access current location:

```jac
cl import from react-router-dom { useLocation }

cl {
    def CurrentPath() -> any {
        location = useLocation();

        return <p>Current path: {location["pathname"]}</p>;
    }
}
```

---

## Nested Routes

```jac
cl import from react-router-dom { BrowserRouter, Routes, Route, Outlet, Link }

cl {
    def Dashboard() -> any {
        return (
            <div>
                <h1>Dashboard</h1>
                <nav>
                    <Link to="stats">Stats</Link>
                    <Link to="settings">Settings</Link>
                </nav>
                <Outlet />
            </div>
        );
    }

    def Stats() -> any {
        return <h2>Stats</h2>;
    }

    def Settings() -> any {
        return <h2>Settings</h2>;
    }

    def app() -> any {
        return (
            <BrowserRouter>
                <Routes>
                    <Route path="/dashboard" element={<Dashboard />}>
                        <Route path="stats" element={<Stats />} />
                        <Route path="settings" element={<Settings />} />
                    </Route>
                </Routes>
            </BrowserRouter>
        );
    }
}
```

---

## Next

- [State Management](../14-state-management/) - Zustand, Redux
