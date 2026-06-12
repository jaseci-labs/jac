---
name: jac-shadcn-blocks-app
description: 6 app shell and dashboard blocks for jac-shadcn (site header/navbar, footer, sidebar app shell, stats grid, data table, login page). Load when building app navigation, a dashboard, or an auth page. Always load jac-shadcn-blocks first for design system constants and anti-patterns.
---

All examples assume `components/pages/MyPage.cl.jac`. `..ui.X` = `components/ui/X`, `...lib.utils` = `lib/utils`. Hyphenated paths must be quoted strings.

---

### `navbar_sticky`

**Use for:** Top of every marketing page. Sticky header with logo, nav links, CTA pair, mobile sheet drawer. App dashboards use `sidebar_nav` instead.

```jac
cl import from ..ui.button { Button }
cl import from ..ui.sheet { Sheet, SheetTrigger, SheetContent, SheetTitle }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Menu01Icon, Rocket01Icon }

cl {
    def:pub SiteHeader() -> JsxElement {
        has mobileOpen: bool = False;
        return <header className="sticky top-0 z-40 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
            <div className="mx-auto max-w-7xl flex h-16 items-center justify-between pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <a href="/" className="flex items-center gap-2 font-semibold">
                    <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-5 text-primary" />
                    <span>Acme</span>
                </a>
                <nav className="hidden lg:flex lg:items-center lg:gap-6">
                    <a href="/features" className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground">Features</a>
                    <a href="/pricing" className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground">Pricing</a>
                    <a href="/docs" className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground">Docs</a>
                    <a href="/blog" className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground">Blog</a>
                </nav>
                <div className="flex items-center gap-2">
                    <Button variant="ghost" size="sm" className="hidden lg:inline-flex">Sign in</Button>
                    <Button size="sm" className="hidden lg:inline-flex">Get started</Button>
                    <Sheet open={mobileOpen} onOpenChange={lambda(v: bool) -> None { mobileOpen = v; }}>
                        <SheetTrigger asChild={True}>
                            <Button variant="ghost" size="icon" className="lg:hidden">
                                <HugeiconsIcon icon={Menu01Icon} strokeWidth={2} className="size-5" />
                            </Button>
                        </SheetTrigger>
                        <SheetContent side="right" className="w-72">
                            <SheetTitle className="sr-only">Navigation</SheetTitle>
                            <nav className="flex flex-col gap-4 pt-8">
                                <a href="/features" className="text-base font-medium text-foreground">Features</a>
                                <a href="/pricing" className="text-base font-medium text-foreground">Pricing</a>
                                <a href="/docs" className="text-base font-medium text-foreground">Docs</a>
                                <a href="/blog" className="text-base font-medium text-foreground">Blog</a>
                                <Button variant="outline" className="mt-4">Sign in</Button>
                                <Button>Get started</Button>
                            </nav>
                        </SheetContent>
                    </Sheet>
                </div>
            </div>
        </header>;
    }
}
```

`sticky top-0` not `position: fixed`. Always `z-40`. Frosted glass: `bg-background/95 backdrop-blur`. Mobile nav must use `Sheet` (not a custom drawer). `SheetTitle` is required - wrap in `className="sr-only"` if visually hidden. Desktop nav `hidden lg:flex`, mobile trigger `lg:hidden`.

---

### `footer_4col`

**Use for:** Bottom of every marketing page. 4-column with logo, social links, 3 nav columns, separator, bottom bar.

