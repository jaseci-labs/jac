# shadcn/ui

Beautifully designed components built with Radix UI and Tailwind CSS for Jac applications.

## Overview

shadcn/ui is a collection of re-usable components built using Radix UI and Tailwind CSS. Unlike traditional component libraries, shadcn/ui components are copied into your project, giving you full control over the code. This approach is perfect for:

- Customizable, accessible components
- Full control over component code
- Modern design system
- TypeScript support
- Tailwind CSS integration

## Example

See the complete working example: [`examples/all-in-one/`](../../examples/all-in-one/)

## Quick Start

### 1. Install Dependencies

shadcn/ui requires several dependencies. Add them to your `jac.toml`:

```toml
[dependencies.npm]
class-variance-authority = "latest"
clsx = "latest"
tailwind-merge = "latest"
lucide-react = "latest"
```

Or install via npm:

```bash
npm install class-variance-authority clsx tailwind-merge lucide-react
```

### 2. Configure Path Aliases

Add path aliases to your `jac.toml` for clean imports:

```toml
[plugins.client.vite.resolve.alias]
"@components" = "./components"
"@lib" = "./lib"
"@utils" = "./utils"
"@hooks" = "./hooks"
```

### 3. Create Utility Function

Create `lib/utils.ts` with the `cn()` utility function:

```typescript
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

/**
 * Utility function to merge Tailwind CSS classes with clsx and tailwind-merge
 * This is the standard shadcn/ui utility function for className handling
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### 4. Create components.json

Create `components.json` in your project root:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "styles.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@components",
    "utils": "@lib/utils",
    "ui": "@components/ui",
    "lib": "@lib",
    "hooks": "@hooks"
  }
}
```

### 5. Add CSS Variables

Add shadcn/ui CSS variables to your `styles.css`:

```css
@import "tailwindcss";

:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --card: 0 0% 100%;
  --card-foreground: 222.2 84% 4.9%;
  --popover: 0 0% 100%;
  --popover-foreground: 222.2 84% 4.9%;
  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;
  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;
  --muted: 210 40% 96.1%;
  --muted-foreground: 215.4 16.3% 46.9%;
  --accent: 210 40% 96.1%;
  --accent-foreground: 222.2 47.4% 11.2%;
  --destructive: 0 84.2% 60.2%;
  --destructive-foreground: 210 40% 98%;
  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  --ring: 222.2 84% 4.9%;
  --radius: 0.5rem;
}

.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --card: 222.2 84% 4.9%;
  --card-foreground: 210 40% 98%;
  --popover: 222.2 84% 4.9%;
  --popover-foreground: 210 40% 98%;
  --primary: 210 40% 98%;
  --primary-foreground: 222.2 47.4% 11.2%;
  --secondary: 217.2 32.6% 17.5%;
  --secondary-foreground: 210 40% 98%;
  --muted: 217.2 32.6% 17.5%;
  --muted-foreground: 215 20.2% 65.1%;
  --accent: 217.2 32.6% 17.5%;
  --accent-foreground: 210 40% 98%;
  --destructive: 0 62.8% 30.6%;
  --destructive-foreground: 210 40% 98%;
  --border: 217.2 32.6% 17.5%;
  --input: 217.2 32.6% 17.5%;
  --ring: 212.7 26.8% 83.9%;
}
```

### 6. Install Tailwind CSS

Ensure Tailwind CSS is configured in your `jac.toml`:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

## Adding Components

### Using shadcn CLI

The easiest way to add components is using the shadcn CLI:

```bash
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add dialog
```

The CLI will automatically:

- Copy the component to `components/ui/`
- Update imports to use your configured aliases
- Install any required dependencies

### Manual Installation

