# Props

Learn how to pass and use props in Jac components.

---

## Props Basics

### JavaScript/React vs Jac

**JavaScript/React:**

```jsx
function Greeting({ name, age }) {
  return (
    <p>
      Hello, {name}! You are {age}.
    </p>
  );
}

<Greeting name="John" age={25} />;
```

**Jac:**

```jac
def Greeting(name: str, age: int) -> any {
    return <p>Hello, {name}! You are {age}.</p>;
}

<Greeting name="John" age={25} />
```

### Key Points

1. Props are defined as **direct function parameters** with types
2. Access props directly by name (like JavaScript destructuring)
3. **Alternative:** You can also access via `props.parameterName` - both approaches work!
4. Type annotations are required: `name: str`, `age: int`, etc.

### Dual Access Pattern

```jac
def TodoItem(id: str, text: str, onDelete: any) -> any {
    # Access directly by parameter name (preferred)
    console.log(text);
    console.log(id);

    # OR access via props (also works!)
    console.log(props.text);
    console.log(props.id);

    # Both work! You can mix approaches
    return <div onClick={lambda: onDelete(id)}>
        {props.text}  {# Using props.text #}
    </div>;
}
```

---

## Defining Components with Props

```jac
def UserCard(name: str, age: int, email: str) -> any {
    return (
        <div style={{ "border": "1px solid #ccc", "padding": "15px" }}>
            <h2>{name}</h2>
            <p>Age: {age}</p>
            <p>Email: {email}</p>
        </div>
    );
}

# Usage
<UserCard name="John" age={25} email="john@example.com" />
```

---

## Passing Different Prop Types

### Strings

```jac
<Greeting name="John" />
<Greeting name={"John"} />  # Also valid
```

### Numbers

```jac
<Counter initialValue={0} />
<Counter initialValue={100} />
```

### Booleans

```jac
<Toggle isActive={True} />
<Toggle isActive={False} />
```

### Arrays

```jac
<List items={["apple", "banana", "cherry"]} />
<List items={users} />
```

### Objects

```jac
<Profile user={{ "name": "John", "age": 25 }} />
<Profile user={userData} />
```

### Functions

```jac
<Button onClick={lambda: handleClick()} />
<Input onChange={lambda e: any -> None { setName(e.target.value); }} />
```

---

## Default Values

Use the `or` operator for default values:

```jac
def Greeting(name: str) -> any {
    displayName = name or "Guest";
    return <h1>Hello, {displayName}!</h1>;
}

# Works with or without name prop
<Greeting name="" />        # "Hello, Guest!"
<Greeting name="John" />    # "Hello, John!"
```

### More Complex Defaults

```jac
def Card(title: str, color: str, size: str) -> any {
    displayTitle = title or "Untitled";
    displayColor = color or "#007bff";
    displaySize = size or "medium";

    return (
        <div style={{ "backgroundColor": displayColor }}>
            <h3>{displayTitle}</h3>
        </div>
    );
}
```

---

## Passing Event Handlers

### onClick

```jac
def Button(label: str, onClick: any) -> any {
    return (
        <button onClick={onClick}>
            {label}
        </button>
    );
}

# Usage
<Button label="Click Me" onClick={lambda: handleClick()} />
```

### onChange

```jac
def Input(value: str, onChange: any, placeholder: str) -> any {
    return (
        <input
            value={value}
            onChange={onChange}
            placeholder={placeholder}
        />
    );
}

# Usage
<Input
    value={name}
    onChange={lambda e: any -> None { setName(e.target.value); }}
    placeholder="Enter name"
/>
```

### With Parameters

```jac
def TodoItem(id: int, text: str, onDelete: any) -> any {
    return (
        <li>
            <span>{text}</span>
            <button onClick={lambda: onDelete(id)}>
                Delete
            </button>
        </li>
    );
}

# Usage
<TodoItem
    id={1}
    text="Buy groceries"
    onDelete={lambda id: int -> None { deleteTodo(id); }}
/>
```

---

## Props with Conditional Rendering

```jac
def Alert(alertType: str, message: str) -> any {
    bgColor = ("#d4edda") if alertType == "success" else (
        ("#f8d7da") if alertType == "error" else ("#fff3cd")
    );

    return (
        <div style={{ "backgroundColor": bgColor, "padding": "10px" }}>
            {message}
        </div>
    );
}

# Usage
<Alert alertType="success" message="Saved!" />
<Alert alertType="error" message="Error occurred" />
```

