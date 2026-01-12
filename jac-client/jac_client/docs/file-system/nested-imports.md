# Nested Folder Imports

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - All `def` functions are **automatically exported** - no `:pub` needed
> - You **cannot export variables** (globals)
>
> **For jac-client >= 0.2.4:**
>
> - Functions **must be explicitly exported** with `:pub` to be importable
> - This documentation assumes version 0.2.4 or later

Jac preserves folder structure during compilation, similar to TypeScript transpilation. This allows you to organize code in nested folders and use relative imports across multiple directory levels.

## Folder Structure Preservation

When Jac compiles your files, it preserves the folder structure in the `compiled/` directory:

```
Source Structure:              Compiled Structure:
my-app/                        compiled/
├── src/                       ├── app.js
│   ├── app.jac        →      ├── ButtonRoot.js
│   ├── ButtonRoot.jac  →     └── level1/
│   └── level1/                    ├── ButtonSecondL.js
    ├── ButtonSecondL.jac →
    ├── Card.jac          →        ├── Card.js
    └── level2/                    └── level2/
        └── ButtonThirdL.jac →         └── ButtonThirdL.js
```

## Relative Import Syntax

Jac uses dot notation for relative imports:

- **Single dot (`.`)** - Current directory
- **Double dot (`..`)** - Parent directory (one level up)
- **Triple dot (`...`)** - Two levels up
- **Multiple dots** - Continue going up the directory tree
- **Dot notation after dots** - Go down into subdirectories (e.g., `.level2`)

## Import Patterns by Directory Level

### Root Level Imports

From the root directory, you can import from nested folders:

```jac
# app.jac (root level)

# Import from root
cl import from .ButtonRoot {
    ButtonRoot
}

# Import from level1
cl import from .level1.ButtonSecondL {
    ButtonSecondL
}

# Import from level1/level2
cl import from .level1.level2.ButtonThirdL {
    ButtonThirdL
}

# Import from level1
cl import from .level1.Card {
    Card
}
```

### Second Level Imports

From `level1/`, you can import from root (up) or level2 (down):

```jac
# level1/ButtonSecondL.jac

# Import from root (go up one level with ..)
cl import from ..ButtonRoot {
    ButtonRoot
}
```

```jac
# level1/Card.jac

# Import from root (go up two levels with ..)
cl import from ..ButtonRoot {
    ButtonRoot
}

# Import from level2 (go down one level with .level2)
cl import from .level2.ButtonThirdL {
    ButtonThirdL
}
```

### Third Level Imports

From `level1/level2/`, you can import from root or parent levels:

```jac
# level1/level2/ButtonThirdL.jac

# Import from root (go up three levels with ...)
cl import from ...ButtonRoot {
    ButtonRoot
}

# Import from second level (go up one level with ..)
cl import from ..ButtonSecondL {
    ButtonSecondL
}
```

## Complete Example

Here's a complete example demonstrating nested folder imports:

**Project Structure:**

```
nested-advance/
├── src/
│   ├── app.jac                # Root entry point
│   ├── ButtonRoot.jac        # Root level button
│   └── level1/
│       ├── ButtonSecondL.jac # Second level button
│       ├── Card.jac          # Card component (imports from root and level2)
│       └── level2/
│           └── ButtonThirdL.jac  # Third level button
└── jac.toml                  # entry-point = "main.jac"
```

**app.jac:**

```jac
cl import from .ButtonRoot {
    ButtonRoot
}
cl import from .level1.ButtonSecondL {
    ButtonSecondL
}
cl import from .level1.level2.ButtonThirdL {
    ButtonThirdL
}
cl import from .level1.Card {
    Card
}

cl def:pub app() -> any {
    return <div>
        <ButtonRoot />
        <ButtonSecondL />
        <ButtonThirdL />
        <Card />
    </div>;
}
```

**level1/ButtonSecondL.jac:**

```jac
cl import from ..ButtonRoot {
    ButtonRoot
}

cl def:pub ButtonSecondL() -> any {
    return <div>
        <Button>Second Level</Button>
        <ButtonRoot />
    </div>;
}
```

**level1/Card.jac:**

```jac
# Imports from both above (root) and below (level2)
cl import from ..ButtonRoot {
    ButtonRoot
}
cl import from .level2.ButtonThirdL {
    ButtonThirdL
}

cl def:pub Card() -> any {
    return <div>
        <ButtonRoot />
        <ButtonThirdL />
    </div>;
}
```

**level1/level2/ButtonThirdL.jac:**

```jac
cl import from ...ButtonRoot {
    ButtonRoot
}
cl import from ..ButtonSecondL {
    ButtonSecondL
}

cl def:pub ButtonThirdL() -> any {
    return <div>
        <Button>Third Level</Button>
        <ButtonRoot />
        <ButtonSecondL />
    </div>;
}
```

