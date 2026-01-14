# Step 6: Event Handlers

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll learn how to handle user interactions like clicks, typing, and key presses to make your app fully interactive!

---

## Part 1: Building the App

### Step 6.1: Handle Input Changes (onChange)

Let's make the input field track what you type:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoInput(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <input
                type="text"
                value={props.input}
                onChange={lambda e: any -> None {
                    props.setInput(e.target.value);
                }}
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
                "color": "white",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                Add
            </button>
        </div>;
    }

    def:pub app() -> any {
        [input, setInput] = useState("");

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoInput input={input} setInput={setInput} />
            <p>You typed: "{input}"</p>
        </div>;
    }
}
```

**Try it!** Type in the input field - you'll see the text appear below!

### Step 6.2: Handle Button Clicks (onClick)

Now let's make the "Add" button work:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoInput(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <input
                type="text"
                value={props.input}
                onChange={lambda e: any -> None {
                    props.setInput(e.target.value);
                }}
                placeholder="What needs to be done?"
                style={{
                    "flex": "1",
                    "padding": "8px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px"
                }}
            />
            <button
                onClick={lambda e: any -> None {
                    props.addTodo();
                }}
                style={{
                    "padding": "8px 16px",
                    "background": "#3b82f6",
                    "color": "white",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                Add
            </button>
        </div>;
    }

    def:pub app() -> any {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");

        # Function to add a new todo
        def addTodo() -> None {
            if not input.trim() {
                return;  # Don't add empty todos
            }

            newTodo = {
                "text": input.trim(),
                "done": false
            };

            setTodos(todos.concat([newTodo]));
            setInput("");  # Clear input
        }

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoInput
                input={input}
                setInput={setInput}
                addTodo={addTodo}
            />

            # Display todos
            <div>
                {todos.map(lambda todo: any -> any {
                    return <div style={{"padding": "8px"}}>
                        {todo.text}
                    </div>;
                })}
            </div>
        </div>;
    }
}
```

**Try it!** Type a todo and click "Add" - it should appear in the list!

### Step 6.3: Handle Enter Key (onKeyPress)

Let's add the ability to press Enter to add a todo:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoInput(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <input
                type="text"
                value={props.input}
                onChange={lambda e: any -> None {
                    props.setInput(e.target.value);
                }}
                onKeyPress={lambda e: any -> None {
                    if e.key == "Enter" {
                        props.addTodo();
                    }
                }}
                placeholder="What needs to be done?"
                style={{
                    "flex": "1",
                    "padding": "8px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px"
                }}
            />
            <button
                onClick={lambda e: any -> None {
                    props.addTodo();
                }}
                style={{
                    "padding": "8px 16px",
                    "background": "#3b82f6",
                    "color": "white",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                Add
            </button>
        </div>;
    }

    # ... rest of code
}
```

**Try it!** Now you can press Enter to add todos!

### Step 6.4: Toggle and Delete Todos

Let's add the complete functionality:

```jac
# No useState import needed - it's auto-injected!

