---
name: jac-shadcn-blocks
description: 15 ready-to-use page block implementations for jac-shadcn projects. Copy-adapt these blocks instead of inventing UI from scratch. Load before building any marketing page, dashboard, or auth flow. Pairs with jac-shadcn-components for full component/import/theming reference.
---

## Design System Constants

Read this section first. These values must be used consistently across all blocks.

### Section padding (physical CSS only - never shorthand `py-` / `px-`)

| Section type | Classes |
|---|---|
| Hero / CTA (major page moments) | `pt-24 pb-24 sm:pt-32 sm:pb-32` |
| Mid-page (features, pricing, FAQ, testimonials) | `pt-16 pb-16 sm:pt-24 sm:pb-24` |
| Compact | `pt-12 pb-12` |
| Dashboard main (inside SidebarInset) | `pt-6 pb-6 pl-6 pr-6` |

### Inner container wrapper

All marketing sections wrap content in:

```jac
<div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
```

Dashboard variant WITHOUT sidebar uses `max-w-7xl`. Dashboard variant WITH sidebar uses NO `max-w-7xl` on `<main>` - the sidebar already constrains width.

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

```jac
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

| Wrong | Correct | Why |
|---|---|---|
| `opacity-70` on text | `text-muted-foreground` | Semantic token handles dark mode |
| `text-gray-500`, `text-zinc-400` | `text-muted-foreground` | Palette classes break theme overrides |
| `bg-white`, `bg-gray-50` | `bg-background` / `bg-card` / `bg-muted` | Raw colors don't invert in dark mode |
| `text-blue-600`, `text-orange-500` | `text-primary` | Theme-agnostic accent |
| `font-light` on headlines | `font-bold` or `font-semibold` | Light headlines read as body copy |
| `py-8` or `py-12` hero/CTA padding | `pt-24 pb-24 sm:pt-32 sm:pb-32` | Hero needs breathing room; shorthand forbidden |
| `p-4` inside a Card | `p-6` | Cards always `p-6` |
| `shadow-xl` everywhere | `shadow-sm` rest, `hover:shadow-md` interactive | Heavy shadows look dated |
| `dark:text-white`, `dark:bg-gray-900` | semantic tokens only | Tokens handle dark mode automatically |
| `mt-7`, `gap-5`, `gap-9` | `mt-8`, `gap-4`, `gap-8` | 4-unit rhythm |
| `border-2` for structural layout | `border` (hairline) only | `border-2` is for emphasis, not layout |
| `className={"base " + extra}` | `className={cn("base", extra)}` | `cn()` runs tailwind-merge deduplication |
| `py-16`, `px-4` (shorthand) | `pt-16 pb-16`, `pl-4 pr-4` (physical) | Jac codebase styling rule |
| JSX comments `{/* */}` or `# ...` inside return block | No comments inside JSX | Jac compiler error |
| `true`, `false`, `null` (lowercase) | `True`, `False`, `None` | Jac uses Python-style booleans |
| `className` on any `Sidebar*` component | wrapping `<div>` instead | jac-shadcn className spread bug wipes base styles |

---

## Block Library

Import path convention: all examples assume the file lives at `components/pages/MyPage.cl.jac`.

- `..ui.button` = `components/ui/button`
- `...lib.utils` = `lib/utils`
- Hyphenated component paths must be quoted strings: `"..ui.navigation-menu"`

---

### `hero_centered`

**Use for:** First section of any marketing or landing page. Default hero - centered text, headline, lead, two CTA buttons, optional product mockup below.
**Install:** `jac add --shadcn badge button`

