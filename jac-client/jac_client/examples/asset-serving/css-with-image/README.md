# Relative Imports Example

This example demonstrates how to import static assets using relative path imports.

## Features

- Imports image using relative path (`./assets/burger.png`)
- Component-scoped asset organization
- Vite processes and optimizes the asset
- Familiar import syntax

## Project Structure

```
relative-imports/
├── app.jac          # Main application file
├── assets/          # Static assets directory
│   └── burger.png   # Burger image
├── compiled/             # Source files (generated)
├── build/           # Build output (generated)
└── dist/            # Distribution output (generated)
```

## Running the Example

1. Make sure node modules are installed:

```bash
npm install
```

1. Run the Jac server:

```bash
jac start app.jac
```

1. Open your browser and navigate to:

```
http://localhost:8000/cl/app
```

## How It Works

### Import Syntax

```jac
cl import from "./assets/burger.png" { default as burgerImage }
<img src={burgerImage} />
```

### Path Resolution

- Relative paths are resolved from the current file location
- `./assets/burger.png` resolves relative to `app.jac`
- Vite processes the import during build
- Assets are optimized and bundled

### Use Cases

**Component-Scoped Assets:**

```jac
# In a component file
cl import from "./images/icon.svg" { default as icon }
```

**Parent Directory Assets:**

```jac
# Access assets from parent directory
cl import from "../shared/assets/logo.png" { default as logo }
```

**Nested Assets:**

```jac
# Assets in subdirectories
cl import from "./assets/images/hero.jpg" { default as hero }
```

### Benefits

- **Familiar Syntax**: Standard relative import pattern
- **Component Organization**: Assets organized by component/feature
- **Flexibility**: Easy to reorganize without changing alias config
- **Modular**: Works well with component-based architecture

## Best Practices

1. Use relative imports for component-specific assets
2. Organize assets near the components that use them
3. Keep relative paths simple and clear
4. Use consistent naming conventions

Happy coding with Jac!
