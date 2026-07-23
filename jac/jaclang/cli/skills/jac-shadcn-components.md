---
name: jac-shadcn-components
description: Building with jac-shadcn primitives (built into jaclang core) - getting components with `jac install --shadcn`, import paths, component selection, composition, styling, icons, and theming with `jac retheme`. Pair with `jac-shadcn-blocks` for design constants and composition patterns. Load when generating components for a project that has components/ui/ or a [jac-shadcn] section in jac.toml.
---

shadcn primitives in Jac are built into **jaclang core**. A jac-shadcn project (`jac create --use jac-shadcn`, or any project with a `[jac-shadcn]` section in `jac.toml`) keeps the primitives in `components/ui/`.

**Never hand-write a primitive** (Button, Card, Input, Dialog, Table, Badge, etc.). If it already lives in `components/ui/`, import and compose it. If it does **not** exist yet, install it with `jac install --shadcn <name>` - do not re-implement it. Your job is to build **high-level page/feature components** in `components/` that compose these primitives.

> The starter from `jac create --use jac-shadcn` ships with **only `button` and `card`** pre-installed. Everything else (dialog, table, select, ...) must be added on demand. Always scan `components/ui/` first, then `jac install --shadcn` what's missing.

## Getting components

```bash
# Create a themed project (all theme flags optional - see Theming)
jac create --use jac-shadcn --theme rose --font inter myapp

# Add primitives - resolves peer deps, patches jac.toml [dependencies.npm], offline
jac install --shadcn dialog table badge select tabs

# Remove primitives
jac remove --shadcn dialog
```

`jac install --shadcn` is bundled and offline (no network). It writes `components/ui/<name>.jac`, auto-installs any peer components, and creates `lib/utils.jac` with `cn()` if missing. The add-name on the command line is the kebab-case registry name (`dropdown-menu`, `alert-dialog`, `input-group`, `input-otp`, ...), but the file it writes is the **underscored** form (`dropdown_menu.jac`) - a hyphen is invalid in a Jac module name.

## Import patterns

**Import the underscored file name.** `jac install --shadcn dropdown-menu` writes `dropdown_menu.jac` - the installer converts the hyphen to an underscore because a hyphen is the minus operator and cannot appear in a Jac module name. So import the underscore: `import from .ui.dropdown_menu { ... }`. No quoting needed, since `_` is a valid identifier character. **Never write the hyphen in an import** - both forms fail: unquoted (`.ui.dropdown-menu`) is a **parse error** (`Unexpected token '-'`), and quoted (`".ui.dropdown-menu"`) passes `jac check` but the compiler emits `./ui/dropdown-menu.js`, which never matches the underscored file, so the build fails with `Could not resolve`.

```jac
# From a composite in components/ (the usual place for your components)
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from .ui.dropdown_menu {
    DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuGroup, DropdownMenuItem
}
import from .ui.dialog { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogFooter }
import from .ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

# cn() utility - always from lib/utils, never from @jac/runtime
import from ..lib.utils { cn }

# npm packages - the string-path import is itself the client seed (no marker needed),
# always QUOTED: a hyphen, @, or / is a parse error unquoted, so `react-dom` /
# `class-variance-authority` need quotes too, not just @-scoped names. (Only local
# dotted paths above - `.ui.X`, `.lib.utils` - may drop the quotes.)
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Search01Icon, Add01Icon, Cancel01Icon, Menu01Icon }
```

**Leading dots are relative to the importing file's folder** (1 dot = current folder, each extra dot goes up one). Pick the prefix from where your file lives:

| Your file | UI primitive | `cn` (lib/utils) |
|-----------|-------------|------------------|
| `components/EventCard.jac` | `.ui.button` | `..lib.utils` |
| `pages/dashboard.jac` (file-based route) | `..components.ui.button` | `..lib.utils` |
| `pages/(auth)/dashboard.jac` (route group) | `...components.ui.button` | `...lib.utils` |
| project root `main.jac` (entry module) | `.components.ui.button` | `.lib.utils` |

**A `pages/` file is not inside `components/`.** From within `components/`, `ui/` is a subfolder, so the prefix is `.ui.X`. From a sibling directory like `pages/`, you go up to the project root and back down into `components/`, so the prefix is `..components.ui.X` - and one MORE dot for each `pages/` subfolder (a route group like `(auth)/` counts as a folder). Undercounting (e.g. `.components.ui.card` from `pages/login.jac`) silently fails the client bundle with `Could not resolve`, not `jac check`.