```jac
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub HeroCentered(props: Any) -> JsxElement {
        return <section className="pt-24 pb-24 sm:pt-32 sm:pb-32">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="mx-auto max-w-3xl text-center">
                    <Badge variant="outline" className="mb-6 gap-1.5">
                        <span className="size-1.5 rounded-full bg-primary" />
                        {"New: v2.0 is here"}
                    </Badge>
                    <h1 className="text-balance text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
                        Ship beautiful UIs without designing from scratch
                    </h1>
                    <p className="mt-6 mx-auto max-w-2xl text-balance text-lg leading-8 text-muted-foreground">
                        A component library for Jac with 53 accessible primitives ready for your next project.
                    </p>
                    <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
                        <Button size="lg">
                            Get started
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                        </Button>
                        <Button size="lg" variant="outline">View components</Button>
                    </div>
                </div>
                <div className="mt-16 overflow-hidden rounded-xl border bg-card shadow-2xl">
                    <img src="/hero-mockup.png" alt="Product preview" className="w-full" />
                </div>
            </div>
        </section>;
    }
}
```

---

### `hero_split`

**Use for:** Landing page with product screenshot on the right. Use when you have a strong product visual. Text left, screenshot right; stacks on mobile.
**Install:** `jac add --shadcn badge button`

```jac
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub HeroSplit(props: Any) -> JsxElement {
        return <section className="pt-24 pb-24 sm:pt-32 sm:pb-32">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="grid grid-cols-1 gap-12 items-center lg:grid-cols-2">
                    <div>
                        <Badge variant="outline" className="mb-6 gap-1.5">
                            <span className="size-1.5 rounded-full bg-primary" />
                            {"For modern teams"}
                        </Badge>
                        <h1 className="text-balance text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
                            The platform built for shipping fast
                        </h1>
                        <p className="mt-6 max-w-xl text-balance text-lg leading-8 text-muted-foreground">
                            Replace your stack with a single tool. Designed for teams that ship every day.
                        </p>
                        <div className="mt-10 flex flex-wrap items-center gap-4">
                            <Button size="lg">
                                Start free trial
                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                            </Button>
                            <Button size="lg" variant="outline">Book a demo</Button>
                        </div>
                    </div>
                    <div className="overflow-hidden rounded-xl border bg-card shadow-2xl">
                        <img src="/hero-split.png" alt="Dashboard preview" className="w-full" />
                    </div>
                </div>
            </div>
        </section>;
    }
}
```

---

### `navbar_sticky`

**Use for:** Top of every marketing page. Sticky header with logo, nav links, CTA pair, mobile sheet drawer. App dashboards use `sidebar_nav` instead.
**Install:** `jac add --shadcn button sheet`

```jac
cl import from ..ui.button { Button }
cl import from ..ui.sheet { Sheet, SheetTrigger, SheetContent, SheetTitle }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Menu01Icon, Rocket01Icon }

cl {
    def:pub SiteHeader(props: Any) -> JsxElement {
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

Key gotchas: Use `sticky top-0` not `position: fixed`. Always `z-40`. Frosted glass `bg-background/95 backdrop-blur`. Mobile nav must use `Sheet` (not a custom drawer). `SheetTitle` is required - wrap `className="sr-only"` if visually hidden. Desktop nav `hidden lg:flex`, mobile trigger `lg:hidden`.

---

### `features_grid`

**Use for:** "Features / What you get / Why X" section after the hero. 3-column icon + title + description grid. Reach for this first.
**Install:** `jac add --shadcn badge` (HugeIcons always `bg-primary/10 text-primary`)

```jac
cl import from ..ui.badge { Badge }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ZapIcon, Shield01Icon, GitBranchIcon }

