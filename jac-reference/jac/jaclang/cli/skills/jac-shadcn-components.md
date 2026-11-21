---
name: jac-shadcn-components
description: Install and compose jac-shadcn primitives, icons, and themes. Use when a project uses jac-shadcn or needs a specific UI primitive.
---

# jac-shadcn components

Use installed project primitives when they meet the task. Inspect their declarations before composing them: prop names, callback types, and forwarded attributes can differ from React examples.

## Locate and install

A jac-shadcn project normally stores primitives under `components/ui/`. Respect an existing location; `[jac-shadcn] components_dir` and `utils_path` can pin it. `jac install --shadcn` discovers an existing UI directory and resolves utility imports.

Use the installer for a missing supported primitive instead of copying a React implementation into Jac. A custom component is appropriate when the requested behavior is not supplied by an existing primitive.

```bash
jac install --shadcn button card input
```

Import using the project's existing relative client paths. Compose the installed components and use the project's theme tokens. Read `jac-shadcn-blocks` for layout recipes only when that helps the requested page.

## Retrieve a component's contract

The catalog and examples are available on demand:

```bash
jac guide reference/agent-patterns/jac-shadcn-components --sections
```

Select the relevant section for controls, dialogs, navigation, tables, icons, or theming. The catalog explains supported composition and known prop limitations; local source remains necessary when the project has customized a primitive.

Run `jac check` and test the actual interaction, including keyboard/focus behavior for dialogs and menus. Do not infer that a generic HTML prop works on every imported component.
