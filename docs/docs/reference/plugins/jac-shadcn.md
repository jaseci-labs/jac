# jac-shadcn Reference

`jac-shadcn` is a Jac CLI plugin that brings [shadcn/ui](https://ui.shadcn.com)-style components to Jac projects. Components are fetched from a remote registry and copied straight into `components/ui/` — **you own the code** and can edit it freely.

---

## Installation

```bash
pip install jac-shadcn
```

Verify:

```bash
jac shadcn --help
```

!!! note "Prerequisite"
    `jac-shadcn` requires `jac-client` (components are `.cl.jac` files).

---

## Quick Start

The shortest path to a working app:

```bash
jac create myapp --use shadcn
cd myapp && jac install
jac start main.jac
```

That's it. You now have:

- A themed `global.css`
- 10 essential components in `components/ui/` (button, card, input, label, dialog, dropdown-menu, separator, badge, avatar, skeleton)
- All npm dependencies in `jac.toml`
- A `jac-shadcn.lock` recording every install

Open `components/ui/button.cl.jac` — that's your code, edit it however you like.

---

## Common Recipes

### Pick a theme up front

```bash
jac create myapp --use shadcn --style nova --theme rose --font outfit
```

### Just add a few components, install the rest yourself

```bash
jac create myapp --use shadcn --bare
cd myapp
jac shadcn add button card
```

### Install every component the registry ships

```bash
jac create myapp --use shadcn --all
```

### Retrofit shadcn onto an existing Jac project

```bash
cd existing-project
jac shadcn init --style nova --theme rose
```

### Add more components later

```bash
jac shadcn add dialog dropdown-menu sheet
```

### Switch theme without losing customizations

```bash
jac shadcn upgrade --style vega --theme blue
# Every installed component re-fetched in the new style;
# global.css user-section preserved.
```

### Remove a component (deps auto-pruned)

```bash
jac shadcn remove combobox
```

### See what's installed

```bash
jac shadcn list --installed-only
```

---

## Commands at a Glance

| Command | Purpose |
|---|---|
| [`jac create <name> --use shadcn`](#jac-create-name-use-shadcn) | Scaffold a new shadcn project |
| [`jac shadcn init`](#jac-shadcn-init) | Set up shadcn in an existing Jac project |
| [`jac shadcn add <names…>`](#jac-shadcn-add-names) | Install specific components |
| [`jac shadcn remove <names…>`](#jac-shadcn-remove-names) | Uninstall components (auto-prunes orphan npm deps) |
| [`jac shadcn list`](#jac-shadcn-list) | Show what's available / what's installed |
| [`jac shadcn upgrade [names…]`](#jac-shadcn-upgrade-names) | Re-fetch components (also: switch styles/themes) |
| [`jac shadcn prune`](#jac-shadcn-prune) | Clean orphan npm deps from `jac.toml` |

Companion commands (built into jaclang): `jac install`, `jac start main.jac`.

---

## Command Reference

Detailed flags + behavior for each command. Skim past these on a first read — the recipes above cover the day-to-day usage.

### `jac create <name> --use shadcn`

Scaffolds a new Jac project and runs `jac shadcn init` automatically. Pre-hook validates every theme flag BEFORE creating any files — an invalid value aborts cleanly with no partial state.

| Flag | Value | Default |
|---|---|---|
| `--style` | `nova` `vega` `maia` `lyra` `mira` | `nova` |
| `--base-color` | `neutral` `stone` `zinc` `gray` | `neutral` |
| `--theme` | 21 values (see [Theme Options](#theme-options)) | `neutral` |
| `--font` | 12 values (see [Theme Options](#theme-options)) | `figtree` |
| `--radius` | `default` `none` `small` `medium` `large` | `default` |
| `--menu-accent` | `subtle` `bold` | `subtle` |
| `--all` | Install all ~53 registry components (mutex with `--bare`) | off |
| `--bare` | Install no components — theme/CSS only | off |

### `jac shadcn init`

Sets up shadcn in the current project. Same flags as `jac create --use shadcn`. Uses a 3-level fallback for any unspecified theme param: **CLI flag → `[jac-shadcn]` in `jac.toml` → hardcoded default**.

What it does per run:

1. Writes `global.css` with managed/user marker blocks (see [`global.css` ownership](#globalcss-ownership))
2. Creates `lib/utils.cl.jac` (with the `cn()` helper) if missing
3. **Syncs** `[jac-shadcn]` in `jac.toml` (writes all six theme fields)
4. Adds `[dependencies.npm]`, `[dependencies.npm.dev]`, `[plugins.client.vite]` if missing
5. Installs the chosen component set (default 10 essentials | `--all` | `--bare`)
6. Writes `jac-shadcn.lock`

Invalid theme values are caught before any HTTP call, with "did you mean: …?" suggestions.

#### Essentials list

The 10 components installed by default cover form, navigation, layout, status, and loading:

`button`, `card`, `input`, `label`, `dialog`, `dropdown-menu`, `separator`, `badge`, `avatar`, `skeleton`

### `jac shadcn add <names…>`

Incremental component install. Supports version pinning via `name@version`.

```bash
jac shadcn add button
jac shadcn add button card dialog
jac shadcn add button@1.0.0
```

Resolves `peerComponents` via BFS (adding `dialog` pulls in `button` if missing). Patches `[dependencies.npm]` via `tomlkit` so your comments + pinning survive. Mistyped names get `difflib` suggestions.

### `jac shadcn remove <names…>`

Removes component files AND auto-prunes orphan npm deps.

| Flag | Effect |
|---|---|
| `--keep-deps` | Skip auto-prune — leave `[dependencies.npm]` untouched |

```bash
jac shadcn remove button
jac shadcn remove button --keep-deps
```

The lockfile tracks which npm deps each component brought in. After removal, any dep no remaining installed component still declares is orphaned and dropped from `jac.toml`. User-pinned deps you added by hand are never touched.

### `jac shadcn list`

Show what the registry offers, marking installed components with `*`.

| Flag | Effect |
|---|---|
| `--installed-only` | Skip the network call; show only what's in `jac-shadcn.lock` |

```bash
jac shadcn list
jac shadcn list --installed-only
```

### `jac shadcn upgrade [names…]`

Re-fetches installed components from the registry. This is how you change styles — the Tailwind classes are baked into component files at fetch time, so editing `jac.toml` alone doesn't change anything until you re-fetch.

| Flag | Effect |
|---|---|
| `--style <X>` | Switch style + persist + re-fetch |
| `--base-color <X>` | Switch base color + persist + re-fetch |
| `--theme <X>` | Switch theme + persist + re-fetch |
| `--font <X>` | Switch font + persist + re-fetch |
| `--radius <X>` | Switch radius + persist + re-fetch |
| `--menu-accent <X>` | Switch menu accent + persist + re-fetch |

```bash
jac shadcn upgrade
jac shadcn upgrade button card
jac shadcn upgrade --style vega
jac shadcn upgrade --style vega --theme blue --font outfit
```

User content between the `user BEGIN`/`user END` markers in `global.css` is preserved across upgrades.

### `jac shadcn prune`

Drops orphan npm deps from `jac.toml` without uninstalling any components.

```bash
jac shadcn prune
```

Only `[dependencies.npm]` entries with the shadcn-managed `"*"` version marker that no installed component still declares are candidates. User-pinned deps (e.g. `lodash = "^4.0.0"`) are never touched.

---

## Using Components

Components are `.cl.jac` files in `components/ui/`, imported with `cl import`:

```jac
cl import from ".components.ui.button" { Button }
cl import from ".components.ui.card" { Card, CardHeader, CardTitle, CardContent }
cl import from ".components.ui.dialog" { Dialog, DialogTrigger, DialogContent }

cl {
    def:pub App() -> JsxElement {
        return <div className="p-8">
            <Card>
                <CardHeader>
                    <CardTitle>Hello shadcn!</CardTitle>
                </CardHeader>
                <CardContent>
                    <Button variant="default">Click me</Button>
                </CardContent>
            </Card>
        </div>;
    }
}
```

### The `cn()` Utility

`lib/utils.cl.jac` ships a `cn()` helper that merges Tailwind classes with `clsx` and `tailwind-merge`:

```jac
cl import from ".lib.utils" { cn }

<button className={cn("rounded px-4 py-2", disabled and "opacity-50", className)} />
```

---

## Theme Options

| Parameter | Values | Default |
|---|---|---|
| `style` | `nova`, `vega`, `maia`, `lyra`, `mira` *(5 total)* | `nova` |
| `baseColor` | `neutral`, `stone`, `zinc`, `gray` *(4 total)* | `neutral` |
| `theme` | `amber`, `blue`, `cyan`, `emerald`, `fuchsia`, `gray`, `green`, `indigo`, `lime`, `neutral`, `orange`, `pink`, `purple`, `red`, `rose`, `sky`, `stone`, `teal`, `violet`, `yellow`, `zinc` *(21 total)* | `neutral` |
| `font` | `geist`, `geist-mono`, `inter`, `noto-sans`, `nunito-sans`, `figtree`, `roboto`, `raleway`, `dm-sans`, `public-sans`, `outfit`, `jetbrains-mono` *(12 total)* | `figtree` |
| `radius` | `default`, `none`, `small`, `medium`, `large` *(5 total)* | `default` |
| `menuAccent` | `subtle`, `bold` | `subtle` |

The plugin validates these client-side before any HTTP call. It tries `GET /options` on the configured registry first; if absent, it falls back to the hardcoded lists above (which match the public registry as of this release).

!!! tip "Preview themes visually"
    Visit [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) to preview style/theme/font combinations live. The "Copy CLI command" button gives you the exact `jac shadcn init --style … --theme …` invocation for your selection.

---

## Configuration

### `jac.toml`

The `[jac-shadcn]` section controls styling. Most fields are populated by `init`; you rarely edit them by hand.

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

| Key | Description | Read by |
|---|---|---|
| `style` | Design system style | `add`, `upgrade` |
| `baseColor` | Base neutral color | `init` (as fallback for `--base-color`) |
| `theme` | Accent / theme color | `init` (as fallback for `--theme`) |
| `font` | Font family | `init` (as fallback for `--font`) |
| `radius` | Border radius | `init` (as fallback for `--radius`) |
| `menuAccent` | Menu accent style | `init` (as fallback for `--menu-accent`) |
| `registry` *(optional)* | Component registry URL (defaults to `https://jac-shadcn.jaseci.org`) | every subcommand that hits the network |

!!! note "Self-hosting / mirrors"
    `registry` is **omitted by default** in scaffolded `jac.toml` files. The plugin uses `https://jac-shadcn.jaseci.org` automatically. Only add the line if you're pointing at a self-hosted or private mirror — once present, the plugin never overwrites it.

All `jac.toml` writes go through `tomlkit`, so hand-edited comments, ordering, and pinning survive every `jac shadcn` command.

### `jac-shadcn.lock`

Every install is recorded at the project root:

```toml
version = 1

[components.button]
version = "1.0.0"
npm_deps = ["class-variance-authority", "radix-ui"]

[components.dialog]
version = "1.0.0"
npm_deps = ["@radix-ui/react-dialog"]
```

**Commit this file** — it's how `upgrade` knows what to re-fetch and how `remove` figures out which npm deps are orphaned.

---

## Files jac-shadcn Manages

| Path | Owned by | When written |
|---|---|---|
| `jac.toml` `[jac-shadcn]` | Plugin (theme fields) | `init`, `upgrade --<field>` |
| `jac.toml` `[dependencies.npm]` | Plugin (component-owned `"*"` entries) | `add`, `init`, `upgrade`, `remove` |
| `jac.toml` `[dependencies.npm.dev]` | Plugin | `init` |
| `jac.toml` `[plugins.client.vite]` | Plugin | `init` (only if missing) |
| `jac-shadcn.lock` | Plugin (always) | every install/remove. **Commit to VCS.** |
| `global.css` | Plugin (managed block) + user (between markers) | `init`, `upgrade` |
| `lib/utils.cl.jac` | Plugin (created once, never overwritten) | `init`, `add` (if missing) |
| `components/ui/*.cl.jac` | Plugin (never overwrites existing) | `add`, `init`, `upgrade` |

---

## Advanced

### `global.css` Ownership

When `jac shadcn init` (or `upgrade`) writes `global.css`, it wraps the generated CSS in marker blocks:

```css
/* === jac-shadcn:managed BEGIN === */
@import "tailwindcss";
@import "tw-animate-css";
/* …generated theme variables… */
/* === jac-shadcn:managed END === */

/* === jac-shadcn:user BEGIN === */
/* Anything between these markers survives `jac shadcn upgrade`. */
/* === jac-shadcn:user END === */
```

**Put your custom CSS between the `user BEGIN` / `user END` markers** and it survives every `init` and `upgrade`. The managed block is fully regenerated; the user block is copied verbatim.

If you run `init` on a legacy `global.css` (no markers), the plugin warns once and replaces the file. Rescue your customizations from VCS before re-running.

### Project Structure

After `jac create myapp --use shadcn`:

```
myapp/
├── jac.toml                  # [jac-shadcn] config + plugin-managed npm deps
├── jac-shadcn.lock           # installed components + versions
├── main.jac                  # entry point
├── global.css                # theme CSS, managed/user marker blocks
├── lib/
│   └── utils.cl.jac          # cn() helper
└── components/
    └── ui/
        ├── button.cl.jac
        ├── card.cl.jac
        ├── dialog.cl.jac
        └── …                 # 10 essentials by default
```

### Registry

The component registry at [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) serves components with style-resolved Tailwind classes. The `cn-*` placeholder classes in component source are replaced with concrete Tailwind classes for your chosen style before delivery.

#### Endpoints

| Endpoint | Used by | Returns |
|---|---|---|
| `GET /registry` | `add`, `upgrade`, `list` | Component manifest + peer deps + shared npm deps |
| `GET /component/{name}?style=…` | `add`, `upgrade`, `init` | Resolved `.cl.jac` source + `npmDeps` + `version` |
| `GET /theme?style=…&baseColor=…&theme=…&font=…&radius=…&menuAccent=…` | `init` | `global_css`, `[jac-shadcn]` config, npm deps, `default_components` list |
| `GET /options` *(planned)* | validation try-fetch (falls back to plugin's hardcoded list) | `{styles, themes, base_colors, fonts, radii, menu_accents}` |

#### Self-hosting

Point `[jac-shadcn].registry` in `jac.toml` at any URL that implements those endpoints. Useful for air-gapped CI, private forks, or registries with custom themes.

### Security

Component filenames returned by the registry are **validated** before being written. The plugin refuses any of:

- `..`, `/`, `\`, or null bytes in the filename
- Absolute paths
- Filenames not ending in `.cl.jac`

This protects against a compromised or hostile registry writing outside `components/ui/`.

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| `No [jac-shadcn] section in jac.toml` | Run `jac shadcn init` or `jac create --use shadcn`. |
| `Network error fetching …` | Verify `[jac-shadcn].registry` in `jac.toml` is reachable (or omit the key to use the public default). |
| `x button: registry returned suspicious filename …` | Registry returned an unsafe path — the install was correctly refused. Report the registry response. |
| `Component not found in registry: buton` | Typo. The hint shows close matches; use `jac shadcn list` for the full set. |
| `Invalid style 'nva' (did you mean: nova?)` | Pick from the [Theme Options](#theme-options) table. |
| `--all and --bare are mutually exclusive` | Pass exactly one (or neither). |
| Style change in `jac.toml` had no effect | Component files are baked at fetch time. Run `jac shadcn upgrade --style <new>` to re-fetch. |
| Customizations in `global.css` got overwritten | They were outside the `user BEGIN/END` markers. Move them inside; future `init`/`upgrade` runs will preserve them. |
| `jac shadcn` not found | The plugin isn't installed in the env that runs `jac`. `pip install jac-shadcn` (into the same env as `jaclang`). |

---

## Running Tests

```bash
cd jac-plugins/jac-shadcn
jac test tests/
```

All HTTP is mocked except a single live smoke test that pings the real registry as a shape canary.
