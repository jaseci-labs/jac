# Step 2: First Component

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll create your first reusable component - a **TodoItem** that displays a single todo.

---

## Part 1: Building the App

### Step 2.1: Create a TodoItem Component

Update your `app.jac`:

```jac
cl {
    # A component to display a single todo
    def TodoItem(props: any) -> JsxElement {
        return <div>
            <input type="checkbox" />
            <span>Learn Jac basics</span>
            <button>Delete</button>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <div>
            <h1>My Todos</h1>
            <TodoItem />
        </div>;
    }
}
```

**Try it!** Save and refresh your browser. You should see a todo item with a checkbox, text, and delete button.

### Step 2.2: Make It Reusable with Props

Now let's make the TodoItem display different text:

```jac
cl {
    # Component that accepts data via props
    def TodoItem(props: any) -> JsxElement {
        return <div>
            <input type="checkbox" checked={props.done} />
            <span>{props.text}</span>
            <button>Delete</button>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <div>
            <h1>My Todos</h1>
            <TodoItem text="Learn Jac basics" done={false} />
            <TodoItem text="Build a todo app" done={false} />
            <TodoItem text="Deploy to production" done={true} />
        </div>;
    }
}
```

**Try it!** You should now see three different todos. Notice how the third one has the checkbox checked!

### Step 2.3: Create Multiple Components

Let's add more components to organize our app:

```jac
cl {
    # Component 1: TodoInput (input field + Add button)
    def TodoInput(props: any) -> JsxElement {
        return <div>
            <input type="text" placeholder="What needs to be done?" />
            <button>Add</button>
        </div>;
    }

    # Component 2: TodoFilters (filter buttons)
    def TodoFilters(props: any) -> JsxElement {
        return <div>
            <button>All</button>
            <button>Active</button>
            <button>Completed</button>
        </div>;
    }

    # Component 3: TodoItem (single todo)
    def TodoItem(props: any) -> JsxElement {
        return <div>
            <input type="checkbox" checked={props.done} />
            <span>{props.text}</span>
            <button>Delete</button>
        </div>;
    }

    # Component 4: TodoList (list of todos)
    def TodoList(props: any) -> JsxElement {
        return <div>
            <TodoItem text="Learn Jac basics" done={true} />
            <TodoItem text="Build a todo app" done={false} />
            <TodoItem text="Deploy to production" done={false} />
        </div>;
    }

    # Main app - combines all components
    def:pub app() -> JsxElement {
        return <div>
            <h1>My Todos</h1>
            <TodoInput />
            <TodoFilters />
            <TodoList />
        </div>;
    }
}
```

**Try it!** Your app now has a clear structure with separate components.

---

**⏭ Want to skip the theory?** Jump to [Step 3: Styling](./step-03-styling.md)

---

## Part 2: Understanding the Concepts

### What is a Component?

A component is a **function that returns UI (JSX)**.

Think of components like Python functions:

```python
# Python - returns text
def greet_user(name):
    return f"Hello, {name}!"

print(greet_user("Alice"))  # Hello, Alice!
print(greet_user("Bob"))    # Hello, Bob!
```

```jac
# Jac - returns UI
def TodoItem(props: any) -> JsxElement {
    return <div>{props.text}</div>;
}

# Usage
<TodoItem text="Learn Jac" />
<TodoItem text="Build app" />
```

### Why Use Components?

**1. Reusability** - Write once, use many times

```jac
<TodoItem text="Task 1" done={false} />
<TodoItem text="Task 2" done={true} />
<TodoItem text="Task 3" done={false} />
```

**2. Organization** - Break complex UI into manageable pieces

```jac
app
├── TodoInput
├── TodoFilters
└── TodoList
    ├── TodoItem
    ├── TodoItem
    └── TodoItem
```

**3. Maintainability** - Easy to find and fix bugs

If there's a bug in how todos display, you know to check `TodoItem`.

### Component Naming Rules

**1. Use PascalCase** (first letter capitalized)

```jac
#  Correct
def TodoItem() -> JsxElement { ... }
def UserProfile() -> JsxElement { ... }
def NavigationBar() -> JsxElement { ... }

#  Wrong
def todoItem() -> any { ... }      # camelCase
def user_profile() -> any { ... }  # snake_case
def navigation-bar() -> any { ... } # kebab-case
```

