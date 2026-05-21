---
name: jac-shadcn-components
description: Using pre-installed jac-shadcn primitives from components/ui/ - import patterns, component selection, composition rules, styling, icons, theming. Load when generating components for a project that has components/ui/ or a [jac-shadcn] section in jac.toml. Pair with jac-cl-components (component shape) and jac-cl-organization (file layout).
---

When `components/ui/` already exists in the project, **never re-implement any primitive** (Button, Card, Input, Dialog, Table, Badge, etc.). Import and compose from those files. Your job is to build **high-level page/feature components** using these primitives.

## Import patterns

```jac
# Primitive components - path is always .components.ui.<filename-without-ext>
import from .components.ui.button { Button }
import from .components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from .components.ui.dialog { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogFooter }
import from .components.ui.badge { Badge }
import from .components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from .components.ui.input { Input }
import from .components.ui.select { Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue }
import from .components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from .components.ui.spinner { Spinner }
import from .components.ui.skeleton { Skeleton }
import from .components.ui.field { Field, FieldLabel, FieldGroup, FieldContent, FieldError }
import from .components.ui.label { Label }

# cn() utility - always from lib/utils, not from @jac/runtime
import from .lib.utils { cn }

# Icons - HugeIcons only
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { SearchIcon, Add01Icon, Cancel01Icon, Menu01Icon }
```

## Component selection

| Need | Component(s) |
|------|-------------|
| Button / action | `Button` - variants: `default`, `outline`, `ghost`, `destructive`, `secondary`, `link` |
| Text field | `Input` |
| Multi-line text | `Textarea` |
| Dropdown select | `Select` + `SelectTrigger` + `SelectContent` + `SelectGroup` + `SelectItem` + `SelectValue` |
| Searchable dropdown | `Combobox` |
| Native `<select>` | `NativeSelect` |
| Toggle / check | `Switch`, `Checkbox`, `RadioGroup` |
| 2–5 option toggle | `ToggleGroup` + `ToggleGroupItem` (never a Button loop) |
| Form field layout | `Field` + `FieldLabel` (never raw div with `space-y-*`) |
| Form group / fieldset | `FieldGroup`, `FieldSet`, `FieldLegend` |
| Input with prefix/suffix | `InputGroup` + `InputGroupAddon` + `InputGroupInput` |
| Data table | `Table` + `TableHeader` + `TableBody` + `TableRow` + `TableHead` + `TableCell` |
| Data card | `Card` + `CardHeader` + `CardTitle` (+ optional `CardDescription`, `CardContent`, `CardFooter`) |
| Status label | `Badge` |
| User avatar | `Avatar` + `AvatarImage` + `AvatarFallback` |
| Navigation tabs | `Tabs` + `TabsList` + `TabsTrigger` + `TabsContent` |
| Accordion | `Accordion` + `AccordionItem` + `AccordionTrigger` + `AccordionContent` |
| Breadcrumb | `Breadcrumb` + `BreadcrumbList` + `BreadcrumbItem` + `BreadcrumbLink` |
| Modal | `Dialog` + `DialogTrigger` + `DialogContent` + `DialogHeader` + `DialogTitle` |
| Side panel | `Sheet` + `SheetTrigger` + `SheetContent` + `SheetHeader` + `SheetTitle` |
| Confirmation | `AlertDialog` + `AlertDialogTrigger` + `AlertDialogContent` + `AlertDialogTitle` + `AlertDialogAction` + `AlertDialogCancel` |
| Dropdown menu | `DropdownMenu` + `DropdownMenuTrigger` + `DropdownMenuContent` + `DropdownMenuGroup` + `DropdownMenuItem` |
| Right-click menu | `ContextMenu` + `ContextMenuTrigger` + `ContextMenuContent` + `ContextMenuGroup` + `ContextMenuItem` |
| Horizontal menu bar | `Menubar` + `MenubarMenu` + `MenubarTrigger` + `MenubarContent` + `MenubarItem` |
| Tooltip | `Tooltip` + `TooltipTrigger` + `TooltipContent` |
| Floating panel | `Popover` + `PopoverTrigger` + `PopoverContent` |
| Hover detail card | `HoverCard` + `HoverCardTrigger` + `HoverCardContent` |
| Loading skeleton | `Skeleton` |
| Loading spinner | `Spinner` |
| Empty state | `Empty` |
| Alert / banner | `Alert` + `AlertTitle` + `AlertDescription` |
| Progress bar | `Progress` |
| Date picker | `Calendar` |
| Slider | `Slider` |
| Chart | `Chart` (wraps Recharts) |
| Scrollable container | `ScrollArea` |
| Divider | `Separator` |
| Command palette | `Command` + `CommandInput` + `CommandList` + `CommandItem` |
| Grouped buttons | `ButtonGroup` + `ButtonGroupSeparator` |
| App shell navigation | `Sidebar` (⚠ never pass `className` to `Sidebar*` sub-components - className spread bug; wrap with `<div>` instead) |
| Top navigation | `NavigationMenu` + `NavigationMenuList` + `NavigationMenuItem` + `NavigationMenuTrigger` + `NavigationMenuContent` |
| Expandable section | `Collapsible` + `CollapsibleTrigger` + `CollapsibleContent` |
| Drag-resize panels | `Resizable` + `ResizablePanelGroup` + `ResizablePanel` + `ResizableHandle` |
| Page navigation | `Pagination` + `PaginationContent` + `PaginationItem` + `PaginationPrevious` + `PaginationNext` |
| Image/content carousel | `Carousel` + `CarouselContent` + `CarouselItem` + `CarouselPrevious` + `CarouselNext` |
| Keyboard key display | `Kbd` |
| One-time password input | `OTPInput` |
| Generic list item | `Item` |