You can also manually copy components from [shadcn/ui](https://ui.shadcn.com/docs/components) and place them in `components/ui/`.

## Using Components in Jac

### Import Components

Import shadcn/ui components in your Jac files:

```jac
# Import React hooks
cl import from react { useState }

# Import shadcn UI components
cl import from "@components/ui/button" { Button }
cl import from "@components/ui/card" {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}

cl {
    def MyComponent() -> any {
        has count: int = 0;

        def handleIncrement() {
            count = count + 1;
        }

        return <Card>
            <CardHeader>
                <CardTitle>Counter</CardTitle>
                <CardDescription>
                    A simple counter example using shadcn/ui
                </CardDescription>
            </CardHeader>
            <CardContent>
                <p style={{"fontSize": "1.5rem", "textAlign": "center"}}>
                    Count: {count}
                </p>
                <Button variant="default" onClick={handleIncrement}>
                    Increment
                </Button>
            </CardContent>
        </Card>;
    }
}
```

## Key Features

### Component Variants

shadcn/ui components use `class-variance-authority` for variant management:

```jac
cl import from "@components/ui/button" { Button }

cl {
    def ButtonVariants() -> any {
        return <div style={{"display": "flex", "gap": "1rem", "flexWrap": "wrap"}}>
            <Button variant="default">Default</Button>
            <Button variant="destructive">Destructive</Button>
            <Button variant="outline">Outline</Button>
            <Button variant="secondary">Secondary</Button>
            <Button variant="ghost">Ghost</Button>
            <Button variant="link">Link</Button>
        </div>;
    }
}
```

### Component Sizes

Many components support size variants:

```jac
cl import from "@components/ui/button" { Button }

cl {
    def ButtonSizes() -> any {
        return <div style={{"display": "flex", "gap": "1rem", "alignItems": "center"}}>
            <Button size="sm">Small</Button>
            <Button size="default">Default</Button>
            <Button size="lg">Large</Button>
            <Button size="icon">🚀</Button>
        </div>;
    }
}
```

### Composing Components

shadcn/ui components are designed to be composed:

```jac
cl import from "@components/ui/card" {
    Card,
    CardHeader,
    CardTitle,
    CardContent
}
cl import from "@components/ui/button" { Button }

cl {
    def Dashboard() -> any {
        return <div style={{"display": "grid", "gridTemplateColumns": "repeat(3, 1fr)", "gap": "1rem"}}>
            <Card>
                <CardHeader>
                    <CardTitle>Card 1</CardTitle>
                </CardHeader>
                <CardContent>
                    <Button>Action</Button>
                </CardContent>
            </Card>
            <Card>
                <CardHeader>
                    <CardTitle>Card 2</CardTitle>
                </CardHeader>
                <CardContent>
                    <Button variant="secondary">Action</Button>
                </CardContent>
            </Card>
            <Card>
                <CardHeader>
                    <CardTitle>Card 3</CardTitle>
                </CardHeader>
                <CardContent>
                    <Button variant="outline">Action</Button>
                </CardContent>
            </Card>
        </div>;
    }
}
```

## Available Components

shadcn/ui provides a comprehensive set of components:

### Form Components

- Button
- Input
- Textarea
- Select
- Checkbox
- Radio Group
- Switch
- Slider
- Label
- Form

### Layout Components

- Card
- Separator
- Aspect Ratio
- Container
- Grid

### Overlay Components

- Dialog
- Alert Dialog
- Sheet
- Popover
- Tooltip
- Hover Card
- Context Menu
- Dropdown Menu

### Data Display

- Table
- Data Table
- Avatar
- Badge
- Progress
- Skeleton
- Tabs
- Accordion
- Carousel

### Navigation

- Navigation Menu
- Breadcrumb
- Pagination
- Menubar

### Feedback

- Alert
- Toast
- Sonner
- Command Palette

See the complete list at [ui.shadcn.com/docs/components](https://ui.shadcn.com/docs/components)

## Customization

### Theming

Customize colors by modifying CSS variables in `styles.css`:

```css
:root {
  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;
  /* Customize other colors... */
}
```

### Component Customization

Since components are copied into your project, you can modify them directly:

```typescript
// components/ui/button.tsx
const buttonVariants = cva(
  "inline-flex items-center justify-center...",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        // Add your custom variant
        custom: "bg-purple-500 text-white hover:bg-purple-600",
      },
    },
  }
)
```

### Dark Mode

shadcn/ui supports dark mode out of the box. Add the `dark` class to enable:

```jac
cl {
    def App() -> any {
        return <div className="dark">
            {/* Dark mode styles will be applied */}
        </div>;
    }
}
```

## Best Practices

### 1. Use Path Aliases

Always use the configured path aliases for imports:

```jac
# Good
cl import from "@components/ui/button" { Button }

# Avoid
cl import from "../../components/ui/button" { Button }
```

### 2. Compose Components

Build complex UIs by composing simple components:

```jac
cl import from "@components/ui/card" {
    Card,
    CardHeader,
    CardTitle,
    CardContent
}
cl import from "@components/ui/button" { Button }

cl {
    def FeatureCard(title: str, description: str) -> any {
        return <Card>
            <CardHeader>
                <CardTitle>{title}</CardTitle>
            </CardHeader>
            <CardContent>
                <p>{description}</p>
                <Button>Learn More</Button>
            </CardContent>
        </Card>;
    }
}
```

### 3. Customize When Needed

Don't hesitate to modify component code to fit your needs. Components are in your project for a reason!

### 4. Use TypeScript

shadcn/ui components are written in TypeScript and provide excellent type safety:

```typescript
import { Button } from "@components/ui/button"

// TypeScript will catch type errors
<Button variant="invalid" /> // ❌ Type error
<Button variant="default" /> // ✅ Correct
```

### 5. Keep Components Updated

When shadcn/ui releases updates, you can update components manually or use the CLI:

```bash
npx shadcn@latest add button --overwrite
```

## Advantages

- **Full Control**: Components are in your codebase, modify as needed
- **Accessible**: Built on Radix UI primitives with accessibility built-in
- **Customizable**: Easy to theme and modify
- **Type-Safe**: Full TypeScript support
- **Modern**: Built with latest React patterns
- **Lightweight**: Only include what you use
- **No Runtime**: Components compile to regular React components

## Comparison with Other Libraries

| Feature | shadcn/ui | Material-UI | Ant Design |
|---------|-----------|-------------|------------|
| Bundle Size | Small (only what you use) | Large | Large |
| Customization | Full (code in your project) | Theme system | Theme system |
| Accessibility | Excellent (Radix UI) | Excellent | Good |
| TypeScript | Full support | Full support | Full support |
| Learning Curve | Low | Medium | Medium |

## Troubleshooting

### Components Not Found

**Problem**: Import errors for shadcn/ui components.

**Solution**:

1. Verify path aliases in `jac.toml` match `components.json`
2. Ensure components are in `components/ui/` directory
3. Check that TypeScript can resolve the paths

### Styles Not Applied

**Problem**: Components render but styles are missing.

**Solution**:

1. Ensure Tailwind CSS is configured and imported
2. Verify CSS variables are in `styles.css`
3. Check that `@import "tailwindcss"` is in your CSS file

### Type Errors

**Problem**: TypeScript errors when using components.

**Solution**:

1. Ensure `tsconfig.json` includes the component paths
2. Verify imports use the correct path aliases
3. Check that component files have proper TypeScript types

## Resources

- [shadcn/ui Documentation](https://ui.shadcn.com)
- [Radix UI Documentation](https://www.radix-ui.com)
- [Tailwind CSS Documentation](https://tailwindcss.com)
- [Example Project](../../examples/all-in-one/)
- [Tailwind CSS Guide](./tailwind.md)

## Related Documentation

- [Tailwind CSS](./tailwind.md) - Utility-first CSS framework
- [Configuration System](../advance/configuration-overview.md) - Project configuration
- [Path Aliases](../advance/custom-config.md) - Custom path configuration
- [TypeScript Support](../working-with-ts.md) - TypeScript in Jac
