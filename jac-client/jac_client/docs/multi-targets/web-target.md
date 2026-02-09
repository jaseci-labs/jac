# Web Target

The **web target** is the default build target for Jac applications. It compiles your Jac code to JavaScript and bundles it with Vite for optimal web performance.

---

## Overview

The web target produces browser-compatible JavaScript bundles that can be deployed to any web server or hosting platform.

**Features:**

- ✅ No setup required
- ✅ Automatic HTML generation
- ✅ CSS bundling
- ✅ Production-ready builds
- ✅ Works with all existing Jac features
- ✅ Hot module replacement (HMR) in dev mode

---

## Quick Start

### Building for Web

```bash
# Build (web is default)
jac build main.jac

# Or explicitly
jac build main.jac --client web
```

**Output:**

- Compiled JavaScript bundle: `.jac/client/dist/client.[hash].js`
- Generated HTML: `.jac/client/dist/index.html`
- CSS files: `.jac/client/dist/styles.css` (if present)

### Development Mode

```bash
# Start dev server with hot reload
jac start main.jac --dev

# Visit http://localhost:8000
```

### Production Mode

```bash
# Build for production
jac build main.jac

# Start production server
jac start main.jac --no-dev
```

---

## Build Process

### 1. Compilation

Jac code is compiled to JavaScript using the Jac runtime:

```jac
# Your Jac code
cl {
    def:pub app() -> any {
        has count: int = 0;
        return <div>Count: {count}</div>;
    }
}
```

↓ Compiles to ↓

```javascript
// Generated JavaScript
export function app() {
    const [count, setCount] = useState(0);
    return React.createElement('div', null, `Count: ${count}`);
}
```

### 2. Bundling

JavaScript is bundled with Vite:

- Processes imports and dependencies
- Optimizes and minifies code
- Handles CSS imports
- Creates production-ready bundle

### 3. HTML Generation

Static `index.html` is automatically generated with:

- Proper HTML head (meta tags, title, etc.)
- `__jac_init__` script tag for client runtime
- Script tag pointing to bundled JavaScript
- CSS links (if CSS files exist)

---

## Output Structure

After building, your `.jac/client/dist/` directory contains:

```
.jac/client/dist/
├── index.html              # Generated HTML entry point
├── client.[hash].js       # Bundled JavaScript
└── styles.css             # Bundled CSS (if present)
```

### index.html

The generated HTML includes everything needed to run your app:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My App</title>
  </head>
  <body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">
      {"module": "main", "function": "app", "args": {}, "argOrder": [], "globals": {}}
    </script>
    <script type="module" src="client.abc123.js"></script>
  </body>
</html>
```

---

## Development Workflow

### 1. Start Development Server

```bash
jac start main.jac --dev
```

This:

- Compiles your Jac code
- Starts Vite dev server on port 5173
- Starts API server on port 8000
- Enables hot module replacement (HMR)

### 2. Make Changes

Edit your `.jac` files and save. Changes automatically reload in the browser.

### 3. Build for Production

```bash
jac build main.jac
```

This:

- Cleans the dist directory
- Compiles and bundles your code
- Generates optimized production bundle
- Creates `index.html`

---

## Configuration

### jac.toml

Web target configuration is in `jac.toml`:

```toml
[project]
name = "my-app"
version = "1.0.0"
entry-point = "main.jac"

[plugin.client]
# Vite configuration
# Package dependencies
# Build settings
```

### Customizing HTML Head

Add metadata in `jac.toml`:

```toml
[plugin.client]
app_meta_data = {
    title = "My Awesome App",
    description = "A great Jac application",
    keywords = "jac, web, app",
    author = "Your Name"
}
```

This generates proper meta tags in the HTML head.

---

## Advanced Features

### CSS Bundling

Import CSS files in your Jac code:

```jac
cl import "./styles.css"

cl {
    def:pub app() -> any {
        return <div className="container">Hello</div>;
    }
}
```

CSS is automatically bundled and included in the HTML.

### Asset Handling

Static assets (images, fonts, etc.) are handled automatically:

```jac
cl {
    def:pub app() -> any {
        return <img src="/assets/logo.png" alt="Logo" />;
    }
}
```

### Code Splitting

Large applications are automatically code-split for optimal loading.

---

## Deployment

### Static Hosting

Deploy the `dist/` directory to any static host:

```bash
# Build
jac build main.jac

# Deploy .jac/client/dist/ to:
# - Netlify
# - Vercel
# - GitHub Pages
# - AWS S3
# - Any web server
```

### Server-Side Rendering

For SSR, use the API server:

```bash
# Start production server
jac start main.jac --no-dev

# Server renders pages on-demand
# Visit http://localhost:8000
```

---

## Best Practices

### 1. Use Dev Mode for Development

Always use `--dev` flag during development for hot reload:

```bash
jac start main.jac --dev
```

### 2. Test Production Builds

Before deploying, test the production build:

```bash
jac build main.jac
jac start main.jac --no-dev
```

### 3. Optimize Bundle Size

- Use dynamic imports for large dependencies
- Remove unused code
- Enable minification (default in production)

### 4. Handle Environment Variables

Use configuration for environment-specific settings:

```toml
[plugin.client]
# Development settings
# Production settings
```

---

## Troubleshooting

### Build Fails

**Error**: "Failed to compile"

- Check for syntax errors in your `.jac` files
- Verify all imports are correct
- Check console for detailed error messages

### Bundle Not Found

**Error**: "Web build failed: bundle not found"

- Ensure build completed successfully
- Check `.jac/client/dist/` directory exists
- Rebuild: `jac build main.jac`

### CSS Not Loading

**Issue**: Styles not applied

- Verify CSS file exists
- Check import path is correct
- Rebuild to regenerate HTML

### Hot Reload Not Working

**Issue**: Changes don't reflect

- Ensure `--dev` flag is used
- Check Vite dev server is running
- Restart dev server if needed

---

## Examples

### Basic Web App

```jac
# main.jac
cl {
    def:pub app() -> any {
        has count: int = 0;

        return <div style={{padding: "2rem"}}>
            <h1>My Web App</h1>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

Build and run:

```bash
jac build main.jac
jac start main.jac
```

### Full-Stack Web App

```jac
# main.jac
cl {
    def:pub app() -> any {
        has todos: list = [];

        async def loadTodos() -> None {
            response = root spawn get_todos();
            todos = response.reports[0];
        }

        useEffect(lambda -> None {
            loadTodos();
        }, []);

        return <div>
            <h1>Todo App</h1>
            {todos.map(lambda todo: any -> any {
                return <div key={todo._jac_id}>{todo.text}</div>;
            })}
        </div>;
    }
}
```

---

## Next Steps

- **[Desktop Target](desktop-target.md)**: Build desktop applications
- **[Routing](../routing.md)**: Add multi-page navigation
- **[Advanced State](../advanced-state.md)**: Manage complex state
- **[Imports](../imports.md)**: Use third-party libraries

---

Happy coding! 🌐
