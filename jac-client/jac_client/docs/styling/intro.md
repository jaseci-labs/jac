# Styling in Jac

This guide covers all styling approaches available in Jac web applications. Each approach is demonstrated with a complete, working counter application example.

## Quick Navigation

### Available Examples

| Styling Approach | Documentation | Example Location |
|------------------|---------------|------------------|
| [**Pure CSS**](./pure-css.md) | Traditional CSS with external stylesheet | [`examples/css-styling/pure-css/`](https://docs.jaseci.org/jac-client/styling/pure-css/) |
| [**Tailwind CSS**](./tailwind.md) | Utility-first CSS framework | [`examples/css-styling/tailwind-example/`](https://docs.jaseci.org/jac-client/styling/tailwind/) |
| [**Sass/SCSS**](./sass.md) | CSS preprocessor with variables, mixins, nesting | [`examples/css-styling/sass-example/`](https://docs.jaseci.org/jac-client/styling/sass/) |
| [**Styled Components**](./styled-components.md) | CSS-in-JS with styled-components | [`examples/css-styling/styled-components/`](https://docs.jaseci.org/jac-client/styling/styled-components/) |
| [**JavaScript Styling**](./js-styling.md) | Inline styles using JavaScript objects | [`examples/css-styling/js-styling/`](https://docs.jaseci.org/jac-client/styling/js-styling/) |
| [**Material-UI**](./material-ui.md) | React component library with Material Design | [`examples/css-styling/material-ui/`](https://docs.jaseci.org/jac-client/styling/material-ui/) |

## Styling Approaches Overview

### Traditional CSS

- **Pure CSS:** Standard CSS with external stylesheets
  - Maximum control, minimal dependencies
  - Perfect for simple projects and learning

### CSS Preprocessors

- **Sass/SCSS:** Variables, nesting, mixins, and functions
  - Better organization for large projects
  - DRY principles with reusable code

### Utility-First CSS

- **Tailwind CSS:** On-demand utility classes
  - Rapid UI development
  - Consistent design system

### CSS-in-JS Libraries

- **Styled Components:** CSS-in-JS with template literals
  - Component-scoped styles
  - Dynamic styling with props

- **JavaScript Styling:** Inline styles using JavaScript objects
  - Programmatic style generation
  - Dynamic styles based on state

### Component Libraries

- **Material-UI:** Comprehensive React component library
  - Pre-built, accessible components
  - Material Design system

## Choosing the Right Approach

### Decision Matrix

| Approach | Complexity | Bundle Size | Runtime Cost | Best For |
|----------|-----------|-------------|--------------|----------|
| Pure CSS | Low | Small | None | Simple projects |
| Tailwind | Medium | Small* | None | Rapid development |
| Sass/SCSS | Medium | Small | None | Large projects |
| Styled Components | Medium | Medium | Medium | Component libraries |
| JavaScript Styling | Low | Small | Low | Dynamic styles |
| Material-UI | Low | Large | Low | Enterprise apps |

*Tailwind bundle size is small after purging unused classes.

### Quick Decision Guide

**Choose Pure CSS if**:

- Building a simple application
- Wanting minimal dependencies
- Learning CSS fundamentals

**Choose Tailwind CSS if**:

- Building modern UIs quickly
- Preferring utility classes
- Needing responsive design

**Choose Sass/SCSS if**:

- Working on large projects
- Needing variables and mixins
- Wanting better organization

**Choose Styled Components if**:

- Wanting component-scoped styles
- Needing dynamic styling
- Preferring CSS-in-JS

**Choose JavaScript Styling if**:

- Needing dynamic styles
- Preferring JavaScript
- Building component libraries

**Choose Material-UI if**:

- Wanting pre-built components
- Needing accessibility
- Preferring Material Design

## Import Syntax

All styling approaches use the `cl import` syntax for client-side imports:

### CSS Files

```jac
# Pure CSS
cl import ".styles.css";

# Sass/SCSS
cl import ".styles.scss";
```

### JavaScript Modules

```jac
# Default export
cl import from .styles { default as styles }

# Named exports
cl import from .styled { Container, Card, Button }
```

### External Packages

```jac
# Styled Components
cl import from "styled-components" { default as styled }

# Material-UI
cl import from "@mui/material/Button" { default as Button }
cl import from "@mui/icons-material/Add" { default as AddIcon }
```

## Running Examples

Each example is a complete, runnable project:

```bash
# Navigate to example directory
cd jac_client/examples/css-styling/<example-name>

# Install dependencies
npm install

# Run the application
jac start main.jac
```

## Best Practices

### General Styling

1. **Consistency**: Choose one approach per project
2. **Performance**: Consider bundle size and runtime cost
3. **Maintainability**: Keep styles organized and documented
4. **Accessibility**: Ensure styles don't break accessibility
5. **Responsive**: Design mobile-first

### CSS Files

1. **Organization**: Use comments to separate sections
2. **Naming**: Use semantic class names (BEM, etc.)
3. **Specificity**: Avoid overly specific selectors
4. **Variables**: Use CSS custom properties for theming

### CSS-in-JS

1. **Scoping**: Leverage component-scoped styles
2. **Performance**: Memoize expensive styled components
3. **Theming**: Use theme providers for global styles
4. **Props**: Keep prop-based styling simple

### Component Libraries

1. **Customization**: Use theme system for brand colors
2. **Variants**: Prefer built-in variants when possible
3. **Composition**: Compose components for flexibility
4. **Accessibility**: Use accessible components by default

## Resources

- [Import System Documentation](../imports.md)
- [Routing Documentation](../routing.md)
- [Lifecycle Hooks](../lifecycle-hooks.md)
- [Complete Example Guide](../guide-example/intro.md)

> **Upcoming Styling Patterns**

<div style="border: 1.5px solid #ffa500; background: #fff4cc; color: #333; padding: 1.2em 1.4em; border-radius: 8px; margin: 2em 0;">

The following styling approaches are <strong>planned</strong> for documentation in Jac, but full code examples are coming soon:

---

<strong>CSS-in-JS Libraries</strong>
<ul>
  <li><strong>Emotion:</strong> CSS-in-JS with similar API to styled-components</li>
  <li><strong>Styled JSX:</strong> CSS-in-JS (Next.js style)</li>
</ul>

<strong>CSS Modules</strong>
<ul>
  <li><strong>CSS Modules:</strong> Scoped CSS with local class names</li>
</ul>

<strong>Modern CSS</strong>
<ul>
  <li><strong>CSS Variables (Custom Properties):</strong> Native CSS variables for theming</li>
  <li><strong>PostCSS:</strong> CSS transformations and plugins</li>
</ul>

<strong>Component Libraries</strong>
<ul>
  <li><strong>Chakra UI:</strong> Modular and accessible component library</li>
  <li><strong>Ant Design:</strong> Enterprise-focused component library</li>
  <li><strong>Radix UI:</strong> Unstyled, accessible primitives</li>
  <li><strong>Mantine:</strong> Full-featured React components</li>
</ul>

<strong>CSS Frameworks</strong>
<ul>
  <li><strong>Bulma:</strong> Flexbox-based CSS framework</li>
  <li><strong>Foundation:</strong> Responsive framework</li>
  <li><strong>Semantic UI:</strong> Natural language class names</li>
</ul>

<strong>Zero-runtime CSS-in-JS</strong>
<ul>
  <li><strong>Vanilla Extract</strong> Type-safe, zero-runtime CSS-in-JS</li>
  <li><strong>Linaria</strong> Zero-runtime CSS-in-JS</li>
  <li><strong>Stitches</strong> CSS-in-JS with variants API</li>
</ul>

<strong>Utility-first</strong>
<ul>
  <li><strong>UnoCSS</strong> On-demand atomic CSS engine</li>
</ul>

<em>Examples for these patterns will be added soon.</em>
</div>

## Contributing

When adding new styling examples:

1. Create a new directory in `examples/css-styling/`
2. Include a complete working counter app
3. Add a README.md with setup instructions
4. Create a documentation file in `docs/styling/`
5. Update this intro.md file
6. Follow the existing example structure