Client placement is inferred - a module with an npm import or JSX compiles client, so a plain `import` needs no `cl` marker, whether in a component file or a top-level entry file like `main.jac`.

Do **not** check a `components/ui/*.jac` primitive with `jac check` directly - they use a `...lib.utils` relative import that only resolves as part of the build. Validate your work by checking your composite or the entry file instead.

## Component selection

Most file names are the underscored registry name (`jac install --shadcn alert-dialog` → file `alert_dialog.jac` → import `.ui.alert_dialog`). The one stem mismatch: `jac install --shadcn input-otp` installs as `otp_input.jac` (import `.ui.otp_input`) and exports `InputOTP`.

| Need | Component(s) |
|------|-------------|
| Button / action | `Button` - variants: `default`, `outline`, `ghost`, `destructive`, `secondary`, `link` |
| Text field | `Input` |
| Multi-line text | `Textarea` |
| Dropdown select | `Select` + `SelectTrigger` + `SelectContent` + `SelectGroup` + `SelectItem` + `SelectValue` |
| Searchable dropdown | `Combobox` + `ComboboxInput` + `ComboboxContent` + `ComboboxItem` (file `combobox`) |
| Native `<select>` | `NativeSelect` + `NativeSelectOption` (file `native_select`) |
| Toggle / check | `Switch`, `Checkbox`, `RadioGroup` + `RadioGroupItem` |
| Single toggle button | `Toggle` |
| 2 to 5 option toggle | `ToggleGroup` + `ToggleGroupItem` (file `toggle_group`; never a Button loop) |
| Form field layout | `Field` + `FieldLabel` (never raw div with `space-y-*`) |
| Form group / fieldset | `FieldGroup`, `FieldSet`, `FieldLegend` |
| Input with prefix/suffix | `InputGroup` + `InputGroupAddon` + `InputGroupInput` (file `input_group`) |
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
| Confirmation | `AlertDialog` + `AlertDialogTrigger` + `AlertDialogContent` + `AlertDialogTitle` + `AlertDialogAction` + `AlertDialogCancel` (file `alert_dialog`) |
| Dropdown menu | `DropdownMenu` + `DropdownMenuTrigger` + `DropdownMenuContent` + `DropdownMenuGroup` + `DropdownMenuItem` (file `dropdown_menu`) |
| Right-click menu | `ContextMenu` + `ContextMenuTrigger` + `ContextMenuContent` + `ContextMenuGroup` + `ContextMenuItem` (file `context_menu`) |
| Horizontal menu bar | `Menubar` + `MenubarMenu` + `MenubarTrigger` + `MenubarContent` + `MenubarItem` |
| Tooltip | `Tooltip` + `TooltipTrigger` + `TooltipContent` |
| Floating panel | `Popover` + `PopoverTrigger` + `PopoverContent` |
| Hover detail card | `HoverCard` + `HoverCardTrigger` + `HoverCardContent` (file `hover_card`) |
| Loading skeleton | `Skeleton` |
| Loading spinner | `Spinner` |
| Empty state | `Empty` + `EmptyHeader` + `EmptyMedia` + `EmptyTitle` + `EmptyDescription` + `EmptyContent` |
| Alert / banner | `Alert` + `AlertTitle` + `AlertDescription` |
| Toast / notification | `Toaster` (mount once at app root); call `toast(...)` from `"sonner"` |
| Progress bar | `Progress` |
| Date picker | `Calendar` |
| Slider | `Slider` |
| Chart | `Chart` (wraps Recharts) |
| Scrollable container | `ScrollArea` + `ScrollBar` (file `scroll_area`) |
| Fixed aspect box | `AspectRatio` (file `aspect_ratio`) |
| Divider | `Separator` |
| Command palette | `Command` + `CommandInput` + `CommandList` + `CommandItem` |
| Grouped buttons | `ButtonGroup` + `ButtonGroupSeparator` (file `button_group`) |
| App shell navigation | `Sidebar` (⚠ never pass `className` to `Sidebar*` sub-components - className spread bug; wrap with `<div>` instead) |
| Top navigation | `NavigationMenu` + `NavigationMenuList` + `NavigationMenuItem` + `NavigationMenuTrigger` + `NavigationMenuContent` (file `navigation_menu`) |
| Expandable section | `Collapsible` + `CollapsibleTrigger` + `CollapsibleContent` |
| Drag-resize panels | `Resizable` + `ResizablePanelGroup` + `ResizablePanel` + `ResizableHandle` |
| Page navigation | `Pagination` + `PaginationContent` + `PaginationItem` + `PaginationPrevious` + `PaginationNext` |
| Image/content carousel | `Carousel` + `CarouselContent` + `CarouselItem` + `CarouselPrevious` + `CarouselNext` |
| Keyboard key display | `Kbd` |
| One-time password input | `InputOTP` + `InputOTPGroup` + `InputOTPSlot` + `InputOTPSeparator` (add `input-otp`, file `otp_input`) |
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
- **`Tooltip` must be wrapped in `<TooltipProvider>`** - usually at app root or `Layout.jac`.