cl {
    # ... (keep TodoInput and TodoFilters)

    def TodoItem(props: any) -> any {
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
                onChange={lambda e: any -> None {
                    props.toggleTodo(props.id);
                }}
                style={{"cursor": "pointer"}}
            />
            <span style={{
                "flex": "1",
                "textDecoration": ("line-through" if props.done else "none"),
                "color": ("#999" if props.done else "#000")
            }}>
                {props.text}
            </span>
            <button
                onClick={lambda e: any -> None {
                    props.deleteTodo(props.id);
                }}
                style={{
                    "padding": "4px 8px",
                    "background": "#ef4444",
                    "color": "white",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer",
                    "fontSize": "12px"
                }}
            >
                Delete
            </button>
        </div>;
    }

    def:pub app() -> any {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");

        # Add todo
        def addTodo() -> None {
            if not input.trim() {
                return;
            }

            newTodo = {
                "id": Date.now(),  # Use timestamp as unique ID
                "text": input.trim(),
                "done": false
            };

            setTodos(todos.concat([newTodo]));
            setInput("");
        }

        # Toggle todo
        def toggleTodo(id: any) -> None {
            setTodos(todos.map(lambda todo: any -> any {
                if todo["id"] == id {
                    return {
                        "id": todo["id"],
                        "text": todo["text"],
                        "done": not todo["done"]
                    };
                }
                return todo;
            }));
        }

        # Delete todo
        def deleteTodo(id: any) -> None {
            setTodos(todos.filter(lambda todo: any -> bool {
                return todo["id"] != id;
            }));
        }

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoInput
                input={input}
                setInput={setInput}
                addTodo={addTodo}
            />

            <div>
                {todos.map(lambda todo: any -> any {
                    return <TodoItem
                        key={todo["id"]}
                        id={todo["id"]}
                        text={todo["text"]}
                        done={todo["done"]}
                        toggleTodo={toggleTodo}
                        deleteTodo={deleteTodo}
                    />;
                })}
            </div>
        </div>;
    }
}
```

**Try it!** You can now:

- Add todos
- Check/uncheck them
- Delete them

### Step 6.5: Add Filter Functionality

Final step - make the filter buttons work:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoFilters(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <button
                onClick={lambda e: any -> None {
                    props.setFilter("all");
                }}
                style={{
                    "padding": "6px 12px",
                    "background": ("#3b82f6" if props.filter == "all" else "#e5e7eb"),
                    "color": ("#ffffff" if props.filter == "all" else "#000000"),
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                All
            </button>
            <button
                onClick={lambda e: any -> None {
                    props.setFilter("active");
                }}
                style={{
                    "padding": "6px 12px",
                    "background": ("#3b82f6" if props.filter == "active" else "#e5e7eb"),
                    "color": ("#ffffff" if props.filter == "active" else "#000000"),
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                Active
            </button>
            <button
                onClick={lambda e: any -> None {
                    props.setFilter("completed");
                }}
                style={{
                    "padding": "6px 12px",
                    "background": ("#3b82f6" if props.filter == "completed" else "#e5e7eb"),
                    "color": ("#ffffff" if props.filter == "completed" else "#000000"),
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                Completed
            </button>
        </div>;
    }

    def:pub app() -> any {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");
        [filter, setFilter] = useState("all");

        # ... (keep addTodo, toggleTodo, deleteTodo functions)

        # Filter todos based on current filter
        def getFilteredTodos() -> list {
            if filter == "active" {
                return todos.filter(lambda todo: any -> bool {
                    return not todo["done"];
                });
            } elif filter == "completed" {
                return todos.filter(lambda todo: any -> bool {
                    return todo["done"];
                });
            }
            return todos;
        }

        filteredTodos = getFilteredTodos();

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoInput input={input} setInput={setInput} addTodo={addTodo} />
            <TodoFilters filter={filter} setFilter={setFilter} />

            <div>
                {filteredTodos.map(lambda todo: any -> any {
                    return <TodoItem
                        key={todo["id"]}
                        id={todo["id"]}
                        text={todo["text"]}
                        done={todo["done"]}
                        toggleTodo={toggleTodo}
                        deleteTodo={deleteTodo}
                    />;
                })}
            </div>
        </div>;
    }
}
```

**Try it!** Now you have a fully functional todo app!

---

**⏭ Want to skip the theory?** Jump to [Step 7: Effects](./step-07-effects.md)

---

## Part 2: Understanding the Concepts

### What are Event Handlers?

Event handlers are functions that run when something happens (user clicks, types, etc.).

**Common events:**

- `onClick` - User clicks an element
- `onChange` - Input value changes
- `onKeyPress` - User presses a key
- `onSubmit` - Form is submitted
- `onFocus` - Element gains focus
- `onBlur` - Element loses focus

### Event Handler Syntax

```jac
<button onClick={lambda e: any -> None {
    # Code runs when button is clicked
    console.log("Clicked!");
}}>
    Click me
</button>
```

**Breakdown:**

- `onClick={}` - The event attribute
- `lambda e: any -> None { }` - Anonymous function
- `e` - Event object (contains info about the event)

### The Event Object (`e`)

```jac
onChange={lambda e: any -> None {
    console.log(e.target);        # The element that triggered the event
    console.log(e.target.value);  # For inputs: the current value
    console.log(e.key);           # For key events: which key was pressed
}}
```

**Common properties:**

- `e.target` - The element that triggered the event
- `e.target.value` - Current value (for inputs)
- `e.key` - Which key was pressed
- `e.preventDefault()` - Prevent default behavior

