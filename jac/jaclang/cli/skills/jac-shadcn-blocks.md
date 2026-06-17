---
name: jac-shadcn-blocks
description: Design system constants, anti-patterns, and composition patterns for jac-shadcn. Load when building any jac-shadcn page - provides spacing scale, type scale, and structural JSX skeletons for auth, sidebar app shell, data table, stats, pricing, CTA, empty state, and marketing sections.
---

Component shape, named typed params (including `children: any = None`), and JSX comments - see `jac-cl-components`.
For semantic color tokens, `cn()` usage, and dark mode - see `jac-shadcn-components`.

---

## Design System Constants

Read before building any page. These values must be used consistently.

### Section padding (physical CSS only - never shorthand `py-` / `px-`)

| Section type | Classes |
|---|---|
| Hero / CTA (major page moments) | `pt-24 pb-24 sm:pt-32 sm:pb-32` |
| Mid-page (features, pricing, FAQ, testimonials) | `pt-16 pb-16 sm:pt-24 sm:pb-24` |
| Compact | `pt-12 pb-12` |
| Dashboard main (inside SidebarInset) | `pt-6 pb-6 pl-6 pr-6` |

### Inner container wrapper

All marketing sections wrap content in:

```
<div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
```

Dashboard variant WITH sidebar: NO `max-w-*` on `<main>` - the sidebar already constrains width.

### Type scale

| Element | Classes |
|---|---|
| Hero h1 | `text-balance text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl` |
| Section h2 | `text-balance text-3xl font-bold tracking-tight sm:text-4xl` |
| Card / block h3 | `text-lg font-semibold` |
| Lead paragraph | `text-balance text-lg leading-8 text-muted-foreground` |
| Body / description | `text-base leading-relaxed text-muted-foreground` |
| Stat number | `text-3xl font-semibold tabular-nums` |
| Small / caption | `text-sm text-muted-foreground` |
| Legal / copyright | `text-xs text-muted-foreground` |

All headlines at `text-3xl` or above MUST have `tracking-tight` and `text-balance`.

### Reusable section header pattern

Every mid-page marketing section uses this header above the content grid:

```
<div className="mx-auto max-w-2xl text-center">
    <Badge variant="outline" className="mb-4">Eyebrow label</Badge>
    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
        Section headline here
    </h2>
    <p className="mt-4 text-balance text-lg text-muted-foreground">
        Supporting one-liner.
    </p>
</div>
```

Content grid below uses `mt-12` (tight) or `mt-16` (spacious).

### Spacing rules

- Cards always `p-6` - NEVER `p-4`.
- Gaps are 4-multiples only: `gap-2 gap-4 gap-6 gap-8 gap-12 gap-16`. Never `gap-5`, `gap-7`, `gap-9`.
- `mt-8` not `mt-7`. `gap-8` not `gap-7`.

---

## Anti-Patterns Checklist

For semantic color tokens (`text-muted-foreground`, `bg-card`, etc.) and `cn()` rules, see `jac-shadcn-components`.

| Wrong | Correct | Why |
|---|---|---|
| `font-light` on headlines | `font-bold` or `font-semibold` | Light headlines read as body copy |
| `py-8` or `py-12` hero/CTA padding | `pt-24 pb-24 sm:pt-32 sm:pb-32` | Hero needs breathing room; shorthand forbidden |
| `p-4` inside a Card | `p-6` | Cards always `p-6` |
| `shadow-xl` everywhere | `shadow-sm` rest, `hover:shadow-md` interactive | Heavy shadows look dated |
| `mt-7`, `gap-5`, `gap-9` | `mt-8`, `gap-4`, `gap-8` | 4-unit rhythm |
| `border-2` for structural layout | `border` (hairline) only | `border-2` is for emphasis, not layout |
| `className={"base " + extra}` | `className={cn("base", extra)}` | `cn()` runs tailwind-merge deduplication |
| `py-16`, `px-4` (shorthand) | `pt-16 pb-16`, `pl-4 pr-4` (physical) | Jac codebase styling rule |
| `{/* */}` inside JSX | `{#* comment text *#}` | `/` and `*` parse as Jac operators inside a slot |
| `# comment` inside JSX text | `{#* comment text *#}` | `#` outside expression slot is literal HTML text |
| `true`, `false`, `null` | `True`, `False`, `None` | Jac uses Python-style booleans |
| `className` on any `Sidebar*` component | wrapping `<div>` instead | jac-shadcn className spread bug wipes base styles |

---

## Composition Patterns

