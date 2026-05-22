# jac-shadcn Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of jac-shadcn. See also [Breaking Changes](../breaking-changes.md).

## jac-shadcn 0.2.0 (Latest Release)

A complete UX + production-readiness overhaul. The plugin now exposes a `jac shadcn` top-level command group with declarative flags, ships an essentials-by-default install set, persists installs in a lockfile, hardens against malicious registries, and switches all `jac.toml` writes to `tomlkit` so your comments and pinning survive.

### Breaking Changes

- **All shadcn commands live under `jac shadcn`.** The old `--shadcn` flag on `jac add` / `jac remove` is gone. Migrate:
  - `jac add --shadcn button card` → `jac shadcn add button card`
  - `jac add --shadcn --init <url>` → `jac shadcn init --style <…> --theme <…>` *(see below — URLs are gone too)*
  - `jac remove --shadcn button` → `jac shadcn remove button`
- **Template alias renamed `jac-shadcn` → `shadcn`.** Use `jac create myapp --use shadcn`.
- **No more URL-based theme init.** `jac shadcn init '<long URL>'` is replaced by declarative flags: `jac shadcn init --style nova --theme rose --font outfit`. The plugin composes the registry call internally.
- **Default install set on `init` is now 10 essentials, not ~53.** `jac shadcn init` (and `jac create --use shadcn`) installs a curated 10-component starter set by default. Pass `--all` to restore the old behavior or `--bare` to install nothing.
- **`menuColor` config field removed.** Never honored by the registry. Drop the line from existing `[jac-shadcn]` sections.
- **`registry` no longer scaffolded into `jac.toml`.** The plugin's hardcoded default is the canonical URL. Add the line manually only for self-hosted mirrors.

### Features

#### New command surface

- **`jac shadcn` top-level command** with six actions (modeled after `jac db`):
  - `jac shadcn init` — bootstrap shadcn into the current project
  - `jac shadcn add <names…>` — install components (supports `name@version`)
  - `jac shadcn remove <names…>` — uninstall + auto-prune orphan deps (`--keep-deps` to opt out)
  - `jac shadcn list [--installed-only]` — registry vs installed
  - `jac shadcn upgrade [names…]` — re-fetch installed components (also: switch styles/themes)
  - `jac shadcn prune` — drop orphan npm deps without uninstalling
- **Theme flags on `jac create --use shadcn`** so scaffold + init happens in one command:
  ```
  jac create myapp --use shadcn --style nova --theme rose --font outfit
  ```
  Pre-hook validates flags before any files are written; bad theme aborts cleanly.

#### Theme flags + validation

- **Declarative flags everywhere**: `--style`, `--base-color`, `--theme`, `--font`, `--radius`, `--menu-accent` on `init`, `upgrade`, and `jac create --use shadcn`.
- **3-level fallback**: CLI flag → `[jac-shadcn]` in `jac.toml` → hardcoded default. Re-run `init` without re-typing every flag.
- **Client-side validation with "did you mean: …?" suggestions** for typos. Tries `GET /options` on the registry first (silent fail-open); falls back to a hardcoded list of all valid values (5 styles, 21 themes, 12 fonts, 4 base colors, 5 radii, 2 menu accents).

#### Install scope control

- **Default: 10 essentials** (`button, card, input, label, dialog, dropdown-menu, separator, badge, avatar, skeleton`). Covers form + nav + layout + status + loading basics.
- **`--all`** on `init` and `jac create --use shadcn`: install every component the registry returns in `default_components`.
- **`--bare`** on the same commands: skip component install entirely; theme + `global.css` only.
- **`--all` + `--bare` mutex** is rejected in the pre-hook.

#### Style/theme switching

- **`jac shadcn upgrade --style vega --theme blue`** re-fetches every installed component in the new style + persists to `jac.toml`. Resolves the long-standing "style is baked at install time" footgun.

#### Files + state

- **`jac-shadcn.lock`** records every install with version + npm deps. Commit to VCS for reproducible installs. Drives auto-prune on remove and `upgrade`'s scope.
- **`global.css` user-section markers**: generated CSS is wrapped in `/* === jac-shadcn:managed === */` and `/* === jac-shadcn:user === */` blocks. User customizations between the user markers survive every `init` and `upgrade`. Legacy files (no markers) get a one-time warning and are replaced.
- **Auto-prune on remove**: `jac shadcn remove button` drops any `[dependencies.npm]` entries that no remaining installed component still needs. User-pinned deps you added by hand are never touched.
- **`name@version` pinning**: `jac shadcn add button@1.0.0` pins, version is recorded in the lockfile.

### Bug Fixes

