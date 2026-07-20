---
name: jac-cl-styling
description: Styling patterns in Jac - Tailwind v4 setup from scratch, conditional classes, cn() utility with clsx+tailwind-merge, semantic color tokens, and auto-scoped .style.css annex files. Load when adding Tailwind to a project or writing dynamic, theme-aware, or component-scoped styles.
---

Everything here applies to any client code - `.cl.jac` files or plain `.jac` components inferred client from their JSX/npm imports (markers like `cl { }` are optional overrides; see `jac-codespaces`).

## Tailwind v4 setup (non-shadcn projects)

jac-shadcn projects ship Tailwind pre-wired - skip this section. For any other client project, three steps:

```bash
jac install --npm --dev tailwindcss @tailwindcss/vite
```

```toml
# jac.toml - registers the Vite plugin
[client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

```css
/* assets/main.css - the whole entry CSS; no tailwind.config.js needed in v4 */
@import "tailwindcss";
```

Then import it once in the app entry: `import "./assets/main.css";` inside the `cl { }` block of `main.jac` (or at the top of the entry `.cl.jac`). Utility classes (`min-h-screen`, `p-8`, `text-3xl`...) now work in any `className`.

## Scoped CSS (`.style.css` annex)

> **jac-shadcn projects: `.style.css` is an anti-pattern.**
> jac-shadcn components resolve styles through `cn()` + Tailwind utilities. Adding a
> `.style.css` annex fights that system and creates specificity conflicts.
> Use `cn()` with Tailwind utility classes (see below) instead.
> `cn()`, semantic tokens (`text-muted-foreground`, `bg-card`, `border`), and conditional
> Tailwind classes from this skill ARE correct in shadcn projects - only the separate
> scoped CSS file approach is wrong.

For plain (non-Tailwind) component CSS, write a `.style.css` file with the
**same base name** as the component. Its classes are auto-scoped to that
module -- no import, no global collisions. The compiler hashes each declared
class and rewrites the matching `className` literals to agree.

```jac
# Card.cl.jac
def:pub Card(title: str) -> JsxElement {
    return <div className="card">
        <h2 className="card-title">{title}</h2>
    </div>;
}
```

```css
/* Card.style.css -- paired by base name; do NOT import it */
.card { padding: 1rem; border: 1px solid #ccc; }
.card-title { font-weight: 600; }

/* :global(...) opts out of scoping (resets, element/global targets) */
:global(body) { margin: 0; }
```

`className="card"` compiles to `className="card-1419142b"` and the CSS
selector is hashed to match; another component can declare its own `.card`
without conflict.

Rules:

- **Base name must match exactly:** `Card.cl.jac` <-> `Card.style.css`. No `import` -- the compiler pairs and injects `import "./Card.css";` itself.
- **Only declared classes are rewritten.** Undeclared tokens (Tailwind utilities, shadcn classes) pass through untouched, so you can mix scoped + utility classes in one `className`.
- **`:global(...)`** keeps a selector unscoped -- use it for resets, element selectors, or targeting third-party classes.
- **Scoped vs global:** use `.style.css` for component-specific classes; use a plain shared `import "./global.css";` (or Tailwind) for app-wide styles.
- **Tailwind projects: no `*` reset in `global.css`.** After `@import "tailwindcss";`, add only `:root` variable blocks and `@theme inline` registrations. A `* { margin: 0; padding: 0; box-sizing: border-box }` reset conflicts with Preflight and collapses spacing utilities. Plain-CSS-only projects (no `@import "tailwindcss"`) may still use resets.

## Conditional Classes

Ternary is Python-style (`A if cond else B`). String concatenation for dynamic classes:

```jac
def:pub TabButton(active: bool, children: any = None) -> JsxElement {
    tab_cls = "border-primary text-foreground" if active else "border-transparent text-muted-foreground";
    return <button className={"px-2.5 py-1.5 border-b-2 " + tab_cls}>{children}</button>;
}
```

## cn() Utility (clsx + tailwind-merge)

Handles conditional + merged Tailwind classes. Write in Jac - no TypeScript needed:

```jac
import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

# Variadic positional args (the clsx / tailwind-merge convention, and how
# jac-shadcn components call cn) - NOT a single list argument.
def:pub cn(*inputs: any) -> any {
    return twMerge(clsx(inputs));
}
```

Required in `jac.toml`: `clsx = "*"` and `tailwind-merge = "*"` under `[dependencies.npm]`.

> **jac-shadcn projects**: `lib/utils.cl.jac` already exports `cn()` - use `import from .lib.utils { cn }`. Don't recreate it and don't add these packages to jac.toml (pre-installed).

Usage (import `cn` from `lib/utils.cl.jac`, then pass each class as a separate argument):

```
import from ...lib.utils { cn }

className={cn("base-class", props.className, "extra" if condition else "")}
```

## Semantic Color Tokens

Use semantic tokens - they adapt to themes and dark mode. Avoid hardcoded hex/gray values:

```
CORRECT:  text-foreground  bg-background  border-border
          text-muted-foreground  bg-muted
          text-primary  bg-primary  text-primary-foreground
          text-destructive  bg-destructive/10

AVOID:    text-gray-900  bg-white  border-gray-200  #3b82f6
```

## See also

- `jac-cl-components` - component shape, `className` prop, event handlers
- `jac-shadcn-components` - jac-shadcn import paths, `cn()` usage, theming with `jac retheme`
