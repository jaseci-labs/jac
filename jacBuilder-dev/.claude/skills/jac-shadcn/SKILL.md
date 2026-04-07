---
name: jac-shadcn
description: Manages jac-shadcn components and projects — adding, removing, styling, and composing UI in Jac. Provides component docs, usage examples, and Jac-specific patterns. Applies when working with jac-shadcn, cn-* tokens, .cl.jac components, or any project with a [jac-shadcn] section in jac.toml. Also triggers for "jac add --shadcn", "jac remove --shadcn", or "jac create --use jac-shadcn".
user-invocable: false
allowed-tools: Bash(jac add *), Bash(jac remove *), Bash(jac create *)
---

# jac-shadcn

A framework for building UI components and design systems in Jac. Components are added as source code (`.cl.jac` files) to the user's project via the CLI. Components use Radix UI primitives, Tailwind CSS v4, and the `cn()` utility (clsx + tailwind-merge).

> **IMPORTANT:** Run all CLI commands using: `jac add --shadcn`, `jac remove --shadcn`, or `jac create --use jac-shadcn`. The Jac virtual environment must be activated first: `source /home/ahzan/.jacvenv/bin/activate`.

## Principles

1. **Use existing components first.** Check what's available in the registry before writing custom UI.
2. **Compose, don't reinvent.** Settings page = Tabs + Card + form controls. Dashboard = Sidebar + Card + Chart + Table.
3. **Use built-in variants before custom styles.** `variant="outline"`, `size="sm"`, etc.
4. **Use semantic colors.** `bg-primary`, `text-muted-foreground` — never raw values like `bg-blue-500`.
5. **Follow Jac patterns.** No destructuring, `has` = `useState`, `glob` for module-level constants. See [jac-patterns.md](./rules/jac-patterns.md).

## Critical Rules

These rules are **always enforced**. Each links to a file with Incorrect/Correct code pairs.

### Styling & Tailwind → [styling.md](./rules/styling.md)

- **`className` for layout, not styling.** Never override component colors or typography.
- **No `space-x-*` or `space-y-*`.** Use `flex` with `gap-*`. For vertical stacks, `flex flex-col gap-*`.
- **Use `size-*` when width and height are equal.** `size-10` not `w-10 h-10`.
- **Use physical CSS properties.** `pt-4 pb-4` not `py-4` — ensures `pt-0` overrides cleanly with `twMerge`.
- **No manual `dark:` color overrides.** Use semantic tokens (`bg-background`, `text-muted-foreground`).
- **Use `cn()` for conditional classes.** Import from `lib/utils.cl.jac`.
- **No manual `z-index` on overlay components.** Dialog, Sheet, Popover, etc. handle their own stacking.

### Forms & Inputs → [forms.md](./rules/forms.md)

- **Use `Field` + `Label` for form layout.** Never raw `div` with `space-y-*`.
- **Buttons inside inputs use `InputGroup` + `InputGroupAddon`.**
- **Option sets (2–5 choices) use `ToggleGroup`.** Don't loop `Button` with manual active state.

### Component Structure → [composition.md](./rules/composition.md)

- **Items always inside their Group.** `SelectItem` → `SelectGroup`. `DropdownMenuItem` → `DropdownMenuGroup`.
- **Dialog, Sheet, and Drawer always need a Title.** Required for accessibility. Use `className="sr-only"` if visually hidden.
- **Use full Card composition.** `CardHeader`/`CardTitle`/`CardDescription`/`CardContent`/`CardFooter`.
- **`TabsTrigger` must be inside `TabsList`.**
- **`Avatar` always needs `AvatarFallback`.**
- **ButtonGroup uses nested groups for gaps.** Use nested `<ButtonGroup>` for visible gaps between sections, `<ButtonGroupSeparator>` for subtle 1px dividers only.

### Jac Language Patterns → [jac-patterns.md](./rules/jac-patterns.md)

- **No tuple unpacking.** `a, b = func()` is invalid.
- **No nested `def` inside `def`.** Define all helpers at module level.
- **No JSX comments.** Remove all `{/* */}` from JSX return blocks.
- **`True`/`False`/`None` capitalized.** Python-style.
- **`has` = `useState`.** `has theme: str = "light"` → `const [theme, setTheme] = useState("light")`.
- **`glob` for module-level constants.** Not `const`.
- **No `forwardRef`.** Apply styles directly to Radix triggers.

