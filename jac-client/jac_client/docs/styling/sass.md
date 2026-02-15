# Sass/SCSS

CSS preprocessor with variables, nesting, mixins, and functions for Jac applications.

## Overview

Sass (Syntactically Awesome Style Sheets) extends CSS with powerful features like variables, nesting, mixins, and functions. This approach is perfect for:

- Large projects with shared styles
- DRY (Don't Repeat Yourself) principles
- Complex styling logic
- Maintainable CSS architecture

## Example

See the complete working example: [`examples/css-styling/sass-example/`](../../examples/css-styling/sass-example/)

## Quick Start

### 1. Install Sass

Add to `package.json`:

```json
{
  "devDependencies": {
    "sass": "^1.77.8"
  }
}
```

### 2. Create SCSS File

Create `styles.scss`:

```scss
$primary-color: #007bff;
$secondary-color: #6c757d;

.button {
    background-color: $primary-color;
    color: white;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;

    &:hover {
        background-color: darken($primary-color, 10%);
    }
}
```

### 3. Import in Jac

```jac
# Pages
cl import from react { useEffect }
cl import ".styles.scss";

# Note: useState is auto-injected when using `has` variables

cl {
    def app() -> JsxElement {
        return <div className="container">
            <button className="button">Click Me</button>
        </div>;
    }
}
```

Vite automatically compiles SCSS to CSS during the build process.

## Sass Features

### Variables

Define reusable values:

```scss
$primary-gradient-start: #dbeafe;
$primary-gradient-end: #e0e7ff;
$white: #ffffff;
$gray-800: #1f2937;
$spacing-unit: 1rem;
```

### Nesting

Nest selectors for better organization:

```scss
.button {
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;

    &:hover {
        transform: scale(1.05);
    }

    &:active {
        transform: scale(0.95);
    }

    &Decrement {
        background-color: $red-500;
    }

    &Reset {
        background-color: $gray-500;
    }
}
```

### Mixins

Create reusable style blocks:

```scss
@mixin flex-center {
    display: flex;
    align-items: center;
    justify-content: center;
}

@mixin button-base {
    color: $white;
    font-weight: bold;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    border: none;
    cursor: pointer;

    &:hover {
        transform: scale(1.05);
    }
}

.container {
    @include flex-center;
    min-height: 100vh;
}

.button {
    @include button-base;
    background-color: $primary-color;
}
```

### Functions

Use built-in and custom functions:

```scss
.button {
    background-color: $red-500;

    &:hover {
        background-color: darken($red-500, 10%);
    }
}

.card {
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);

    &:hover {
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
    }
}
```

### Partials and Imports

Organize styles across multiple files:

```scss
// _variables.scss
$primary: #007bff;
$secondary: #6c757d;

// _mixins.scss
@mixin flex-center {
    display: flex;
    align-items: center;
    justify-content: center;
}

// styles.scss
@import 'variables';
@import 'mixins';

.container {
    @include flex-center;
    background-color: $primary;
}
```

## Best Practices

### 1. Use Variables

Define colors, spacing, and other values as variables:

```scss
$colors: (
    primary: #007bff,
    secondary: #6c757d,
    success: #28a745,
    danger: #dc3545,
);

.button {
    background-color: map-get($colors, primary);
}
```

### 2. Create Mixins

Extract common patterns into mixins:

```scss
@mixin respond-to($breakpoint) {
    @media (min-width: $breakpoint) {
        @content;
    }
}

.container {
    padding: 1rem;

    @include respond-to(768px) {
        padding: 2rem;
    }
}
```

### 3. Organize with Partials

Split large files into smaller modules:

```
styles/
├── _variables.scss
├── _mixins.scss
├── _components.scss
└── main.scss
```

### 4. Use Nesting Wisely

Don't nest too deeply (max 3-4 levels):

```scss
// Good
.card {
    padding: 1rem;

    &__header {
        font-weight: bold;
    }
}

// Avoid
.card {
    .header {
        .title {
            .text {
                // Too deep!
            }
        }
    }
}
```

### 5. Leverage Functions

Use Sass functions for calculations:

```scss
.container {
    width: percentage(2/3);
    margin: rem(16px);
}
```

## Common Patterns

### BEM with Nesting

```scss
.card {
    padding: 1rem;

    &__header {
        padding: 1rem;
        border-bottom: 1px solid #ddd;
    }

    &__body {
        padding: 1.5rem;
    }

    &--highlighted {
        border: 2px solid $primary;
    }
}
```

### Color Management

```scss
$colors: (
    primary: #007bff,
    secondary: #6c757d,
    success: #28a745,
    danger: #dc3545,
);

@function color($name) {
    @return map-get($colors, $name);
}

.button {
    background-color: color(primary);
}
```

### Responsive Mixins

```scss
@mixin respond-to($breakpoint) {
    @if $breakpoint == mobile {
        @media (max-width: 767px) { @content; }
    }
    @else if $breakpoint == tablet {
        @media (min-width: 768px) { @content; }
    }
    @else if $breakpoint == desktop {
        @media (min-width: 1024px) { @content; }
    }
}

.container {
    padding: 1rem;

    @include respond-to(tablet) {
        padding: 2rem;
    }
}
```

## Advantages

- **Variables** for maintainable theming
- **Nesting** for better organization
- **Mixins** for reusable code
- **Functions** for dynamic values
- **Partials** for modular CSS
- **Compiles to standard CSS**
- **Large ecosystem** and community

## Limitations

- **Requires build step**
- **Learning curve** for Sass syntax
- **Can get complex** with deep nesting
- **Additional dependency**
- **Debugging** can be harder (source maps help)

## When to Use

Choose Sass/SCSS when:

- You're working on large projects
- You need variables and mixins
- You want better CSS organization
- You prefer preprocessing over runtime CSS
- You need complex styling logic
- You want to share styles across components

## Import Syntax

SCSS files are imported using the `cl import` syntax:

```jac
cl import ".styles.scss";
```

This compiles to:

```javascript
import "./styles.scss";
```

Vite automatically processes SCSS imports and compiles them to CSS.

## Next Steps

- Explore [Sass Documentation](https://sass-lang.com/documentation)
- Check out Less for similar preprocessing (coming soon)
- Learn about PostCSS for CSS transformations (coming soon)
- See [Pure CSS](./pure-css.md) for traditional CSS approach

## Resources

- [Sass Documentation](https://sass-lang.com/documentation)
- [Sass Guidelines](https://sass-guidelin.es/)
- [Sass Playground](https://www.sassmeister.com/)
