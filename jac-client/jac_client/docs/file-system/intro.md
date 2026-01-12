# File System Organization

Jac client supports flexible file organization patterns that allow you to structure your code for maintainability and scalability.

## Overview

This guide covers two main aspects of file organization:

1. **Separating Backend and Frontend Code** - Organizing server-side and client-side logic
2. **Nested Folder Imports** - Managing imports across multiple directory levels

## Quick Start

### Backend/Frontend Separation

Jac allows you to organize code by execution environment:

- Use `.jac` files for backend logic (nodes, walkers)
- Use `.cl.jac` files for frontend-only code
- Or mix both in the same file using `cl` blocks

**Example:**

```jac
# Backend
node Todo { has text: str; }

# Frontend
cl {
    def app() -> any {
        return <div>Hello</div>;
    }
}
```

### Nested Folder Imports

Jac preserves folder structure during compilation, allowing you to organize code in nested folders:

**Example:**

```jac
# From level1/Button.jac importing from root
cl import from ..ButtonRoot { ButtonRoot }

# From root importing from level1
cl import from .level1.Button { Button }
```

## Guides

- **[The `main.jac` Entry Point](main.jac.md)** - Required entry point file and `app()` function
- **[Backend/Frontend Separation](backend-frontend.md)** - Complete guide to organizing server and client code
- **[Nested Folder Imports](nested-imports.md)** - Guide to managing imports across directory levels

## Examples

Working examples demonstrating file organization:

- [`nested-basic/`](../../examples/nested-folders/nested-basic/) - Simple nested folder structure
- [`nested-advance/`](../../examples/nested-folders/nested-advance/) - Advanced multi-level nesting

Run any example:

```bash
cd jac-client/jac_client/examples/nested-folders/<example-name>
npm install
jac start main.jac
```

## Related Documentation

- [Import System](../imports.md)
- [Styling](../styling/intro.md)
- [Asset Serving](../asset-serving/intro.md)