```jac
cl import from ..ui.button { Button }
cl import from ..ui.separator { Separator }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    GithubIcon, TwitterIcon, Linkedin01Icon, CubeIcon
}

cl {
    def:pub FooterFourColumn() -> JsxElement {
        return <footer className="border-t">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8 pt-16 pb-16">
                <div className="grid gap-8 lg:grid-cols-[2fr_1fr_1fr_1fr]">
                    <div>
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={CubeIcon} strokeWidth={2} className="size-6 text-primary" />
                            <span className="text-base font-semibold">Acme</span>
                        </div>
                        <p className="mt-4 max-w-xs text-sm text-muted-foreground">
                            Ship beautiful UIs without designing from scratch.
                        </p>
                        <div className="mt-6 flex gap-2">
                            <Button variant="ghost" size="icon" aria-label="GitHub">
                                <HugeiconsIcon icon={GithubIcon} strokeWidth={2} className="size-4" />
                            </Button>
                            <Button variant="ghost" size="icon" aria-label="Twitter">
                                <HugeiconsIcon icon={TwitterIcon} strokeWidth={2} className="size-4" />
                            </Button>
                            <Button variant="ghost" size="icon" aria-label="LinkedIn">
                                <HugeiconsIcon icon={Linkedin01Icon} strokeWidth={2} className="size-4" />
                            </Button>
                        </div>
                    </div>
                    <div>
                        <h3 className="text-sm font-semibold">Product</h3>
                        <ul className="mt-4 flex flex-col gap-3">
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Features</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Pricing</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Changelog</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Roadmap</a></li>
                        </ul>
                    </div>
                    <div>
                        <h3 className="text-sm font-semibold">Company</h3>
                        <ul className="mt-4 flex flex-col gap-3">
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">About</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Blog</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Careers</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Contact</a></li>
                        </ul>
                    </div>
                    <div>
                        <h3 className="text-sm font-semibold">Resources</h3>
                        <ul className="mt-4 flex flex-col gap-3">
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Docs</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Guides</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Support</a></li>
                            <li><a href="#" className="text-sm text-muted-foreground transition-colors hover:text-foreground">Status</a></li>
                        </ul>
                    </div>
                </div>
                <Separator className="mt-8 mb-8" />
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <p className="text-xs text-muted-foreground">
                        {"© 2026 Acme, Inc. All rights reserved."}
                    </p>
                    <div className="flex gap-6">
                        <a href="#" className="text-xs text-muted-foreground transition-colors hover:text-foreground">Privacy</a>
                        <a href="#" className="text-xs text-muted-foreground transition-colors hover:text-foreground">Terms</a>
                        <a href="#" className="text-xs text-muted-foreground transition-colors hover:text-foreground">Cookies</a>
                    </div>
                </div>
            </div>
        </footer>;
    }
}
```

Logo column is `2fr`, link columns `1fr` each - `lg:grid-cols-[2fr_1fr_1fr_1fr]` NOT `lg:grid-cols-4`. Social icons `variant="ghost" size="icon"`. Use `<Separator />` not `<hr>`. Copyright in `{"© 2026..."}` braces. Bottom text `text-xs`. No `bg-muted` background - shares `bg-background` with page.

---

### `sidebar_nav`

**Use for:** App shell for authenticated product surfaces (dashboards, admin panels). NOT for marketing pages.

> CRITICAL: NEVER pass `className` to any `Sidebar*` component. jac-shadcn's spread ordering bug wipes base styles. Use a wrapping `<div>` for layout overrides instead.

