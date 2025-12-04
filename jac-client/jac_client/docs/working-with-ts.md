# Working with TypeScript in Jac

> **⚠️ Warning: TypeScript as Last Resort**
>
> **Always prefer writing code in Jac when possible.** TypeScript support is provided for cases where you need to:
> - Integrate existing TypeScript/React component libraries
> - Reuse complex TypeScript components from other projects
> - Work with teams that require TypeScript for specific components
>
> For new development, Jac provides all the features you need with better integration and simpler syntax. Only use TypeScript when absolutely necessary.

---

This guide explains how to configure and use TypeScript components in your Jac applications when needed.

## Overview

Jac supports importing and using TypeScript (`.ts`, `.tsx`) components alongside Jac code. TypeScript files are automatically processed by Vite during the build process, providing full type safety and modern tooling support.

## Setup

There are two ways to set up TypeScript in your Jac project:

1. **During project creation** - The easiest way, using the CLI
2. **For existing projects** - Manual setup for projects already created

---

## Method 1: Setup During Project Creation

The simplest way to add TypeScript support is during project creation using the `jac create_jac_app` command.

### Steps

1. **Create a new Jac project:**
   ```bash
   jac create_jac_app my-app
   ```

2. **When prompted, answer 'y' for TypeScript support:**
   ```
   Does your project require TypeScript support? (y/n): y
   ```

That's it! The CLI will automatically:
- ✅ Install TypeScript dependencies
- ✅ Create `tsconfig.json` with proper configuration
- ✅ Update `vite.config.js` with TypeScript support
- ✅ Create a `components/` directory with a sample `Button.tsx` component
- ✅ Update `app.jac` with a TypeScript import example
- ✅ Update `README.md` with TypeScript instructions

### What Gets Created

- **TypeScript dependencies** in `package.json`:
  - `typescript`
  - `@types/react`
  - `@types/react-dom`
  - `@vitejs/plugin-react`

- **Configuration files:**
  - `tsconfig.json` - TypeScript configuration
  - Updated `vite.config.js` - With React plugin and TS extensions

- **Sample component:**
  - `components/Button.tsx` - Example TypeScript component

---

## Method 2: Adding TypeScript to an Existing Project

If you already have a Jac project and want to add TypeScript support, follow these steps:

### Step 1: Install TypeScript Dependencies

Add TypeScript and React type definitions to your `package.json`:

```json
{
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "@vitejs/plugin-react": "^4.2.1"
  }
}
```

Then run:
```bash
npm install
```

### Step 2: Create TypeScript Configuration

Create a `tsconfig.json` file in your project root:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    /* Bundler mode */
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",

    /* Linting */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["components/**/*"],
  "exclude": ["node_modules", "dist", "build", "compiled"]
}
```

**Key settings:**
- `jsx: "react-jsx"` - Enables React JSX support
- `noEmit: true` - TypeScript only type-checks, Vite handles compilation
- `moduleResolution: "bundler"` - Optimized for Vite bundling
- `include: ["components/**/*"]` - Include your TypeScript component directories

### Step 3: Update Vite Configuration

Add the React plugin and TypeScript file extensions to your `vite.config.js`:

```javascript
import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";
import react from "@vitejs/plugin-react";  // Add this import

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],  // Add React plugin for TSX support
  root: ".",
  build: {
    rollupOptions: {
      input: "build/main.js",
      output: {
        entryFileNames: "client.[hash].js",
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: "dist",
    emptyOutDir: true,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "compiled/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "compiled/assets"),
    },
    extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],  // Add TS extensions
  },
});
```

**Changes:**
- Import and add `@vitejs/plugin-react` to plugins
- Add `.ts`, `.tsx`, `.mts` to the `resolve.extensions` array

### Step 4: Create Components Directory (Optional)

Create a directory for your TypeScript components:

```bash
mkdir components
```

You're now ready to create and use TypeScript components in your Jac project!

---

## Creating TypeScript Components

### Example: Button Component

Create a TypeScript component in `components/Button.tsx`:

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
cl import from react {useState, useEffect}
cl import from ".components/Button.tsx" { Button }

cl {
    def app() -> any {
        let [count, setCount] = useState(0);
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

## Troubleshooting

### TypeScript file not found during build

Ensure:
- TypeScript files are in the `components/` directory (or path specified in `tsconfig.json` include)
- The import path in Jac includes the `.tsx` extension
- Vite config has TypeScript extensions in `resolve.extensions`

### Type errors in TypeScript components

- Check that `@types/react` and `@types/react-dom` are installed
- Verify `tsconfig.json` has correct `jsx` and `lib` settings
- Ensure React version matches type definitions

### Import resolution issues

- Make sure the import path uses quotes: `".components/Button.tsx"`
- Verify the file exists in the expected location
- Check that the path matches the directory structure

## Example Project

See the complete working example in:
```
jac-client/jac_client/examples/ts-support/
```

This example demonstrates:
- TypeScript component creation
- Importing TypeScript in Jac files
- Full build pipeline configuration
- Type-safe component usage

## Quick Reference

### During Project Creation
```bash
jac create_jac_app my-app
# Answer 'y' when prompted for TypeScript support
```

### For Existing Projects
1. Install dependencies: `npm install typescript @types/react @types/react-dom @vitejs/plugin-react --save-dev`
2. Create `tsconfig.json` (copy from Method 2, Step 2)
3. Update `vite.config.js` (copy from Method 2, Step 3)
4. Create `components/` directory
5. Start creating TypeScript components!

Happy coding with TypeScript and Jac! 🚀