cl {
    def:pub FeaturesGrid(props: Any) -> JsxElement {
        return <section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Features</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Everything you need to ship
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Built for teams that want to move fast without breaking the design system.
                    </p>
                </div>

                <div className="mx-auto mt-16 grid max-w-6xl grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
                    <div className="flex flex-col gap-4">
                        <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            <HugeiconsIcon icon={ZapIcon} strokeWidth={2} className="size-5" />
                        </div>
                        <h3 className="text-lg font-semibold">Lightning fast</h3>
                        <p className="text-sm text-muted-foreground leading-relaxed">
                            Hot reload in under 50ms. No build step between you and the pixel.
                        </p>
                    </div>

                    <div className="flex flex-col gap-4">
                        <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            <HugeiconsIcon icon={Shield01Icon} strokeWidth={2} className="size-5" />
                        </div>
                        <h3 className="text-lg font-semibold">Type-safe by default</h3>
                        <p className="text-sm text-muted-foreground leading-relaxed">
                            Walker contracts and graph schemas catch mistakes before they ship.
                        </p>
                    </div>

                    <div className="flex flex-col gap-4">
                        <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-5" />
                        </div>
                        <h3 className="text-lg font-semibold">Git-native versioning</h3>
                        <p className="text-sm text-muted-foreground leading-relaxed">
                            Every save creates a commit. Roll back any change in two clicks.
                        </p>
                    </div>
                </div>
            </div>
        </section>;
    }
}
```

Icon container rule: always `bg-primary/10 text-primary` - never `bg-primary` (icon disappears) or per-card colors (looks amateur). Feature items stay left-aligned - only the section header is centered.

---

### `features_alternating`

**Use for:** "How it works" walkthroughs with a screenshot per step. Alternating image/text rows.
**Install:** `jac add --shadcn badge`

```jac
cl import from ..ui.badge { Badge }

cl {
    def:pub FeaturesAlternating(props: Any) -> JsxElement {
        return <section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="mx-auto max-w-2xl text-center">
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        How it works
                    </h2>
                </div>

                <div className="mx-auto mt-16 flex max-w-6xl flex-col gap-24">
                    <div className="grid items-center gap-12 lg:grid-cols-2">
                        <div>
                            <Badge variant="outline" className="mb-4">Step 1</Badge>
                            <h3 className="text-balance text-3xl font-bold tracking-tight">
                                Start from a template
                            </h3>
                            <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
                                Pick a curated starter or import a JacPack. Your project is live in seconds.
                            </p>
                        </div>
                        <div className="overflow-hidden rounded-xl border bg-muted aspect-video" />
                    </div>

                    <div className="grid items-center gap-12 lg:grid-cols-2">
                        <div className="overflow-hidden rounded-xl border bg-muted aspect-video lg:order-1" />
                        <div className="lg:order-2">
                            <Badge variant="outline" className="mb-4">Step 2</Badge>
                            <h3 className="text-balance text-3xl font-bold tracking-tight">
                                Edit with AI in the loop
                            </h3>
                            <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
                                JacCoder reads your project graph and ships diffs you can review inline.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </section>;
    }
}
```

Note: `lg:order-1` / `lg:order-2` on the second row flips the image to the left at `lg` breakpoint. Use a real `<img>` or `bg-muted aspect-video` placeholder for screenshots.

---

### `pricing_3tier`

**Use for:** Pricing/plans section. 3-tier comparison, center card highlighted as "Most Popular". Conversion-focused.
**Install:** `jac add --shadcn card button badge`

```jac
cl import from ...lib.utils { cn }
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick01Icon }

glob _tiers: list = [
    {
        "name": "Starter",
        "price": "0",
        "description": "For hobby projects and trying things out.",
        "features": ["Up to 3 projects", "Community support", "Basic analytics"],
        "cta": "Get started",
        "popular": False
    },
    {
        "name": "Builder",
        "price": "15",
        "description": "Everything you need to ship a real product.",
        "features": ["Unlimited projects", "Email support", "Advanced analytics", "Custom domains"],
        "cta": "Start building",
        "popular": True
    },
    {
        "name": "Pro",
        "price": "25",
        "description": "For teams that need scale and SLAs.",
        "features": ["Everything in Builder", "Priority support", "SSO + audit logs", "99.9% SLA"],
        "cta": "Contact sales",
        "popular": False
    }
];