## Composition rules

Violations cause accessibility errors or runtime white screens.

- **`Dialog`, `Sheet`, `Drawer` always need a title.** Use `<DialogTitle className="sr-only">...</DialogTitle>` if visually hidden.
- **Full Card composition:** `CardHeader` → `CardTitle` (+ optional `CardDescription`) → `CardContent` → optional `CardFooter`. Never bare `<Card>` with raw text children.
- **`SelectItem` inside `SelectGroup`.** Same for `DropdownMenuItem` → `DropdownMenuGroup`, `ContextMenuItem` → `ContextMenuGroup`.
- **`TabsTrigger` inside `TabsList`.** `TabsList` inside `Tabs`.
- **`Avatar` always needs `AvatarFallback`** - shown when image fails to load.
- **`AlertDialog` requires both `AlertDialogAction` and `AlertDialogCancel`** in the footer.
- **`ButtonGroup` uses nested `<ButtonGroup>` for gaps** between sections; `<ButtonGroupSeparator>` for subtle 1px dividers only.
- **`Field` + `FieldLabel` for form fields** - never raw `<div className="flex flex-col gap-2">` with a plain `<label>`.

## Styling rules

- **Semantic colors only.** `bg-primary`, `text-muted-foreground`, `border-border`, `bg-card`. Never `bg-blue-500`, `text-gray-600`.
- **No `space-x-*` or `space-y-*`.** Use `flex gap-*` or `flex flex-col gap-*`.
- **Equal width + height → `size-*`.** `size-10` not `w-10 h-10`.
- **No `dark:` overrides.** CSS variables handle light/dark automatically.
- **`cn()` always from `.lib.utils`** - never recreate it, never from `@jac/runtime`.

Load `jac-cl-styling` for full conditional class patterns and cn() usage.

## Icon pattern