**2. Name describes what it does**

```jac
#  Good names
def TodoItem() -> JsxElement { ... }
def LoginForm() -> JsxElement { ... }
def ProductCard() -> JsxElement { ... }

#  Bad names
def Component1() -> JsxElement { ... }
def Thing() -> JsxElement { ... }
def X() -> JsxElement { ... }
```

### Understanding Props

**Props** = "Properties" = Data passed to a component

```jac
# Passing props (like function arguments)
<TodoItem text="Learn Jac" done={false} />

# Receiving props (in the component)
def TodoItem(props: any) -> JsxElement {
    text = props.text;      # "Learn Jac"
    done = props.done;      # false
    return <div>{text}</div>;
}
```

**Important**: In React (which Jac uses), components receive props as a **single object**, not individual parameters.

```jac
#  Correct way
def TodoItem(props: any) -> JsxElement {
    text = props.text;
    done = props.done;
    # ...
}

#  Wrong way (won't work)
def TodoItem(text: str, done: bool) -> JsxElement {
    # This doesn't work in React!
}
```

### Accessing Props

Three ways to access props:

**Method 1: Direct access**

```jac
def TodoItem(props: any) -> JsxElement {
    return <span>{props.text}</span>;
}
```

**Method 2: Extract to variables**

```jac
def TodoItem(props: any) -> JsxElement {
    text = props.text;
    done = props.done;
    return <span>{text}</span>;
}
```

**Method 3: Dictionary access (explicit)**

```jac
def TodoItem(props: any) -> JsxElement {
    text = props["text"];
    done = props["done"];
    return <span>{text}</span>;
}
```

All three ways work! Use whichever feels clearest to you.

### Composing Components

You can nest components inside other components:

```jac
# TodoList uses TodoItem
def TodoList() -> JsxElement {
    return <div>
        <TodoItem text="Task 1" done={false} />
        <TodoItem text="Task 2" done={true} />
    </div>;
}

# App uses TodoList
def:pub app() -> JsxElement {
    return <div>
        <h1>My Todos</h1>
        <TodoList />
    </div>;
}
```

This creates a hierarchy:

```
app
└── TodoList
    ├── TodoItem
    └── TodoItem
```

### Using JSX in Props

You can pass any value as props:

```jac
# String
<TodoItem text="Hello" />

# Number
<TodoItem count={42} />

# Boolean
<TodoItem done={true} />

# Variable
myText = "Learn Jac";
<TodoItem text={myText} />

# Expression
<TodoItem priority={5 + 3} />
```

---

## What You've Learned

- Components are functions that return UI
- How to create a component
- PascalCase naming convention
- Passing data to components with props
- Receiving props as a single object
- Composing components (nesting)
- Organizing app into multiple components

---

## Common Issues

### Issue: Component not showing up

**Check:**

- Is the name in PascalCase? `TodoItem` not `todoItem`
- Did you use `<TodoItem />` (with angle brackets)?
- Does it have a `return` statement?

### Issue: "object with keys {text, done}"

**Cause**: Using individual parameters instead of props object

```jac
#  Wrong
def TodoItem(text: str, done: bool) -> JsxElement {
    # ...
}

#  Correct
def TodoItem(props: any) -> JsxElement {
    text = props.text;
    # ...
}
```

### Issue: Props are undefined

**Check:**

- Did you pass the props when using the component?
- Are the prop names spelled the same in both places?

```jac
# Passing props
<TodoItem text="Learn" done={false} />

# Receiving props (names must match!)
def TodoItem(props: any) -> JsxElement {
    props.text  # "Learn"
    props.done  # false
}
```

---

## Quick Exercise

Try adding a new component:

```jac
def TodoStats(props: any) -> JsxElement {
    return <div>
        <p>Total: {props.total}</p>
        <p>Completed: {props.completed}</p>
    </div>;
}

# Use it in app
def:pub app() -> JsxElement {
    return <div>
        <h1>My Todos</h1>
        <TodoStats total={3} completed={1} />
        # ... rest of your components
    </div>;
}
```

---

## Next Step

Great! You can now create and organize components. But they look plain. Let's make them beautiful with **styling**!

 **[Continue to Step 3: Styling](./step-03-styling.md)**