cl {
    def:pub PricingSection(props: Any) -> JsxElement {
        return <section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Pricing</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Simple pricing that scales with you
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Start free. Upgrade when you need more.
                    </p>
                </div>

                <div className="mx-auto mt-12 grid max-w-5xl grid-cols-1 gap-6 lg:grid-cols-3 lg:gap-8">
                    {_tiers.map(lambda(tier: Any) -> Any {
                        isPopular = tier.popular;
                        return <Card className={cn(
                            "relative flex flex-col",
                            isPopular and "border-primary shadow-lg ring-1 ring-primary" or ""
                        )} key={tier.name}>
                            {isPopular and <Badge className="absolute -top-3 left-1/2 -translate-x-1/2">Most Popular</Badge> or None}
                            <CardHeader>
                                <CardTitle className="text-xl">{tier.name}</CardTitle>
                                <CardDescription>{tier.description}</CardDescription>
                                <div className="mt-4 flex items-baseline gap-1">
                                    <span className="text-4xl font-bold tracking-tight">{"$" + tier.price}</span>
                                    <span className="text-sm text-muted-foreground">/month</span>
                                </div>
                            </CardHeader>
                            <CardContent className="flex-1">
                                <ul className="flex flex-col gap-3 text-sm">
                                    {tier.features.map(lambda(feature: str) -> Any { return <li className="flex items-start gap-2" key={feature}>
                                        <HugeiconsIcon icon={Tick01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                                        <span>{feature}</span>
                                    </li>; })}
                                </ul>
                            </CardContent>
                            <CardFooter>
                                <Button className="w-full" variant={isPopular and "default" or "outline"}>{tier.cta}</Button>
                            </CardFooter>
                        </Card>;
                    })}
                </div>
            </div>
        </section>;
    }
}
```

Rules: `flex flex-col` + `flex-1` on `CardContent` keeps CTA buttons aligned at the bottom across all cards. Never `lg:scale-105` for emphasis - use `border-primary shadow-lg ring-1 ring-primary` instead. CTA always `w-full`. Stay at 3 tiers; 4 only for Enterprise/Custom.

---

### `testimonial_grid`

**Use for:** Social proof section between hero and pricing. 3-column card grid of customer quotes.
**Install:** `jac add --shadcn card avatar badge`

```jac
cl import from ..ui.card { Card }
cl import from ..ui.avatar { Avatar, AvatarImage, AvatarFallback }
cl import from ..ui.badge { Badge }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { StarIcon }

glob _testimonials: list = [
    {"quote": "Cut our build time in half. The team ships features we used to put off for months.", "name": "Sarah Chen", "title": "Engineering Lead, Acme", "avatar": "/avatars/01.png", "fallback": "SC"},
    {"quote": "The cleanest API I've worked with this year. Onboarding took an afternoon, not a week.", "name": "Marcus Webb", "title": "CTO, Northwind", "avatar": "/avatars/02.png", "fallback": "MW"},
    {"quote": "Replaced three internal tools. Our PMs ship dashboards now without bothering us.", "name": "Priya Patel", "title": "Director of Platform, Lumen", "avatar": "/avatars/03.png", "fallback": "PP"}
];

cl {
    def:pub TestimonialGrid(props: Any) -> JsxElement {
        items = props.items or _testimonials;
        return <section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Testimonials</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Loved by builders
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Teams across the world ship faster with us.
                    </p>
                </div>
                <div className="mt-16 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                    {items.map(lambda(t: Any) -> Any {
                        return <Card key={t.name} className="p-6">
                            <div className="flex items-center gap-0.5 text-primary">
                                <HugeiconsIcon icon={StarIcon} strokeWidth={2} className="size-4 fill-current" />
                                <HugeiconsIcon icon={StarIcon} strokeWidth={2} className="size-4 fill-current" />
                                <HugeiconsIcon icon={StarIcon} strokeWidth={2} className="size-4 fill-current" />
                                <HugeiconsIcon icon={StarIcon} strokeWidth={2} className="size-4 fill-current" />
                                <HugeiconsIcon icon={StarIcon} strokeWidth={2} className="size-4 fill-current" />
                            </div>
                            <p className="mt-4 text-base leading-relaxed">{t.quote}</p>
                            <div className="mt-6 flex items-center gap-3">
                                <Avatar>
                                    <AvatarImage src={t.avatar} alt={t.name} />
                                    <AvatarFallback>{t.fallback}</AvatarFallback>
                                </Avatar>
                                <div>
                                    <div className="text-sm font-semibold">{t.name}</div>
                                    <div className="text-xs text-muted-foreground">{t.title}</div>
                                </div>
                            </div>
                        </Card>;
                    })}
                </div>
            </div>
        </section>;
    }
}
```

Rules: Stars always `text-primary fill-current` - never `text-yellow-400`. Quotes stay upright (not italic). Cards use direct `p-6` (not `CardContent`) since there is no CardHeader. Always include `AvatarFallback`.

---

### `faq_accordion`

**Use for:** FAQ section, near the bottom of marketing pages above the final CTA.
**Install:** `jac add --shadcn accordion badge`

```jac
cl import from ..ui.accordion { Accordion, AccordionItem, AccordionTrigger, AccordionContent }
cl import from ..ui.badge { Badge }

