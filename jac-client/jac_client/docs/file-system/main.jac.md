# The `main.jac` Entry Point

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - The `app()` function is **automatically exported** - no `:pub` needed
>
> **For jac-client >= 0.2.4:**
>
> - The `app()` function **must be exported** with `:pub` (e.g., `def:pub app()`)

Every Jac client project **must** have a `main.jac` file. This file serves as the entry point for your application and is required for the build system to work correctly.

## Why `main.jac` is Required

### Entry Point for the Build System

When you run `jac start main.jac` (or `jac start` which reads from `jac.toml`), the build system:

1. Compiles `main.jac` to JavaScript
2. Generates an entry file (`compiled/main.js`) that imports your `app` function:

   ```javascript
   import { app as App } from "./app.js";
   ```

3. Renders your app component in the browser

**Without `main.jac`, the build system cannot find your application entry point.**

## The `app()` Function

The `main.jac` file **must** export an `app()` function. This function is:

- The root component of your application
- Automatically imported and rendered by the build system
- The starting point for all your UI components

### Required Structure

Every `main.jac` file must contain:

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            {/* Your application UI */}
        </div>;
    }
}
```

### Minimal Example

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>Hello, World!</h1>
        </div>;
    }
}
```

## Key Requirements

1. **File must be named `main.jac`**
   - The build system specifically looks for this filename
   - Located at the project root directory

2. **Must contain `app()` function**
   - Function name must be exactly `app`
   - Must be exported with `:pub` (e.g., `def:pub app()`)
   - Must be defined inside a `cl { }` block
   - Must return JSX (HTML-like syntax)

3. **Must be a client function**
   - Defined inside `cl { }` block
   - This ensures it runs in the browser

## Common Mistakes

**Missing `app()` function:**

```jac
#  WRONG - No app() function
cl {
    def HomePage() -> JsxElement {
        return <div>Home</div>;
    }
}
```

**Wrong function name:**

```jac
#  WRONG - Function named 'main' instead of 'app'
cl {
    def main() -> JsxElement {
        return <div>App</div>;
    }
}
```

**Not exported:**

```jac
#  WRONG - app() not exported with :pub
cl {
    def app() -> JsxElement {
        return <div>App</div>;
    }
}
```

**Not in `cl` block:**

```jac
#  WRONG - app() not in cl block
def app() -> JsxElement {
    return <div>App</div>;
}
```

## Project Structure

Your project structure should look like this:

```
my-app/
├── jac.toml              # Project configuration (entry-point = "main.jac")
├── main.jac              # Required entry point
├── components/           # Reusable components
│   └── Button.tsx        # Example TypeScript component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Running Your App

To start your application, you can use either:

**Option 1: Specify the file path**

```bash
jac start main.jac
```

**Option 2: Use jac.toml entry-point (recommended)**

```bash
jac start
```

The `jac start` command (without arguments) reads the `entry-point` from `jac.toml`:

```toml
[project]
entry-point = "main.jac"
```

Both commands compile `main.jac`, create the build entry point, and serve your app at `http://localhost:8000/cl/app`.

---

**Remember**: `main.jac` with `app()` function (exported with `:pub`) is **required** for every Jac client project. Without it, your application cannot start!

## Related Documentation

- [Exporting Functions and Variables](../exporting-functions-and-variables.md) - Learn how to export functions with `:pub`
- [Import System](../imports.md) - Import exported functions from other files
