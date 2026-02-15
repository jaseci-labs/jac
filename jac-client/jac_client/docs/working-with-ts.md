# Working with TypeScript in Jac

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - All `def` functions are **automatically exported** - no `:pub` needed
> - You **cannot export variables** (globals)
>
> **For jac-client >= 0.2.4:**
>
> - Functions and variables **must be explicitly exported** with `:pub` to be importable
> - This documentation assumes version 0.2.4 or later

## TypeScript as Last Resort

> **️ Warning: TypeScript as Last Resort**
>
> **Always prefer writing code in Jac when possible.** TypeScript support is provided for cases where you need to:
>
> - Integrate existing TypeScript/React component libraries
> - Reuse complex TypeScript components from other projects
> - Work with teams that require TypeScript for specific components
>
> For new development, Jac provides all the features you need with better integration and simpler syntax. Only use TypeScript when absolutely necessary.

---

This guide explains how to configure and use TypeScript components in your Jac applications when needed.

## Overview

Jac supports importing and using TypeScript (`.ts`, `.tsx`) components alongside Jac code. TypeScript files are automatically processed by Vite during the build process, providing full type safety and modern tooling support.

**TypeScript is automatically supported in all  Jac projects.** No configuration needed - just start using TypeScript components right away!

## Setup

TypeScript is automatically supported by default. Simply create a new project:

```bash
jac create --use client my-app
```

TypeScript is ready to use immediately. A sample Button component is included in `src/components/Button.tsx`!

---

## Adding TypeScript Components

### Example: Creating a Button Component

Create a TypeScript component in `src/components/Button.tsx`:

```typescript
import React from 'react';

interface ButtonProps {
  label: string;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  variant = 'primary',
  disabled = false
}) => {
  const baseStyles: React.CSSProperties = {
    padding: '0.75rem 1.5rem',
    fontSize: '1rem',
    fontWeight: '600',
    borderRadius: '0.5rem',
    border: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    transition: 'all 0.2s ease',
  };

  const variantStyles: Record<string, React.CSSProperties> = {
    primary: {
      backgroundColor: disabled ? '#9ca3af' : '#3b82f6',
      color: '#ffffff',
    },
    secondary: {
      backgroundColor: disabled ? '#e5e7eb' : '#6b7280',
      color: '#ffffff',
    },
  };

  return (
    <button
      style={{ ...baseStyles, ...variantStyles[variant] }}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  );
};

export default Button;
```

## Using TypeScript Components in Jac

Import and use your TypeScript components in your Jac files:

```jac
# Pages
cl import from react { useEffect }
cl import from ".components/Button.tsx" { Button }

# Note: useState is auto-injected when using `has` variables

cl {
    has count: int = 0;  # Automatically creates React state

    def app() -> JsxElement {
        useEffect(lambda -> None {
            console.log("Count: ", count);
        }, [count]);
        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda -> None {setCount(count + 1);}}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda -> None {setCount(0);}}
                    variant="secondary"
                />
            </div>
        </div>;
    }
}
```

**Import syntax:**

- Use quotes around the import path: `".components/Button.tsx"`
- Include the `.tsx` extension in the import path
- Import named exports: `{ Button }`

## Customizing TypeScript Configuration

While TypeScript works out of the box, you can customize the generated `tsconfig.json` via `jac.toml`:

```toml
# Override compiler options
[plugins.client.ts.compilerOptions]
target = "ES2022"
strict = false
noUnusedLocals = false

# Custom include/exclude paths
[plugins.client.ts]
include = ["components/**/*", "lib/**/*"]
exclude = ["node_modules", "dist", "tests"]
```

**Note**: If you provide your own `tsconfig.json` file in the project root, it will be used as-is instead of generating one.

For more details, see [Custom Configuration](./advance/custom-config.md).

## Troubleshooting

### Import resolution issues

- Make sure the import path uses quotes: `".components/Button.tsx"`
- Include the `.tsx` extension in the import path
- Verify the file exists in the expected location

## Example Project

See the complete working example in:

```
jac-client/jac_client/examples/ts-support/
```

Happy coding with TypeScript and Jac!
