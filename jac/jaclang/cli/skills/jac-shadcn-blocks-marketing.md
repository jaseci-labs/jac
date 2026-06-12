---
name: jac-shadcn-blocks-marketing
description: 8 marketing and landing page blocks for jac-shadcn (hero x2, features x2, pricing, testimonials, FAQ, final CTA). Load when building a landing page or any marketing section. Always load jac-shadcn-blocks first for design system constants and anti-patterns.
---

All examples assume `components/pages/MyPage.cl.jac`. `..ui.X` = `components/ui/X`, `...lib.utils` = `lib/utils`. Hyphenated paths must be quoted strings.

---

### `hero_centered`

**Use for:** First section of any marketing page. Centered text, headline, lead, two CTA buttons, optional product mockup.

```jac
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub HeroCentered() -> JsxElement {
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

**Use for:** Landing page with a strong product visual. Text left, screenshot right; stacks on mobile.

```jac
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub HeroSplit() -> JsxElement {
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

### `features_grid`

**Use for:** "Features / What you get" section after the hero. 3-column icon + title + description grid.

```jac
cl import from ..ui.badge { Badge }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ZapIcon, Shield01Icon, GitBranchIcon }

cl {
    def:pub FeaturesGrid() -> JsxElement {
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

Icon containers: always `bg-primary/10 text-primary` - never `bg-primary` (icon vanishes) or per-card accent colors. Items stay left-aligned; only the section header is centered.

---

### `features_alternating`

**Use for:** "How it works" walkthrough with a screenshot per step. Alternating image/text rows.

```jac
cl import from ..ui.badge { Badge }

cl {
    def:pub FeaturesAlternating() -> JsxElement {
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

`lg:order-1 / lg:order-2` on the second row flips the image left at `lg`. Replace `bg-muted aspect-video` placeholders with real `<img>` in production.

---

### `testimonial_grid`

**Use for:** Social proof between hero and pricing. 3-column card grid of customer quotes.

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
    def:pub TestimonialGrid(items: list = []) -> JsxElement {
        items = items or _testimonials;
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

Stars: `text-primary fill-current` - never `text-yellow-400`. Cards use `p-6` directly (no `CardHeader`, so don't wrap in `CardContent`). Always include `AvatarFallback`.

---

### `pricing_3tier`

**Use for:** Pricing section. 3-tier comparison, center card highlighted as "Most Popular".

```jac
cl import from ...lib.utils { cn }
cl import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
cl import from ..ui.badge { Badge }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick01Icon }

glob _tiers: list = [
    {"name": "Starter", "price": "0", "description": "For hobby projects and trying things out.", "features": ["Up to 3 projects", "Community support", "Basic analytics"], "cta": "Get started", "popular": False},
    {"name": "Builder", "price": "15", "description": "Everything you need to ship a real product.", "features": ["Unlimited projects", "Email support", "Advanced analytics", "Custom domains"], "cta": "Start building", "popular": True},
    {"name": "Pro", "price": "25", "description": "For teams that need scale and SLAs.", "features": ["Everything in Builder", "Priority support", "SSO + audit logs", "99.9% SLA"], "cta": "Contact sales", "popular": False}
];

cl {
    def:pub PricingSection() -> JsxElement {
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
                                    {tier.features.map(lambda(f: str) -> Any { return <li className="flex items-start gap-2" key={f}>
                                        <HugeiconsIcon icon={Tick01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                                        <span>{f}</span>
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

`flex flex-col` + `flex-1` on `CardContent` keeps CTA buttons bottom-aligned across all cards. Popular emphasis: `border-primary shadow-lg ring-1 ring-primary` - never `lg:scale-105`. CTA always `w-full`.

---

### `faq_accordion`

**Use for:** FAQ section near the bottom of marketing pages, above the final CTA.

```jac
cl import from ..ui.accordion { Accordion, AccordionItem, AccordionTrigger, AccordionContent }
cl import from ..ui.badge { Badge }

cl {
    def:pub FaqSection() -> JsxElement {
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

Container is `max-w-3xl` (not `max-w-7xl`) - answers shouldn't sprawl. Strings with `'` or `?` must be in braces: `{"Can't find what you're looking for?"}`.

---

### `cta_centered`

**Use for:** Final conversion section, last block before the footer.

```jac
cl import from ..ui.card { Card }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

cl {
    def:pub FinalCta() -> JsxElement {
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

On `bg-primary`: primary CTA = `variant="secondary"` (default disappears on primary bg), outline = `border-primary-foreground/20 text-primary-foreground`. Lead text uses `opacity-90` not `text-muted-foreground` (muted tokens don't work on primary backgrounds).
