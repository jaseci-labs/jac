# Jac Client

Build full-stack web applications with Jac - one language for frontend and backend.

Jac Client enables you to write React-like components, manage state, and build interactive UIs all in Jac. No need for separate frontend frameworks, HTTP clients, or complex build configurations.

---

## Features

- **Single Language**: Write frontend and backend in Jac
- **No HTTP Client**: Use `jacSpawn()` instead of fetch/axios
- **React Hooks**: Use standard React `useState` and `useEffect` hooks (useState is auto-injected when using `has` variables)
- **Component-Based**: Build reusable UI components with JSX
- **Graph Database**: Built-in graph data model eliminates need for SQL/NoSQL
- **Type Safety**: Type checking across frontend and backend
- **Vite-Powered**: Optimized production bundles with Vite

---

## Quick Start

### Installation

```bash
pip install jac-client
```

### Create a New App

```bash
jac create --use client my-app
cd my-app
jac start src/app.jac
```

Visit `http://localhost:8000` to see your app! (The `app` component is served at the root by default.)

You can also access the app at `http://localhost:8000/cl/app`.

> **Note**: The `--use client` flag creates a client-side project with an organized folder structure. Without it, `jac create` creates a standard Jac project.

---

## Documentation

For detailed guides and tutorials, see the **[docs folder](jac_client/docs/)**:

- **[Getting Started Guide](jac_client/docs/README.md)** - Complete beginner's guide
- **[Routing](jac_client/docs/routing.md)** - Multi-page applications with declarative routing (`<Router>`, `<Routes>`, `<Route>`)
- **[Lifecycle Hooks](jac_client/docs/lifecycle-hooks.md)** - Using React hooks (`useState`, `useEffect`)
- **[Advanced State](jac_client/docs/advanced-state.md)** - Managing complex state with React hooks
- **[Imports](jac_client/docs/imports.md)** - Importing third-party libraries (React, Ant Design, Lodash), Jac files, and JavaScript modules

---

## Example

### Simple Counter with React Hooks

```jac
# Note: useState is auto-injected when using has variables in cl blocks
# Only useEffect needs explicit import
cl import from react { useEffect }

cl {
    def Counter() -> JsxElement {
        # useState is automatically available - no import needed!
        [count, setCount] = useState(0);

        useEffect(lambda -> None {
            console.log("Count changed:", count);
        }, [count]);

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                setCount(count + 1);
            }}>
                Increment
            </button>
        </div>;
    }

    def app() -> JsxElement {
        return Counter();
    }
}
```

> **Note:** When using `has` variables in `cl {}` blocks or `.cl.jac` files, the `useState` import is automatically injected. You only need to explicitly import other hooks like `useEffect`.

### Full-Stack Todo App

```jac
# useState is auto-injected, only import useEffect
cl import from react { useEffect }
cl import from '@jac/runtime' { jacSpawn }

# Backend: Jac nodes and walkers
node Todo {
    has text: str;
    has done: bool = False;
}

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
}

# Frontend: React component
cl {
    def app() -> JsxElement {
        # useState is automatically available - no import needed!
        [todos, setTodos] = useState([]);

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                result = await jacSpawn("read_todos", "", {});
                setTodos(result.reports);
            }
            loadTodos();
        }, []);

        return <div>
            <h1>My Todos</h1>
            {todos.map(lambda todo: any -> any {
                return <div key={todo._jac_id}>{todo.text}</div>;
            })}
        </div>;
    }
}
```

---

## Requirements

- Python: 3.12+
- Bun: For package management and Vite bundling ([install](https://bun.sh))
- Jac Language: `jaclang` (installed automatically)

---

## ️ How It Works

Jac Client is a plugin that:

1. Compiles your `.jac` client code to JavaScript
2. Bundles dependencies with Vite for optimal performance
3. Provides a runtime for reactive state and components
4. Integrates seamlessly with Jac's backend graph operations

---

## Learn More

- **Full Documentation**: See [docs/](jac_client/docs/) for comprehensive guides
- **Examples**: Check `jac_client/examples/` for working examples
- **Issues**: Report bugs on [GitHub Issues](https://github.com/Jaseci-Labs/jaseci/issues)

---

## License

MIT License - see [LICENSE](../LICENSE) file.

---

**Happy coding with Jac!**
