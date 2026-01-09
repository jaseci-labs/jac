# Plain Starter

A basic Jac client-side application starter with React and TypeScript support.

## Project Structure

```
plain-starter/
├── jac.toml              # Project configuration
├── src/                  # Source files
│   ├── app.jac           # Main application entry
│   └── components/       # Reusable components
│       └── Button.tsx    # Example TypeScript component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac serve src/app.jac
```

## TypeScript Support

Create TypeScript components in `src/components/` and import them in your Jac files:

```jac
cl import from "./components/Button.tsx" {{ Button }}
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```

