---
name: jac-cl-styling
description: Tailwind styling patterns in Jac - conditional classes, cn() utility with clsx+tailwind-merge, semantic color tokens. Load when writing dynamic or theme-aware styles.
---

## Conditional Classes

Ternary is Python-style (`A if cond else B`). String concatenation for dynamic classes:

```jac
def:pub TabButton(active: bool, children: any) -> JsxElement {
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
