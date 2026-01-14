# Pure CSS

Traditional CSS with external stylesheets. The most straightforward styling approach for Jac applications.

## Overview

Pure CSS is the foundation of web styling. You write CSS in a separate file and import it into your Jac code. This approach is perfect for:

- Simple projects
- Learning CSS fundamentals
- Maximum control over styling
- Minimal dependencies

## Example

See the complete working example: [`examples/css-styling/pure-css/`](../../examples/css-styling/pure-css/)

## Quick Start

### 1. Create CSS File

Create a `styles.css` file in your project:

```css
.container {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.card {
    background: white;
    border-radius: 20px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    padding: 40px;
    min-width: 400px;
    text-align: center;
}

.title {
    font-size: 2rem;
    color: #667eea;
    margin: 0 0 10px 0;
    font-weight: 600;
}
```

### 2. Import CSS in Jac

In your Jac file, import the CSS file:

```jac
# Pages
cl import from react { useEffect }
cl import ".styles.css";

# Note: useState is auto-injected when using `has` variables

cl {
    has count: int = 0;  # Automatically creates React state

    def app() -> any {
        return <div className="container">
            <div className="card">
                <h1 className="title">Counter Application</h1>
                <p>Count: {count}</p>
            </div>
        </div>;
    }
}
```

### 3. Use Class Names

Apply CSS classes using the `className` prop:

```jac
return <div className="container">
    <div className="card">
        <h1 className="title">Counter Application</h1>
    </div>
</div>;
```

### 4. Dynamic Classes

Dynamically construct class names based on state:

```jac
countClass = "countDisplay " + ("positive" if count > 0 else "negative" if count < 0 else "zero");

return <div className={countClass}>{count}</div>;
```

## Import Syntax

CSS files are imported using the `cl import` syntax:

```jac
cl import ".styles.css";
```

This compiles to:

```javascript
import "./styles.css";
```

Vite automatically processes CSS imports and extracts them to a separate CSS file during the build process.

## Best Practices

### 1. Organize Your CSS

Use comments to separate sections:

```css
/* ============================================
   Container Styles
   ============================================ */
.container {
    /* styles */
}

/* ============================================
   Card Styles
   ============================================ */
.card {
    /* styles */
}
```

### 2. Use Semantic Class Names

Make class names descriptive and meaningful:

```css
/* Good */
.button-primary { }
.card-header { }
.navigation-menu { }

/* Avoid */
.btn1 { }
.div1 { }
.red { }
```

### 3. Use CSS Variables for Theming

Leverage CSS custom properties for theming:

```css
:root {
    --primary-color: #007bff;
    --secondary-color: #6c757d;
    --spacing-unit: 1rem;
}

.button {
    background-color: var(--primary-color);
    padding: var(--spacing-unit);
}
```

### 4. Mobile-First Design

Design for mobile, then enhance for desktop:

```css
/* Mobile first */
.container {
    padding: 1rem;
}

/* Desktop */
@media (min-width: 768px) {
    .container {
        padding: 2rem;
    }
}
```

### 5. Avoid Inline Styles

Keep styles in the CSS file for maintainability:

```jac
//  Avoid
<div style={{"padding": "1rem", "color": "blue"}}>

//  Prefer
<div className="container">
```

## Advantages

- **No build step required** for CSS
- **Easy to understand** and maintain
- **Works with any CSS framework**
- **Minimal dependencies**
- **Great browser support**
- **Familiar syntax** for developers

## Limitations

- **No variables or nesting** (use CSS variables for theming)
- **No preprocessing features**
- **Global scope** (use BEM or similar for scoping)
- **No dynamic styling** based on props
- **Manual organization** required

## When to Use

Choose Pure CSS when:

- You're building a simple application
- You want minimal dependencies
- You prefer traditional CSS workflow
- You're learning CSS fundamentals
- You need maximum control
- You want to avoid build complexity

## CSS Variables (Custom Properties)

Use CSS custom properties for theming and dynamic values:

```css
:root {
    --primary: #007bff;
    --secondary: #6c757d;
    --success: #28a745;
    --danger: #dc3545;
    --spacing-sm: 0.5rem;
    --spacing-md: 1rem;
    --spacing-lg: 2rem;
}

.button {
    background-color: var(--primary);
    padding: var(--spacing-md);
}

.button-success {
    background-color: var(--success);
}
```

## Responsive Design

Use media queries for responsive layouts:

```css
.container {
    padding: 1rem;
}

@media (min-width: 768px) {
    .container {
        padding: 2rem;
    }
}

@media (min-width: 1024px) {
    .container {
        padding: 3rem;
    }
}
```

## Naming Conventions

### BEM (Block Element Modifier)

```css
.card { }                    /* Block */
.card__header { }           /* Element */
.card__header--highlighted { } /* Modifier */
```

### Utility Classes

```css
.text-center { text-align: center; }
.mt-1 { margin-top: 0.25rem; }
.p-2 { padding: 0.5rem; }
```

## Next Steps

- Learn about [CSS Variables](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties) for advanced theming
- Explore [Sass/SCSS](./sass.md) for preprocessing features
- Check out [Tailwind CSS](./tailwind.md) for utility-first approach
- See CSS Modules for scoped styles (coming soon)

## Resources

- [MDN CSS Documentation](https://developer.mozilla.org/en-US/docs/Web/CSS)
- [CSS Tricks](https://css-tricks.com/)
- [Can I Use](https://caniuse.com/) - Browser compatibility
