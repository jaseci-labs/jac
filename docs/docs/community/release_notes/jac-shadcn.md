# jac-shadcn Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of jac-shadcn. See also [Breaking Changes](../breaking-changes.md).

## jac-shadcn 0.1.1 (Latest Release)

### Features

- **`--init` for Existing Projects**: Initialize jac-shadcn theming in an existing Jac project using a URL with query parameters — same customization experience as `jac create`
  - `jac add --shadcn --init 'https://jac-shadcn.jaseci.org/theme?style=nova&baseColor=neutral&theme=orange&font=figtree'`
  - Sets up `global.css`, `lib/utils.cl.jac`, `[jac-shadcn]` config, npm deps, dev deps, and Vite/Tailwind plugin config
  - Installs all default components automatically — matching parity with `jac create`
- **Registry `/theme` Endpoint**: New GET endpoint returns theme config, global CSS, npm dependencies, and default component list for the `--init` workflow
- **"Copy Init Command" on Registry Website**: New button in the customizer modal lets users copy the `--init` CLI command directly from [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org)

### Bug Fixes

- **TOML Greedy Substring Matching**: Fixed `clsx` matching `clsx-utils` and `tailwindcss` matching `@tailwindcss/vite` — now uses exact key matching via `_dep_exists_in_toml()`
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