### Icons → [icons.md](./rules/icons.md)

- **Use HugeIcons.** Import from `@hugeicons/react` + `@hugeicons/core-free-icons`.
- **Use `HugeiconsIcon` component.** `<HugeiconsIcon icon={SearchIcon} />`.
- **Icons in components use `strokeWidth` and `className` for sizing.**

## Key Patterns

```jac
# Component definition — props extraction, no destructuring
def:pub MyComponent(props: Any) -> JsxElement {
    variant = props.variant or "default";
    return <div className={cn("bg-card", props.className)}>{props.children}</div>;
}

# State management — has = useState
has count: int = 0;

# Module-level constants — glob
glob _variants: Any = cva("base-classes", {"variants": {...}});

# Conditional classes — cn()
computedClass = cn("flex items-center", isActive and "bg-primary" or "bg-muted");

# Icons — HugeIcons
<HugeiconsIcon icon={SearchIcon} strokeWidth={2} className="size-4" />

# Radix trigger styling — apply buttonVariants directly
<DropdownMenuTrigger className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
```

## Component Selection

| Need                       | Use                                                                     |
| -------------------------- | ----------------------------------------------------------------------- |
| Button/action              | `Button` with appropriate variant                                       |
| Form inputs                | `Input`, `Select`, `Combobox`, `Switch`, `Checkbox`, `RadioGroup`, `Textarea`, `InputOTP`, `Slider` |
| Toggle between 2–5 options | `ToggleGroup` + `ToggleGroupItem`                                       |
| Data display               | `Table`, `Card`, `Badge`, `Avatar`                                      |
| Navigation                 | `Sidebar`, `NavigationMenu`, `Breadcrumb`, `Tabs`, `Pagination`         |
| Overlays                   | `Dialog` (modal), `Sheet` (side panel), `Drawer` (bottom sheet), `AlertDialog` (confirmation) |
| Feedback                   | `Alert`, `Progress`, `Skeleton`, `Spinner`, `Empty`                     |
| Charts                     | `Chart` (wraps Recharts)                                                |
| Layout                     | `Card`, `Separator`, `Resizable`, `ScrollArea`, `Accordion`, `Collapsible` |
| Menus                      | `DropdownMenu`, `ContextMenu`, `Menubar`                                |
| Tooltips/info              | `Tooltip`, `HoverCard`, `Popover`                                       |
| Button sections with gaps  | Nested `ButtonGroup` (not flat with `ButtonGroupSeparator`)             |

## CLI

```bash
# Activate venv first
source /home/ahzan/.jacvenv/bin/activate

# Add components (auto-resolves peer dependencies)
jac add --shadcn button card dialog

# Remove components
jac remove --shadcn button

# Create new project from jac-shadcn template
jac create --use jac-shadcn

# Start dev server
jac start main.jac
```

## Project Configuration

The `[jac-shadcn]` section in `jac.toml` configures the plugin:

```toml
[jac-shadcn]
style = "nova"          # nova, vega, maia, lyra, mira
registry = "https://jac-shadcn.jaseci.org"
```

## cn-* Token System

Components in the **registry project** use style-agnostic placeholder classes (`cn-button`, `cn-card`). These are resolved per-style via CSS files (`styles/style-nova.css`, etc.). When components are installed in user projects via `jac add --shadcn`, cn-* tokens are **already resolved** to concrete Tailwind classes. Users never see cn-* tokens.

> **Registry developers only:** When adding new components to the registry, define cn-* tokens in all 5 style files. See [the registry CLAUDE.md](https://jac-shadcn.jaseci.org) for details.

## Detailed References

- [rules/styling.md](./rules/styling.md) — Semantic colors, variants, className, spacing, size, dark mode, cn()
- [rules/forms.md](./rules/forms.md) — Field, Label, InputGroup, ToggleGroup, validation
- [rules/composition.md](./rules/composition.md) — Groups, overlays, Card, Tabs, Avatar, Alert, Separator, Skeleton, Badge, ButtonGroup
- [rules/icons.md](./rules/icons.md) — HugeIcons, HugeiconsIcon component, sizing
- [rules/jac-patterns.md](./rules/jac-patterns.md) — Jac compiler gotchas, has/glob/def patterns, JSX rules
- [cli.md](./cli.md) — Commands, flags, project config
- [customization.md](./customization.md) — Theming, CSS variables, extending components
