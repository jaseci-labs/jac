# all-in-one

A Jac client-side application with React support, Tailwind CSS, and shadcn/ui.

## Project Structure

```
all-in-one/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
├── lib/                   # Utility functions (shadcn/ui)
│   └── utils.ts          # cn() utility for className merging
├── utils/                 # Application utilities
├── hooks/                 # Custom React hooks
├── assets/               # Static assets (images, fonts, etc.)
└── .jac/                 # Build output (generated)
```

## Features

- **React** with TypeScript support
- **Tailwind CSS** for styling
- **shadcn/ui** components with path aliases
- **Custom path aliases** configured in `jac.toml`

## Getting Started

Start the development server:

```bash
jac start main.jac
```

## Path Aliases

This example demonstrates custom path alias configuration for shadcn/ui:

```toml
[plugins.client.vite.resolve.alias]
"@components" = "./components"
"@lib" = "./lib"
"@utils" = "./utils"
"@hooks" = "./hooks"
```

These aliases allow you to import using clean paths:

```typescript
import { cn } from "@lib/utils"
import { Button } from "@components/button"
```

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

Or use TypeScript/React components with the alias:

```typescript
import { Button } from "@components/button"
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```

## Shadcn/ui

This example is fully configured with shadcn/ui:

### Dependencies

- `class-variance-authority` - For component variants
- `clsx` - For conditional className
- `tailwind-merge` - For merging Tailwind classes
- `lucide-react` - Icon library

### Setup Files

- `components.json` - shadcn/ui configuration file
- `lib/utils.ts` - Provides the `cn()` utility function for merging class names
- `components/ui/` - Directory containing shadcn UI components
- `styles.css` - Includes shadcn/ui CSS variables for theming

### Example Components

- `components/ui/button.tsx` - Button component with variants
- `components/ui/card.tsx` - Card component with header, content, footer
- `components/ShadcnExample.jac` - Example usage of shadcn UI components

### Using shadcn UI Components

Import and use shadcn UI components in your Jac files:

```jac
cl import from "@components/ui/button" { Button }
cl import from "@components/ui/card" {
    Card,
    CardHeader,
    CardTitle,
    CardContent
}

cl {
    def MyComponent() -> any {
        return <Card>
            <CardHeader>
                <CardTitle>Hello shadcn/ui</CardTitle>
            </CardHeader>
            <CardContent>
                <Button variant="default">Click me</Button>
            </CardContent>
        </Card>;
    }
}
```

### Adding More shadcn Components

You can add more shadcn UI components by:

1. Using the shadcn CLI: `npx shadcn@latest add [component-name]`
2. Or manually copying components from [shadcn/ui](https://ui.shadcn.com/docs/components)

The `components.json` file is already configured with the correct aliases.
