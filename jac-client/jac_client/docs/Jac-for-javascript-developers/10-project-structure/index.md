# Project Structure

How to organize JAC-Client projects.

---

## Entry Point

Every project needs `app.jac` with a `def app()` function:

```jac
cl import from react { useState }

cl {
    def app() -> any {
        return (
            <div>
                <h1>Hello JAC!</h1>
            </div>
        );
    }
}
```

---

## Basic Structure

```
my-project/
├── app.jac              # Entry point (required)
├── components/
│   ├── header.jac
│   ├── footer.jac
│   └── button.jac
├── pages/
│   ├── home.jac
│   └── about.jac
└── utils/
    └── helpers.jac
```

---

## Multi-File Example

**components/button.jac:**

```jac
cl {
    def:pub Button(onClick: any, children: any) -> any {
        return (
            <button onClick={onClick}>
                {children}
            </button>
        );
    }
}
```

**components/header.jac:**

```jac
cl {
    def:pub Header(title: str) -> any {
        return (
            <header>
                <h1>{title}</h1>
            </header>
        );
    }
}
```

**app.jac:**

```jac
cl import from react { useState }
cl import from .components.button { Button }
cl import from .components.header { Header }

cl {
    def app() -> any {
        [count, setCount] = useState(0);

        return (
            <div>
                <Header title="My App" />
                <p>Count: {count}</p>
                <Button onClick={lambda: setCount(count + 1)}>
                    Click me
                </Button>
            </div>
        );
    }
}
```

---

## Nested Folders

```
app/
├── app.jac
├── components/
│   ├── ui/
│   │   ├── button.jac
│   │   └── input.jac
│   └── layout/
│       ├── header.jac
│       └── sidebar.jac
└── features/
    ├── auth/
    │   └── login.jac
    └── dashboard/
        └── stats.jac
```

Import with full path:

```jac
cl import from .components.ui.button { Button }
cl import from .components.layout.header { Header }
cl import from .features.auth.login { LoginForm }
```

---

## Best Practices

1. **One component per file** - easier to maintain
2. **Group by feature** - auth/, dashboard/, etc.
3. **Shared components in components/** - reusable UI
4. **Utils for helpers** - pure functions
5. **Keep app.jac minimal** - just compose components

---

## Next

- [Styling](../11-styling/) - CSS approaches