### Passing Functions as Props

You can pass functions down to child components:

```jac
def Parent() -> any {
    def handleClick() -> None {
        console.log("Clicked!");
    }

    # Pass function to child
    return <Child onClick={handleClick} />;
}

def Child(props: any) -> any {
    # Call parent's function
    return <button onClick={props.onClick}>
        Click me
    </button>;
}
```

This lets children trigger parent behavior!

### Updating State in Event Handlers

```jac
def:pub app() -> any {
    [count, setCount] = useState(0);

    def increment() -> None {
        setCount(count + 1);  # Update state
    }

    return <button onClick={increment}>
        Count: {count}
    </button>;
}
```

When state updates, React re-renders the component with the new value!

### Array Methods for State Updates

**`.concat()` - Add items**

```jac
#  Correct way to add
setTodos(todos.concat([newTodo]));

#  Wrong (modifies original)
todos.push(newTodo);
setTodos(todos);
```

**`.map()` - Update items**

```jac
# Toggle a todo
setTodos(todos.map(lambda todo: any -> any {
    if todo["id"] == targetId {
        return {"id": todo["id"], "done": not todo["done"]};
    }
    return todo;
}));
```

**`.filter()` - Remove items**

```jac
# Delete a todo
setTodos(todos.filter(lambda todo: any -> bool {
    return todo["id"] != targetId;
}));
```

### Inline vs Named Functions

**Inline (good for simple logic):**

```jac
<button onClick={lambda e: any -> None {
    setCount(count + 1);
}}>
    Click
</button>
```

**Named (good for complex logic):**

```jac
def handleClick() -> None {
    if count < 10 {
        setCount(count + 1);
    } else {
        alert("Max reached!");
    }
}

<button onClick={handleClick}>Click</button>
```

### Event Handler Common Patterns

**Pattern 1: Toggle Boolean**

```jac
[isOpen, setIsOpen] = useState(false);

def toggle() -> None {
    setIsOpen(not isOpen);
}

<button onClick={toggle}>Toggle</button>
```

**Pattern 2: Update Input**

```jac
[text, setText] = useState("");

<input
    value={text}
    onChange={lambda e: any -> None {
        setText(e.target.value);
    }}
/>
```

**Pattern 3: Add to List**

```jac
[items, setItems] = useState([]);

def addItem(newItem: any) -> None {
    setItems(items.concat([newItem]));
}
```

**Pattern 4: Remove from List**

```jac
def removeItem(id: any) -> None {
    setItems(items.filter(lambda item: any -> bool {
        return item.id != id;
    }));
}
```

---

## What You've Learned

- What event handlers are
- Common events (onClick, onChange, onKeyPress)
- Event handler syntax with lambda functions
- The event object (`e`)
- Passing functions as props
- Updating state in event handlers
- Array methods (concat, map, filter)
- Inline vs named functions

---

## Common Issues

### Issue: Event handler not firing

**Check:**

- Did you use `onClick` not `onclick`? (capital C)
- Did you pass a function? `onClick={myFunction}` not `onClick={myFunction()}`

### Issue: Input not updating

**Check:**

- Did you add both `value` and `onChange`?
- Is `onChange` calling the state setter?

```jac
#  Correct
<input
    value={text}
    onChange={lambda e: any -> None {
        setText(e.target.value);
    }}
/>

#  Missing onChange
<input value={text} />
```

### Issue: State not updating

**Check:** Are you creating a new array/object?

```jac
#  Wrong (modifying original)
todos.push(newTodo);
setTodos(todos);

#  Correct (creating new array)
setTodos(todos.concat([newTodo]));
```

---

## Quick Exercise

Try adding a "Clear All" button:

```jac
def clearAll() -> None {
    setTodos([]);
}

<button onClick={clearAll}>Clear All</button>
```

And a "Clear Completed" button:

```jac
def clearCompleted() -> None {
    setTodos(todos.filter(lambda todo: any -> bool {
        return not todo["done"];
    }));
}

<button onClick={clearCompleted}>Clear Completed</button>
```

---

## Next Step

Excellent! Your app is now fully interactive with local state. But when you refresh the page, all your todos disappear!

In the next step, we'll use **useEffect** to load data when the app starts!

 **[Continue to Step 7: Effects](./step-07-effects.md)**