## Styling rules

- **Semantic colors only.** `bg-primary`, `text-muted-foreground`, `border-border`, `bg-card`. Never `bg-blue-500`, `text-gray-600`. Never `opacity-70` to dim text - use `text-muted-foreground` instead (opacity tricks break dark mode).
- **No `space-x-*` or `space-y-*`.** Use `flex gap-*` or `flex flex-col gap-*`.
- **Equal width + height → `size-*`.** `size-10` not `w-10 h-10`.
- **No `dark:` overrides.** CSS variables handle light/dark automatically.
- **`cn()` always from `lib/utils`** - never recreate it, never from `@jac/runtime`.

Load `jac-cl-styling` for full conditional class patterns and cn() usage.

## Icon pattern

⚠ **Never guess an icon name.** The package exports ~5,500 icons and most are
number-suffixed, so the obvious name is usually wrong: there is no `SearchIcon`,
`DocumentIcon`, `FolderIcon`, `PlusIcon`, or `TrendUpIcon`. A wrong name is NOT a
compile error - `jac check` and the build both pass, and it fails only when the
page loads, with `SyntaxError: ... does not provide an export named 'DocumentIcon'`.
Use a name from the table below, or list the real ones:

```bash
ls .jac/client/node_modules/@hugeicons/core-free-icons/dist/esm/ | grep -v '\.map' | grep -i '^chart'
```

| Need | Icon (verified) |
|---|---|
| home / menu / back / forward | `Home01Icon`, `Menu01Icon`, `ArrowLeft01Icon`, `ArrowRight01Icon`, `ArrowUpRight01Icon` |
| add / edit / delete / close | `Add01Icon` (or `PlusSignIcon`), `Edit01Icon`, `Delete01Icon`, `Cancel01Icon` |
| search / filter / download / upload | `Search01Icon`, `FilterIcon`, `Download01Icon`, `Upload01Icon` |
| success / warning / info | `CheckmarkCircle01Icon`, `Alert01Icon`, `InformationCircleIcon` |
| file / folder / message / mail | `File01Icon`, `Folder01Icon`, `Message01Icon`, `Mail01Icon` |
| calendar / clock | `Calendar1Icon`, `Clock1Icon` (single digit, NOT `01`) |
| user / settings / logout / bell | `UserIcon`, `Settings01Icon`, `Logout01Icon`, `Notification01Icon` |
| chart / analytics / dashboard / money | `ChartIcon`, `Analytics01Icon`, `DashboardSquare01Icon`, `DollarCircleIcon` |
| star / eye / lock / sparkle | `StarIcon`, `EyeIcon`, `LockIcon`, `SparklesIcon` |
| overflow menu | `MoreVerticalIcon`, `MoreHorizontalIcon` |

```jac
import from .ui.button { Button, buttonVariants }
import from .ui.dropdown_menu { DropdownMenuTrigger }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Add01Icon, Search01Icon, MoreVerticalIcon }

# Inline icon
def:pub InlineIconExample() -> JsxElement {
    return <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4" />;
}

# Icon-only button
def:pub IconButtonExample() -> JsxElement {
    return <Button size="icon">
        <HugeiconsIcon icon={Add01Icon} strokeWidth={2} />
    </Button>;
}

# Radix trigger styled directly with buttonVariants() - simplest icon-trigger form
def:pub RadixTriggerExample() -> JsxElement {
    return <DropdownMenuTrigger className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
        <HugeiconsIcon icon={MoreVerticalIcon} strokeWidth={2} className="size-4" />
    </DropdownMenuTrigger>;
}
```

