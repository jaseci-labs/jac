---
name: Landing Page Competitive Research
description: Analysis of Lovable, Bolt, v0, StackBlitz, Cursor landing pages vs current Jac Builder Studio landing page
type: project
---

## Current Landing Page State (pages/LandingPage.cl.jac)
- Pill navbar: logo + Sign In + Get Started
- Orange radial gradient glow behind hero
- "Now in Public Beta" animated green dot badge
- Hero heading: "Build Jac apps." / "In your browser." (two-tone, 5.5rem, -0.03em tracking)
- Subtitle: "Write, preview, and version your Jac projects — no install needed. Open source, by devs for devs."
- Two CTAs: "Just let me play" (guest auto-login) + "Sign in to save" (outline)
- Micro-copy: "No sign-up required · Projects tied to this browser"
- Footer: "by devs, for devs · Jaseci Labs" (links to github.com/jaseci-labs/jaseci)
- NO feature section, NO screenshots, NO social proof, NO templates, NO footer nav

## Competitor Patterns (researched 2026-03-20)

### Lovable (lovable.dev)
- Heading: "Build something Lovable"
- Subtitle: "Create apps and websites by chatting with AI"
- NO prompt input on landing page
- 3-step explainer: Idea → Watch it build → Refine and ship
- "Lovable in numbers" stats section (counters, even if 0M is embarrassing)
- 6 template cards with real screenshots
- Company logo strip
- Full footer with Discord/Reddit/X/YouTube/LinkedIn

### Bolt.new
- Heading: "What will you build today?"
- Subtitle: "Create stunning apps & websites by chatting with AI."
- NO prompt input on landing page (Plan CTA button instead)
- Claims: "98% less errors", "1,000x larger projects", "#1 professional vibe coding tool"
- Company logo strip
- Persona targeting: PMs, entrepreneurs, marketers, agencies, students

### v0 by Vercel (v0.app)
- Heading: "What do you want to create?"
- PROMPT INPUT IS THE HERO — text box is the primary CTA, no separate button
- Community template gallery with creator names, view/fork counts
- 12 integration icons
- GitHub integration + one-click Vercel deploy highlighted
- Minimal footer

### StackBlitz (stackblitz.com)
- Heading: "How product & engineering teams work together with AI"
- NO prompt input
- Primary CTA: "Try Bolt.new" (they ARE Bolt's engine, positions accordingly)
- Logo strip: Google, Meta, Shopify, Salesforce, Intel, Mozilla, Cloudflare, Stripe
- Named testimonial: Ilya Grigorik (Principal Engineer, Shopify)
- WebContainers comparison table vs legacy cloud IDEs

### Cursor (cursor.com)
- Heading: "Built to make you extraordinarily productive, Cursor is the best way to code with AI."
- Interactive demo of IDE in hero (not a prompt input)
- CTAs: "Download for macOS" + "Try mobile agent"
- STRONGEST social proof: Jensen Huang, Patrick Collison, Greg Brockman, Andrej Karpathy, shadcn, Diana Hu (YC GP)
- Logo strip: Stripe, OpenAI, Linear, Datadog, NVIDIA, Figma, Ramp, Adobe
- SOC 2 Certified badge
- Multilingual (8 languages)

## Key Patterns Across All Competitors
1. Every competitor has at least a 3-section feature explainer below the hero
2. Template/example galleries (Lovable, v0) are the most effective trust builders
3. v0 is the ONLY one with a prompt input on landing — and it is the most conversion-optimized
4. Named social proof from real people beats stat counters (especially fake ones)
5. A full footer (docs, GitHub, Discord, pricing) adds credibility even for small teams
6. None of them rely on a hero-only page — ours is the only one that does

## Recommendations (Priority Order)
P0 - Add prompt input to hero (pass via URL param /dashboard?prompt=... to JacCoder)
P0 - Add 3-4 feature explainer cards below hero
P0 - Add template gallery (4-6 forkable cards, can be static/hardcoded initially)
P1 - Add GitHub stars counter (live or build-time from API)
P1 - One real named testimonial from a Jaseci community member
P1 - Autoplay muted looping demo video (15-30s WebM)
P1 - Expand footer (docs, GitHub, Discord, changelog, terms, privacy)
P2 - Refine hero copy to mention walkers/graph-native/AI
P2 - Add "Built with Jaseci" or academic citation strip for credibility

## What NOT to Copy
- Fake/zero stats sections ("0M+ projects")
- Fortune 500 trust badge without actual customers
- Persona subpages (too early, not enough user base to justify)
- Pricing page until pricing is decided
