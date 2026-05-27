# Jac Super

Enhanced console output plugin for Jac CLI with Rich formatting, plus shadcn-style UI components for Jac projects.

## Installation

```bash
pip install jac-super
```

Once installed, the plugin automatically registers and enhances all Jac CLI command output.

## Usage

No configuration required. After installation, jac-super automatically enhances output for all Jac commands:

- `jac create` - Enhanced project creation messages
- `jac start` - Server startup and status messages
- `jac run` - Formatted execution output
- `jac config` - Styled configuration display

## Environment Variables

| Variable | Effect |
|----------|--------|
| `NO_COLOR` | Disables colors (fallback to base console) |
| `NO_EMOJI` | Disables emojis (uses text labels) |
| `TERM=dumb` | Disables both colors and emojis |

## Shadcn Components

jac-super also brings [shadcn/ui](https://ui.shadcn.com)-style components to Jac projects. The components, styles, and color themes all ship **bundled with the plugin** (under `jac_super/shadcn/registry/`), so create, theme, add, and remove all work fully offline -- no network calls.

### Create a themed project

```bash
jac create --use jac-shadcn --theme rose --font inter myapp
```

Scaffolds a themed starter (generated `global.css`, `lib/utils`, `button`/`card`, and a `main.jac` demo). All theme flags are optional: `--style` (nova|vega|maia|lyra|mira), `--baseColor`, `--theme`, `--font`, `--radius`, `--menuAccent`. The chosen values are written to `[jac-shadcn]` in `jac.toml`.

### Re-theme in place

```bash
jac retheme --theme emerald --font outfit   # switch accent + font
jac retheme --style mira                     # switch style + restyle installed components
jac retheme                                  # regenerate global.css from jac.toml
```

`jac retheme` regenerates `global.css` from the `[jac-shadcn]` config (with optional flag overrides) and, when `--style` changes, re-resolves the components already in `components/ui/`.

### Add / remove components

```bash
jac add --shadcn button card dialog    # resolve + install (auto-resolves peer deps)
jac remove --shadcn button dialog      # delete from components/ui/
```

Adding components resolves the chosen `style`'s Tailwind classes from the bundled sources, writes `.cl.jac` files to `components/ui/`, updates `[dependencies.npm]` in `jac.toml`, and creates `lib/utils.cl.jac` with the `cn()` helper if missing. The component set under `jac_super/shadcn/registry/` is a vendored snapshot of the [jac-shadcn](https://github.com/jaseci-labs/jac-shadcn) repo.

### Configure the style

Add a `[jac-shadcn]` section to your project's `jac.toml`:

```toml
[jac-shadcn]
style = "nova"   # nova | vega | maia | lyra | mira
```

### Use components in your code

```jac
cl import from "./components/ui/button" { Button }

cl {
    def:pub MyPage() -> JsxElement {
        return <div>
            <Button variant="outline">Click me</Button>
        </div>;
    }
}
```