## ⚠ `asChild` triggers and ref forwarding (silent no-open bug)

`<DialogTrigger asChild={True}>`, `<DropdownMenuTrigger asChild={True}>`, `<PopoverTrigger asChild={True}>`, etc. render their **child** as the trigger and attach a positioning-anchor ref to it. The installed `components/ui/` primitives handle this. But if the child is a **hand-written composite of your own**, it MUST declare a trailing `ref: Ref[...]` parameter (which lowers to React `forwardRef`) - otherwise the anchor ref lands nowhere and the menu/popover/dialog **silently never opens**. No compile error, no console error.

```jac
# Usable as an asChild trigger child - the trailing ref param forwards the anchor
def:pub MyMenuButton(label: str, ref: Ref[HTMLButtonElement]) -> JsxElement {
    return <button ref={ref} className="...">{label}</button>;
}
```

Prefer the installed `Button` (already handles this) or style the trigger directly with `buttonVariants()` as above. See `jac-npm-packages` for ref-forwarding details and its known `jac check` false positives.

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
theme = "rose"        # accent: any base color or amber/blue/cyan/emerald/fuchsia/green/indigo/lime/orange/pink/purple/red/rose/sky/teal/violet/yellow
font = "inter"        # figtree (default), inter, geist, geist-mono, roboto, raleway, dm-sans, public-sans, outfit, noto-sans, nunito-sans, jetbrains-mono
radius = "default"    # default | none | small | medium | large
menuAccent = "subtle" # subtle | bold
```

`jac retheme --font <name>` patches `[dependencies.npm]` automatically - no manual font package edit, and `jac install` runs before `jac start --dev`.

### baseColor vs theme

**baseColor** sets the gray palette of the entire UI: backgrounds, borders, muted text, card surfaces, and secondary states. Think of it as the "temperature" of the neutral shades.

| baseColor | Tone | Use when |
|---|---|---|
| neutral | Pure gray (default) | Most apps - safe universal choice |
| stone | Warm gray | Organic, earthy, warm brands |
| zinc | Cool gray | Technical, cold, developer tools |
| gray | Mid gray | Clean, slightly warm neutral |

**theme** is the accent/brand color layered on top of baseColor. It sets only `--primary`, chart highlight colors, and `--sidebar-primary`. These two are independent: `baseColor=neutral + theme=amber` = gray UI with amber buttons.

### Theme reference

| Theme | Visual feel | Best for |
|---|---|---|
| neutral | Monochrome, no accent | Minimal tools, content-first apps |
| stone | Neutral warm tone | Subtle warmth, organic brands |
| zinc | Neutral cool tone | Cool/technical feel |
| gray | Mid neutral tone | Clean, versatile |
| amber | Warm orange-yellow | E-commerce, food, productivity |
| orange | Bold orange | Energy, sports, bold consumer apps |
| yellow | Bright yellow | Education, children, playful apps |
| lime | Fresh lime-green | Environmental, health, food |
| green | Classic green | Finance, health, success states |
| emerald | Rich emerald-green | Health, wellness, sustainability |
| teal | Teal/cyan-green | Healthcare, professional services |
| cyan | Bright cyan | Tech, data visualization, modern SaaS |
| sky | Light blue | Travel, cloud, open/airy feel |
| blue | Classic blue | Enterprise, finance, trusted services |
| indigo | Deep indigo/purple-blue | Developer tools, analytics, B2B SaaS |
| violet | Vibrant violet | Creative tech, AI products |
| purple | Deep purple | Premium, luxury, creative |
| fuchsia | Hot pink-purple | Fashion, beauty, bold consumer |
| pink | Soft pink | Lifestyle, wellness, social |
| rose | Rose pink | Romantic, lifestyle, friendly apps |
| red | Bold red | Alerts-heavy tools, bold brands |

### Font reference

| Font | Feel | Best for |
|---|---|---|
| figtree | Warm, friendly, modern | Default - most apps |
| inter | Professional, neutral | SaaS, enterprise, dashboards |
| geist | Clean technical, Vercel-like | Developer tools, API products |
| geist-mono | Monospace, code-oriented | Code editors, terminal apps |
| roboto | Neutral, Material-like | Familiar, widely readable |
| raleway | Elegant, light weight | Portfolio, creative, luxury |
| dm-sans | Modern, geometric | Startup, modern SaaS |
| public-sans | Clean, government-like | Government, civic, structured |
| outfit | Friendly, rounded | Mobile apps, consumer products |
| noto-sans | Universal, multilingual | Apps needing broad language support |
| nunito-sans | Rounded, approachable | Children, education, accessibility |
| jetbrains-mono | Developer monospace | IDE-like tools, code display |

### Full retheme flag reference

```bash
# Apply all 6 design choices in one command:
jac retheme --style nova --baseColor neutral --theme indigo --font inter --radius default --menuAccent subtle

