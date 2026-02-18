# Step 4: Building the Complete Todo UI

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll put all your components together to create the full todo application interface!

---

## Part 1: Building the App

### Step 4.1: Complete App with All Components

Let's build the complete UI. Replace your entire `app.jac` with:

```jac
cl {
    # Component 1: Todo Input
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

    # Component 2: Filter Buttons
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

    # Component 3: Single Todo Item
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

    # Component 4: Todo List (renders multiple TodoItems)
    def TodoList(props: any) -> JsxElement {
        return <div>
            <TodoItem text="Learn Jac basics" done={true} />
            <TodoItem text="Build a todo app" done={false} />
            <TodoItem text="Deploy to production" done={false} />
        </div>;
    }

    # Main App
    def:pub app() -> JsxElement {
        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px",
            "background": "#ffffff",
            "borderRadius": "8px",
            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
        }}>
            <h1 style={{"marginBottom": "20px"}}>My Todos</h1>
            <TodoInput />
            <TodoFilters />
            <TodoList />

            # Stats footer
            <div style={{
                "marginTop": "16px",
                "padding": "10px",
                "background": "#f9fafb",
                "borderRadius": "4px",
                "fontSize": "14px",
                "color": "#666"
            }}>
                2 items left
            </div>
        </div>;
    }
}
```

**Try it!** You should now see a complete todo application interface!

It looks like a real app, but clicking buttons won't do anything yet (we'll add that next).

### Step 4.2: Add Empty State

What if there are no todos? Let's handle that:

```jac
cl {
    # ... (keep all previous components)

    # Updated TodoList with empty state
    def TodoList(props: any) -> JsxElement {
        # For now, we'll manually control this
        hasTodos = true;  # Change to false to see empty state

        if not hasTodos {
            return <div style={{
                "padding": "20px",
                "textAlign": "center",
                "color": "#999"
            }}>
                No todos yet. Add one above!
            </div>;
        }

        return <div>
            <TodoItem text="Learn Jac basics" done={true} />
            <TodoItem text="Build a todo app" done={false} />
            <TodoItem text="Deploy to production" done={false} />
        </div>;
    }

    # ... (rest of the code stays the same)
}
```

**Try it!** Change `hasTodos = true` to `hasTodos = false` and see the empty state message.

---

**⏭ Want to skip the theory?** Jump to [Step 5: Local State](./step-05-local-state.md)

---

## Part 2: Understanding the Concepts

### Component Hierarchy

Your app now has a clear structure:

```
app (main container)
├── h1 (title)
├── TodoInput (input field + button)
├── TodoFilters (All/Active/Completed buttons)
├── TodoList (container)
│   ├── TodoItem (Learn Jac)
│   ├── TodoItem (Build app)
│   └── TodoItem (Deploy)
└── div (stats footer)
```

### Container Component Pattern

`TodoList` is a **container component** - it manages and renders multiple child components:

```jac
def TodoList() -> JsxElement {
    return <div>
        <TodoItem text="Task 1" done={false} />
        <TodoItem text="Task 2" done={true} />
        <TodoItem text="Task 3" done={false} />
    </div>;
}
```

This pattern makes it easy to:

- Add/remove todos (just add/remove `<TodoItem>` components)
- Style the list container separately from items
- Handle empty states

### Props Flow (Top-Down)

Data flows **down** from parent to child through props:

```
app
  └─> passes nothing to TodoList
        └─> passes {text, done} to each TodoItem
```

Right now, data is hard-coded. Later, we'll use **state** to make it dynamic.

### Conditional Rendering

We used a simple `if` statement to show/hide content:

```jac
if not hasTodos {
    return <div>No todos yet!</div>;
}

return <div>
    # Show todos
</div>;
```

This is called **conditional rendering** - showing different UI based on conditions.

**Other ways to do this:**

**Method 1: If/Else in component**

```jac
def TodoList() -> JsxElement {
    if hasTodos {
        return <div>Show todos</div>;
    } else {
        return <div>Empty state</div>;
    }
}
```

**Method 2: Ternary operator in JSX**

