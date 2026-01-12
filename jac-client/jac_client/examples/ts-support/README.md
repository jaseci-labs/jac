# ts-support

This example demonstrates how to use TypeScript components in a Jac application.

## Features

- TypeScript component (`Button.tsx`) with type safety
- Import TypeScript components in Jac files
- Vite handles TypeScript compilation and bundling
- Full type checking and IntelliSense support

## Project Structure

```
ts-support/
├── app.jac              # Main Jac application file
├── components/          # TypeScript components
│   └── Button.tsx      # TypeScript Button component
├── package.json         # Dependencies including TypeScript
├── tsconfig.json        # TypeScript configuration
└── vite.config.js       # Vite configuration with React plugin
```

## Setup

1. Install dependencies:

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

### TypeScript Component

The `Button.tsx` component is a fully typed React component:

```typescript
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
  // Component implementation
};
```

### Importing in Jac

Import the TypeScript component in your Jac file:

```jac
cl import from .components.Button { Button }
```

The Jac compiler will:

1. Preserve the import statement in the compiled JavaScript
2. Copy the TypeScript file to the `compiled/` directory
3. Vite will process and bundle the TypeScript file during build

### Using the Component

Use the TypeScript component in your Jac code:

```jac
<Button
    label="Increment"
    onClick={lambda -> None {setCount(count + 1);}}
    variant="primary"
/>
```

## TypeScript Configuration

The `tsconfig.json` is configured for:

- React JSX support
- Modern ES2020 target
- Strict type checking
- Module resolution for bundlers

## Build Process

1. Jac files are compiled to JavaScript in `compiled/`
2. TypeScript files are copied to `compiled/` maintaining structure
3. Babel transpiles JavaScript from `compiled/` to `build/`
4. Vite bundles everything from `build/` to `dist/`, processing TypeScript files

## Benefits

- **Type Safety**: Catch errors at compile time
- **IntelliSense**: Full IDE support for TypeScript components
- **Reusability**: Share TypeScript components across Jac applications
- **Modern Tooling**: Leverage the full TypeScript ecosystem

Happy coding with Jac and TypeScript!
