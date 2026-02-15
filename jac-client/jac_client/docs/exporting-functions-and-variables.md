# Exporting Functions and Variables

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - The `:pub` modifier is **not supported**
> - All `def` functions are **automatically exported** (no need to mark them)
> - You **cannot export variables** (globals) - only functions can be exported
>
> **For jac-client >= 0.2.4:**
>
> - You **must explicitly export** functions and variables using `:pub`
> - Functions and variables are **private by default** and won't be available for import unless marked with `:pub`
> - This documentation applies to version 0.2.4 and later

In Jac, you can explicitly export functions and variables using the `:pub` modifier. This makes them available for import in other files.

## Why Export?

When you define functions or variables in a Jac file, they are **private by default**. To make them available for import in other files, you need to explicitly mark them with `:pub`.

## Exporting Functions

### Basic Function Export

To export a function, add `:pub` after `def`:

```jac
cl {
    def:pub MyComponent() -> JsxElement {
        return <div>
            <h1>Hello from MyComponent!</h1>
        </div>;
    }
}
```

### Exporting Async Functions

Async functions can also be exported:

```jac
cl {
    async def:pub fetchData(url: str) -> dict {
        response = await fetch(url);
        return await response.json();
    }
}
```

### Exporting Functions with Parameters

```jac
cl {
    def:pub Button(label: str, onClick: callable) -> JsxElement {
        return <button onClick={onClick}>
            {label}
        </button>;
    }
}
```

## Exporting Variables (Globals)

### Basic Variable Export

To export a variable, add `:pub` after `glob`:

```jac
cl {
    glob:pub API_URL: str = "https://api.example.com";
    glob:pub MAX_ITEMS: int = 100;
}
```

### Exporting Multiple Variables

You can export multiple variables in a single declaration:

```jac
cl {
    glob:pub API_URL: str = "https://api.example.com",
          MAX_ITEMS: int = 100,
          TIMEOUT: int = 5000;
}
```

### Exporting Complex Types

```jac
cl {
    glob:pub THEME: dict = {
        "primary": "#3b82f6",
        "secondary": "#6b7280",
        "success": "#10b981"
    };

    glob:pub CONFIG: dict = {
        "api": {
            "baseUrl": "https://api.example.com",
            "timeout": 5000
        }
    };
}
```

## Complete Example

Here's a complete example showing how to export and import:

**components/Button.jac:**

```jac
cl {
    # Export a component
    def:pub Button(label: str, variant: str = "primary") -> JsxElement {
        styles = {
            "primary": {"backgroundColor": "#3b82f6", "color": "white"},
            "secondary": {"backgroundColor": "#6b7280", "color": "white"}
        };

        return <button style={styles.get(variant, styles["primary"])}>
            {label}
        </button>;
    }

    # Export a constant
    glob:pub BUTTON_VARIANTS: list = ["primary", "secondary", "danger"];
}
```

**app.jac:**

```jac
cl import from .components.Button {
    Button,
    BUTTON_VARIANTS
}

cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>My App</h1>
            <Button label="Click Me" variant="primary" />
            <Button label="Cancel" variant="secondary" />
            <p>Available variants: {BUTTON_VARIANTS.join(", ")}</p>
        </div>;
    }
}
```

## The `app()` Function

The `app()` function in your main entry file (`main.jac`) **must** be exported:

```jac
cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>Hello, World!</h1>
        </div>;
    }
}
```

This is required because the build system imports it:

```javascript
import { app as App } from "./app.js";
```

## Private vs Public

### Private (Default)

Functions and variables without `:pub` are **private** and cannot be imported:

```jac
cl {
    # Private function - cannot be imported
    def helperFunction() -> str {
        return "This is private";
    }

    # Public function - can be imported
    def:pub publicFunction() -> str {
        return "This is public";
    }
}
```

### When to Use Private

Use private functions/variables for:

- Internal helper functions
- Implementation details
- Functions only used within the same file
- Constants that shouldn't be exposed

### When to Use Public

Use public functions/variables for:

- Components that will be imported
- Utility functions shared across files
- Configuration constants
- API endpoints or settings
- The main `app()` function

## Exporting from Nested Folders

When organizing code in nested folders, exported functions can be imported using relative paths:

**components/ui/Button.jac:**

```jac
cl {
    def:pub Button(label: str) -> JsxElement {
        return <button>{label}</button>;
    }
}
```

**app.jac:**

```jac
cl import from .components.ui.Button {
    Button
}

cl {
    def:pub app() -> JsxElement {
        return <div>
            <Button label="Click Me" />
        </div>;
    }
}
```

## Common Patterns

### Pattern 1: Component Library

**components/Button.jac:**

```jac
cl {
    glob:pub BUTTON_SIZES: list = ["small", "medium", "large"];

    def:pub Button(label: str, size: str = "medium") -> JsxElement {
        sizeStyles = {
            "small": {"padding": "0.5rem", "fontSize": "0.875rem"},
            "medium": {"padding": "0.75rem", "fontSize": "1rem"},
            "large": {"padding": "1rem", "fontSize": "1.125rem"}
        };

        return <button style={sizeStyles.get(size, sizeStyles["medium"])}>
            {label}
        </button>;
    }
}
```

### Pattern 2: Utility Functions

**utils/helpers.jac:**

```jac
cl {
    def:pub formatDate(date: any) -> str {
        return date.toLocaleDateString();
    }

    def:pub capitalize(text: str) -> str {
        return text[0].upper() + text[1:];
    }

    # Private helper - not exported
    def _validateInput(input: str) -> bool {
        return input and len(input) > 0;
    }
}
```

### Pattern 3: Configuration

**config/constants.jac:**

```jac
cl {
    glob:pub API_BASE_URL: str = "https://api.example.com";
    glob:pub API_VERSION: str = "v1";
    glob:pub TIMEOUT: int = 5000;

    glob:pub ENDPOINTS: dict = {
        "users": "/users",
        "todos": "/todos",
        "auth": "/auth"
    };
}
```

## Best Practices

1. **Export only what's needed**: Don't export everything - keep internal implementation details private

2. **Use descriptive names**: Exported functions/variables are part of your public API

3. **Document exports**: Add comments explaining what exported functions do

4. **Group related exports**: Keep related functions/variables in the same file

5. **Always export `app()`**: The main entry point must be exported

## Troubleshooting

### Function Not Found When Importing

**Problem:** You're trying to import a function but getting an error.

**Solution:** Make sure the function has `:pub`:

```jac
# Wrong - missing :pub
cl {
    def MyComponent() -> JsxElement { ... }
}

# Correct - has :pub
cl {
    def:pub MyComponent() -> JsxElement { ... }
}
```

### Variable Not Available

**Problem:** Imported variable is undefined.

**Solution:** Ensure the variable is exported with `glob:pub`:

```jac
# Wrong - missing :pub
cl {
    glob API_URL: str = "https://api.example.com";
}

# Correct - has :pub
cl {
    glob:pub API_URL: str = "https://api.example.com";
}
```

### `app()` Function Not Found

**Problem:** Build system can't find the `app()` function.

**Solution:** Make sure `app()` is exported:

```jac
# Wrong
cl {
    def app() -> JsxElement { ... }
}

# Correct
cl {
    def:pub app() -> JsxElement { ... }
}
```

## Related Documentation

- [Import System](imports.md) - Learn how to import exported functions and variables
- [File System Organization](file-system/intro.md) - Organize your exports across files
- [Nested Folder Imports](file-system/nested-imports.md) - Import from nested directories
- [The `main.jac` Entry Point](file-system/main.jac.md) - Understanding the main entry point
