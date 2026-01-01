# Rendering Lists

Learn how to render lists in JAC-Client JSX.

---

## Basic List Rendering

### Using map with Helper Function

```jac
def ItemList() -> any {
    items = ["Apple", "Banana", "Cherry"];

    def renderItem(item: str, index: int) -> any {
        return <li key={index}>{item}</li>;
    }

    return <ul>{items.map(renderItem)}</ul>;
}
```

### Inline Lambda

```jac
def ItemList() -> any {
    items = ["Apple", "Banana", "Cherry"];

    return (
        <ul>
            {items.map(lambda item: str, index: int -> any {
                return <li key={index}>{item}</li>;
            })}
        </ul>
    );
}
```

---

## Keys

Always provide unique keys for list items:

```jac
def UserList() -> any {
    users = [
        { "id": 1, "name": "Alice" },
        { "id": 2, "name": "Bob" },
        { "id": 3, "name": "Charlie" }
    ];

    # Good: Use unique ID as key
    def renderUser(user: dict, index: int) -> any {
        return <li key={user["id"]}>{user["name"]}</li>;
    }

    return <ul>{users.map(renderUser)}</ul>;
}
```

### When to Use Index as Key

Only use index when:

- List is static (never changes)
- Items have no unique ID
- List won't be reordered

```jac
# Acceptable for static list
staticItems = ["Home", "About", "Contact"];

{staticItems.map(lambda item: str, index: int -> any {
    return <li key={index}>{item}</li>;
})}
```

---

## Object Lists

```jac
def ProductList() -> any {
    products = [
        { "id": 1, "name": "Laptop", "price": 999 },
        { "id": 2, "name": "Phone", "price": 699 },
        { "id": 3, "name": "Tablet", "price": 499 }
    ];

    def renderProduct(product: dict, index: int) -> any {
        return (
            <div key={product["id"]} style={{
                "border": "1px solid #ccc",
                "padding": "10px",
                "margin": "10px 0"
            }}>
                <h3>{product["name"]}</h3>
                <p>${product["price"]}</p>
            </div>
        );
    }

    return <div>{products.map(renderProduct)}</div>;
}
```

---

## Filtered Lists

```jac
def FilteredList() -> any {
    [filter, setFilter] = useState("all");

    items = [
        { "id": 1, "name": "Task 1", "completed": True },
        { "id": 2, "name": "Task 2", "completed": False },
        { "id": 3, "name": "Task 3", "completed": True }
    ];

    # Filter items
    filteredItems = items;
    if filter == "completed" {
        filteredItems = items.filter(lambda i: dict -> bool {
            return i["completed"];
        });
    } elif filter == "active" {
        filteredItems = items.filter(lambda i: dict -> bool {
            return not i["completed"];
        });
    }

    def renderItem(item: dict, index: int) -> any {
        return (
            <li key={item["id"]}>
                {item["name"]} {item["completed"] and ""}
            </li>
        );
    }

    return (
        <div>
            <select onChange={lambda e: any -> None { setFilter(e.target.value); }}>
                <option value="all">All</option>
                <option value="active">Active</option>
                <option value="completed">Completed</option>
            </select>
            <ul>{filteredItems.map(renderItem)}</ul>
        </div>
    );
}
```

---

## Interactive Lists

```jac
def TodoList() -> any {
    [todos, setTodos] = useState([
        { "id": 1, "text": "Learn JAC", "done": False },
        { "id": 2, "text": "Build app", "done": False }
    ]);

    def toggleTodo(id: int) -> None {
        def toggle(todo: dict, index: int) -> dict {
            if todo["id"] == id {
                return { **todo, "done": not todo["done"] };
            }
            return todo;
        }
        setTodos(todos.map(toggle));
    }

    def deleteTodo(id: int) -> None {
        setTodos(todos.filter(lambda t: dict -> bool {
            return t["id"] != id;
        }));
    }

    def renderTodo(todo: dict, index: int) -> any {
        return (
            <li key={todo["id"]}>
                <span
                    style={{
                        "textDecoration": ("line-through") if todo["done"] else ("none"),
                        "cursor": "pointer"
                    }}
                    onClick={lambda: toggleTodo(todo["id"])}
                >
                    {todo["text"]}
                </span>
                <button onClick={lambda: deleteTodo(todo["id"])}>Delete</button>
            </li>
        );
    }

    return <ul>{todos.map(renderTodo)}</ul>;
}
```

---

## Empty State

```jac
def ItemList(items: list, onAdd: any) -> any {
    itemList = items or [];

    if itemList.length == 0 {
        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <p>No items found</p>
                <button onClick={onAdd}>Add Item</button>
            </div>
        );
    }

    def renderItem(item: dict, index: int) -> any {
        return <li key={item["id"]}>{item["name"]}</li>;
    }

    return <ul>{itemList.map(renderItem)}</ul>;
}
```

---

## Grid Layout

```jac
def ImageGrid() -> any {
    images = [
        { "id": 1, "src": "/img1.jpg", "alt": "Image 1" },
        { "id": 2, "src": "/img2.jpg", "alt": "Image 2" },
        { "id": 3, "src": "/img3.jpg", "alt": "Image 3" },
        { "id": 4, "src": "/img4.jpg", "alt": "Image 4" }
    ];

    def renderImage(image: dict, index: int) -> any {
        return (
            <div key={image["id"]} style={{
                "width": "200px",
                "height": "200px",
                "overflow": "hidden"
            }}>
                <img
                    src={image["src"]}
                    alt={image["alt"]}
                    style={{ "width": "100%", "height": "100%", "objectFit": "cover" }}
                />
            </div>
        );
    }

    return (
        <div style={{
            "display": "grid",
            "gridTemplateColumns": "repeat(auto-fill, minmax(200px, 1fr))",
            "gap": "20px"
        }}>
            {images.map(renderImage)}
        </div>
    );
}
```

---

## Nested Lists

```jac
def CategoryList() -> any {
    categories = [
        {
            "id": 1,
            "name": "Fruits",
            "items": ["Apple", "Banana", "Cherry"]
        },
        {
            "id": 2,
            "name": "Vegetables",
            "items": ["Carrot", "Broccoli", "Spinach"]
        }
    ];

    def renderCategory(category: dict, catIndex: int) -> any {
        return (
            <div key={category["id"]}>
                <h3>{category["name"]}</h3>
                <ul>
                    {category["items"].map(lambda item: str, itemIndex: int -> any {
                        return <li key={itemIndex}>{item}</li>;
                    })}
                </ul>
            </div>
        );
    }

    return <div>{categories.map(renderCategory)}</div>;
}
```

---

## Summary

| Pattern | When to Use |
|---------|-------------|
| Helper function | Cleaner, reusable render logic |
| Inline lambda | Simple, one-off rendering |
| Filter then map | Conditional list rendering |
| Empty state check | Handle no items gracefully |
| Unique keys | Always for dynamic lists |

---

## Next Section

- [Exception Handling](../08-exception-handling/) - try/except
