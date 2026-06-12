---
name: jac-shadcn-blocks
description: Design system constants and anti-patterns for jac-shadcn block development (spacing scale, type scale, section padding, container widths). Always load this before any jac-shadcn-blocks-* group file. Pairs with jac-shadcn-components for primitives and theming.
---

Component shape, named typed params (including `children: any = None`), and JSX comments - see `jac-cl-components`.
For semantic color tokens, `cn()` usage, and dark mode - see `jac-shadcn-components`.

---

## Design System Constants

Read before using any block group file. These values must be used consistently.

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

## Block Group Index

Load the base file (this file) first, then the group file matching your task.

| Group file | Blocks | When to load |
|---|---|---|
| `jac-shadcn-blocks-marketing` | HeroCentered, HeroSplit, FeaturesGrid, FeaturesAlternating, TestimonialGrid, PricingSection, FaqSection, FinalCta | Building a landing page or any marketing section |
| `jac-shadcn-blocks-app` | SiteHeader, FooterFourColumn, AppShell, StatsGrid, DataTablePage, LoginPage | Building app navigation, a dashboard, or an auth page |
| `jac-shadcn-blocks-empty` | ProjectsEmpty, SearchEmpty, ErrorEmpty | Page or section needs a feedback state for empty or failed data |

---

## Block -> Component Mapping

`jac add --shadcn` resolves peer dependencies automatically - only list the primary ones.

| Block | Primary jac-shadcn components |
|---|---|
| `hero_centered` | badge, button |
| `hero_split` | badge, button |
| `navbar_sticky` | button, sheet |
| `features_grid` | badge |
| `features_alternating` | badge |
| `pricing_3tier` | card, badge, button |
| `testimonial_grid` | card, avatar, badge |
| `faq_accordion` | accordion, badge |
| `cta_centered` | card, button |
| `footer_4col` | button, separator |
| `sidebar_nav` | sidebar, separator, breadcrumb |
| `stats_row` | card, badge |
| `data_table_page` | sidebar, card, table, badge, button, input |
| `empty_state` | empty, button |
| `auth_card_centered` | card, input, button, field |

---

## Typical Component Sets by App Type

| App type | Typical blocks | Typical components |
|---|---|---|
| SaaS (marketing + app) | navbar, hero, features, pricing, testimonials, faq, cta, footer, sidebar, stats | badge, button, card, sidebar, table, input, avatar, separator, accordion |
| Dashboard (app-only) | sidebar, stats, data-table, empty-state | sidebar, card, table, badge, button, input, separator, breadcrumb |
| Landing (marketing only) | navbar, hero, features, testimonials, cta, footer | badge, button, card, avatar, separator |
| Web app (auth + pages) | navbar, hero, cta, footer, auth-card, sidebar | button, card, input, field, sidebar, badge |
| Tool (focused utility) | navbar, sidebar, stats, data-table, empty-state | sidebar, table, input, badge, button, card |
| Blog / content | navbar, hero, features, faq, footer | badge, button, card, separator, avatar |

---

## Full Page Composition Examples

### Marketing landing page

```
SiteHeader          (jac-shadcn-blocks-app: navbar_sticky)
HeroCentered        (jac-shadcn-blocks-marketing: hero_centered)
FeaturesGrid        (jac-shadcn-blocks-marketing: features_grid)
TestimonialGrid     (jac-shadcn-blocks-marketing: testimonial_grid)
PricingSection      (jac-shadcn-blocks-marketing: pricing_3tier)
FaqSection          (jac-shadcn-blocks-marketing: faq_accordion)
FinalCta            (jac-shadcn-blocks-marketing: cta_centered)
FooterFourColumn    (jac-shadcn-blocks-app: footer_4col)
```

### SaaS app shell (authenticated)

```
AppShell (jac-shadcn-blocks-app: sidebar_nav) wrapping:
  StatsGrid         (jac-shadcn-blocks-app: stats_row)
  DataTablePage     (jac-shadcn-blocks-app: data_table_page)
  ProjectsEmpty     (jac-shadcn-blocks-empty: empty_state - when no data)
```

### Auth flow (standalone pages, not inside shell)

```
LoginPage           (jac-shadcn-blocks-app: auth_card_centered)
  - Full-viewport centered card
  - No navbar, no footer
  - Redirect to dashboard on success
```
