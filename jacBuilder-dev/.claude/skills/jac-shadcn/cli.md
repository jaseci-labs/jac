# jac-shadcn CLI Reference

Configuration is read from the `[jac-shadcn]` section in `jac.toml`.

> **IMPORTANT:** Always activate the Jac virtual environment first: `source /home/ahzan/.jacvenv/bin/activate`

## Commands

### `jac add --shadcn` — Add components

```bash
jac add --shadcn button card dialog
```

Fetches resolved components from the registry and installs them into `components/ui/`. Automatically resolves peer dependencies via BFS traversal.

**What happens:**
1. Reads `[jac-shadcn]` config from `jac.toml` (style, registry URL)
2. Fetches component manifest from `/registry`
3. BFS-resolves peer dependencies (e.g., `dialog` auto-adds `button` if needed)
4. Fetches each component from `/component/{name}?style={style}` — **cn-* tokens already resolved**
5. Writes `.cl.jac` files to `components/ui/`
6. Patches `[dependencies.npm]` in `jac.toml` with required npm packages
7. Creates `lib/utils.cl.jac` (cn() helper) if missing

### `jac remove --shadcn` — Remove components

```bash
jac remove --shadcn button card
```

Deletes `components/ui/{name}.cl.jac` files. Does not remove npm dependencies or peer components.

### `jac create --use jac-shadcn` — Create new project

```bash
jac create --use jac-shadcn
```

Scaffolds a new jac-shadcn project from the template jacpack.

### `jac start` — Start dev server

```bash
jac start main.jac
```

Serves on `http://localhost:8000`. No separate build step — the Jac compiler handles transpilation + Vite bundling.

---

## Project Configuration

### jac.toml

```toml
[jac-shadcn]
style = "nova"                              # Visual style
registry = "https://jac-shadcn.jaseci.org"  # Component registry URL

[dependencies.npm]
"radix-ui" = "^1.4.3"
"@base-ui/react" = "^1.2.0"
"class-variance-authority" = "*"
"clsx" = "*"
"tailwind-merge" = "*"
"@hugeicons/react" = "*"
"@hugeicons/core-free-icons" = "*"
```

### Available Styles

| Style | Description |
|-------|-------------|
| `nova` | Default — rounded, clean, modern |
| `vega` | Subtle shadows, medium rounding |
| `maia` | Extra rounded (4xl), pill-shaped |
| `lyra` | Sharp corners, no border-radius |
| `mira` | Compact, relaxed line-height |

---

## Registry Endpoints

The jac-shadcn registry at `https://jac-shadcn.jaseci.org` serves:

| Endpoint | Description |
|----------|-------------|
| `GET /registry` | Component manifest (names, npmDeps, peerComponents) |
| `GET /component/{name}?style=nova` | Single resolved component file content |
| `GET /jacpack?style=nova&theme=rose&font=inter&...` | Complete .jacpack for project scaffolding |

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Jac (`.cl.jac` for client-side JSX) |
| UI Primitives | Radix UI (`radix-ui` ^1.4.3), Base UI (`@base-ui/react` ^1.2.0) |
| Styling | Tailwind CSS v4 + `class-variance-authority` (CVA) |
| Icons | HugeIcons (`@hugeicons/react` + `@hugeicons/core-free-icons`) |
| CSS Utilities | `clsx` + `tailwind-merge` via `cn()` |
| Build | Vite (auto-configured by Jac compiler) |
| React | v18.3.1 (pinned) — no ref-as-prop (React 19 feature) |