cl {
    def:pub FaqSection(props: Any) -> JsxElement {
        return <section className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div className="mx-auto max-w-3xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <div className="text-center">
                    <Badge variant="outline" className="mb-4">FAQ</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        {"Frequently asked questions"}
                    </h2>
                    <p className="mt-4 text-lg text-muted-foreground">
                        Everything you need to know before getting started.
                    </p>
                </div>

                <Accordion type="single" collapsible className="mt-12">
                    <AccordionItem value="q1">
                        <AccordionTrigger className="text-left text-base font-medium">
                            Is there a free trial?
                        </AccordionTrigger>
                        <AccordionContent className="text-muted-foreground leading-relaxed">
                            Yes. All paid plans include a 14-day free trial. No credit card required.
                        </AccordionContent>
                    </AccordionItem>
                    <AccordionItem value="q2">
                        <AccordionTrigger className="text-left text-base font-medium">
                            Can I cancel anytime?
                        </AccordionTrigger>
                        <AccordionContent className="text-muted-foreground leading-relaxed">
                            Yes. Cancel from settings. Access continues through the end of the billing period.
                        </AccordionContent>
                    </AccordionItem>
                    <AccordionItem value="q3">
                        <AccordionTrigger className="text-left text-base font-medium">
                            Do you offer team plans?
                        </AccordionTrigger>
                        <AccordionContent className="text-muted-foreground leading-relaxed">
                            Yes. Team plans include SSO, audit logs, and priority support. Contact sales for pricing.
                        </AccordionContent>
                    </AccordionItem>
                </Accordion>

                <div className="mt-16 text-center">
                    <p className="text-lg text-muted-foreground">
                        {"Can't find what you're looking for? "}
                        <a href="/contact" className="font-medium text-foreground underline-offset-4 hover:underline">
                            Contact support
                        </a>
                        .
                    </p>
                </div>
            </div>
        </section>;
    }
}
```

Rules: `max-w-3xl` container (not `max-w-7xl`) - answer lines must not sprawl. `type="single" collapsible` for short FAQ. AccordionContent uses `text-muted-foreground` so the question wins visual hierarchy. Escape hatch uses inline `<a>` not a `Button`. Strings with `?` or `'` must be wrapped: `{"Can't find what you're looking for?"}`.

---

### `cta_centered`

**Use for:** Final conversion section, last block before the footer. Inverted card panel (default) or plain centered.
**Install:** `jac add --shadcn card button`

```jac
cl import from ..ui.card { Card }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub FinalCta(props: Any) -> JsxElement {
        return <section className="pt-24 pb-24 sm:pt-32 sm:pb-32">
            <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
                <Card className="overflow-hidden bg-primary text-primary-foreground">
                    <div className="grid gap-8 pt-8 pb-8 pl-8 pr-8 sm:pt-12 sm:pb-12 sm:pl-12 sm:pr-12 lg:grid-cols-[1fr_auto] lg:items-center">
                        <div>
                            <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                                Ready to ship faster?
                            </h2>
                            <p className="mt-4 text-lg opacity-90">
                                Start building today. No credit card required.
                            </p>
                        </div>
                        <div className="flex flex-wrap gap-3">
                            <Button size="lg" variant="secondary">
                                Get started
                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                            </Button>
                            <Button size="lg" variant="outline" className="border-primary-foreground/20 text-primary-foreground hover:bg-primary-foreground/10">
                                Talk to sales
                            </Button>
                        </div>
                    </div>
                </Card>
            </div>
        </section>;
    }
}
```