```jac
cl import from ...lib.utils { cn }
cl import from ..ui.sidebar {
    SidebarProvider, Sidebar, SidebarContent, SidebarHeader, SidebarFooter,
    SidebarMenu, SidebarMenuItem, SidebarMenuButton, SidebarTrigger, SidebarInset,
    SidebarGroup, SidebarGroupLabel
}
cl import from ..ui.separator { Separator }
cl import from ..ui.breadcrumb {
    Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbLink,
    BreadcrumbPage, BreadcrumbSeparator
}
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    DashboardSquare01Icon, ChartLineData01Icon, UserGroupIcon, Settings05Icon
}

cl {
    def:pub AppShell(activeRoute: str = "overview", children: any = None) -> JsxElement {

        navItems = [
            {"id": "overview", "label": "Overview", "icon": DashboardSquare01Icon},
            {"id": "analytics", "label": "Analytics", "icon": ChartLineData01Icon},
            {"id": "customers", "label": "Customers", "icon": UserGroupIcon},
            {"id": "settings", "label": "Settings", "icon": Settings05Icon}
        ];

        return <SidebarProvider>
            <Sidebar collapsible="offcanvas">
                <SidebarHeader>
                    <div className="flex items-center gap-2 pl-2 pr-2 pt-2">
                        <div className="flex size-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
                            <HugeiconsIcon icon={DashboardSquare01Icon} strokeWidth={2} className="size-4" />
                        </div>
                        <span className="text-sm font-semibold">Acme Inc</span>
                    </div>
                </SidebarHeader>
                <SidebarContent>
                    <SidebarGroup>
                        <SidebarGroupLabel>Platform</SidebarGroupLabel>
                        <SidebarMenu>
                            {navItems.map(lambda(item: Any) -> Any {
                                itemIcon = item.icon;
                                isActive = item.id == activeRoute;
                                return <SidebarMenuItem key={item.id}>
                                    <SidebarMenuButton asChild={True} isActive={isActive}>
                                        <a href={"/" + item.id}>
                                            <HugeiconsIcon icon={itemIcon} strokeWidth={2} className="size-4" />
                                            <span>{item.label}</span>
                                        </a>
                                    </SidebarMenuButton>
                                </SidebarMenuItem>;
                            })}
                        </SidebarMenu>
                    </SidebarGroup>
                </SidebarContent>
                <SidebarFooter>
                    <div className="flex items-center gap-2 pl-2 pr-2 pb-2">
                        <div className="flex size-8 items-center justify-center rounded-full bg-muted text-xs font-medium">JD</div>
                        <span className="text-sm font-medium">Jane Doe</span>
                    </div>
                </SidebarFooter>
            </Sidebar>
            <SidebarInset>
                <header className="flex h-14 items-center gap-2 border-b pl-4 pr-4">
                    <SidebarTrigger />
                    <Separator orientation="vertical" className="mr-2 h-4" />
                    <Breadcrumb>
                        <BreadcrumbList>
                            <BreadcrumbItem>
                                <BreadcrumbLink href="/overview">Dashboard</BreadcrumbLink>
                            </BreadcrumbItem>
                            <BreadcrumbSeparator />
                            <BreadcrumbItem>
                                <BreadcrumbPage>Overview</BreadcrumbPage>
                            </BreadcrumbItem>
                        </BreadcrumbList>
                    </Breadcrumb>
                </header>
                <main className="flex flex-1 flex-col gap-6 pt-6 pb-6 pl-6 pr-6">
                    {children}
                </main>
            </SidebarInset>
        </SidebarProvider>;
    }
}
```

`SidebarInset` main uses `pt-6 pb-6 pl-6 pr-6` (dashboard rhythm, not `pt-24`). NO `max-w-*` inside `SidebarInset`. Always include `<Separator orientation="vertical" className="mr-2 h-4" />` between `SidebarTrigger` and breadcrumb. `collapsible="offcanvas"` collapses to hidden; `collapsible="icon"` collapses to icon rail.

---

### `stats_row`

**Use for:** KPI metrics row at the top of a dashboard. 4 cards in a responsive grid.