```jac
import from .components.ui.button { Button, buttonVariants }
import from .components.ui.dropdown_menu { DropdownMenuTrigger }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Add01Icon, SearchIcon, MoreVerticalIcon }

# Inline icon
def:pub InlineIconExample() -> JsxElement {
    return <HugeiconsIcon icon={SearchIcon} strokeWidth={2} className="size-4" />;
}

# Icon-only button
def:pub IconButtonExample() -> JsxElement {
    return <Button size="icon">
        <HugeiconsIcon icon={Add01Icon} strokeWidth={2} />
    </Button>;
}

# Radix trigger - no forwardRef, apply buttonVariants() directly
def:pub RadixTriggerExample() -> JsxElement {
    return <DropdownMenuTrigger className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
        <HugeiconsIcon icon={MoreVerticalIcon} strokeWidth={2} className="size-4" />
    </DropdownMenuTrigger>;
}
```

## Theming

All theming after project initialization is done by **editing `styles/global.css` directly**. The `[jac-shadcn]` fields in `jac.toml` (`style`, `baseColor`, `theme`, `font`, `radius`, etc.) were only used during project scaffolding - changing them post-init has no effect.

> **Style is fixed.** The visual style (nova/vega/maia/lyra/mira) is baked into the component `.cl.jac` files at template creation time and cannot be changed mid-project. The fullstack template ships with `nova`.

### Changing colors

Edit CSS variables in `styles/global.css` using OKLCH format (`oklch(lightness chroma hue)`):

```css
:root {
    --primary: oklch(0.852 0.199 91.936);
    --primary-foreground: oklch(0.421 0.095 57.708);
    --background: oklch(1 0 0);
    --foreground: oklch(0.145 0 0);
}
.dark {
    --primary: oklch(0.795 0.184 86.047);
    --primary-foreground: oklch(0.421 0.095 57.708);
    --background: oklch(0.145 0 0);
    --foreground: oklch(0.985 0 0);
}
```

Key color variables:

| Variable | Purpose |
|----------|---------|
| `--background` / `--foreground` | Page background and default text |
| `--primary` / `--primary-foreground` | Primary buttons and actions |
| `--secondary` / `--secondary-foreground` | Secondary actions |
| `--muted` / `--muted-foreground` | Muted/disabled states |
| `--accent` / `--accent-foreground` | Hover and accent states |
| `--destructive` | Error and destructive actions |
| `--card` / `--card-foreground` | Card surfaces |
| `--border` | Default border color |

### Changing border radius

Edit `--radius` in `styles/global.css`. All components derive from it:

```css
:root { --radius: 0.5rem; }  /* try 0.25rem (sharp) to 1rem (pill) */
```

| Tailwind class | Derived value |
|---|---|
| `rounded-sm` | `calc(var(--radius) - 4px)` |
| `rounded-md` | `calc(var(--radius) - 2px)` |
| `rounded-lg` | `var(--radius)` |
| `rounded-xl` | `calc(var(--radius) + 4px)` |

### Changing the font

The template ships with Figtree. To switch fonts, make two changes:

