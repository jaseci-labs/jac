# Styling & Customization

See [customization.md](../customization.md) for theming, CSS variables, and adding custom colors.

## Contents

- Semantic colors
- Built-in variants first
- className for layout only
- No space-x-*/ space-y-*
- Use physical CSS properties (pt/pb not py)
- Prefer size-*over w-* h-* when equal
- Prefer truncate shorthand
- No manual dark: color overrides
- Use cn() for conditional classes
- No manual z-index on overlay components

---

## Semantic colors

**Incorrect:**

```jac
<div className="bg-blue-500 text-white">
    <p className="text-gray-600">Secondary text</p>
</div>
```

**Correct:**

```jac
<div className="bg-primary text-primary-foreground">
    <p className="text-muted-foreground">Secondary text</p>
</div>
```

---

## No raw color values for status/state indicators

Use Badge variants, semantic tokens like `text-destructive`, or CSS variables — never raw Tailwind colors.

**Incorrect:**

```jac
<span className="text-emerald-600">+20.1%</span>
<span className="text-red-600">-3.2%</span>
```

**Correct:**

```jac
<Badge variant="secondary">+20.1%</Badge>
<span className="text-destructive">-3.2%</span>
```

---

## Built-in variants first

**Incorrect:**

```jac
<Button className="border border-input bg-transparent hover:bg-accent">Click me</Button>
```

**Correct:**

```jac
<Button variant="outline">Click me</Button>
```

---

## className for layout only

Use `className` for layout (e.g. `max-w-md`, `mx-auto`, `mt-4`), **not** for overriding component colors or typography.

**Incorrect:**

```jac
<Card className="bg-blue-100 text-blue-900 font-bold">
    <CardContent>Dashboard</CardContent>
</Card>
```

**Correct:**

```jac
<Card className="max-w-md mx-auto">
    <CardContent>Dashboard</CardContent>
</Card>
```

---

## No space-x-*/ space-y-*

Use `gap-*` instead. `space-y-4` → `flex flex-col gap-4`. `space-x-2` → `flex gap-2`.

```jac
<div className="flex flex-col gap-4">
    <Input />
    <Input />
    <Button>Submit</Button>
</div>
```

---

## Use physical CSS properties

Use `pt-4 pb-4` instead of `py-4`. This ensures `pt-0` overrides cleanly with `twMerge`.

**Incorrect:**

```jac
<div className="py-4 px-6">Content</div>
```

**Correct:**

```jac
<div className="pt-4 pb-4 pl-6 pr-6">Content</div>
```

---

## Prefer size-*over w-* h-* when equal

`size-10` not `w-10 h-10`. Applies to icons, avatars, skeletons, etc.

---

## Prefer truncate shorthand

`truncate` not `overflow-hidden text-ellipsis whitespace-nowrap`.

---

## No manual dark: color overrides

Use semantic tokens — they handle light/dark via CSS variables. `bg-background text-foreground` not `bg-white dark:bg-gray-950`.

---

## Use cn() for conditional classes

Import from `lib/utils.cl.jac`. Use for conditional or merged class names.

**Incorrect:**

```jac
className = "flex items-center " + (isActive and "bg-primary text-primary-foreground" or "bg-muted");
```

**Correct:**

```jac
cl import from ...lib.utils { cn }

className = cn("flex items-center", isActive and "bg-primary text-primary-foreground" or "bg-muted");
```

---

## No manual z-index on overlay components

`Dialog`, `Sheet`, `Drawer`, `AlertDialog`, `DropdownMenu`, `Popover`, `Tooltip`, `HoverCard` handle their own stacking. Never add `z-50` or `z-[999]`.
