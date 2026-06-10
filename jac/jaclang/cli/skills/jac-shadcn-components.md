---
name: jac-shadcn-components
description: Building with jac-shadcn primitives (delivered by the jac-super plugin) - getting components with `jac add --shadcn`, import paths, component selection, composition, styling, icons, and theming with `jac retheme`. Load when generating components for a project that has components/ui/ or a [jac-shadcn] section in jac.toml. Pair with jac-cl-components (component shape) and jac-cl-organization (file layout).
---

shadcn primitives in Jac are delivered by the **jac-super** plugin. A jac-shadcn project (`jac create --use jac-shadcn`, or any project with a `[jac-shadcn]` section in `jac.toml`) keeps the primitives in `components/ui/`.

**Never hand-write a primitive** (Button, Card, Input, Dialog, Table, Badge, etc.). If it already lives in `components/ui/`, import and compose it. If it does **not** exist yet, install it with `jac add --shadcn <name>` - do not re-implement it. Your job is to build **high-level page/feature components** in `components/` that compose these primitives.

> The starter from `jac create --use jac-shadcn` ships with **only `button` and `card`** pre-installed. Everything else (dialog, table, select, ...) must be added on demand. Always scan `components/ui/` first, then `jac add` what's missing.

## Getting components

```bash
# Create a themed project (all theme flags optional - see Theming)
jac create --use jac-shadcn --theme rose --font inter myapp

# Add primitives - resolves peer deps, patches jac.toml [dependencies.npm], offline
jac add --shadcn dialog table badge select tabs

# Remove primitives
jac remove --shadcn dialog
```

`jac add --shadcn` is bundled and offline (no network). It writes `components/ui/<name>.cl.jac`, auto-installs any peer components, and creates `lib/utils.cl.jac` with `cn()` if missing. The add-name is the kebab-case registry name (`dropdown-menu`, `alert-dialog`, `input-group`, `input-otp`, ...).

## Import patterns

**Always quote the module path, and keep the hyphens.** Installed files keep their hyphenated registry names (`dropdown-menu.cl.jac`, `alert-dialog.cl.jac`, `otp-input.cl.jac`). An **unquoted** dotted import of a hyphenated name is a **parse error** (`Unexpected token '-'`); converting the hyphen to an underscore (`dropdown_menu`) silently resolves to nothing (`Module not found` warning, component is undefined at runtime). Quoting always works - even for single-word names - so quote every UI-primitive import.

```jac
# From a composite in components/ (the usual place for your components)
import from ".ui.button" { Button }
import from ".ui.card" { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from ".ui.dropdown-menu" {
    DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuGroup, DropdownMenuItem
}
import from ".ui.dialog" { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogFooter }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

# cn() utility - always from lib/utils, never from @jac/runtime
import from "..lib.utils" { cn }

# npm packages (icons etc.) - always cl import, always a quoted bare-package string
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { SearchIcon, Add01Icon, Cancel01Icon, Menu01Icon }
```

**Leading dots are relative to the importing file's folder** (1 dot = current folder, each extra dot goes up one). Pick the prefix from where your file lives:

| Your file | UI primitive | `cn` (lib/utils) |
|-----------|-------------|------------------|
| `components/EventCard.cl.jac` | `".ui.button"` | `"..lib.utils"` |
| `components/pages/EventsPage.cl.jac` | `"..ui.button"` | `"...lib.utils"` |
| project root `main.jac` (use `cl import`) | `".components.ui.button"` | `".lib.utils"` |

In a `.cl.jac` file plain `import` is already client-context (no `cl` needed). In a top-level `.jac` entry file (like `main.jac`) prefix with `cl import` to mark the client import.

Do **not** check a `components/ui/*.cl.jac` primitive with `jac check` directly - they use a `...lib.utils` relative import that only resolves as part of the build. Validate your work by checking your composite or the entry file instead.

## Component selection

Most filenames are the kebab-case of the component (`alert-dialog` → import `".ui.alert-dialog"`). The one mismatch: `jac add --shadcn input-otp` installs as `otp-input.cl.jac` and exports `InputOTP`.

