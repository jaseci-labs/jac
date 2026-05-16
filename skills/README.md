# Jac-Skills

Curated reference skills for writing **Jac** - the language and fullstack framework from [Jaseci](https://www.jaseci.org/). Each skill is a focused, self-contained guide to one area of Jac: syntax, type system, Object-Spatial Programming (nodes/edges/walkers), the `by llm()` MTP pattern, and the fullstack `.cl.jac` / `.sv.jac` client–server model.

Each skill is a self-contained `SKILL.md` with YAML frontmatter, kept as the authoritative reference for Jac code generation.

> Why this exists: training-time impressions of Jac are frequently wrong (the syntax has changed; Jac is easily confused with Python or JSX). These skills are the corrective spec.

## Install

These follow the [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) open format (`SKILL.md` + YAML frontmatter), which Claude Code, Claude.ai, the Claude Agent SDK, and Cursor all read directly - no conversion needed.

### Claude Code - as a plugin (recommended)

Install and update all skills with one command:

```
/plugin marketplace add jaseci-labs/jaseci
/plugin install jac-skills@jaseci
```

Run `/plugin marketplace update jaseci` to pull later revisions.

### Claude Code - manual

Copy the skill folders into a skills directory Claude Code scans:

```sh
# Personal (all projects)
cp -r skills/jac-* ~/.claude/skills/

# Project-scoped (this repo only)
mkdir -p .claude/skills && cp -r skills/jac-* .claude/skills/
```

Each `skills/jac-<name>/` directory is self-contained - copy as many or as few as you want.

### Claude.ai

Upload any individual `skills/jac-<name>/` folder in **Settings → Capabilities → Skills**.

### Claude Agent SDK

Point the SDK at a skills directory containing the `jac-*` folders (e.g. via `settingSources` / the `--skills` option), or vendor the folders into your agent's `.claude/skills/`.

### Cursor

Cursor reads the same `SKILL.md` format. Copy the skill folders into a directory Cursor scans:

```sh
# Personal (all projects)
cp -r skills/jac-* ~/.cursor/skills/

# Project-scoped (this repo only)
mkdir -p .cursor/skills && cp -r skills/jac-* .cursor/skills/
```

Reload the workspace (`Cmd/Ctrl+Shift+P` → **Developer: Reload Window**) to pick them up. Discovered skills appear under **Cursor Settings → Rules** in the *Agent Decides* section, and can be invoked from the `/` menu in Agent chat.

## Skills

Start with **`jac-core-cheatsheet`** (language baseline) and **`jac-types`** (the type system) - most other skills build on them.

| Skill | What it covers |
|---|---|
| `jac-core-cheatsheet` | Language baseline: imports, control flow, lambdas, ternary, strings, error handling. Read first. |
| `jac-types` | Type system: annotations, generics, unions, optionals, inference, common type errors. |
| `jac-has-fields` | Declaring typed fields on stateful archetypes - types, defaults, ordering, optionals. |
| `jac-impl-files` | Splitting declarations from method bodies into `.jac` / `.impl.jac` companion files. |
| `jac-node-edge-patterns` | Object-Spatial Programming: defining nodes/edges, connecting, querying by type/field. |
| `jac-walker-patterns` | Walkers that traverse the graph - entry points, visit, the OSP traversal model. |
| `jac-by-llm` | Delegating a function body to an LLM - structured outputs, tool use, prompt wiring. |
| `jac-scaffold` | Bootstrapping a project with `jac create --use <template>`. |
| `jac-fullstack-patterns` | Wiring `main.jac` for a fullstack app - endpoint registration, client mount. |
| `jac-sv-endpoints` | Server-side callable functions - visibility, typed responses, CRUD basics. |
| `jac-sv-auth` | Server auth model - public vs authenticated endpoints, per-user data isolation. |
| `jac-sv-persistence` | Modeling relationships and querying the graph from server endpoints. |
| `jac-cl-components` | Client UI components - shape, reactive `has` state, mount effects, events. |
| `jac-cl-organization` | Structuring a multi-component client app - layout, hooks, naming. |
| `jac-cl-routing` | Multi-page client navigation - routes, redirects, navigation from handlers. |
| `jac-cl-auth` | Client auth - signup/login/logout, guarding pages behind login. |
| `jac-cl-styling` | Tailwind patterns - conditional classes, `cn()`, semantic colors. |
| `jac-npm-packages` | Adding npm packages to `jac.toml` and importing them in `.cl.jac`. |
| `jac-shadcn-components` | Using pre-installed jac-shadcn primitives from `components/ui/`. |

## Contributing

These skills are actively curated and updated as the Jac language evolves. Open issues and pull requests in this repository.
