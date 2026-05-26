# jac-shadcn

A Jac CLI plugin that brings [shadcn/ui](https://ui.shadcn.com)-style components to Jac projects. Components are fetched from the [jac-shadcn registry](https://jac-shadcn.jaseci.org) and copied straight into your project — **you own the code** and can edit it freely.

## Installation

```bash
pip install jac-shadcn
```

Verify:

```bash
jac shadcn --help
```

**Requirements:** Python 3.10+, `jaclang>=0.11.1`, `jac-client>=0.1.0`. Both are pulled in automatically. `tomlkit>=0.13` is also installed (used to keep your hand-edited `jac.toml` comments intact across `jac shadcn` commands).

## Quick Start

```bash
jac create myapp --use shadcn
cd myapp && jac install
jac start main.jac
```

That single command scaffolds the project, themes it, and installs 10 essential components: `button`, `card`, `input`, `label`, `dialog`, `dropdown-menu`, `separator`, `badge`, `avatar`, `skeleton`.

## Common Recipes

```bash
# Pick a theme up front
jac create myapp --use shadcn --style nova --theme rose --font outfit

# Theme only, install components yourself
jac create myapp --use shadcn --bare
cd myapp && jac shadcn add button card

# Install every component the registry ships
jac create myapp --use shadcn --all

# Retrofit shadcn onto an existing Jac project
cd existing-project
jac shadcn init --style nova --theme rose

# Add more components later
jac shadcn add dialog dropdown-menu sheet

# Switch theme; all installed components re-fetched in the new style
jac shadcn upgrade --style vega --theme blue

# Remove a component; orphan npm deps auto-pruned
jac shadcn remove combobox

# See what's installed
jac shadcn list --installed-only
```

## Commands

| Command | Purpose |
|---|---|
| `jac create <name> --use shadcn` | Scaffold a new shadcn project (theme + 10 essentials in one shot) |
| `jac shadcn init` | Set up shadcn in an existing Jac project |
| `jac shadcn add <names…>` | Install specific components (supports `name@version` pinning) |
| `jac shadcn remove <names…>` | Uninstall components (auto-prunes orphan npm deps; `--keep-deps` opts out) |
| `jac shadcn list [--installed-only]` | Show what's available / what's installed |
| `jac shadcn upgrade [names…]` | Re-fetch components (also switches styles/themes via flags) |
| `jac shadcn prune` | Drop orphan npm deps from `jac.toml` |

All theme flags (`--style`, `--base-color`, `--theme`, `--font`, `--radius`, `--menu-accent`) are valid on `jac create --use shadcn`, `jac shadcn init`, and `jac shadcn upgrade`.

`jac shadcn init` and `jac create --use shadcn` also accept `--all` (install every component) and `--bare` (install none — theme/CSS only).

## Using Components

```jac
cl import from ".components.ui.button" { Button }
cl import from ".components.ui.card" { Card, CardHeader, CardTitle, CardContent }

cl {
    def:pub App() -> JsxElement {
        return <div className="p-8">
            <Card>
                <CardHeader><CardTitle>Hello shadcn!</CardTitle></CardHeader>
                <CardContent>
                    <Button variant="default">Click me</Button>
                </CardContent>
            </Card>
        </div>;
    }
}
```

## Theme Options

| Parameter | Values | Default |
|---|---|---|
| `style` | `nova`, `vega`, `maia`, `lyra`, `mira` *(5)* | `nova` |
| `baseColor` | `neutral`, `stone`, `zinc`, `gray` *(4)* | `neutral` |
| `theme` | `amber`, `blue`, `cyan`, `emerald`, `fuchsia`, `gray`, `green`, `indigo`, `lime`, `neutral`, `orange`, `pink`, `purple`, `red`, `rose`, `sky`, `stone`, `teal`, `violet`, `yellow`, `zinc` *(21)* | `neutral` |
| `font` | `geist`, `geist-mono`, `inter`, `noto-sans`, `nunito-sans`, `figtree`, `roboto`, `raleway`, `dm-sans`, `public-sans`, `outfit`, `jetbrains-mono` *(12)* | `figtree` |
| `radius` | `default`, `none`, `small`, `medium`, `large` *(5)* | `default` |
| `menuAccent` | `subtle`, `bold` | `subtle` |

Invalid values are caught client-side before any HTTP call, with `difflib`-powered "did you mean: …?" suggestions.

> **Tip:** Preview themes visually at [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) — the customizer's "Copy CLI command" button gives you the exact `jac shadcn init --style … --theme …` invocation.

## Project Structure

After `jac create myapp --use shadcn`:

```
myapp/
├── jac.toml                  # [jac-shadcn] config + plugin-managed npm deps
├── jac-shadcn.lock           # installed components + versions  — commit this
├── main.jac
├── global.css                # theme CSS with managed/user marker blocks
├── lib/
│   └── utils.cl.jac          # cn() helper (clsx + tailwind-merge)
└── components/
    └── ui/
        ├── button.cl.jac
        ├── card.cl.jac
        └── …                 # 10 essentials by default
```

## `jac.toml` Configuration

The `[jac-shadcn]` section is populated by `init`; you rarely edit it by hand. To change a theme field post-init, use `jac shadcn upgrade --<field> <value>` — that updates `jac.toml` AND re-fetches affected components in one step.

```toml
[jac-shadcn]
style = "nova"
baseColor = "neutral"
theme = "neutral"
font = "figtree"
radius = "default"
menuAccent = "subtle"
# registry = "https://my-mirror.example.com"   # only for self-hosted mirrors
```

All writes go through `tomlkit`, so hand-edited comments + ordering survive every `jac shadcn` command.

## `global.css` Ownership

Generated CSS is wrapped in marker blocks. Put your customizations between the `user BEGIN/END` markers and they survive `init` and `upgrade`:

```css
/* === jac-shadcn:managed BEGIN === */
/* ...generated theme variables... */
/* === jac-shadcn:managed END === */

/* === jac-shadcn:user BEGIN === */
.my-button { color: hotpink; }   /* survives jac shadcn upgrade */
/* === jac-shadcn:user END === */
```

## Running Tests

```bash
cd jac-plugins/jac-shadcn
jac test tests/
```

100 tests across 6 files. HTTP is mocked except a single live smoke test that pings the real registry as a shape canary.

## Full Reference

See the [jac-shadcn reference docs](https://docs.jaseci.org/reference/plugins/jac-shadcn/) for the full command surface, registry endpoints, security notes, and troubleshooting.

## License

MIT
