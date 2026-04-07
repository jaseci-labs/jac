# Customization & Theming

Components reference semantic CSS variable tokens. Change the variables to change every component.

## Contents

- How it works (CSS variables → Tailwind utilities → components)
- Color variables and OKLCH format
- Dark mode setup
- Changing the theme
- Adding custom colors (Tailwind v4)
- Border radius
- Customizing components (variants, className, wrappers)

---

## How It Works

1. CSS variables defined in `:root` (light) and `.dark` (dark mode) in `global.css`.
2. Tailwind v4 maps them via `@theme inline`: `--color-primary: var(--primary)` → enables `bg-primary`.
3. Components use these utilities — changing a variable changes all components that reference it.

---

## Color Variables

Every color follows the `name` / `name-foreground` convention. The base variable is for backgrounds, `-foreground` is for text/icons on that background.

| Variable                                     | Purpose                          |
| -------------------------------------------- | -------------------------------- |
| `--background` / `--foreground`              | Page background and default text |
| `--card` / `--card-foreground`               | Card surfaces                    |
| `--primary` / `--primary-foreground`         | Primary buttons and actions      |
| `--secondary` / `--secondary-foreground`     | Secondary actions                |
| `--muted` / `--muted-foreground`             | Muted/disabled states            |
| `--accent` / `--accent-foreground`           | Hover and accent states          |
| `--destructive`                              | Error and destructive actions    |
| `--border`                                   | Default border color             |
| `--input`                                    | Form input borders               |
| `--ring`                                     | Focus ring color                 |
| `--chart-1` through `--chart-5`              | Chart/data visualization         |
| `--sidebar-*`                                | Sidebar-specific colors          |

Colors use OKLCH: `--primary: oklch(0.205 0 0)` where values are lightness (0–1), chroma (0 = gray), and hue (0–360).

---

## Dark Mode

Class-based toggle via `.dark` on the root element and body. The app adds `.dark` in `useEffect`:

```jac
useEffect(lambda -> Any {
    document.documentElement.classList.add("dark");
    document.body.classList.add("dark");
    return;
}, []);
```

Dark mode is configured in `global.css` with `@custom-variant dark (&:is(.dark *))`.

---

## Changing the Theme

Edit CSS variables directly in `global.css`:

```css
:root {
    --primary: oklch(0.852 0.199 91.936);
    --primary-foreground: oklch(0.421 0.095 57.708);
}

.dark {
    --primary: oklch(0.795 0.184 86.047);
    --primary-foreground: oklch(0.421 0.095 57.708);
}
```

Or use the jac-shadcn customizer at `https://jac-shadcn.jaseci.org` to pick a theme visually and export it.

---

## Adding Custom Colors (Tailwind v4)

Add variables to `global.css`. Never create a new CSS file.

```css
/* 1. Define in global.css */
:root {
    --warning: oklch(0.84 0.16 84);
    --warning-foreground: oklch(0.28 0.07 46);
}
.dark {
    --warning: oklch(0.41 0.11 46);
    --warning-foreground: oklch(0.99 0.02 95);
}
```

```css
/* 2. Register with Tailwind v4 (@theme inline) */
@theme inline {
    --color-warning: var(--warning);
    --color-warning-foreground: var(--warning-foreground);
}
```

```jac
# 3. Use in components
<div className="bg-warning text-warning-foreground">Warning</div>
```

---

## Border Radius

`--radius` controls border radius globally. Components derive values from it:

| Tailwind class | Value |
|---------------|-------|
| `rounded-sm` | `calc(var(--radius) - 4px)` |
| `rounded-md` | `calc(var(--radius) - 2px)` |
| `rounded-lg` | `var(--radius)` |
| `rounded-xl` | `calc(var(--radius) + 4px)` |
| `rounded-2xl` | `calc(var(--radius) + 8px)` |

---

## Customizing Components

### 1. Built-in variants

```jac
<Button variant="outline" size="sm">Click</Button>
```

### 2. Tailwind classes via className

```jac
<Card className="max-w-md mx-auto">Content</Card>
```

### 3. Add a new variant

Edit the component source to add a variant via CVA:

```jac
glob _buttonVariants: Any = cva("...", {
    "variants": {
        "variant": {
            "default": "bg-primary text-primary-foreground",
            "outline": "border border-border bg-background",
            "warning": "bg-warning text-warning-foreground hover:bg-warning/90"
        }
    }
});
```

### 4. Wrapper components

Compose jac-shadcn primitives into higher-level components:

```jac
cl {
    def:pub ConfirmDialog(props: Any) -> JsxElement {
        title = props.title or "Confirm";
        description = props.description or "Are you sure?";
        return <AlertDialog>
            <AlertDialogTrigger>{props.trigger}</AlertDialogTrigger>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>{title}</AlertDialogTitle>
                    <AlertDialogDescription>{description}</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction onClick={props.onConfirm}>Confirm</AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>;
    }
}
```