1. In `jac.toml` `[dependencies.npm]` - replace the font package (old one can be removed since it's no longer imported):

```toml
# remove: "@fontsource-variable/figtree" = "*"
"@fontsource-variable/inter" = "*"
```

1. In `styles/global.css` - replace the import and update `--font-sans` in the `@theme inline` block:

```css
/* replace */
@import "@fontsource-variable/figtree";
/* with */
@import "@fontsource-variable/inter";

/* in @theme inline, replace */
--font-sans: 'Figtree Variable', sans-serif;
/* with */
--font-sans: 'Inter Variable', sans-serif;
```

Common packages: `inter`, `outfit`, `raleway`, `nunito`, `plus-jakarta-sans`, `geist`. Font family name = package name in title case + " Variable" (e.g. `plus-jakarta-sans` → `'Plus Jakarta Sans Variable'`). No need to run `jac install` manually - it runs automatically before `jac start --dev`.

### Changing sidebar/menu colors

`menuAccent` and `menuColor` were baked into `--sidebar-*` CSS variables in `global.css`. Edit them directly:

```css
:root {
    --sidebar: oklch(0.985 0 0);                            /* sidebar background */
    --sidebar-foreground: oklch(0.145 0 0);                 /* sidebar text */
    --sidebar-primary: oklch(0.646 0.222 41.116);           /* active item background */
    --sidebar-primary-foreground: oklch(0.98 0.016 73.684); /* active item text */
    --sidebar-accent: oklch(0.97 0 0);                      /* hover background */
    --sidebar-accent-foreground: oklch(0.205 0 0);          /* hover text */
    --sidebar-border: oklch(0.922 0 0);
}
.dark {
    --sidebar: oklch(0.205 0 0);
    --sidebar-foreground: oklch(0.985 0 0);
    /* ... same pattern */
}
```

### Adding custom colors

Define in `global.css` `:root`/`.dark` blocks, then register in the `@theme inline` block. Never create a new CSS file.

```css
/* 1. global.css - define */
:root { --warning: oklch(0.84 0.16 84); --warning-foreground: oklch(0.28 0.07 46); }
.dark { --warning: oklch(0.41 0.11 46); --warning-foreground: oklch(0.99 0.02 95); }

/* 2. global.css - register */
@theme inline { --color-warning: var(--warning); --color-warning-foreground: var(--warning-foreground); }
```

```jac
def:pub WarningAlert() -> JsxElement {
    return <div className="bg-warning text-warning-foreground">Warning</div>;
}
```

## Complete example

```jac
import from .components.ui.card { Card, CardHeader, CardTitle, CardContent }
import from .components.ui.button { Button }
import from .components.ui.badge { Badge }
import from .components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from .components.ui.dialog { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle }
import from .components.ui.spinner { Spinner }
import from .lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Add01Icon }

def:pub EventListPage() -> JsxElement {
    has events: list = [];
    has loading: bool = True;

    async can with entry {
        # sv import RPC call goes here
        loading = False;
    }

    if loading {
        return <div className="flex items-center justify-center p-8">
            <Spinner />
        </div>;
    }

    return <div className="flex flex-col gap-6 p-6">
        <div className="flex items-center justify-between">
            <h1 className="text-2xl font-semibold">Events</h1>
            <Dialog>
                <DialogTrigger asChild={True}>
                    <Button>
                        <HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="size-4" />
                        New Event
                    </Button>
                </DialogTrigger>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Create Event</DialogTitle>
                    </DialogHeader>
                </DialogContent>
            </Dialog>
        </div>
        <Card>
            <CardHeader>
                <CardTitle>Upcoming Events</CardTitle>
            </CardHeader>
            <CardContent>
                <Table>
                    <TableHeader>
                        <TableRow>
                            <TableHead>Name</TableHead>
                            <TableHead>Status</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for e in events {
                            if e != None {
                                <TableRow key={e["id"]}>
                                    <TableCell>{e["name"]}</TableCell>
                                    <TableCell>
                                        <Badge variant="outline">{e["status"]}</Badge>
                                    </TableCell>
                                </TableRow>
                            }
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>
    </div>;
}
```

## Rules

- **Never re-implement a primitive.** `components/ui/` has Button, Card, Input, Dialog, Table, etc. Import them; don't write them.
- **Import path formula:** `import from .components.ui.<filename-without-extension> { ExportedName }`. Filenames match component names: `button.cl.jac` → `Button`, `card.cl.jac` → `Card, CardHeader, ...`.
- **`cn()` always from `.lib.utils`**, not from `@jac/runtime` or anywhere else. It's pre-implemented - don't recreate it.
- **Build high-level components in `components/`** (e.g., `EventCard.cl.jac`, `EventsPage.cl.jac`) that compose the primitives. Never add page logic to `components/ui/` files.
- **Do NOT recreate or edit `global.css` or `jac.toml`** in jac-shadcn projects - they are pre-configured. To change theme, edit CSS variables in `global.css` directly.

## See also

- `jac-cl-components` - component shape, `has` state, event handlers, JSX rules
- `jac-cl-organization` - file layout, hook pattern, when to extract
- `jac-cl-styling` - conditional classes, cn() usage, semantic color tokens
- `jac-npm-packages` - note: in jac-shadcn projects all npm packages are pre-installed
