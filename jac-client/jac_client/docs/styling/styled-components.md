# Styled Components

CSS-in-JS library with component-scoped styles and dynamic styling for Jac applications.

## Overview

Styled Components allows you to write CSS-in-JS using template literals. Styles are scoped to components and can be dynamic based on props. This approach is perfect for:

- Component-scoped styles
- Dynamic styling based on props
- CSS-in-JS with full CSS features
- React component libraries

## Example

See the complete working example: [`examples/css-styling/styled-components/`](../../examples/css-styling/styled-components/)

## Quick Start

### 1. Install styled-components

Add to `package.json`:

```json
{
  "dependencies": {
    "styled-components": "^6.1.13"
  }
}
```

### 2. Create Styled Components

Create `styled.js`:

```javascript
import styled from "styled-components";

export const Container = styled.div`
    min-height: 100vh;
    background: linear-gradient(to bottom right, #dbeafe, #e0e7ff);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
`;

export const Card = styled.div`
    background-color: #ffffff;
    border-radius: 1rem;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    padding: 2rem;
    max-width: 28rem;
    width: 100%;
`;

export const Button = styled.button`
    color: #ffffff;
    font-weight: bold;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    background-color: ${props => props.bgColor};

    &:hover {
        transform: scale(1.05);
    }

    &:active {
        transform: scale(0.95);
    }
`;
```

### 3. Import and Use in Jac

```jac
# Pages
cl import from react { useEffect }
cl import from .styled {
    Container,
    Card,
    Button
}

# Note: useState is auto-injected when using `has` variables

cl {
    def app() -> JsxElement {
        return <Container>
            <Card>
                <Button bgColor="#ef4444" onClick={handleClick}>
                    Click Me
                </Button>
            </Card>
        </Container>;
    }
}
```

## Key Features

### Dynamic Styling with Props

Styled components can access props for dynamic styling:

```javascript
const Button = styled.button`
    background-color: ${props => props.bgColor || '#007bff'};
    color: ${props => props.primary ? 'white' : 'black'};
    padding: ${props => props.large ? '1rem 2rem' : '0.75rem 1.5rem'};
`;
```

### Pseudo-classes

Use CSS pseudo-classes:

```javascript
const Button = styled.button`
    background-color: #007bff;

    &:hover {
        background-color: #0056b3;
        transform: scale(1.05);
    }

    &:active {
        transform: scale(0.95);
    }

    &:focus {
        outline: 2px solid #007bff;
        outline-offset: 2px;
    }
`;
```

### Media Queries

Responsive design with media queries:

```javascript
const Container = styled.div`
    padding: 1rem;

    @media (min-width: 768px) {
        padding: 2rem;
    }

    @media (min-width: 1024px) {
        padding: 3rem;
    }
`;
```

### Theming

Use ThemeProvider for global themes:

```javascript
import { ThemeProvider } from 'styled-components';

const theme = {
    colors: {
        primary: '#007bff',
        secondary: '#6c757d',
        success: '#28a745',
    },
    spacing: {
        sm: '0.5rem',
        md: '1rem',
        lg: '2rem',
    }
};

// In your app
<ThemeProvider theme={theme}>
    <App />
</ThemeProvider>
```

Access theme in styled components:

```javascript
const Button = styled.button`
    background-color: ${props => props.theme.colors.primary};
    padding: ${props => props.theme.spacing.md};
`;
```

## Best Practices

### 1. Component Naming

Use PascalCase for styled components:

```javascript
// Good
const PrimaryButton = styled.button`...`;
const CardHeader = styled.div`...`;

// Avoid
const button = styled.button`...`;
const card_header = styled.div`...`;
```

### 2. Extract Common Styles

Create base components and extend them:

```javascript
const ButtonBase = styled.button`
    color: #ffffff;
    font-weight: bold;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    border: none;
    cursor: pointer;
`;

const PrimaryButton = styled(ButtonBase)`
    background-color: #007bff;

    &:hover {
        background-color: #0056b3;
    }
`;

const SecondaryButton = styled(ButtonBase)`
    background-color: #6c757d;

    &:hover {
        background-color: #545b62;
    }
`;
```

### 3. Use Props Wisely

Keep prop-based styling simple:

```javascript
// Good
const Button = styled.button`
    background-color: ${props => props.variant === 'primary' ? '#007bff' : '#6c757d'};
`;

// Avoid complex logic in template literals
const Button = styled.button`
    background-color: ${props => {
        if (props.variant === 'primary') {
            if (props.disabled) return '#ccc';
            return '#007bff';
        }
        // ... too complex
    }};
`;
```

### 4. Organize Files

Group related styled components together:

```javascript
// components/Button.styled.js
export const Button = styled.button`...`;
export const ButtonGroup = styled.div`...`;

// components/Card.styled.js
export const Card = styled.div`...`;
export const CardHeader = styled.div`...`;
export const CardBody = styled.div`...`;
```

### 5. Performance

Use `React.memo` for expensive styled components:

```javascript
const ExpensiveComponent = React.memo(styled.div`
    /* complex styles */
`);
```

## Advanced Patterns

### Extending Components

Extend existing styled components:

```javascript
const Button = styled.button`
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
`;

const PrimaryButton = styled(Button)`
    background-color: #007bff;
    color: white;
`;

const LargeButton = styled(Button)`
    padding: 1rem 2rem;
    font-size: 1.25rem;
`;
```

### Conditional Rendering

Use conditional logic in styles:

```javascript
const Container = styled.div`
    display: ${props => props.hidden ? 'none' : 'flex'};
    opacity: ${props => props.disabled ? 0.5 : 1};
    pointer-events: ${props => props.disabled ? 'none' : 'auto'};
`;
```

### Animations

Use CSS animations:

```javascript
const FadeIn = styled.div`
    animation: fadeIn 0.5s ease-in;

    @keyframes fadeIn {
        from {
            opacity: 0;
            transform: translateY(-10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
`;
```

## Advantages

- **Component-scoped styles** (no CSS conflicts)
- **Dynamic styling** based on props
- **Full CSS features** (pseudo-classes, media queries)
- **Type-safe** with TypeScript
- **Automatic vendor prefixing**
- **Dead code elimination**
- **No class name collisions**

## Limitations

- **Runtime overhead** (styles generated at runtime)
- **Learning curve** for CSS-in-JS
- **Larger bundle size** than CSS
- **Requires JavaScript** for styling
- **Debugging** can be harder

## When to Use

Choose Styled Components when:

- You want component-scoped styles
- You need dynamic styling based on props
- You prefer CSS-in-JS approach
- You're building component libraries
- You want full CSS features in JavaScript
- You want to avoid class name conflicts

## Import Syntax

Styled components are imported as JavaScript modules:

```jac
cl import from .styled {
    Container,
    Card,
    Button
}
```

For external packages:

```jac
cl import from "styled-components" { default as styled }
```

## Next Steps

- Explore Emotion for similar CSS-in-JS (coming soon)
- Check out Vanilla Extract for zero-runtime CSS-in-JS (coming soon)
- Learn about [JavaScript Styling](./js-styling.md) for inline styles
- See CSS Modules for scoped CSS (coming soon)

## Resources

- [Styled Components Documentation](https://styled-components.com/docs)
- [Styled Components Best Practices](https://styled-components.com/docs/basics#styling-any-component)