## Import Path Reference

| Your Location | Target Location | Import Path |
|--------------|----------------|-------------|
| `app.jac` (root) | `ButtonRoot.jac` (root) | `.ButtonRoot` |
| `app.jac` (root) | `level1/ButtonSecondL.jac` | `.level1.ButtonSecondL` |
| `app.jac` (root) | `level1/level2/ButtonThirdL.jac` | `.level1.level2.ButtonThirdL` |
| `level1/ButtonSecondL.jac` | `ButtonRoot.jac` (root) | `..ButtonRoot` |
| `level1/Card.jac` | `ButtonRoot.jac` (root) | `..ButtonRoot` |
| `level1/Card.jac` | `level2/ButtonThirdL.jac` | `.level2.ButtonThirdL` |
| `level1/level2/ButtonThirdL.jac` | `ButtonRoot.jac` (root) | `...ButtonRoot` |
| `level1/level2/ButtonThirdL.jac` | `level1/ButtonSecondL.jac` | `..ButtonSecondL` |

## Benefits of Nested Folder Structure

1. **Relative imports work correctly**: Folder structure is preserved, so imports resolve properly
2. **No file name conflicts**: Files with the same name in different folders don't overwrite each other
3. **Familiar structure**: Organize code in nested folders just like in TypeScript/JavaScript projects
4. **Consistent with modern tooling**: Matches the behavior of TypeScript, Babel, and other transpilers
5. **Scalable organization**: Organize large applications into logical folder hierarchies

## Best Practices for Nested Folders

1. **Organize by feature or component type**: Group related files together

   ```
   components/
   ├── ui/
   │   ├── Button.jac
   │   └── Card.jac
   ├── layout/
   │   ├── Header.jac
   │   └── Footer.jac
   └── features/
       ├── TodoList.jac
       └── TodoItem.jac
   ```

2. **Use consistent naming**: Keep file names descriptive and consistent
3. **Limit nesting depth**: Avoid going too deep (3-4 levels is usually sufficient)
4. **Document import patterns**: Comment complex import relationships

## Common Patterns

### Pattern 1: Component Library Structure

```
components/
├── ui/
│   ├── Button.jac
│   └── Input.jac
├── forms/
│   ├── LoginForm.jac
│   └── SignupForm.jac
└── layout/
    ├── Header.jac
    └── Sidebar.jac
```

**Usage:**

```jac
# From root
cl import from .components.ui.Button { Button }
cl import from .components.forms.LoginForm { LoginForm }

# From components/ui/Button.jac importing from forms
cl import from ..forms.LoginForm { LoginForm }
```

### Pattern 2: Feature-Based Structure

```
features/
├── auth/
│   ├── Login.jac
│   └── Signup.jac
├── todos/
│   ├── TodoList.jac
│   └── TodoItem.jac
└── dashboard/
    ├── Dashboard.jac
    └── Stats.jac
```

**Usage:**

```jac
# From root
cl import from .features.auth.Login { Login }
cl import from .features.todos.TodoList { TodoList }

# From features/auth/Login.jac importing from todos
cl import from ..todos.TodoList { TodoList }
```

### Pattern 3: Mixed Structure

```
src/
├── app.jac                # Root entry
├── components/
│   └── ui/
│       └── Button.jac
├── utils/
│   └── helpers/
│       └── format.jac
└── hooks/
    └── useCounter.jac
```

**Usage:**

```jac
# From app.jac
cl import from .components.ui.Button { Button }
cl import from .utils.helpers.format { capitalize }
cl import from .hooks.useCounter { useCounter }

# From components/ui/Button.jac
cl import from ...utils.helpers.format { capitalize }
```

## Troubleshooting

### Import Not Found

- Verify the file exists at the expected path
- Check that the relative path matches the folder structure
- Ensure file extension is `.jac` (not `.cl.jac` for imports)

### Wrong Import Path

- Count the directory levels between source and target
- Use `..` for each level up, `.folder` for each level down
- Start with `.` for current directory imports

### File Name Conflicts

- Use nested folders to avoid conflicts
- Files with the same name in different folders won't conflict
- Folder structure is preserved in compiled output

## Examples

Complete working examples demonstrating nested folder imports:

- [`nested-basic/`](../../examples/nested-folders/nested-basic/) - Simple nested folder structure
- [`nested-advance/`](../../examples/nested-folders/nested-advance/) - Advanced multi-level nesting

Run any example:

```bash
cd jac-client/jac_client/examples/nested-folders/<example-name>
npm install
jac start main.jac
```

## Related Documentation

- [Backend/Frontend Separation](backend-frontend.md)
- [Import System](../imports.md)
- [Exporting Functions and Variables](../exporting-functions-and-variables.md)
- [File System Organization](intro.md)