# All supported flags (any combination, all optional):
# --style       nova | vega | maia | lyra | mira
# --baseColor   neutral | stone | zinc | gray        (NOT --base-color)
# --theme       <any theme name from table above>
# --font        <any font name from table above>
# --radius      default | none | small | medium | large
# --menuAccent  subtle | bold                        (NOT --menu-accent)
# skip --menuColor: field exists but CSS generation ignores it (no visual effect)
```

> **Flag names are camelCase** - matching jac.toml key names exactly: `--baseColor` not `--base-color`, `--menuAccent` not `--menu-accent`. Kebab-case variants are not recognized.
>
> **menuColor: exclude from retheme calls.** The `--menuColor` flag and `menuColor` jac.toml field exist, but `resolve_css_vars()` in jaclang core does not process them. Any value set has zero CSS effect. Leave as default until core ships support.

### Understanding / hand-editing the generated CSS

`global.css` defines CSS variables in OKLCH (`oklch(lightness chroma hue)`) under `:root` and `.dark`, then registers them in an `@theme inline` block. Key variables:

| Variable | Purpose |
|---|---|
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

To add a custom color the generator doesn't emit, define it in `:root`/`.dark` and register it in `@theme inline` (a later `jac retheme` regenerates the file and drops it):

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

A composite page in `components/` (so primitives are `".ui.<name>"`, `cn` is `"..lib.utils"`). Run `jac install --shadcn card button badge table dialog spinner` first if those aren't installed.

```jac
import from ".ui.card" { Card, CardHeader, CardTitle, CardContent }
import from ".ui.button" { Button }
import from ".ui.badge" { Badge }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ".ui.dialog" { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle }
import from ".ui.spinner" { Spinner }
import from "..lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Add01Icon }