Rules: Primary CTA on inverted bg = `variant="secondary"` (not `variant="default"` - it disappears). Outline button on inverted bg needs `border-primary-foreground/20 text-primary-foreground hover:bg-primary-foreground/10`. Always `size="lg"` - this is the biggest button on the page. Lead paragraph uses `opacity-90` not `text-muted-foreground` (muted tokens don't work on `bg-primary`).

---

### `footer_4col`

**Use for:** Bottom of every marketing page. 4-column with logo, social links, 3 nav columns, separator, bottom bar.
**Install:** `jac add --shadcn button separator`

```jac
cl import from ..ui.button { Button }
cl import from ..ui.separator { Separator }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    GithubIcon, TwitterIcon, Linkedin01Icon, CubeIcon
}

cl {
    def:pub FooterFourColumn(props: Any) -> JsxElement {
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

Rules: Logo column is `2fr`, link columns are `1fr` each - use `lg:grid-cols-[2fr_1fr_1fr_1fr]` NOT `lg:grid-cols-4`. Social icons `variant="ghost" size="icon"`. Use `<Separator />` (not `<hr>` or `<div>`). Copyright in `{"© 2026..."}` braces. Bottom text is `text-xs`. No heavy `bg-muted` background - share `bg-background` with the page.

---

### `sidebar_nav`

**Use for:** App shell for authenticated product surfaces (dashboards, admin panels, IDEs). NOT for marketing pages.
**Install:** `jac add --shadcn sidebar card badge separator breadcrumb`

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
    def:pub AppShell(props: Any) -> JsxElement {
        has activeRoute: str = props.activeRoute or "overview";

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
                    {props.children}
                </main>
            </SidebarInset>
        </SidebarProvider>;
    }
}
```

Rules: `SidebarInset` main area uses `pt-6 pb-6 pl-6 pr-6` (tight dashboard rhythm - not `pt-24`). NO `max-w-7xl` inside `SidebarInset`. Always include `<Separator orientation="vertical" className="mr-2 h-4" />` between `SidebarTrigger` and breadcrumb. Pass `collapsible="offcanvas"` (collapses to hidden) or `collapsible="icon"` (collapses to icon rail). For the icon-collapsible variant with team switcher and dropdown menus, see `examples/sidebar-07.cl.jac`.

---

### `stats_row`

**Use for:** KPI metrics row at the top of a dashboard main area. 4 cards in a responsive grid.
**Install:** `jac add --shadcn card badge`

```jac
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
cl import from ..ui.badge { Badge }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    ArrowUpRight01Icon, ArrowDownRight01Icon, DollarCircleIcon,
    UserGroupIcon, ChartLineData01Icon, Activity01Icon
}

cl {
    def:pub StatsGrid(props: Any) -> JsxElement {
        stats = props.stats or [
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

Rules: Stat numbers always `text-3xl font-semibold tabular-nums` (prevents layout jitter on updates). Use `Badge variant="outline"` with arrow icon for deltas - never `text-green-500` / `text-red-500`. Card hierarchy: `CardDescription` (label) > `CardTitle` (number) > `Badge` (delta) > `CardContent` (caption). Drop `stats_row` directly inside `sidebar_nav` main area.

---

### `data_table_page`

**Use for:** Full-page data list inside an app shell (customers, orders, projects). Sidebar shell with card-wrapped table, search input, status badges, row action menus.
**Install:** `jac add --shadcn sidebar card table badge button input separator`

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
    def:pub DataTablePage(props: Any) -> JsxElement {
        has search: str = "";
        rows = props.rows or [];

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

Rules: Same `SidebarInset` / `border-b` / `h-14` header pattern as `sidebar_nav`. No `max-w-*` inside `SidebarInset` main. Table wraps in a `Card` - never bare table. Amount column uses `text-right tabular-nums`. For a more advanced sidebar with team switcher and dropdown menus, see `examples/sidebar-07.cl.jac` and `examples/dashboard-01.cl.jac`.

---

### `empty_state`

**Use for:** Zero-item list views, first-run experiences, failed network requests.
**Install:** `jac add --shadcn empty button`

```jac
cl import from ...ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription, EmptyContent }
cl import from ...ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { FolderIcon, PlusSignIcon, Search01Icon, Alert02Icon, RefreshIcon }