```jac
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
cl import from ..ui.badge { Badge }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    ArrowUpRight01Icon, ArrowDownRight01Icon, DollarCircleIcon,
    UserGroupIcon, ChartLineData01Icon, Activity01Icon
}

cl {
    def:pub StatsGrid(stats: list = []) -> JsxElement {
        stats = stats or [
            {"label": "Total Revenue", "value": "$45,231.89", "change": "+20.1%", "trend": "up", "icon": DollarCircleIcon, "caption": "vs last month"},
            {"label": "Active Users", "value": "+2,350", "change": "+15.3%", "trend": "up", "icon": UserGroupIcon, "caption": "vs last month"},
            {"label": "Conversion", "value": "3.24%", "change": "-2.1%", "trend": "down", "icon": ChartLineData01Icon, "caption": "vs last month"},
            {"label": "Active Now", "value": "+573", "change": "+201", "trend": "up", "icon": Activity01Icon, "caption": "since last hour"}
        ];

        return <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
            {stats.map(lambda(stat: Any) -> Any {
                isUp = stat.trend == "up";
                arrowIcon = isUp and ArrowUpRight01Icon or ArrowDownRight01Icon;
                statIcon = stat.icon;
                return <Card key={stat.label}>
                    <CardHeader>
                        <div className="flex items-center justify-between">
                            <CardDescription>{stat.label}</CardDescription>
                            <HugeiconsIcon icon={statIcon} strokeWidth={2} className="size-4 text-muted-foreground" />
                        </div>
                        <CardTitle className="text-3xl font-semibold tabular-nums">{stat.value}</CardTitle>
                        <Badge variant="outline" className="mt-2 w-fit">
                            <HugeiconsIcon icon={arrowIcon} strokeWidth={2} className="size-3" />
                            <span className="tabular-nums">{stat.change}</span>
                        </Badge>
                    </CardHeader>
                    <CardContent>
                        <div className="text-sm text-muted-foreground">{stat.caption}</div>
                    </CardContent>
                </Card>;
            })}
        </div>;
    }
}
```

Stat numbers always `text-3xl font-semibold tabular-nums` (prevents layout jitter on updates). Use `Badge variant="outline"` with arrow icon for deltas - never `text-green-500` / `text-red-500`. Drop inside `sidebar_nav` main area directly.

---

### `data_table_page`

**Use for:** Full-page data list inside an app shell (customers, orders, projects). Card-wrapped table, search input, status badges, row action menus.

```jac
cl import from ..ui.sidebar {
    SidebarProvider, Sidebar, SidebarContent, SidebarHeader,
    SidebarMenu, SidebarMenuItem, SidebarMenuButton, SidebarTrigger, SidebarInset
}
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
cl import from ..ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from ..ui.input { Input }
cl import from ..ui.separator { Separator }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { UserGroupIcon, Add01Icon, Search01Icon, MoreHorizontalIcon }

cl {
    def:pub DataTablePage(rows: list = []) -> JsxElement {
        has search: str = "";

        return <SidebarProvider>
            <Sidebar>
                <SidebarHeader>
                    <div className="pl-2 pr-2 pt-2 text-sm font-semibold">Acme Inc</div>
                </SidebarHeader>
                <SidebarContent>
                    <SidebarMenu>
                        <SidebarMenuItem>
                            <SidebarMenuButton isActive={True}>
                                <HugeiconsIcon icon={UserGroupIcon} strokeWidth={2} className="size-4" />
                                <span>Customers</span>
                            </SidebarMenuButton>
                        </SidebarMenuItem>
                    </SidebarMenu>
                </SidebarContent>
            </Sidebar>
            <SidebarInset>
                <header className="flex h-14 items-center gap-2 border-b pl-4 pr-4">
                    <SidebarTrigger />
                    <Separator orientation="vertical" className="mr-2 h-4" />
                    <span className="text-sm font-medium">Customers</span>
                    <div className="flex-1" />
                    <Button size="sm">
                        <HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="size-4" />
                        Add customer
                    </Button>
                </header>
                <main className="flex flex-1 flex-col gap-6 pt-6 pb-6 pl-6 pr-6">
                    <Card>
                        <CardHeader>
                            <div className="flex items-center justify-between">
                                <div>
                                    <CardTitle>Customers</CardTitle>
                                    <CardDescription>Manage your customer accounts.</CardDescription>
                                </div>
                                <div className="flex items-center gap-2">
                                    <div className="relative">
                                        <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
                                        <Input
                                            placeholder="Search customers..."
                                            value={search}
                                            onInput={lambda e: Any { search = e.target.value; }}
                                            className="pl-8 w-64"
                                        />
                                    </div>
                                </div>
                            </div>
                        </CardHeader>
                        <CardContent>
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Name</TableHead>
                                        <TableHead>Email</TableHead>
                                        <TableHead>Status</TableHead>
                                        <TableHead className="text-right">Amount</TableHead>
                                        <TableHead className="w-12" />
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {rows.map(lambda(row: Any) -> Any {
                                        statusVariant = row.status == "active" and "secondary" or "outline";
                                        return <TableRow key={row.id}>
                                            <TableCell className="font-medium">{row.name}</TableCell>
                                            <TableCell className="text-muted-foreground">{row.email}</TableCell>
                                            <TableCell>
                                                <Badge variant={statusVariant}>{row.status}</Badge>
                                            </TableCell>
                                            <TableCell className="text-right tabular-nums">{row.amount}</TableCell>
                                            <TableCell>
                                                <Button variant="ghost" size="icon">
                                                    <HugeiconsIcon icon={MoreHorizontalIcon} strokeWidth={2} className="size-4" />
                                                </Button>
                                            </TableCell>
                                        </TableRow>;
                                    })}
                                </TableBody>
                            </Table>
                        </CardContent>
                    </Card>
                </main>
            </SidebarInset>
        </SidebarProvider>;
    }
}
```

