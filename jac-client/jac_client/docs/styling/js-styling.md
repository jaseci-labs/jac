# JavaScript Styling

Inline styles using JavaScript objects for dynamic styling in Jac applications.

## Overview

JavaScript styling uses JavaScript objects to define styles, which are then applied via the `style` prop. This approach is perfect for:

- Dynamic styling based on state
- Programmatic style generation
- Component-scoped styles without CSS files
- React-style inline styling

## Example

See the complete working example: [`examples/css-styling/js-styling/`](../../examples/css-styling/js-styling/)

## Quick Start

### 1. Define Style Objects

Create `styles.js`:

```javascript
const countDisplay = {
    fontSize: "3.75rem",
    fontWeight: "bold",
    transition: "color 0.3s ease"
};

export default {
    container: {
        minHeight: "100vh",
        background: "linear-gradient(to bottom right, #dbeafe, #e0e7ff)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "1rem"
    },
    card: {
        backgroundColor: "#ffffff",
        borderRadius: "1rem",
        boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
        padding: "2rem",
        maxWidth: "28rem",
        width: "100%"
    },
    countDisplayZero: {
        ...countDisplay,
        color: "#1f2937"
    },
    countDisplayPositive: {
        ...countDisplay,
        color: "#16a34a"
    },
    countDisplayNegative: {
        ...countDisplay,
        color: "#dc2626"
    },
    button: {
        color: "#ffffff",
        fontWeight: "bold",
        padding: "0.75rem 1.5rem",
        borderRadius: "0.5rem",
        border: "none",
        cursor: "pointer"
    },
    buttonDecrement: {
        backgroundColor: "#ef4444"
    },
    buttonReset: {
        backgroundColor: "#6b7280"
    },
    buttonIncrement: {
        backgroundColor: "#22c55e"
    }
};
```

### 2. Import Styles

```jac
# Pages
cl import from react { useEffect }
cl import from .styles { default as styles }

# Note: useState is auto-injected when using `has` variables

cl {
    def app() -> JsxElement {
        return <div style={styles.container}>
            <div style={styles.card}>
                <h1 style={styles.title}>Counter Application</h1>
            </div>
        </div>;
    }
}
```

### 3. Apply Styles

Use the `style` prop with style objects:

```jac
return <div style={styles.container}>
    <div style={styles.card}>
        <h1 style={styles.title}>Counter Application</h1>
    </div>
</div>;
```

### 4. Dynamic Styles

Select styles based on state:

```jac
countStyle = styles.countDisplayZero if count == 0 else (styles.countDisplayPositive if count > 0 else styles.countDisplayNegative);

return <div style={countStyle}>{count}</div>;
```

## Style Object Format

JavaScript style objects use camelCase property names (React convention):

```javascript
{
    backgroundColor: "#ffffff",  // not background-color
    fontSize: "1.5rem",         // not font-size
    marginTop: "10px",          // not margin-top
    zIndex: 1,                  // not z-index
    borderTopLeftRadius: "4px"  // not border-top-left-radius
}
```

## Best Practices

### 1. Use Object Spread

Share common styles with spread operator:

```javascript
const baseButton = {
    padding: "0.75rem 1.5rem",
    borderRadius: "0.5rem",
    border: "none",
    cursor: "pointer"
};

export default {
    primaryButton: {
        ...baseButton,
        backgroundColor: "#007bff",
        color: "#ffffff"
    },
    secondaryButton: {
        ...baseButton,
        backgroundColor: "#6c757d",
        color: "#ffffff"
    }
};
```

### 2. Organize by Component

Group related styles together:

```javascript
export default {
    // Container styles
    container: { ... },
    card: { ... },

    // Button styles
    button: { ... },
    buttonPrimary: { ... },
    buttonSecondary: { ... },

    // Text styles
    title: { ... },
    subtitle: { ... }
};
```

### 3. Use Constants

Define reusable values at the top:

```javascript
const COLORS = {
    primary: "#007bff",
    secondary: "#6c757d",
    success: "#28a745",
    danger: "#dc3545"
};

const SPACING = {
    sm: "0.5rem",
    md: "1rem",
    lg: "2rem"
};

export default {
    button: {
        backgroundColor: COLORS.primary,
        padding: SPACING.md
    }
};
```

### 4. CamelCase Properties

Follow React naming convention:

```javascript
// Good
{
    backgroundColor: "#fff",
    fontSize: "1rem",
    marginTop: "10px"
}

// Avoid
{
    "background-color": "#fff",  // Wrong
    "font-size": "1rem"          // Wrong
}
```

### 5. Extract Complex Logic

Move style calculations to functions:

```javascript
export const getButtonStyle = (variant, disabled) => {
    const base = {
        padding: "0.75rem 1.5rem",
        borderRadius: "0.5rem",
        border: "none",
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? 0.5 : 1
    };

    const variants = {
        primary: { backgroundColor: "#007bff", color: "#ffffff" },
        secondary: { backgroundColor: "#6c757d", color: "#ffffff" }
    };

    return { ...base, ...variants[variant] };
};
```

## Advanced Patterns

### Style Functions

Create functions that return styles:

```javascript
export const getButtonStyle = (variant) => ({
    padding: "0.75rem 1.5rem",
    borderRadius: "0.5rem",
    backgroundColor: variant === 'primary' ? '#007bff' : '#6c757d',
    color: '#ffffff'
});
```

Use in Jac:

```jac
buttonStyle = getButtonStyle("primary");

return <button style={buttonStyle}>Click Me</button>;
```

### Conditional Styles

Use ternary operators for conditional styles:

```javascript
export default {
    button: (isActive, isDisabled) => ({
        backgroundColor: isActive ? '#007bff' : '#6c757d',
        opacity: isDisabled ? 0.5 : 1,
        cursor: isDisabled ? 'not-allowed' : 'pointer'
    })
};
```

### Dynamic Values

Calculate styles based on props:

```javascript
export const getContainerStyle = (width, height) => ({
    width: `${width}px`,
    height: `${height}px`,
    display: "flex",
    alignItems: "center",
    justifyContent: "center"
});
```

## Advantages

- **Dynamic styling** based on props/state
- **No CSS file needed**
- **Type-safe** with TypeScript
- **Component-scoped** by default
- **Programmatic style generation**
- **Easy to debug** (JavaScript objects)
- **No build step** for styles

## Limitations

- **No pseudo-classes** (hover, focus, etc.)
- **No media queries**
- **No CSS animations** (use JavaScript)
- **Verbose** for complex styles
- **No CSS preprocessor features**
- **Performance** can be slower for many elements

## When to Use

Choose JavaScript Styling when:

- You need dynamic styles based on state
- You want programmatic style generation
- You prefer keeping styles in JavaScript
- You're building component libraries
- You need runtime style calculations
- You want type safety with TypeScript

## Import Syntax

Style objects are imported as JavaScript modules:

```jac
# Default export
cl import from .styles { default as styles }

# Named exports (if using named exports)
cl import from .styles { button, card, container }
```

## Combining Styles

You can combine multiple style objects:

```jac
combinedStyle = {
    ...styles.base,
    ...styles.button,
    ...(isActive ? styles.active : {})
};

return <button style={combinedStyle}>Click Me</button>;
```

## Next Steps

- Explore [Styled Components](./styled-components.md) for CSS-in-JS with more features
- Check out Emotion for similar CSS-in-JS approach (coming soon)
- Learn about CSS Modules for scoped CSS (coming soon)
- See [Pure CSS](./pure-css.md) for traditional CSS approach

## Resources

- [React Inline Styles](https://react.dev/learn/javascript-in-jsx-with-curly-braces#using-double-curlies-css-and-other-objects-in-jsx)
- [CSS-in-JS Comparison](https://github.com/MicheleBertoli/css-in-js)