def:pub EventListPage() -> JsxElement {
    has events: list[dict] = [];   # type the element (use the sv import-ed view type); a bare `list` loses element typing -> E1032 on field access
    has loading: bool = True;

    async can with entry {
        # sv import RPC call goes here
        loading = False;
    }

    if loading {
        return <div className="flex items-center justify-center p-8"><Spinner /></div>;
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
                    <DialogHeader><DialogTitle>Create Event</DialogTitle></DialogHeader>
                </DialogContent>
            </Dialog>
        </div>
        <Card>
            <CardHeader><CardTitle>Upcoming Events</CardTitle></CardHeader>
            <CardContent>
                <Table>
                    <TableHeader>
                        <TableRow><TableHead>Name</TableHead><TableHead>Status</TableHead></TableRow>
                    </TableHeader>
                    <TableBody>
                        {for e in events {
                            if e != None {
                                <TableRow key={e["id"]}>
                                    <TableCell>{e["name"]}</TableCell>
                                    <TableCell><Badge variant="outline">{e["status"]}</Badge></TableCell>
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

- **Scan `components/ui/` first; if a primitive is missing, `jac install --shadcn <name>` - never hand-write it.** The starter ships only `button` + `card`; add the rest on demand.
- **Import the underscored file name.** `import from .ui.dropdown_menu { ... }` - the installer writes `dropdown_menu.jac`, so the hyphen becomes an underscore. Never write the hyphen: unquoted is a parse error, quoted builds to `./ui/dropdown-menu.js` and fails to resolve.
- **Import path = dots relative to your file's folder.** From `components/`: `".ui.<name>"` and `"..lib.utils"`. See the location table above.
- **`cn()` always from `lib/utils`**, never from `@jac/runtime`. It's pre-implemented - don't recreate it.
- **Build high-level components in `components/`** (e.g., `EventCard.jac`, `EventsPage.jac`) that compose the primitives. Never add page logic to `components/ui/` files, and never edit those files - they're managed by the registry.
- **Theme with `jac retheme`, not by editing `global.css`** (a retheme overwrites it). Don't recreate or hand-edit `jac.toml`'s `[jac-shadcn]`/`[dependencies.npm]` - `jac install`/`jac retheme` manage them.

## Peer dependency chains

`jac install --shadcn` auto-resolves peer dependencies via BFS. When calling `jac install --shadcn`, list only primaries - never list peer components manually.

| Primary | Auto-installed peers |
|---|---|
| sidebar | button, input, separator, sheet, skeleton, tooltip |
| command | dialog |
| dialog | button |
| sheet | button |
| pagination | button |
| calendar | button |
| toggle-group | toggle |
| input-group | button, input, textarea |
| field | label, separator |
| item | separator |
| button-group | separator |

## Extended component exports

These exports exist in the registry but are not listed in the component selection table above.

| Component | Additional exports |
|---|---|
| `Card` | `CardAction` - action slot in the card header (top-right area) |
| `Avatar` | `AvatarBadge` (status dot overlay), `AvatarGroup` + `AvatarGroupCount` (stacked group) |
| `Combobox` | `ComboboxChips`, `ComboboxChip`, `ComboboxChipsInput`, `ComboboxClear`, `useComboboxAnchor` - multi-select chip pattern |
| `InputGroup` | `InputGroupButton` (button slot), `InputGroupText` (text slot), `InputGroupTextarea` (textarea slot) |
| `Dialog` | `showCloseButton` prop on `DialogContent` (defaults `True`) |
| `Sheet` | `showCloseButton` prop on `SheetContent` (defaults `False`) |
| `AlertDialog` | `size` prop on `AlertDialogContent` |
| `Item` | `ItemGroup`, `ItemSeparator`, `ItemMedia`, `ItemContent`, `ItemTitle`, `ItemDescription`, `ItemActions`, `ItemHeader`, `ItemFooter` - full slot composition for list rows |
| `ButtonGroup` | `ButtonGroupText` (text separator slot) |
| `Kbd` | `KbdGroup` (grouped key sequence) |
| `NativeSelect` | `NativeSelectOptGroup` (option group) |

## Jac-shadcn gotchas

Consolidated quick-reference. See Import patterns and component selection sections for full details.

**Sidebar className spread** - Never pass `className` directly to `SidebarMenuButton`, `SidebarMenuAction`, `SidebarGroup`, `SidebarMenuItem`, or `SidebarTrigger`. The prop spreads after computed base classes, overriding them. Use a wrapping `<div>` for layout overrides instead.

**Never edit files in `components/ui/`** - Managed by `jac install --shadcn` and `jac remove --shadcn`. Manual edits are silently overwritten on next run.

**Import the underscored file name; hyphens never work.**

```
import from .ui.dropdown_menu { DropdownMenu }      # correct - matches the installed file
import from ".ui.dropdown_menu" { DropdownMenu }    # also fine - quoting is optional for _ names
import from .ui.dropdown-menu { DropdownMenu }       # WRONG - unquoted hyphen is a parse error
import from ".ui.dropdown-menu" { DropdownMenu }     # WRONG - builds ./ui/dropdown-menu.js, no such file
```

**File name vs command name:** `jac install --shadcn dropdown-menu` (kebab command) installs `dropdown_menu.jac` (underscored file). The import path uses the underscored file name: `import from .ui.dropdown_menu`.

## See also

- `jac-cl-components` - component shape, `has` state, event handlers, JSX rules
- `jac-cl-organization` - file layout, hook pattern, when to extract
- `jac-cl-styling` - conditional classes, cn() usage, semantic color tokens
- `jac-npm-packages` - note: in jac-shadcn projects npm deps are managed by `jac install`/`jac retheme`
- `jac-shadcn-blocks` - design system constants, anti-patterns, and composition pattern skeletons