Same `SidebarInset` / `border-b` / `h-14` header pattern as `sidebar_nav`. No `max-w-*` inside `SidebarInset` main. Table wraps in a `Card` - never bare table. Amount column uses `text-right tabular-nums`.

---

### `auth_card_centered`

**Note:** The fullstack jac-shadcn template already includes `pages/LoginPage.cl.jac` and `pages/SignupPage.cl.jac`. Copy-adapt those files rather than building from scratch.

**Key rules for auth pages:**

- Auth pages center a card in `min-h-svh` - NOT a `pt-24` marketing section.
- Card width is `max-w-sm` (narrow, focused). Never `max-w-md`.
- Submit button always `w-full type="submit"`.
- SSO buttons use `variant="outline"` only - never brand colors.
- Strings with apostrophes or `?` must be wrapped: `{"Don't have an account?"}`.
- No `tracking-wide` or uppercase on card title. Sentence-case `text-2xl`.
- Every auth page has a footer link to the opposite flow (sign-in links to sign-up and vice versa).

```jac
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
cl import from ..ui.input { Input }
cl import from ..ui.button { Button }
cl import from ..ui.field { Field, FieldLabel }

cl {
    def:pub LoginPage() -> JsxElement {
        return <div className="flex min-h-svh items-center justify-center pt-12 pb-12 pl-4 pr-4">
            <Card className="w-full max-w-sm">
                <CardHeader>
                    <CardTitle className="text-2xl">Sign in</CardTitle>
                    <CardDescription>Enter your email to access your account.</CardDescription>
                </CardHeader>
                <CardContent>
                    <form className="flex flex-col gap-6">
                        <Field>
                            <FieldLabel htmlFor="email">Email</FieldLabel>
                            <Input id="email" type="email" placeholder="m@example.com" required />
                        </Field>
                        <Field>
                            <div className="flex items-center">
                                <FieldLabel htmlFor="password">Password</FieldLabel>
                                <a href="/forgot" className="ml-auto text-sm underline-offset-4 hover:underline">
                                    {"Forgot your password?"}
                                </a>
                            </div>
                            <Input id="password" type="password" required />
                        </Field>
                        <Button type="submit" className="w-full">Sign in</Button>
                    </form>
                </CardContent>
                <CardFooter>
                    <p className="w-full text-center text-sm text-muted-foreground">
                        {"Don't have an account?"} <a href="/signup" className="text-foreground underline-offset-4 hover:underline">Sign up</a>
                    </p>
                </CardFooter>
            </Card>
        </div>;
    }
}
```

For the full auth flow with `jacLogin`, `jacSignup`, async handlers, and 3-step registration, see `jac-cl-auth`.