- **Path-traversal hardening**: filenames returned by the registry are validated. Anything containing `..`, `/`, `\`, a null byte, an absolute path, or a non-`.cl.jac` suffix is refused with a clear error. Protects against a compromised or hostile registry writing outside `components/ui/`.
- **Actionable error messages**: every error includes a `hint:` line. Network failures point at `[jac-shadcn].registry`; missing config points at `jac shadcn init`.
- **`init` now syncs the full `[jac-shadcn]` section** every run instead of only writing it when absent. Re-running with a new flag actually updates `jac.toml`.

### Refactor

- **All `jac.toml` writes go through `tomlkit`**: hand-edited comments, ordering, and pinning survive every command. Replaced the previous string-find/insert helpers that could corrupt user-edited files.
- **`init_shadcn_theme()` signature**: now `init_shadcn_theme(config, *, style, base_color, theme, font, radius, menu_accent, install_set)`. Direct API users need to migrate from the old `theme_url` positional.
- **Plugin registration**: moved from `extend_command` hooks on `jac add` / `jac remove` to a single top-level `jac shadcn` command via `@registry.command()` (same API as `jac db`).

---

## jac-shadcn 0.1.1

### Features

- **`--init` for Existing Projects**: Initialize jac-shadcn theming in an existing Jac project using a URL with query parameters -- same customization experience as `jac create`
  - `jac add --shadcn --init 'https://jac-shadcn.jaseci.org/theme?style=nova&baseColor=neutral&theme=orange&font=figtree'`
  - Sets up `global.css`, `lib/utils.cl.jac`, `[jac-shadcn]` config, npm deps, dev deps, and Vite/Tailwind plugin config
  - Installs all default components automatically, matching parity with `jac create`
- **Registry `/theme` Endpoint**: New GET endpoint returns theme config, global CSS, npm dependencies, and default component list for the `--init` workflow
- **"Copy Init Command" on Registry Website**: New button in the customizer modal lets users copy the `--init` CLI command directly from [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org)

### Bug Fixes

- **TOML Greedy Substring Matching**: Fixed `clsx` matching `clsx-utils` and `tailwindcss` matching `@tailwindcss/vite` . Now uses exact key matching via `_dep_exists_in_toml()`
- **TOML Key Quoting**: Keys with special characters (`@`, `/`, `-`, `.`) are now properly quoted in TOML output
- **Ternary Precedence Bug**: Fixed URL construction where `x + y if cond else z` bound incorrectly as `x + (y if cond else z)`
- **Dark Mode Radius**: Custom radius values are now applied to both light and dark mode CSS variables (previously only light mode)
- **`global.css` Silent Overwrite**: `--init` now warns before overwriting an existing `global.css`
- **Registry URL Injection**: Sanitized user-provided URLs to prevent TOML injection via quote characters
- **Missing `[dependencies.npm]` Guard**: `jac add --shadcn` now creates the `[dependencies.npm]` section if it doesn't exist before patching

---

## jac-shadcn 0.1.0

Initial release of jac-shadcn, a Jac CLI plugin for managing [shadcn/ui](https://ui.shadcn.com)-style components in Jac projects.

### Features

- **Component Management**: Add and remove pre-built, themed UI components via the Jac CLI
  - `jac add --shadcn button card dialog` - fetch and install components from the registry
  - `jac remove --shadcn button card` - remove installed components
- **Automatic Peer Dependency Resolution**: BFS-based resolution automatically installs required peer components (e.g., adding `dialog` auto-adds `button` if missing)
- **Live Component Registry**: Components served from [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) with style-resolved Tailwind classes - `cn-*` tokens are replaced with concrete classes based on your chosen style before delivery
- **5 Built-in Styles**: `nova`, `vega`, `maia`, `lyra`, `mira` - each with configurable base colors, themes, fonts, and border radius
- **Project Scaffolding**: Create new projects with `jac create --use 'https://jac-shadcn.jaseci.org/jacpack'`, with full theme customization via query parameters
- **NPM Dependency Management**: Automatically updates `[dependencies.npm]` in `jac.toml` when adding components
- **Utility Generation**: Auto-creates `lib/utils.cl.jac` with the `cn()` utility (clsx + tailwind-merge) on first component add
- **Tailwind v4 + CSS Variables**: Projects scaffold with modern Tailwind v4 config, `tw-animate-css`, and oklch-based CSS custom properties for theming
- **Declaration/Implementation Split**: Source follows the Jac `impl` pattern - signatures in `.jac` files, implementations in `impl/*.impl.jac`
- **Test Suite**: 26 tests covering config reading, peer dependency resolution, npm dep updates, component add/remove, template validation, and live registry integration
