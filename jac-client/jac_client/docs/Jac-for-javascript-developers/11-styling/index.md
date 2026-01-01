# Styling

Different approaches to styling in JAC-Client.

---

## Inline Styles

Object with quoted keys:

```jac
def StyledComponent() -> any {
    styles = {
        "container": {
            "padding": "20px",
            "backgroundColor": "#f0f0f0",
            "borderRadius": "8px"
        },
        "title": {
            "color": "#333",
            "fontSize": "24px",
            "fontWeight": "bold"
        }
    };

    return (
        <div style={styles["container"]}>
            <h1 style={styles["title"]}>Hello</h1>
        </div>
    );
}
```

---

## Dynamic Styles

```jac
def DynamicStyle() -> any {
    [isActive, setIsActive] = useState(False);

    buttonStyle = {
        "padding": "10px 20px",
        "backgroundColor": ("blue") if isActive else ("gray"),
        "color": "white",
        "cursor": "pointer"
    };

    return (
        <button
            style={buttonStyle}
            onClick={lambda: setIsActive(not isActive)}
        >
            {("Active") if isActive else ("Inactive")}
        </button>
    );
}
```

---

## CSS Classes

Create a CSS file and use className:

**styles.css:**

```css
.container {
    padding: 20px;
    max-width: 800px;
    margin: 0 auto;
}

.button {
    padding: 10px 20px;
    background-color: blue;
    color: white;
    border: none;
    border-radius: 4px;
}

.button:hover {
    background-color: darkblue;
}
```

**app.jac:**

```jac
cl {
    def app() -> any {
        return (
            <div className="container">
                <button className="button">Click me</button>
            </div>
        );
    }
}
```

---

## Tailwind CSS

```jac
def TailwindExample() -> any {
    return (
        <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-lg">
            <h1 className="text-2xl font-bold text-gray-800 mb-4">
                Tailwind Styling
            </h1>
            <button className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                Click me
            </button>
        </div>
    );
}
```

---

## Styled Components

```jac
cl import from styled-components { default as styled }

cl {
    StyledButton = styled.button`
        padding: 10px 20px;
        background-color: ${lambda props: any -> str {
            # Access styled-components props
            return ("blue") if props.primary else ("gray");
        }};
        color: white;
        border: none;
        border-radius: 4px;
    `;

    def app() -> any {
        return (
            <div>
                <StyledButton primary={True}>Primary</StyledButton>
                <StyledButton primary={False}>Secondary</StyledButton>
            </div>
        );
    }
}
```

---

## Summary

| Approach | Use Case |
|----------|----------|
| Inline styles | Quick, dynamic styles |
| CSS classes | Traditional, reusable |
| Tailwind | Utility-first, rapid development |
| Styled-components | Component-scoped, dynamic |

---

## Next

- [Forms](../12-forms/) - Form handling
