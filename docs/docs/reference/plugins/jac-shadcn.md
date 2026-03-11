# jac-shadcn Reference

jac-shadcn is a Jac CLI plugin that brings [shadcn/ui](https://ui.shadcn.com)-style components to Jac projects. Instead of installing a component library as a dependency, jac-shadcn fetches pre-built, themed UI components from a remote registry and copies them directly into your project -- you own the code and can customize it freely.

It integrates with the Jac CLI (`jac add`, `jac remove`), manages peer dependencies automatically, and works with jac-client's `.cl.jac` compilation pipeline out of the box.

---

## Installation

```bash
pip install jac-shadcn
```

Verify the plugin is registered:

```bash
jac add --help    # should show --shadcn flag
jac remove --help # should show --shadcn flag
```

!!! note "Prerequisite"
    jac-shadcn requires `jac-client` to be installed, since components are `.cl.jac` files compiled by the client pipeline.

---

## Project Setup

### Create a New Project

The fastest way to start is with the jac-shadcn project template:

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack' myapp
cd myapp
jac install
```

This scaffolds a project with:

- Tailwind v4 configuration
- CSS variables for theming (oklch color space)
- `lib/utils.cl.jac` with the `cn()` utility
- Pre-configured `jac.toml` with `[jac-shadcn]` section

### Create with Custom Theme

Pass theme options as query parameters to the template URL:

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack?style=mira&baseColor=stone&theme=emerald&font=outfit&radius=none' myapp
```

### Project Structure

After setup and adding some components, your project looks like:

```
myapp/
├── jac.toml              # Project config with [jac-shadcn] section
├── main.jac              # Entry point
├── global.css            # Tailwind + CSS variables for theming
├── lib/
│   └── utils.cl.jac      # cn() utility (clsx + tailwind-merge)
└── components/
    └── ui/
        ├── button.cl.jac
        ├── card.cl.jac
        └── dialog.cl.jac
```

---

## Adding Components

Use `jac add --shadcn` to fetch components from the registry:

```bash
jac add --shadcn button card dialog
```

This will:

1. Fetch style-resolved components from the registry
2. Automatically install peer dependencies (e.g., `dialog` pulls in `button` if missing)
3. Write `.cl.jac` files to `components/ui/`
4. Update `[dependencies.npm]` in `jac.toml` with required npm packages
5. Create `lib/utils.cl.jac` with the `cn()` utility if it doesn't exist

### Peer Dependency Resolution

Components can depend on other components. When you add `dialog`, jac-shadcn checks the registry for its `peerComponents` and automatically adds any that are missing from your project. This is a BFS traversal, so transitive dependencies are resolved too.

```bash
# If dialog depends on button, and button is not installed:
jac add --shadcn dialog
# Both dialog.cl.jac AND button.cl.jac are installed
```

---

## Removing Components

```bash
jac remove --shadcn button dialog
```

This deletes the `.cl.jac` files from `components/ui/`. npm dependencies in `jac.toml` are not removed automatically -- clean them up manually if needed.

---

## Using Components

Import components from `components/ui/` and use them like any React component:

```jac
cl import from ".components.ui.button" { Button }

cl {
    def:pub MyPage() -> JsxElement {
        return <div>
            <Button variant="outline">Click me</Button>
        </div>;
    }
}
```

### Combining Multiple Components

```jac
cl import from ".components.ui.button" { Button }
cl import from ".components.ui.card" { Card, CardHeader, CardTitle, CardContent }
cl import from ".components.ui.input" { Input }

cl {
    def:pub LoginForm() -> JsxElement {
        return <Card className="w-[350px]">
            <CardHeader>
                <CardTitle>Login</CardTitle>
            </CardHeader>
            <CardContent>
                <div className="grid gap-4">
                    <Input type="email" placeholder="Email" />
                    <Input type="password" placeholder="Password" />
                    <Button className="w-full">Sign In</Button>
                </div>
            </CardContent>
        </Card>;
    }
}
```

### The cn() Utility

The `cn()` function (auto-generated in `lib/utils.cl.jac`) merges Tailwind classes intelligently using `clsx` + `tailwind-merge`:

```jac
cl import from "..lib.utils" { cn }

cl {
    def:pub MyComponent(variant: str = "default") -> JsxElement {
        className = cn(
            "px-4 py-2 rounded-md font-medium",
            variant == "primary" and "bg-primary text-primary-foreground",
            variant == "outline" and "border border-input bg-background"
        );

        return <button className={className}>Click me</button>;
    }
}
```

---

## Configuration

### jac.toml Settings

The `[jac-shadcn]` section in `jac.toml` controls styling and registry:

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

| Key | Description | Default |
|-----|-------------|---------|
| `style` | Design system style | `nova` |
| `baseColor` | Base neutral color | `neutral` |
| `theme` | Accent/theme color | `neutral` |
| `font` | Font family | `figtree` |
| `radius` | Border radius | `default` |
| `menuAccent` | Menu accent style | `subtle` |
| `menuColor` | Menu color | `default` |
| `registry` | Component registry URL | `https://jac-shadcn.jaseci.org` |

### Theme Options

#### Styles

| Style | Description |
|-------|-------------|
| `nova` | Default modern style |
| `vega` | Alternative style variant |
| `maia` | Alternative style variant |
| `lyra` | Alternative style variant |
| `mira` | Alternative style variant |

#### Base Colors

`neutral`, `stone`, `zinc`, `gray`

#### Theme Colors

`neutral`, `rose`, `emerald`, `blue`, and more

#### Fonts

`inter`, `figtree`, `outfit`, and more

#### Border Radius

`default`, `none`, `sm`, `md`, `lg`

---

## Adding to an Existing jac-client Project

The themed `global.css` (with the correct CSS variables for your chosen style, colors, font, and radius) is generated by the registry during `jac create`. There is currently no standalone command to fetch just the CSS, so the recommended approach is to scaffold a temporary project and copy the theme files over.

### Recommended: Scaffold and Copy

**1. Create a temporary project with your desired theme:**

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack?style=nova&baseColor=stone&theme=blue&font=outfit' temp-shadcn
```

**2. Copy the generated files into your existing project:**

```bash
cp temp-shadcn/global.css ./global.css
cp -r temp-shadcn/lib ./lib
```

**3. Merge the `[jac-shadcn]` and `[dependencies.npm]` sections from `temp-shadcn/jac.toml` into your project's `jac.toml`:**

```toml
# Add these sections to your existing jac.toml

[jac-shadcn]
style = "nova"
baseColor = "stone"
theme = "blue"
font = "outfit"
radius = "default"
menuAccent = "subtle"
menuColor = "default"
registry = "https://jac-shadcn.jaseci.org"

[dependencies.npm]
clsx = "^2.1.1"
tailwind-merge = "^3.5.0"
tw-animate-css = "^1.4.0"
```

**4. Clean up and install:**

```bash
rm -rf temp-shadcn
jac install
jac add --shadcn button card
```

!!! warning "Why not just copy the CSS from the docs?"
    The CSS variables shown in examples use the **default neutral/nova** theme. If you want a different theme (e.g., `blue` + `stone` + `mira`), the oklch color values will be completely different. The registry generates these dynamically based on your chosen options, so always use `jac create` to get the correct values for your theme.

---

## Registry

The component registry at [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) serves components with style-resolved Tailwind classes. The `cn-*` tokens in component source are replaced with concrete Tailwind classes based on your configured style before delivery.

### Registry API

| Endpoint | Description |
|----------|-------------|
| `GET /registry` | Component manifest with peer dependencies and shared npm deps |
| `GET /component/{name}?style={style}` | Resolved component source code |
| `GET /jacpack?style=...&baseColor=...&theme=...&font=...&radius=...` | Project template for `jac create` |

---

## Complete Example

Here's a full example creating a styled landing page with jac-shadcn components:

**1. Create and set up the project:**

```bash
jac create --use 'https://jac-shadcn.jaseci.org/jacpack?style=nova&theme=blue' myapp
cd myapp
jac install
jac add --shadcn button card badge separator
```

**2. Build the page (`main.jac`):**

```jac
cl import from ".components.ui.button" { Button }
cl import from ".components.ui.card" { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
cl import from ".components.ui.badge" { Badge }
cl import from ".components.ui.separator" { Separator }

cl {
    def:pub App() -> JsxElement {
        return <div className="min-h-screen bg-background flex items-center justify-center p-8">
            <Card className="w-[450px]">
                <CardHeader>
                    <div className="flex items-center gap-2">
                        <CardTitle>My Jac App</CardTitle>
                        <Badge variant="secondary">v1.0</Badge>
                    </div>
                    <CardDescription>
                        Built with jac-client and jac-shadcn
                    </CardDescription>
                </CardHeader>
                <Separator />
                <CardContent className="pt-6">
                    <p className="text-muted-foreground">
                        This is a fully themed UI built with shadcn-style
                        components in Jac.
                    </p>
                </CardContent>
                <CardFooter className="flex justify-end gap-2">
                    <Button variant="outline">Cancel</Button>
                    <Button>Get Started</Button>
                </CardFooter>
            </Card>
        </div>;
    }
}
```

**3. Run the dev server:**

```bash
jac start main.jac
```

---

## Running Tests

```bash
jac test tests/test_shadcn.jac
```
