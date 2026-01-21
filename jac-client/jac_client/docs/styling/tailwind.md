# Tailwind CSS

Utility-first CSS framework for rapid UI development in Jac applications.

## Overview

Tailwind CSS provides low-level utility classes that you can compose to build custom designs. This approach is perfect for:

- Rapid UI development
- Consistent design systems
- Responsive designs
- Modern, utility-based styling

## Example

See the complete working example: [`examples/css-styling/tailwind-example/`](../../examples/css-styling/tailwind-example/)

## Quick Start

There are two approaches to configuring Tailwind CSS in Jac projects:

### Option A: Tailwind v4 (Vite Plugin)

For Tailwind CSS v4, use the native Vite plugin approach:

```bash
jac add --npm -d tailwindcss @tailwindcss/vite
```

Configure in `jac.toml`:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

### Option B: Tailwind v3 (PostCSS - Recommended for most projects)

For Tailwind CSS v3, use the PostCSS approach with `[plugins.client.configs]`:

```bash
jac add --npm -d tailwindcss autoprefixer postcss
```

Configure in `jac.toml`:

```toml
[plugins.client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[plugins.client.configs.tailwind]
content = ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"]
plugins = []

[plugins.client.configs.tailwind.theme.extend.fontFamily]
sans = ["Inter", "system-ui", "-apple-system", "sans-serif"]
```

This generates `postcss.config.js` and `tailwind.config.js` automatically in `.jac/client/configs/`. No standalone config files needed in your project root!

### 3. Add Tailwind Directives

Create `global.css`:

```css
@import "tailwindcss";
```

### 4. Import CSS in Jac

```jac
# Pages
cl import from react { useEffect }
cl import ".global.css";

# Note: useState is auto-injected when using `has` variables

cl {
    def app() -> any {
        return <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
            <h1 className="text-3xl font-bold">Hello, Tailwind!</h1>
        </div>;
    }
}
```

## Using Utility Classes

### Spacing

```jac
<div className="p-4 m-2 gap-4">
    {/* padding: 1rem, margin: 0.5rem, gap: 1rem */}
</div>
```

### Colors

```jac
<div className="bg-blue-500 text-white hover:bg-blue-600">
    {/* Blue background, white text, darker blue on hover */}
</div>
```

### Layout

```jac
<div className="flex items-center justify-center">
    {/* Flexbox with centered items */}
</div>
```

### Responsive

```jac
<div className="text-sm md:text-lg lg:text-xl">
    {/* Small on mobile, large on tablet, xl on desktop */}
</div>
```

## Dynamic Classes

Combine static and dynamic classes:

```jac
countColorClass = "text-gray-800" if count == 0 else ("text-green-600" if count > 0 else "text-red-600");

return <div className={"text-6xl font-bold " + countColorClass + " transition-colors duration-300"}>
    {count}
</div>;
```

## Common Utility Patterns

### Buttons

```jac
<button className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded">
    Click Me
</button>
```

### Cards

```jac
<div className="bg-white rounded-lg shadow-lg p-6">
    <h2 className="text-2xl font-bold mb-4">Card Title</h2>
    <p className="text-gray-600">Card content</p>
</div>
```

### Flexbox Layouts

```jac
<div className="flex flex-col md:flex-row gap-4">
    <div className="flex-1">Column 1</div>
    <div className="flex-1">Column 2</div>
</div>
```

### Grid Layouts

```jac
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <div>Item 1</div>
    <div>Item 2</div>
    <div>Item 3</div>
</div>
```

## Best Practices

### 1. Use Responsive Prefixes

Design mobile-first with responsive breakpoints:

```jac
<div className="text-sm md:text-base lg:text-lg">
    Responsive text
</div>
```

### 2. Combine Utilities

Chain multiple utilities for complex styles:

```jac
<button className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-3 px-6 rounded-lg shadow-lg transition-all duration-200 transform hover:scale-105">
    Button
</button>
```

### 3. Use Hover/Focus States

Leverage pseudo-class variants:

```jac
<button className="bg-blue-500 hover:bg-blue-600 focus:ring-2 focus:ring-blue-300">
    Interactive Button
</button>
```

### 4. Leverage Transitions

Add smooth transitions:

```jac
<div className="transition-all duration-200 hover:scale-105">
    Hoverable element
</div>
```

### 5. Use Arbitrary Values

For custom values:

```jac
<div className="w-[500px] h-[300px] bg-[#1da1f2]">
    Custom dimensions and color
</div>
```

## Configuration

### jac.toml Configuration

Tailwind is configured through `jac.toml` in your project root.

#### For Tailwind v4 (Vite Plugin)

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[dependencies.npm.dev]
tailwindcss = "^4.0.0"
"@tailwindcss/vite" = "^4.0.0"
```

#### For Tailwind v3 (PostCSS)

```toml
[plugins.client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[plugins.client.configs.tailwind]
content = ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"]
plugins = []

[dependencies.npm.dev]
tailwindcss = "^3.4.0"
autoprefixer = "^10.4.0"
postcss = "^8.4.0"
```

The config files are automatically generated in `.jac/client/configs/`. You don't need to create or edit them manually.

### Tailwind Theme Customization

Customize Tailwind's theme directly in `jac.toml`:

```toml
[plugins.client.configs.tailwind.theme.extend.colors]
brand = "#your-color"
primary = "#3490dc"

[plugins.client.configs.tailwind.theme.extend.spacing]
"128" = "32rem"

[plugins.client.configs.tailwind.theme.extend.fontFamily]
sans = ["Inter", "system-ui", "sans-serif"]
```

## Advantages

- **Rapid development** with utility classes
- **Consistent design system**
- **Responsive by default**
- **Small bundle size** (unused classes are purged)
- **Great documentation** and ecosystem
- **Highly customizable**

## Limitations

- **Can get verbose** with many classes
- **Learning curve** for utility-first approach
- **Less semantic** than component-based CSS
- **Requires build step**
- **HTML can get cluttered**

## When to Use

Choose Tailwind CSS when:

- You want to build UIs quickly
- You prefer utility classes over custom CSS
- You need a consistent design system
- You're building modern, responsive designs
- You want a small bundle size
- You prefer configuration over writing CSS

## Purging Unused Classes

Tailwind automatically removes unused classes in production builds, keeping bundle size small. No configuration needed with Vite plugin.

## Customization

### Custom Colors

```toml
# jac.toml
[plugins.client.configs.tailwind.theme.extend.colors]
brand-blue = "#1e40af"
brand-purple = "#7c3aed"
```

### Custom Spacing

```toml
# jac.toml
[plugins.client.configs.tailwind.theme.extend.spacing]
"18" = "4.5rem"
"88" = "22rem"
```

## Next Steps

- Explore [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- Check out UnoCSS for similar utility-first approach (coming soon)
- Learn about CSS Modules for component-scoped styles (coming soon)
- See [Pure CSS](./pure-css.md) for traditional CSS approach

## Resources

- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Tailwind UI Components](https://tailwindui.com/)
- [Tailwind Play](https://play.tailwindcss.com/) - Online playground
