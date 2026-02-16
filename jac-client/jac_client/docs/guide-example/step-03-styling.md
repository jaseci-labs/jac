# Step 3: Styling Components

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll learn how to style your components using inline CSS to make them look great!

---

## Part 1: Building the App

### Step 3.1: Style the TodoItem Component

Let's make our TodoItem look better:

```jac
cl {
    def TodoItem(props: any) -> JsxElement {
        return <div style={{
            "display": "flex",
            "alignItems": "center",
            "gap": "10px",
            "padding": "10px",
            "borderBottom": "1px solid #e5e7eb"
        }}>
            <input
                type="checkbox"
                checked={props.done}
                style={{"cursor": "pointer"}}
            />
            <span style={{
                "flex": "1",
                "textDecoration": ("line-through" if props.done else "none"),
                "color": ("#999" if props.done else "#000")
            }}>
                {props.text}
            </span>
            <button style={{
                "padding": "4px 8px",
                "background": "#ef4444",
                "color": "#ffffff",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer",
                "fontSize": "12px"
            }}>
                Delete
            </button>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <div style=  {{"padding": "20px"}}>
            <h1>My Todos</h1>
            <TodoItem text="Learn Jac basics" done={true} />
            <TodoItem text="Build a todo app" done={false} />
        </div>;
    }
}
```

**Try it!** Your todos now have spacing, colors, and the completed ones show strikethrough text!

### Step 3.2: Style the TodoInput Component

```jac
cl {
    def TodoInput(props: any) -> JsxElement {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <input
                type="text"
                placeholder="What needs to be done?"
                style={{
                    "flex": "1",
                    "padding": "8px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px"
                }}
            />
            <button style={{
                "padding": "8px 16px",
                "background": "#3b82f6",
                "color": "#ffffff",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer",
                "fontWeight": "600"
            }}>
                Add
            </button>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <div style={{"padding": "20px"}}>
            <h1>My Todos</h1>
            <TodoInput />
        </div>;
    }
}
```

### Step 3.3: Style the TodoFilters Component

```jac
cl {
    def TodoFilters(props: any) -> JsxElement {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <button style={{
                "padding": "6px 12px",
                "background": "#3b82f6",
                "color": "#ffffff",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer",
                "fontSize": "14px"
            }}>
                All
            </button>
            <button style={{
                "padding": "6px 12px",
                "background": "#e5e7eb",
                "color": "#000000",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer",
                "fontSize": "14px"
            }}>
                Active
            </button>
            <button style={{
                "padding": "6px 12px",
                "background": "#e5e7eb",
                "color": "#000000",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer",
                "fontSize": "14px"
            }}>
                Completed
            </button>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <div style={{"padding": "20px"}}>
            <h1>My Todos</h1>
            <TodoFilters />
        </div>;
    }
}
```

**Try it!** The "All" button is now blue (active), while the others are gray.

---

**⏭ Want to skip the theory?** Jump to [Step 4: Todo UI](./step-04-todo-ui.md)

---

## Part 2: Understanding the Concepts

### What are Inline Styles?

In traditional HTML/CSS, you might write:

```html
<!-- HTML -->
<div style="color: blue; font-size: 20px;">Hello</div>
```

In Jac (using JSX), styles are **dictionaries** (JavaScript objects):

```jac
<div style={{"color": "blue", "fontSize": "20px"}}>Hello</div>
```

### Why Double Curly Braces `{{ }}`?

```jac
<div style={{ "color": "blue" }}>
      ^  ^
      |  |
      |  └─ Dictionary: {"color": "blue"}
      └──── JSX expression: insert Jac code here
```

- **Outer `{ }`** = "I'm inserting Jac code into JSX"
- **Inner `{ }`** = "This is a dictionary/object"

**Think of it like:**

```python
# Python
styles = {"color": "blue", "fontSize": "20px"}
element.set_style(styles)

# Jac/JSX
<div style={{"color": "blue", "fontSize": "20px"}}>
```

### CSS Property Names: camelCase

CSS uses kebab-case (`background-color`), but JSX uses camelCase (`backgroundColor`):

```jac
# CSS property → JSX property
background-color → "backgroundColor"
font-size        → "fontSize"
border-radius    → "borderRadius"
margin-top       → "marginTop"
text-align       → "textAlign"
```

**Examples:**

```jac
#  Correct (camelCase)
{
    "backgroundColor": "#ffffff",
    "fontSize": "16px",
    "borderRadius": "8px"
}

#  Wrong (kebab-case won't work)
{
    "background-color": "#ffffff",  # Error!
    "font-size": "16px"              # Error!
}
```

### Common Style Properties

**Layout & Spacing:**

