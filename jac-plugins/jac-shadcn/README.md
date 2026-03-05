# jac-shadcn

A Jac CLI plugin that brings [shadcn/ui](https://ui.shadcn.com)-style components to Jac projects. Fetch pre-built, themed UI components from the [jac-shadcn registry](https://jac-shadcn.jaseci.org) and install them directly into your project.

## Installation

```bash
pip install jac-shadcn
```

Verify it's registered:

```bash
jac add --help  # should show --shadcn flag
```

## Quick Start

### Create a new project

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack' myapp
cd myapp
jac install
```

This scaffolds a project with Tailwind v4, theming CSS variables, and the `lib/utils.cl.jac` utility.

### Create with custom theme

Pass theme options as query parameters:

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack?style=mira&baseColor=stone&theme=emerald&font=outfit&radius=none' myapp
```

Available options:

| Option       | Values                                     | Default    |
|-------------|-------------------------------------------|------------|
| `style`     | `nova`, `vega`, `maia`, `lyra`, `mira`    | `nova`     |
| `baseColor` | `neutral`, `stone`, `zinc`, `gray`         | `neutral`  |
| `theme`     | `neutral`, `rose`, `emerald`, `blue`, etc. | `neutral`  |
| `font`      | `inter`, `figtree`, `outfit`, etc.         | `figtree`  |
| `radius`    | `default`, `none`, `sm`, `md`, `lg`        | `default`  |
| `menuAccent`| `subtle`, `bold`                           | `subtle`   |
| `menuColor` | `default`, `primary`                       | `default`  |

## Usage

### Add components

```bash
jac add --shadcn button card dialog
```

This will:

1. Fetch resolved components from the registry
2. Auto-install peer dependencies (e.g., `dialog` pulls in `button` if missing)
3. Write `.cl.jac` files to `components/ui/`
4. Update `[dependencies.npm]` in `jac.toml`
5. Create `lib/utils.cl.jac` with the `cn()` utility if it doesn't exist

### Remove components

```bash
jac remove --shadcn button dialog
```

Deletes the component files from `components/ui/`.

### Use components in your code

```jac
cl import from "./components/ui/button" { Button }

cl {
    def:pub MyPage() -> JsxElement {
        return <div>
            <Button variant="outline">Click me</Button>
        </div>;
    }
}
```

## Adding to an Existing Project

If you have an existing `jac-client` project, add the `[jac-shadcn]` section to your `jac.toml`:

```toml
[jac-shadcn]
style = "nova"
baseColor = "neutral"
theme = "neutral"
font = "figtree"
radius = "default"
menuAccent = "subtle"
menuColor = "default"
registry = "https://jac-shadcn.jaseci.org"
```

Then add the required npm dependencies:

```toml
[dependencies.npm]
clsx = "^2.1.1"
tailwind-merge = "^3.5.0"
tw-animate-css = "^1.4.0"
```

Make sure your `global.css` includes Tailwind and the shadcn CSS variables:

```css
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:is(.dark *));

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --radius: 0.625rem;
  --font-sans: 'Figtree Variable', sans-serif;
}
```

Then install components:

```bash
jac install
jac add --shadcn button card
```

## Project Structure

After setup, your project will look like:

```
myapp/
├── jac.toml              # Project config with [jac-shadcn] section
├── main.jac
├── global.css            # Tailwind + CSS variables
├── lib/
│   └── utils.cl.jac      # cn() utility
└── components/
    └── ui/
        ├── button.cl.jac
        ├── card.cl.jac
        └── dialog.cl.jac
```

## Running Tests

```bash
jac test tests/test_shadcn.jac
```

## Registry

The component registry is hosted at [https://jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org). Components are served with style-resolved Tailwind classes -the `cn-*` tokens are replaced with concrete classes based on your chosen style before delivery.

### Registry API

```
GET /registry          → Component manifest with peer deps and shared npm deps
GET /component/{name}?style={style}  → Resolved component source
GET /jacpack?style=...               → Project template for jac create
```

## License

MIT
