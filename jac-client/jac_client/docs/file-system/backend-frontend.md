# Separating Backend and Frontend Code

Jac allows you to organize your code by execution environment, making it easier to maintain and understand your application architecture.

## File Extensions

### `.jac` Files - Server-side Code

Standard Jac files (`.jac`) contain your backend logic:

- Node definitions
- Walker implementations
- Business logic
- Data processing

**Example: `app.jac`**

```jac
# Backend - Todo Node
node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - Walkers
walker create_todo {
    has text: str;

    can create with Root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker read_todos {
    can read with Root entry {
        visit [-->(?:Todo)];
    }

    can report_todos with Todo entry {
        report here;
    }
}
```

### `.cl.jac` Files - Client-side Code (Optional)

Client files (`.cl.jac`) contain your frontend components and logic. All code in these files is automatically treated as client-side code without requiring the `cl` keyword.

**Example: `app.cl.jac`**

```jac
import from react {
    useState
}

def app -> Any {
    [answer, setAnswer] = useState(0);

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

## Mixed Backend and Frontend in Same File

You can also combine backend and frontend code in the same `.jac` file using `cl` blocks:

**Example: `app.jac` with both backend and frontend**

```jac
# Backend - Todo Node
node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - Walker
walker create_todo {
    has text: str;
    can create with Root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

# Frontend Components
cl {
    def app() -> JsxElement {
        [todos, setTodos] = useState([]);

        async def addTodo() -> None {
            response = root spawn create_todo(text="New task");
            # Update UI
        }

        return <div>
            {/* Your UI here */}
        </div>;
    }
}
```

## Key Benefits

### 1. No `cl` Keyword Required in `.cl.jac` Files

In `.cl.jac` files, you don't need to prefix declarations with `cl`:

- All code is compiled for the client environment
- Cleaner syntax for frontend-only files

### 2. Clear Separation of Concerns

**Option 1: Separate Files**

```
my-app/
├── app.jac       # Server-side: walkers, nodes, business logic
└── app.cl.jac    # Client-side: components, UI, event handlers
```

**Option 2: Single File with `cl` Blocks**

```jac
# Backend code (no cl keyword)
node Todo { ... }
walker create_todo { ... }

# Frontend code (cl block)
cl {
    def app() -> JsxElement { ... }
}
```

### 3. Seamless Integration

Client code can invoke server walkers using `root spawn`:

```jac
# In app.cl.jac or cl block
async def computeAnswer() -> None {
    response = root spawn create_todo(text="Task 1");  # Calls walker from app.jac
    result = response.reports;
    setAnswer(result);
}
```

## Best Practices

1. **Keep backend logic in `.jac` files**: Data models, business rules, and walker implementations
2. **Keep frontend logic in `.cl.jac` files or `cl` blocks**: React components, UI state, event handlers
3. **Use `root spawn` for client-server communication**: Clean API between frontend and backend
4. **Organize by feature**: Group related `.jac` and `.cl.jac` files together

## Project Structure Examples

### Simple Structure

```
my-app/
├── app.jac          # Backend: nodes and walkers
└── app.cl.jac        # Frontend: React components
```

### Feature-Based Structure

```
my-app/
├── app.jac           # Main backend logic
├── app.cl.jac        # Main frontend entry
├── todos/
│   ├── todos.jac     # Todo backend logic
│   └── todos.cl.jac  # Todo frontend components
└── auth/
    ├── auth.jac      # Auth backend logic
    └── auth.cl.jac   # Auth frontend components
```

### Mixed Structure (Single Files)

```
my-app/
├── app.jac           # Backend + Frontend in one file
├── todos.jac         # Todo feature (backend + frontend)
└── auth.jac          # Auth feature (backend + frontend)
```

## When to Use Each Approach

### Use Separate Files (`.jac` + `.cl.jac`)

- Large applications with clear separation
- Team workflows where backend/frontend are separate
- When you want explicit file-based organization

### Use Single File with `cl` Blocks

- Small to medium applications
- When backend and frontend are tightly coupled
- Quick prototypes and demos
- When you prefer fewer files

## Examples

See working examples in the codebase:

- [`basic-full-stack/`](../../examples/basic-full-stack/) - Mixed backend/frontend in single file
- [`full-stack-with-auth/`](../../examples/full-stack-with-auth/) - Complete full-stack application

## Related Documentation

- [Nested Folder Imports](nested-imports.md)
- [Import System](../imports.md)
- [Lifecycle Hooks](../lifecycle-hooks.md)