```jac
{
    "display": "flex",           # Flexbox layout
    "flexDirection": "column",   # Stack vertically
    "gap": "16px",              # Space between children
    "padding": "20px",          # Inner spacing
    "margin": "10px"            # Outer spacing
}
```

**Colors & Backgrounds:**

```jac
{
    "color": "#1f2937",              # Text color
    "backgroundColor": "#ffffff",     # Background color
    "border": "1px solid #e5e7eb",   # Border
    "boxShadow": "0 1px 3px rgba(0,0,0,0.1)"  # Shadow
}
```

**Typography:**

```jac
{
    "fontSize": "16px",
    "fontWeight": "600",      # Bold (100-900)
    "fontFamily": "sans-serif",
    "textAlign": "center",
    "lineHeight": "1.5"
}
```

**Borders & Corners:**

```jac
{
    "borderRadius": "8px",    # Rounded corners
    "border": "1px solid #ccc",
    "borderBottom": "2px solid blue"
}
```

### String Values

All CSS values must be **strings** (in quotes):

```jac
#  Correct
{
    "padding": "20px",
    "color": "#3b82f6",
    "fontSize": "16px"
}

#  Wrong (missing quotes)
{
    "padding": 20px,      # Error!
    "color": #3b82f6,     # Error!
    "fontSize": 16px      # Error!
}
```

### Conditional Styling

You can change styles based on conditions:

```jac
# Using ternary operator
<span style={{
    "color": ("#999" if props.done else "#000"),
    "textDecoration": ("line-through" if props.done else "none")
}}>
    {props.text}
</span>
```

**This is like:**

```python
# Python
color = "#999" if done else "#000"
text_decoration = "line-through" if done else "none"

# Jac
"color": ("#999" if props.done else "#000")
```

### Flexbox Basics

Flexbox is a powerful layout system. Here are the basics:

```jac
# Parent container
<div style={{
    "display": "flex",         # Enable flexbox
    "gap": "10px"             # Space between children
}}>
    <div>Item 1</div>
    <div>Item 2</div>
    <div>Item 3</div>
</div>
```

**Common flexbox properties:**

```jac
{
    "display": "flex",              # Enable flexbox
    "flexDirection": "row",         # Horizontal (default)
    "flexDirection": "column",      # Vertical
    "justifyContent": "center",     # Center horizontally
    "alignItems": "center",         # Center vertically
    "gap": "16px"                  # Space between items
}
```

**Example: Centering content**

```jac
<div style={{
    "display": "flex",
    "justifyContent": "center",  # Horizontal center
    "alignItems": "center",      # Vertical center
    "height": "100vh"            # Full screen height
}}>
    <h1>Centered!</h1>
</div>
```

### Reusing Styles

You can store styles in variables to avoid repetition:

```jac
def:pub app() -> JsxElement {
    # Define common button style
    buttonStyle = {
        "padding": "8px 16px",
        "border": "none",
        "borderRadius": "4px",
        "cursor": "pointer",
        "fontWeight": "600"
    };

    return <div>
        <button style={buttonStyle}>Click me</button>
        <button style={buttonStyle}>Or me</button>
    </div>;
}
```

---

## What You've Learned

- How to write inline styles in Jac
- Double curly braces `{{ }}` syntax
- camelCase property names
- Common CSS properties
- Conditional styling with ternary operator
- Flexbox basics for layout
- Reusing styles with variables

---

## Common Issues

### Issue: Styles not applying

**Check:**

- Did you use double curly braces `{{ }}`?
- Are property names in quotes? `"padding"` not `padding`
- Are values in quotes? `"20px"` not `20px`
- Are you using camelCase? `"fontSize"` not `"font-size"`

### Issue: "Unexpected token"

**Cause**: Missing quotes around property names or values

```jac
#  Wrong
{padding: 20px}

#  Correct
{"padding": "20px"}
```

### Issue: CSS property not working

**Solution**: Convert kebab-case to camelCase

```jac
#  Wrong
{"background-color": "#fff"}

#  Correct
{"backgroundColor": "#fff"}
```

---

## Quick Exercise

Try adding a container with centered content:

```jac
def:pub app() -> JsxElement {
    return <div style={{
        "maxWidth": "600px",
        "margin": "0 auto",
        "padding": "20px",
        "backgroundColor": "#f9fafb",
        "minHeight": "100vh"
    }}>
        <h1 style={{"textAlign": "center"}}>My Todos</h1>
        <TodoInput />
        <TodoFilters />
    </div>;
}
```

This creates:

- Centered container (max width 600px)
- Light gray background
- Full height
- Centered title

---

## Next Step

Great! Your components now look professional. Next, let's build the **complete Todo UI** with all the components working together!

 **[Continue to Step 4: Todo UI](./step-04-todo-ui.md)**