| Need | Component(s) |
|------|-------------|
| Button / action | `Button` - variants: `default`, `outline`, `ghost`, `destructive`, `secondary`, `link` |
| Text field | `Input` |
| Multi-line text | `Textarea` |
| Dropdown select | `Select` + `SelectTrigger` + `SelectContent` + `SelectGroup` + `SelectItem` + `SelectValue` |
| Searchable dropdown | `Combobox` + `ComboboxInput` + `ComboboxContent` + `ComboboxItem` (file `combobox`) |
| Native `<select>` | `NativeSelect` + `NativeSelectOption` (file `native-select`) |
| Toggle / check | `Switch`, `Checkbox`, `RadioGroup` + `RadioGroupItem` |
| Single toggle button | `Toggle` |
| 2–5 option toggle | `ToggleGroup` + `ToggleGroupItem` (file `toggle-group`; never a Button loop) |
| Form field layout | `Field` + `FieldLabel` (never raw div with `space-y-*`) |
| Form group / fieldset | `FieldGroup`, `FieldSet`, `FieldLegend` |
| Input with prefix/suffix | `InputGroup` + `InputGroupAddon` + `InputGroupInput` (file `input-group`) |
| Data table | `Table` + `TableHeader` + `TableBody` + `TableRow` + `TableHead` + `TableCell` |
| Data card | `Card` + `CardHeader` + `CardTitle` (+ optional `CardDescription`, `CardContent`, `CardFooter`) |
| Status label | `Badge` |
| User avatar | `Avatar` + `AvatarImage` + `AvatarFallback` |
| Navigation tabs | `Tabs` + `TabsList` + `TabsTrigger` + `TabsContent` |
| Accordion | `Accordion` + `AccordionItem` + `AccordionTrigger` + `AccordionContent` |
| Breadcrumb | `Breadcrumb` + `BreadcrumbList` + `BreadcrumbItem` + `BreadcrumbLink` |
| Modal | `Dialog` + `DialogTrigger` + `DialogContent` + `DialogHeader` + `DialogTitle` |
| Side panel | `Sheet` + `SheetTrigger` + `SheetContent` + `SheetHeader` + `SheetTitle` |
| Bottom drawer | `Drawer` |
| Confirmation | `AlertDialog` + `AlertDialogTrigger` + `AlertDialogContent` + `AlertDialogTitle` + `AlertDialogAction` + `AlertDialogCancel` (file `alert-dialog`) |
| Dropdown menu | `DropdownMenu` + `DropdownMenuTrigger` + `DropdownMenuContent` + `DropdownMenuGroup` + `DropdownMenuItem` (file `dropdown-menu`) |
| Right-click menu | `ContextMenu` + `ContextMenuTrigger` + `ContextMenuContent` + `ContextMenuGroup` + `ContextMenuItem` (file `context-menu`) |
| Horizontal menu bar | `Menubar` + `MenubarMenu` + `MenubarTrigger` + `MenubarContent` + `MenubarItem` |
| Tooltip | `Tooltip` + `TooltipTrigger` + `TooltipContent` |
| Floating panel | `Popover` + `PopoverTrigger` + `PopoverContent` |
| Hover detail card | `HoverCard` + `HoverCardTrigger` + `HoverCardContent` (file `hover-card`) |
| Loading skeleton | `Skeleton` |
| Loading spinner | `Spinner` |
| Empty state | `Empty` |
| Alert / banner | `Alert` + `AlertTitle` + `AlertDescription` |
| Toast / notification | `Toaster` (mount once at app root); call `toast(...)` from `"sonner"` |
| Progress bar | `Progress` |
| Date picker | `Calendar` |
| Slider | `Slider` |
| Chart | `Chart` (wraps Recharts) |
| Scrollable container | `ScrollArea` + `ScrollBar` (file `scroll-area`) |
| Fixed aspect box | `AspectRatio` (file `aspect-ratio`) |
| Divider | `Separator` |
| Command palette | `Command` + `CommandInput` + `CommandList` + `CommandItem` |
| Grouped buttons | `ButtonGroup` + `ButtonGroupSeparator` (file `button-group`) |
| App shell navigation | `Sidebar` (⚠ never pass `className` to `Sidebar*` sub-components - className spread bug; wrap with `<div>` instead) |
| Top navigation | `NavigationMenu` + `NavigationMenuList` + `NavigationMenuItem` + `NavigationMenuTrigger` + `NavigationMenuContent` (file `navigation-menu`) |
| Expandable section | `Collapsible` + `CollapsibleTrigger` + `CollapsibleContent` |
| Drag-resize panels | `Resizable` + `ResizablePanelGroup` + `ResizablePanel` + `ResizableHandle` |
| Page navigation | `Pagination` + `PaginationContent` + `PaginationItem` + `PaginationPrevious` + `PaginationNext` |
| Image/content carousel | `Carousel` + `CarouselContent` + `CarouselItem` + `CarouselPrevious` + `CarouselNext` |
| Keyboard key display | `Kbd` |
| One-time password input | `InputOTP` + `InputOTPGroup` + `InputOTPSlot` + `InputOTPSeparator` (add `input-otp`, file `otp-input`) |
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
- **`cn()` always from `lib/utils`** - never recreate it, never from `@jac/runtime`.

Load `jac-cl-styling` for full conditional class patterns and cn() usage.

## Icon pattern

