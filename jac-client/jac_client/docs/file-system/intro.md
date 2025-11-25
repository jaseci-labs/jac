# File System Organization

Jac client supports a clean separation of concerns by allowing you to organize your code into separate files based on execution environment. This makes it easier to maintain and understand your application architecture.

## File Extensions

### `.jac` Files - Server-side Code
Standard Jac files (`.jac`) contain your backend logic:
- Node definitions
- Walker implementations
- Business logic
- Data processing

**Example: `app.jac`**
```jac
walker add {
    has x: int;
    has y: int;
    can compute with `root entry {
        result = self.x + self.y;
        report result;
    }
}
```

### `.cl.jac` Files - Client-side Code
Client files (`.cl.jac`) contain your frontend components and logic. All code in these files is automatically treated as client-side code without requiring the `cl` keyword.

**Example: `app.cl.jac`**
```jac
import from react {
    useState
}

def app -> Any {
    let [answer, setAnswer] = useState(0);

    async def computeAnswer() -> None {
        response = root spawn add(x=40, y=2);
        result = response.reports;
        setAnswer(result);
    }

    return <div>
        <button onClick={computeAnswer}>
            Click Me
        </button>
        <div>
            <h1>
                Answer:
                <span>{answer}</span>
            </h1>
        </div>
    </div>;
}
```

## Key Benefits

### 1. **No `cl` Keyword Required**
In `.cl.jac` files, you don't need to prefix declarations with `cl`:
- All code is compiled for the client environment

### 2. **Clear Separation of Concerns**
```
my-app/
├── app.jac       # Server-side: walkers, nodes, business logic
└── app.cl.jac    # Client-side: components, UI, event handlers
```

### 3. **Seamless Integration**
Client code can invoke server walkers using `root spawn`:

```jac
# In app.cl.jac
async def computeAnswer() -> None {
    response = root spawn add(x=40, y=2);  # Calls walker from app.jac
    result = response.reports;
    setAnswer(result);
}
```

## Best Practices

1. **Keep backend logic in `.jac` files**: Data models, business rules, and walker implementations
2. **Keep frontend logic in `.cl.jac` files**: React components, UI state, event handlers
3. **Use `root spawn` for client-server communication**: Clean API between frontend and backend
4. **Organize by feature**: Group related `.jac` and `.cl.jac` files together

This organization keeps your codebase maintainable and makes it immediately clear which code runs where.