cl {
    def:pub ProjectsEmpty(props: Any) -> JsxElement {
        onCreate = props.onCreate;
        return <div className="flex min-h-[400px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={FolderIcon} strokeWidth={2} />
                    </EmptyMedia>
                    <EmptyTitle>No projects yet</EmptyTitle>
                    <EmptyDescription>
                        Get started by creating your first project.
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <Button onClick={onCreate}>
                        <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-4" />
                        Create project
                    </Button>
                </EmptyContent>
            </Empty>
        </div>;
    }

    def:pub SearchEmpty(props: Any) -> JsxElement {
        searchTerm = props.searchTerm or "";
        clearSearch = props.onClear;
        return <div className="flex min-h-[320px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={Search01Icon} strokeWidth={2} />
                    </EmptyMedia>
                    <EmptyTitle>No results found</EmptyTitle>
                    <EmptyDescription>
                        {"We couldn't find anything matching "}
                        <span className="font-medium text-foreground">{searchTerm}</span>
                        {". Try a different search term."}
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <Button variant="outline" onClick={clearSearch}>
                        Clear search
                    </Button>
                </EmptyContent>
            </Empty>
        </div>;
    }

    def:pub ErrorEmpty(props: Any) -> JsxElement {
        retry = props.onRetry;
        return <div className="flex min-h-[400px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="text-destructive" />
                    </EmptyMedia>
                    <EmptyTitle>Something went wrong</EmptyTitle>
                    <EmptyDescription>
                        {"We couldn't load your data. Check your connection and try again."}
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <div className="flex flex-wrap items-center justify-center gap-3">
                        <Button onClick={retry}>
                            <HugeiconsIcon icon={RefreshIcon} strokeWidth={2} className="size-4" />
                            Retry
                        </Button>
                        <Button variant="ghost" asChild={True}>
                            <a href="/support">Contact support</a>
                        </Button>
                    </div>
                </EmptyContent>
            </Empty>
        </div>;
    }
}
```

Rules: Always use `Empty` + `EmptyHeader` + `EmptyMedia` + `EmptyTitle` + `EmptyDescription` + `EmptyContent` - never raw `<div>`. `EmptyMedia variant="icon"` handles size and muted ring - do NOT pass `className="size-16"` to the inner icon. Error state uses `text-destructive` not `text-red-500`. Page-level empty states need `min-h-[400px]` wrapper. When embedded inside an existing Card, skip the min-h wrapper and use `CardContent className="pt-12 pb-12"` instead.

---

### `auth_card_centered`

**Note:** The fullstack jac-shadcn template already includes `pages/LoginPage.cl.jac` and `pages/SignupPage.cl.jac`. Copy-adapt those files rather than building from scratch.

For the jac-shadcn auth pattern with `Input`, `Label`/`Field`, `Button`, and error handling, see the `## jac-shadcn form pattern` section in the `jac-cl-auth` skill.

**Install check:** `jac add --shadcn input button card separator field` (button and card are usually already present).

**Key rules for auth pages:**

- Auth pages center a card in `min-h-svh` - NOT a `pt-24` marketing section.
- Card width is `max-w-sm` (narrow, focused). Never `max-w-md`.
- Submit button always `w-full type="submit"`.
- SSO buttons use `variant="outline"` only - never brand colors.
- Strings with apostrophes or `?` must be wrapped: `{"Don't have an account?"}`.
- No `tracking-wide` or uppercase on card title. Keep sentence-case `text-2xl`.
- Every auth page has a footer link to the opposite flow (sign-in links to sign-up and vice versa).

