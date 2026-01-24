# JavaScript Styling Example

This example demonstrates styling a Jac application using JavaScript objects for inline styles.

## Overview

JavaScript styling uses JavaScript objects to define styles, which are then applied via the `style` prop. This approach is perfect for:

- Dynamic styling based on state
- Programmatic style generation
- Component-scoped styles without CSS files
- React-style inline styling

## Project Structure

```
js-styling/
├── app.jac          # Main application component
├── styles.js        # Style objects exported as default
├── package.json     # Dependencies
└── vite.config.js   # Vite configuration
```

## Setup

1. Install dependencies:

```bash
bun install
```

1. Run the application:

```bash
jac start app.jac
```

## How It Works

### 1. Define Style Objects

In `styles.js`, export a default object with all styles:

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
    // ... more styles
};
```

### 2. Import Styles

In your Jac file:

```jac
cl import from .styles { default as styles }
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
    zIndex: 1                   // not z-index
}
```

## Best Practices

1. **Use object spread**: Share common styles with spread operator
2. **Organize by component**: Group related styles together
3. **Use constants**: Define reusable values at the top
4. **CamelCase properties**: Follow React naming convention
5. **Extract complex logic**: Move style calculations to functions

## Advantages

- Dynamic styling based on props/state
- No CSS file needed
- Type-safe (with TypeScript)
- Component-scoped by default
- Programmatic style generation

## Limitations

- No pseudo-classes (hover, focus, etc.)
- No media queries
- No CSS animations (use JavaScript)
- Verbose for complex styles
- No CSS preprocessor features

## When to Use

Choose JavaScript Styling when:

- You need dynamic styles based on state
- You want programmatic style generation
- You prefer keeping styles in JavaScript
- You're building component libraries
- You need runtime style calculations

## Advanced Patterns

### Style Functions

Create functions that return styles:

```javascript
export const getButtonStyle = (variant) => ({
    ...buttonBase,
    backgroundColor: variant === 'primary' ? '#007bff' : '#6c757d'
});
```

### Conditional Styles

Use ternary operators for conditional styles:

```javascript
export default {
    button: {
        backgroundColor: isActive ? '#007bff' : '#6c757d',
        opacity: isDisabled ? 0.5 : 1,
    }
};
```

## Next Steps

- Explore [Styled Components](../styled-components/) for CSS-in-JS with more features
- Check out [Emotion](../emotion-example/) for similar CSS-in-JS approach (coming soon)
- Learn about [CSS Modules](../css-modules/) for scoped CSS (coming soon)
