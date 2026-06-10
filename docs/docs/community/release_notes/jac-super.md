# Jac-Super Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Super**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-super 0.1.20 (Latest Release)

### New Features

- **Feature: sonner toast component**: The jac-shadcn registry now ships the sonner toast/notification component, installable with `jac add --shadcn sonner`. (jaseci-labs/jaseci#6467)

### Bug Fixes

- **Fix: jac-shadcn projects build out of the box**: `jac create --use jac-shadcn` now wires Tailwind and generates importable, compilable components. (jaseci-labs/jaseci#6461)
- **Fix: idiomatic `cn(*inputs)` in shadcn scaffold**: now that the client compiler emits rest parameters, the generated `cn` helper uses `cn(*inputs: any)` instead of a 12-positional-argument workaround. (jaseci-labs/jaseci#6466)

### Refactors

- **Refactor: registry components use the bare client form**: jac-shadcn components delivered by `jac add --shadcn` no longer carry redundant `cl` import and block markers. (jaseci-labs/jaseci#6467)

## jac-super 0.1.18

### Bug Fixes

- **Fix: `jac remove --shadcn` resolves the installed filename**: Removal now looks up each component's file via the registry instead of assuming `<name>.cl.jac`, so components whose registry name differs from their file (e.g. `input-otp` installs as `otp-input.cl.jac`) are correctly removed instead of silently no-op'ing.

### Refactors

- **Refactor: shadcn components use idiomatic Jac client style**: All 53 shadcn UI components under `registry/components/ui` were rewritten from JS/React-flavored code to idiomatic Jac client conventions (typed prop bundles spread with `{**x}`, list comprehensions and `{for ... {}}` statement slots over `.map`/`.filter`, `len()`/`isinstance`/f-strings/`is None` over their JS equivalents, and `any` annotations on npm/context-derived values) so the whole set passes `jac check` with zero errors. No runtime behavior change.
- **Refactor: One-line JSX returns across shadcn components**: Applied the updated formatter, collapsing short `return <Element/>;` statements onto a single line across the shadcn registry UI components.

## jac-super 0.1.16

### New Features

- **shadcn/ui components bundled into jac-super**: The former standalone `jac-shadcn` plugin is now part of `jac-super`. Install `jac-super` (no separate `pip install jac-shadcn`) to get the `--shadcn` flag on `jac add`/`jac remove` and the `jac-shadcn` project template. The full component set ships with the package, so `jac add --shadcn` resolves and installs components fully offline -- no calls to the registry website.
- **Offline themed shadcn projects**: `jac create --use jac-shadcn` now scaffolds a themed starter fully offline -- color themes (21 of them), fonts, and radii are bundled with `jac-super`, no registry website needed. Pass `--style`, `--baseColor`, `--theme`, `--font`, `--radius`, and `--menuAccent` to customize at create time.
- **`jac retheme` command**: Re-theme an existing jac-shadcn project in place -- regenerates `global.css` from the `[jac-shadcn]` config (with optional `--theme`/`--font`/`--style`/… overrides) and re-resolves installed components when the style changes.
- **Fix: scoped npm deps in jac.toml**: `jac add --shadcn` and themed create now TOML-quote scoped npm keys (e.g. `@fontsource-variable/inter`, `@hugeicons/react`), which previously produced a malformed `[dependencies.npm]` section.

### Refactors

- **Refactor: jac-super console reduced to a single Rich renderer**: The Rich-enhanced console collapses 15 re-implemented methods into one `RichRenderer` (a `ConsoleRenderer` backend) plus a thin `JacSuperConsole` that overrides only `_make_renderer`, so the method surface can no longer drift from the base. Caller data is rendered through `rich.text.Text` and is never markup-parsed or auto-highlighted, and the renderer honors the facade's `no_color`/`emoji` decision instead of Rich's independent auto-detection.

## jac-super 0.1.15

### Bug Fixes

- **Fix: `JacSuperConsole` honors `sys.stderr` redirection**: `console.error` / `console.warning` now resolve `sys.stderr` per call via `RichConsole(stderr=True)` instead of capturing the stream at construction, so test redirection (`sys.stderr = io.StringIO()`) works again.
- **Fix: `print` passes long lines through unchanged**: The `print` override now sets `soft_wrap=True`, restoring the documented `JacConsole` contract so JSON, paths, and code snippets are no longer reflowed to the terminal width.

## jac-super 0.1.11

### Bug Fixes

- **Fix:** `jac check` diagnostic snippets preserve bracketed source like `[root()-->][?:Task]` and list comprehension RHS verbatim instead of stripping them.

## jac-super 0.1.10

- **Fix: `JacSuperConsole.warning` Now Writes to Stderr**: `warning()` was incorrectly using `self._console` (stdout) while `error()` already used `_console_stderr`. Warnings now go to stderr as intended, so they no longer corrupt piped command output.

## jac-super 0.1.9

- 1 small refactor/change.

## jac-super 0.1.8

## jac-super 0.1.7

- **Style: Remove Bold from CLI Console Output**: Removed bold from all Rich theme entries and inline styles, keeping only color for a cleaner look.

## jac-super 0.1.6

- 1 small refactor/change.

## jac-super 0.1.5

## jac-super 0.1.4

## jac-super 0.1.3

## jac-super 0.1.2

- Various refactors

## jac-super 0.1.1

- **KWESC_NAME syntax changed from `<>` to backtick**: Updated keyword-escaped names from `<>` prefix to backtick prefix to match the jaclang grammar change.

## jac-super 0.1.0

- **Rich-Enhanced Console Output**: Introduced `jac-super` as a plugin that provides elegant, colorful terminal output for Jac CLI commands. The plugin overrides the base console implementation to add Rich-based formatting with:
  - **Themed Output**: Custom color themes for success (green), error (red), warning (yellow), and info (cyan) messages
  - **Formatted Panels**: Beautiful bordered panels for next steps and structured information
  - **Styled Tables**: Rich table formatting for tabular data with proper column alignment
  - **Spinners & Status**: Animated spinners and status indicators for long-running operations
  - **URL Styling**: Underlined, clickable URL formatting in terminal output
  - **Emoji Support**: Smart emoji usage with automatic fallback to text labels when emojis aren't supported