**Minimal login card reference:**

```jac
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
cl import from ..ui.input { Input }
cl import from ..ui.button { Button }
cl import from ..ui.field { Field, FieldLabel }

cl {
    def:pub LoginPage(props: Any) -> JsxElement {
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

For the full auth flow with `jacLogin`, `jacSignup`, async handlers, and 3-step registration, see `jac-cl-auth` skill.

---

## Block -> Component Mapping Table

UIDesignerAgent: use this table to populate `UISpec.components`. List only primary components - `jac add --shadcn` resolves peer dependencies automatically.

| Block | Primary jac-shadcn components | `jac add --shadcn` command |
|---|---|---|
| `hero_centered` | badge, button | `jac add --shadcn badge button` |
| `hero_split` | badge, button | `jac add --shadcn badge button` |
| `navbar_sticky` | button, sheet | `jac add --shadcn button sheet` |
| `features_grid` | badge | `jac add --shadcn badge` |
| `features_alternating` | badge | `jac add --shadcn badge` |
| `pricing_3tier` | card, badge, button | `jac add --shadcn card badge button` |
| `testimonial_grid` | card, avatar, badge | `jac add --shadcn card avatar badge` |
| `faq_accordion` | accordion, badge | `jac add --shadcn accordion badge` |
| `cta_centered` | card, button | `jac add --shadcn card button` |
| `footer_4col` | button, separator | `jac add --shadcn button separator` |
| `sidebar_nav` | sidebar, separator, breadcrumb | `jac add --shadcn sidebar` (sidebar resolves all peers) |
| `stats_row` | card, badge | `jac add --shadcn card badge` |
| `data_table_page` | sidebar, card, table, badge, button, input | `jac add --shadcn sidebar card table badge button input` |
| `empty_state` | empty, button | `jac add --shadcn empty button` |
| `auth_card_centered` | card, input, button, field | `jac add --shadcn card input button field` |

---

## Typical Component Sets by App Type

Quick-reference for UIDesignerAgent when populating `UISpec.components`.

| App type | Typical blocks | Typical components |
|---|---|---|
| `saas` (marketing + app) | navbar, hero, features, pricing, testimonials, faq, cta, footer, sidebar, stats | badge, button, card, sidebar, table, input, avatar, separator, accordion |
| `dashboard` (app-only) | sidebar, stats, data-table, empty-state | sidebar, card, table, badge, button, input, separator, breadcrumb |
| `landing` (marketing only) | navbar, hero, features, testimonials, cta, footer | badge, button, card, avatar, separator |
| `web-app` (auth + pages) | navbar, hero, cta, footer, auth-card, sidebar | button, card, input, field, sidebar, badge |
| `tool` (focused utility) | navbar, sidebar, stats, data-table, empty-state | sidebar, table, input, badge, button, card |
| `blog` / `content` | navbar, hero, features, faq, footer | badge, button, card, separator, avatar |

---

## Full Page Composition Examples

### Marketing landing page (typical order)

```
SiteHeader (navbar_sticky)
  HeroCentered (hero_centered)
  FeaturesGrid (features_grid)
  TestimonialGrid (testimonial_grid)
  PricingSection (pricing_3tier)
  FaqSection (faq_accordion)
  FinalCta (cta_centered)
FooterFourColumn (footer_4col)
```

### SaaS app shell (authenticated)

```
AppShell (sidebar_nav) wrapping:
  StatsGrid (stats_row)
  [ChartCard or table]
  [DataTablePage for list routes]
  [ProjectsEmpty when no data]
```

### Auth flow (standalone pages, not inside shell)

```
LoginPage or SignupPage (auth_card_centered)
  - Full-viewport centered card
  - No navbar, no footer
  - Redirect to dashboard on success
```
