# Imports and Exports

JAC-Client module system for importing npm packages, local files, and utilities.

---

## Import Syntax

```jac
cl import from <source> { item1, item2 }
```

---

## NPM Packages

```jac
# React
cl import from react { useState, useEffect, useCallback }

# React Router
cl import from react-router-dom { BrowserRouter, Routes, Route, Link, useNavigate }

# Zustand
cl import from zustand { create }

# Other libraries
cl import from axios { default as axios }
```

---

## Local Files

```jac
# Same folder
cl import from .button { Button }

# Parent folder
cl import from ..components.header { Header }

# Nested path
cl import from .components.ui.card { Card }
```

---

## @jac-client/utils

Built-in utilities:

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

## Export Syntax

Use `:pub` annotation to export:

```jac
# Export function
def:pub MyButton(label: str) -> any {
    return <button>{label}</button>;
}

# Export variable
glob:pub API_URL = "https://api.example.com";

# Export class/object
obj:pub User {
    has name: str;
    has email: str;
}

# Export enum
enum:pub Status {
    PENDING,
    ACTIVE,
    COMPLETED
}
```

---

## Complete Example

**button.jac:**

```jac
cl {
    def:pub Button(onClick: any, children: any) -> any {
        return (
            <button
                onClick={onClick}
                style={{"padding": "10px 20px"}}
            >
                {children}
            </button>
        );
    }
}
```

**app.jac:**

```jac
cl import from react { useState }
cl import from .button { Button }

cl {
    def app() -> any {
        [count, setCount] = useState(0);

        return (
            <div>
                <p>Count: {count}</p>
                <Button onClick={lambda: setCount(count + 1)}>
                    Increment
                </Button>
            </div>
        );
    }
}
```

---

## Summary

| Type | Syntax |
|------|--------|
| Import npm | `cl import from package { items }` |
| Import local | `cl import from .path { items }` |
| Export function | `def:pub name() -> type { }` |
| Export variable | `glob:pub name = value` |
| Export class | `obj:pub Name { }` |
| Export enum | `enum:pub Name { }` |

---

## Next

- [Project Structure](../10-project-structure/) - File organization