```jac
import from ".ui.button" { Button, buttonVariants }
import from ".ui.dropdown-menu" { DropdownMenuTrigger }
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

Theming is managed by the **`jac retheme`** command, which regenerates `styles`/`global.css` from the `[jac-shadcn]` section of `jac.toml` (plus any flag overrides) and persists the chosen values back to `jac.toml`.

```bash
jac retheme --theme emerald --font outfit   # switch accent + font
jac retheme --style mira                     # switch style + re-resolve installed components
jac retheme                                  # regenerate global.css from the current [jac-shadcn] config
```

> **`jac retheme` overwrites `global.css` wholesale.** Hand edits to `global.css` are not preserved across a `retheme`. For accent color, base palette, font, radius, and menu accent, change them through `jac retheme` flags (it also updates `jac.toml`), not by editing CSS. Only hand-edit `global.css` for one-off custom colors you won't `retheme` over.

The `[jac-shadcn]` block in `jac.toml` is the source of truth (no longer just scaffolding):

```toml
[jac-shadcn]
style = "nova"        # nova | vega | maia | lyra | mira  (--style also restyles installed components)
baseColor = "neutral" # neutral | stone | zinc | gray
theme = "rose"        # accent: neutral, stone, zinc, gray, amber, blue, cyan, emerald,
                      #   fuchsia, green, indigo, lime, orange, pink, purple, red, rose,
                      #   sky, teal, violet, yellow
font = "inter"        # figtree (default), inter, geist, geist-mono, roboto, raleway,
                      #   dm-sans, public-sans, outfit, noto-sans, nunito-sans, jetbrains-mono
radius = "default"    # default | none | small | medium | large
menuAccent = "subtle" # subtle | bold
```

`jac retheme --font <name>` patches `[dependencies.npm]` automatically - no manual font package edit, and `jac install` runs before `jac start --dev`.

### Understanding / hand-editing the generated CSS

`global.css` defines CSS variables in OKLCH (`oklch(lightness chroma hue)`) under `:root` and `.dark`, then registers them in an `@theme inline` block. Key variables:

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
| `--radius` | Base radius; `rounded-sm/md/lg/xl` derive from it |
| `--sidebar*` | Sidebar background/text/active/hover colors |

To add a **custom** color the generator doesn't emit, define it in `:root`/`.dark` and register it in `@theme inline` (remember a later `jac retheme` regenerates the file and drops it):

```css
:root { --warning: oklch(0.84 0.16 84); --warning-foreground: oklch(0.28 0.07 46); }
.dark { --warning: oklch(0.41 0.11 46); --warning-foreground: oklch(0.99 0.02 95); }
@theme inline { --color-warning: var(--warning); --color-warning-foreground: var(--warning-foreground); }
```

```jac
def:pub WarningAlert() -> JsxElement {
    return <div className="bg-warning text-warning-foreground">Warning</div>;
}
```

## Complete example

A composite page in `components/` (so primitives are `".ui.<name>"`, `cn` is `"..lib.utils"`). Run `jac add --shadcn card button badge table dialog spinner` first if those aren't installed.

```jac
import from ".ui.card" { Card, CardHeader, CardTitle, CardContent }
import from ".ui.button" { Button }
import from ".ui.badge" { Badge }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ".ui.dialog" { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle }
import from ".ui.spinner" { Spinner }
import from "..lib.utils" { cn }
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

- **Scan `components/ui/` first; if a primitive is missing, `jac add --shadcn <name>` - never hand-write it.** The starter ships only `button` + `card`; add the rest on demand.
- **Quote every UI-primitive import path and keep the hyphens.** `import from ".ui.dropdown-menu" { ... }`. Unquoted hyphens are a parse error; underscores resolve to nothing.
- **Import path = dots relative to your file's folder.** From `components/`: `".ui.<name>"` and `"..lib.utils"`. See the location table above.
- **`cn()` always from `lib/utils`**, never from `@jac/runtime`. It's pre-implemented - don't recreate it.
- **Build high-level components in `components/`** (e.g., `EventCard.cl.jac`, `EventsPage.cl.jac`) that compose the primitives. Never add page logic to `components/ui/` files, and never edit those files - they're managed by the registry.
- **Theme with `jac retheme`, not by editing `global.css`** (a retheme overwrites it). Don't recreate or hand-edit `jac.toml`'s `[jac-shadcn]`/`[dependencies.npm]` - `jac add`/`jac retheme` manage them.

## See also

- `jac-cl-components` - component shape, `has` state, event handlers, JSX rules
- `jac-cl-organization` - file layout, hook pattern, when to extract
- `jac-cl-styling` - conditional classes, cn() usage, semantic color tokens
- `jac-npm-packages` - note: in jac-shadcn projects npm deps are managed by `jac add`/`jac retheme`
