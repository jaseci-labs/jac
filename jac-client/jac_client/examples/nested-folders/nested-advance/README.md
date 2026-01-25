# Nested Folder Levels Example

This example demonstrates multiple levels of folder nesting and how relative imports work across different directory levels.

## Project Structure

```
nested-advance/
├── app.jac                    # Root entry point
├── ButtonRoot.jac            # Root level button
└── level1/
    ├── ButtonSecondL.jac     # Second level button
    ├── Card.jac              # Card component (imports from root and level2)
    └── level2/
        └── ButtonThirdL.jac  # Third level button
```

## Import Patterns Demonstrated

### 1. Root Level (`app.jac`)

```jac
# Import from root
cl import from .ButtonRoot { ButtonRoot }

# Import from level1
cl import from .level1.ButtonSecondL { ButtonSecondL }

# Import from level1/level2
cl import from .level1.level2.ButtonThirdL { ButtonThirdL }
```

### 2. Second Level (`level1/ButtonSecondL.jac`)

```jac
# Import from root (go up one level with ..)
cl import from ..ButtonRoot { ButtonRoot }
```

### 3. Card Component (`level1/Card.jac`)

This demonstrates importing from both above and below:

```jac
# Import from root (go up two levels with ..)
cl import from ..ButtonRoot { ButtonRoot }

# Import from level2 (go down one level with .level2)
cl import from .level2.ButtonThirdL { ButtonThirdL }
```

### 4. Third Level (`level1/level2/ButtonThirdL.jac`)

```jac
# Import from root (go up three levels with ...)
cl import from ...ButtonRoot { ButtonRoot }

# Import from second level (go up one level with ..)
cl import from ..ButtonSecondL { ButtonSecondL }
```

## Running the Example

Make sure node modules are installed:

```bash
bun install
```

To run your Jac code, use the Jac CLI:

```bash
jac start app.jac
```

## Key Concepts

- **Single dot (`.`)** - Current directory
- **Double dot (`..`)** - Parent directory (one level up)
- **Triple dot (`...`)** - Two levels up
- **Multiple dots** - Continue going up the directory tree
- **Dot notation after dots** - Go down into subdirectories (e.g., `.level2`)

This example shows how folder structure is preserved during compilation, ensuring all relative imports work correctly!