Minimal structural skeletons with the non-obvious rules for each. Use these as starting points - fill in real content, data, and handlers.

### Auth card (centered viewport)

```
<div className="flex min-h-svh items-center justify-center pt-12 pb-12 pl-4 pr-4">
    <Card className="w-full max-w-sm">
        <CardHeader>
            <CardTitle className="text-2xl">Sign in</CardTitle>
            <CardDescription>Enter your email to access your account.</CardDescription>
        </CardHeader>
        <CardContent>
            <form className="flex flex-col gap-6">
                <Field><FieldLabel htmlFor="email">Email</FieldLabel><Input id="email" type="email" /></Field>
                <Button type="submit" className="w-full">Sign in</Button>
            </form>
        </CardContent>
        <CardFooter>
            <p className="w-full text-center text-sm text-muted-foreground">
                {"Don't have an account?"} <a href="/signup" className="text-foreground underline-offset-4 hover:underline">Sign up</a>
            </p>
        </CardFooter>
    </Card>
</div>
```

- `min-h-svh` not `pt-24` - auth is viewport-centered, not a marketing section.
- `max-w-sm` not `max-w-md` - auth cards are narrow and focused.
- Submit button always `w-full type="submit"`. SSO buttons always `variant="outline"`.
- Strings with `'` or `?` must be in braces: `{"Don't have an account?"}`.
- For the full auth flow (`jacLogin`, `jacSignup`, 3-step registration), see `jac-cl-auth`.

---

### App shell with sidebar

```
<SidebarProvider>
    <Sidebar collapsible="offcanvas">
        <SidebarHeader>...</SidebarHeader>
        <SidebarContent>
            <SidebarGroup>
                <SidebarGroupLabel>Platform</SidebarGroupLabel>
                <SidebarMenu>...</SidebarMenu>
            </SidebarGroup>
        </SidebarContent>
        <SidebarFooter>...</SidebarFooter>
    </Sidebar>
    <SidebarInset>
        <header className="flex h-14 items-center gap-2 border-b pl-4 pr-4">
            <SidebarTrigger />
            <Separator orientation="vertical" className="mr-2 h-4" />
            <Breadcrumb><BreadcrumbList>...</BreadcrumbList></Breadcrumb>
        </header>
        <main className="flex flex-1 flex-col gap-6 pt-6 pb-6 pl-6 pr-6">{children}</main>
    </SidebarInset>
</SidebarProvider>
```

- `SidebarInset` main uses `pt-6 pb-6 pl-6 pr-6` (dashboard rhythm) - not `pt-24` (marketing).
- No `max-w-*` on `<main>` inside `SidebarInset` - sidebar already constrains width.
- `Separator orientation="vertical" className="mr-2 h-4"` is required between `SidebarTrigger` and breadcrumb.
- `collapsible="offcanvas"` collapses to hidden; `collapsible="icon"` collapses to icon rail.
- Never pass `className` to any `Sidebar*` sub-component - see Anti-Patterns.

---

### Data table in card

```
<Card>
    <CardHeader>
        <div className="flex items-center justify-between">
            <div>
                <CardTitle>Customers</CardTitle>
                <CardDescription>Manage your accounts.</CardDescription>
            </div>
            <div className="flex items-center gap-2">
                <Input placeholder="Search..." className="w-64" />
                <Button size="sm">Add</Button>
            </div>
        </div>
    </CardHeader>
    <CardContent>
        <Table>
            <TableHeader>
                <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Amount</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {rows.map(lambda(row: Any) -> Any {
                    return <TableRow key={row.id}>
                        <TableCell className="font-medium">{row.name}</TableCell>
                        <TableCell><Badge variant="outline">{row.status}</Badge></TableCell>
                        <TableCell className="text-right tabular-nums">{row.amount}</TableCell>
                    </TableRow>;
                })}
            </TableBody>
        </Table>
    </CardContent>
</Card>
```

- Table always wrapped in `Card` - never a bare `<Table>`.
- Amount/number columns: `className="text-right tabular-nums"`.
- Status badge: `variant="secondary"` for active, `variant="outline"` for inactive/default.

---

### Stats row (KPI cards)

```
<div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
    <Card>
        <CardHeader>
            <div className="flex items-center justify-between">
                <CardDescription>Total Revenue</CardDescription>
                <HugeiconsIcon icon={DollarCircleIcon} strokeWidth={2} className="size-4 text-muted-foreground" />
            </div>
            <CardTitle className="text-3xl font-semibold tabular-nums">$45,231</CardTitle>
            <Badge variant="outline" className="mt-2 w-fit">
                <HugeiconsIcon icon={ArrowUpRight01Icon} strokeWidth={2} className="size-3" />
                +20.1%
            </Badge>
        </CardHeader>
        <CardContent>
            <div className="text-sm text-muted-foreground">vs last month</div>
        </CardContent>
    </Card>
</div>
```