```jac
return <div>
    {(
        <div>Show todos</div>
    ) if hasTodos else (
        <div>Empty state</div>
    )}
</div>;
```

**Method 3: And operator (&&)**

```jac
return <div>
    {(<div>Empty state</div>) if not hasTodos else None}
    # Shows only when hasTodos is false
</div>;
```

Use whichever feels clearest to you!

### Layout Strategy

Our app uses a centered card layout:

```jac
<div style={{
    "maxWidth": "600px",      # Don't get too wide
    "margin": "20px auto",    # Center horizontally
    "padding": "20px",        # Inner spacing
    "background": "#ffffff",  # White card
    "borderRadius": "8px",    # Rounded corners
    "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"  # Subtle shadow
}}>
```

This creates a "card" effect that looks modern and professional.

### Spacing Between Components

We use `marginBottom` to add space between components:

```jac
<h1 style={{"marginBottom": "20px"}}>My Todos</h1>
# 20px gap here
<TodoInput />   # Has marginBottom: "16px" in its style
# 16px gap here
<TodoFilters />  # Has marginBottom: "16px" in its style
# 16px gap here
<TodoList />
```

This creates consistent vertical rhythm in your design.

### Color Scheme

Our app uses a consistent color palette:

```jac
{
    "primary": "#3b82f6",      # Blue (buttons, accents)
    "danger": "#ef4444",       # Red (delete button)
    "background": "#ffffff",   # White (main background)
    "lightGray": "#f9fafb",    # Light gray (stats footer)
    "border": "#e5e7eb",       # Gray border
    "text": "#000",            # Black text
    "textMuted": "#999",       # Gray text (completed todos)
    "textLight": "#666"        # Medium gray (stats)
}
```

Using consistent colors makes your app look polished!

---

## What You've Learned

- Building a complete UI by composing components
- Component hierarchy and organization
- Container components that render lists
- Conditional rendering for empty states
- Centered card layout pattern
- Consistent spacing and colors
- Props flow from parent to child

---

## Common Issues

### Issue: Components overlapping

**Solution**: Check that each component has proper margins/padding:

```jac
<TodoInput />    # Add marginBottom
<TodoFilters />  # Add marginBottom
<TodoList />
```

### Issue: Layout looks broken

**Check:**

- Is `maxWidth` set on the container?
- Is `margin: "0 auto"` used for centering?
- Does the container have `padding`?

### Issue: Empty state not showing

**Check**: Make sure you're returning ONLY the empty state when there are no todos:

```jac
if not hasTodos {
    return <div>Empty state</div>;  # Return here, don't continue
}

return <div>Show todos</div>;  # This only runs if hasTodos is true
```

---

## Quick Exercise

Try customizing your app:

**1. Change the color scheme:**

```jac
# Change primary color from blue to purple
"background": "#8b5cf6"  # Instead of "#3b82f6"
```

**2. Add more mock todos:**

```jac
def TodoList() -> JsxElement {
    return <div>
        <TodoItem text="Task 1" done={false} />
        <TodoItem text="Task 2" done={true} />
        <TodoItem text="Task 3" done={false} />
        <TodoItem text="Task 4" done={false} />
        <TodoItem text="Task 5" done={true} />
    </div>;
}
```

**3. Add a header:**

```jac
def:pub app() -> JsxElement {
    return <div>
        # Add a header
        <div style={{
            "textAlign": "center",
            "padding": "20px",
            "background": "#3b82f6",
            "color": "white",
            "marginBottom": "20px"
        }}>
            <h1 style={{"margin": "0"}}> Todo App</h1>
            <p style={{"margin": "5px 0 0 0"}}>Stay organized!</p>
        </div>

        # Main content
        <div style={{
            "maxWidth": "600px",
            "margin": "0 auto",
            "padding": "20px"
        }}>
            <TodoInput />
            <TodoFilters />
            <TodoList />
        </div>
    </div>;
}
```

---

## Next Step

Excellent! Your UI is complete and looks great. But it's all static - clicking buttons does nothing!

In the next step, we'll add **state** to make your app interactive!

 **[Continue to Step 5: Local State](./step-05-local-state.md)**
