# jac-plugins Release Notes

## jac-shadcn 0.1.0 (Latest Release)

Initial release of jac-shadcn, a Jac CLI plugin for managing [shadcn/ui](https://ui.shadcn.com)-style components in Jac projects.

### Features

- **Component Management**: Add and remove pre-built, themed UI components via the Jac CLI
  - `jac add --shadcn button card dialog` -fetch and install components from the registry
  - `jac remove --shadcn button card` -remove installed components
- **Automatic Peer Dependency Resolution**: BFS-based resolution automatically installs required peer components (e.g., adding `dialog` auto-adds `button` if missing)
- **Live Component Registry**: Components served from [jac-shadcn.jaseci.org](https://jac-shadcn.jaseci.org) with style-resolved Tailwind classes -`cn-*` tokens are replaced with concrete classes based on your chosen style before delivery
- **5 Built-in Styles**: `nova`, `vega`, `maia`, `lyra`, `mira` -each with configurable base colors, themes, fonts, and border radius
- **Project Scaffolding**: Create new projects with `jac create --use 'https://jac-shadcn.jaseci.org/jacpack'`, with full theme customization via query parameters
- **NPM Dependency Management**: Automatically updates `[dependencies.npm]` in `jac.toml` when adding components
- **Utility Generation**: Auto-creates `lib/utils.cl.jac` with the `cn()` utility (clsx + tailwind-merge) on first component add
- **Tailwind v4 + CSS Variables**: Projects scaffold with modern Tailwind v4 config, `tw-animate-css`, and oklch-based CSS custom properties for theming
- **Declaration/Implementation Split**: Source follows the Jac `impl` pattern -signatures in `.jac` files, implementations in `impl/*.impl.jac`
- **Test Suite**: 26 tests covering config reading, peer dependency resolution, npm dep updates, component add/remove, template validation, and live registry integration