- Stat numbers: `text-3xl font-semibold tabular-nums` (prevents layout jitter on live updates).
- Delta badges: `variant="outline"` with an arrow icon - never `text-green-500` / `text-red-500`.

---

### Pricing grid (3-tier)

```
<div className="mx-auto mt-12 grid max-w-5xl grid-cols-1 gap-6 lg:grid-cols-3">
    <Card className={cn("relative flex flex-col", isPopular and "border-primary shadow-lg ring-1 ring-primary" or "")}>
        {isPopular and <Badge className="absolute -top-3 left-1/2 -translate-x-1/2">Most Popular</Badge> or None}
        <CardHeader>
            <CardTitle>{tier.name}</CardTitle>
            <CardDescription>{tier.description}</CardDescription>
        </CardHeader>
        <CardContent className="flex-1">
            {#* feature list *#}
        </CardContent>
        <CardFooter>
            <Button className="w-full" variant={isPopular and "default" or "outline"}>{tier.cta}</Button>
        </CardFooter>
    </Card>
</div>
```

- `flex flex-col` + `flex-1` on `CardContent` keeps CTA buttons bottom-aligned across all cards.
- Popular tier: `border-primary shadow-lg ring-1 ring-primary` - never `lg:scale-105`.
- CTA always `w-full`.

---

### CTA banner (primary background)

```
<Card className="overflow-hidden bg-primary text-primary-foreground">
    <div className="grid gap-8 pt-8 pb-8 pl-8 pr-8 lg:grid-cols-[1fr_auto] lg:items-center">
        <div>
            <h2 className="text-balance text-3xl font-bold tracking-tight">Ready to ship?</h2>
            <p className="mt-4 text-lg opacity-90">No credit card required.</p>
        </div>
        <div className="flex gap-3">
            <Button size="lg" variant="secondary">Get started</Button>
            <Button size="lg" variant="outline" className="border-primary-foreground/20 text-primary-foreground hover:bg-primary-foreground/10">
                Learn more
            </Button>
        </div>
    </div>
</Card>
```

- On `bg-primary`: primary CTA button = `variant="secondary"` (default disappears on primary bg). Outline = `border-primary-foreground/20 text-primary-foreground`.
- Lead text: `opacity-90` not `text-muted-foreground` (muted tokens break on primary backgrounds).

---

### Empty state

```
<div className="flex min-h-[400px] items-center justify-center">
    <Empty>
        <EmptyHeader>
            <EmptyMedia variant="icon">
                <HugeiconsIcon icon={FolderIcon} strokeWidth={2} />
            </EmptyMedia>
            <EmptyTitle>No items yet</EmptyTitle>
            <EmptyDescription>Get started by creating your first item.</EmptyDescription>
        </EmptyHeader>
        <EmptyContent>
            <Button>Create item</Button>
        </EmptyContent>
    </Empty>
</div>
```

- Always use the full `Empty > EmptyHeader > EmptyMedia > EmptyTitle > EmptyDescription > EmptyContent` hierarchy - never a raw `<div>`.
- `EmptyMedia variant="icon"` sizes itself - do NOT pass `className="size-16"` to the inner icon.
- Error state icon: `className="text-destructive"` not `text-red-500`.
- Card-embedded: skip the `min-h-[400px]` wrapper, use `<CardContent className="pt-12 pb-12">` instead.

---

### Marketing section

```
<section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
    <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
        <div className="mx-auto max-w-2xl text-center">
            <Badge variant="outline" className="mb-4">Features</Badge>
            <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">Headline</h2>
            <p className="mt-4 text-balance text-lg text-muted-foreground">Lead copy.</p>
        </div>
        <div className="mx-auto mt-16 grid max-w-6xl grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
            {#* content items *#}
        </div>
    </div>
</section>
```

- FAQ/narrow content uses `max-w-3xl` container (not `max-w-7xl`) - answers should not sprawl.
- Feature icon containers: `bg-primary/10 text-primary` not `bg-primary` (icon disappears against solid primary bg).
- Alternating image/text rows: `lg:order-1 / lg:order-2` on the second row flips image position.
- Stars in testimonials: `fill-current text-primary` not `text-yellow-400` (semantic color only).