---

## Passing Props to Child Components

```jac
def TodoList(todos: list, onDelete: any) -> any {
    return (
        <ul>
            {todos.map(lambda todo: dict -> any {
                return <TodoItem
                    key={todo["id"]}
                    id={todo["id"]}
                    text={todo["text"]}
                    onDelete={onDelete}
                />;
            })}
        </ul>
    );
}
```

---

## Props Pattern: Container & Presentational

### Container Component (Logic)

```jac
def TodoContainer() -> any {
    [todos, setTodos] = useState([]);
    [input, setInput] = useState("");

    def addTodo() -> None {
        if input.trim() != "" {
            setTodos(todos.concat([{
                "id": Date.now(),
                "text": input
            }]));
            setInput("");
        }
    }

    def deleteTodo(id: int) -> None {
        setTodos(todos.filter(lambda t: dict -> bool {
            return t["id"] != id;
        }));
    }

    return (
        <TodoView
            todos={todos}
            input={input}
            onInputChange={lambda e: any -> None { setInput(e.target.value); }}
            onAdd={lambda: addTodo()}
            onDelete={deleteTodo}
        />
    );
}
```

### Presentational Component (UI)

```jac
def TodoView(todos: list, input: str, onInputChange: any, onAdd: any, onDelete: any) -> any {
    return (
        <div>
            <input value={input} onChange={onInputChange} />
            <button onClick={onAdd}>Add</button>
            <ul>
                {todos.map(lambda todo: dict -> any {
                    return <li key={todo["id"]}>
                        {todo["text"]}
                        <button onClick={lambda: onDelete(todo["id"])}>X</button>
                    </li>;
                })}
            </ul>
        </div>
    );
}
```

---

## Common Patterns

### Boolean Props

```jac
def Button(label: str, disabled: bool) -> any {
    isDisabled = disabled or False;

    return (
        <button disabled={isDisabled}>
            {label}
        </button>
    );
}

<Button label="Submit" disabled={True} />
```

### Optional Props

```jac
def Card(title: str, description: str, imageUrl: str) -> any {
    hasImage = imageUrl != None and imageUrl != "";

    return (
        <div>
            {hasImage and <img src={imageUrl} />}
            <h3>{title}</h3>
            <p>{description or "No description"}</p>
        </div>
    );
}
```

### Array Props

```jac
def List(items: list) -> any {
    itemList = items or [];

    if itemList.length == 0 {
        return <p>No items</p>;
    }

    return <ul>
        {itemList.map(lambda item: str, index: int -> any {
            return <li key={index}>{item}</li>;
        })}
    </ul>;
}

<List items={["Apple", "Banana", "Cherry"]} />
```

---

## Complete Example

```jac
cl import from react { useState }

cl {
    # Transaction item with direct props
    def TransactionItem(
        id: str,
        description: str,
        amount: float,
        category: str,
        onDelete: any
    ) -> any {
        return <div className="transaction-item">
            <span className="category">{category}</span>
            <span className="description">{description}</span>
            <span className="amount">${amount.toFixed(2)}</span>
            <button onClick={lambda: onDelete(id)}>X</button>
        </div>;
    }

    # List component receiving array and handler
    def TransactionList(transactions: list, onDelete: any) -> any {
        if transactions.length == 0 {
            return <p>No transactions yet.</p>;
        }

        return <div>
            {transactions.map(lambda tx: dict -> any {
                return <TransactionItem
                    key={tx["id"]}
                    id={tx["id"]}
                    description={tx["description"]}
                    amount={tx["amount"]}
                    category={tx["category"]}
                    onDelete={onDelete}
                />;
            })}
        </div>;
    }
}
```

---

## Summary

| Pattern       | JavaScript                | Jac                      |
| ------------- | ------------------------- | ------------------------ |
| Define props  | `function Comp({ name })` | `def Comp(name: str)`    |
| Access prop   | `name`                    | `name`                   |
| Default value | `name = "Guest"`          | `name or "Guest"`        |
| Pass string   | `name="John"`             | `name="John"`            |
| Pass number   | `age={25}`                | `age={25}`               |
| Pass boolean  | `active={true}`           | `active={True}`          |
| Pass function | `onClick={() => {}}`      | `onClick={lambda: fn()}` |
| Pass array    | `items={[...]}`           | `items={[...]}`          |
| Pass object   | `user={{...}}`            | `user={{...}}`           |

---

## Next

- [Children](03-children.md) - Component composition
