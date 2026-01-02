# useCallback & useMemo

Learn performance optimization hooks in Jac.

---

## useCallback

### Purpose

Memoizes a function to prevent unnecessary re-creation on every render.

### JavaScript/React vs Jac

**JavaScript/React:**

```javascript
const handleClick = useCallback(() => {
  setCount(count + 1);
}, [count]);
```

**Jac:**

```jac
handleClick = useCallback(
    lambda -> None { setCount(count + 1); },
    [count]
);
```

---

## Import

```jac
cl import from react { useState, useCallback, useMemo }
```

---

## useCallback Examples

### Basic Usage

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    # Memoized callback
    increment = useCallback(
        lambda -> None { setCount(count + 1); },
        [count]
    );

    decrement = useCallback(
        lambda -> None { setCount(count - 1); },
        [count]
    );

    return (
        <div>
            <p>Count: {count}</p>
            <button onClick={increment}>+</button>
            <button onClick={decrement}>-</button>
        </div>
    );
}
```

### Passing to Child Components

```jac
def Parent() -> any {
    [items, setItems] = useState([]);

    # Memoized to prevent Child re-renders
    handleAdd = useCallback(
        lambda item: dict -> None {
            setItems(items.concat([item]));
        },
        [items]
    );

    handleRemove = useCallback(
        lambda id: int -> None {
            setItems(items.filter(lambda i: dict -> bool {
                return i["id"] != id;
            }));
        },
        [items]
    );

    return (
        <div>
            <AddForm onAdd={handleAdd} />
            <ItemList items={items} onRemove={handleRemove} />
        </div>
    );
}
```

### Event Handlers

```jac
def Form() -> any {
    [name, setName] = useState("");
    [email, setEmail] = useState("");

    handleNameChange = useCallback(
        lambda e: any -> None { setName(e.target.value); },
        []
    );

    handleEmailChange = useCallback(
        lambda e: any -> None { setEmail(e.target.value); },
        []
    );

    handleSubmit = useCallback(
        lambda e: any -> None {
            e.preventDefault();
            console.log("Submitting:", name, email);
        },
        [name, email]
    );

    return (
        <form onSubmit={handleSubmit}>
            <input value={name} onChange={handleNameChange} />
            <input value={email} onChange={handleEmailChange} />
            <button type="submit">Submit</button>
        </form>
    );
}
```

---

## useMemo

### Purpose

Memoizes a computed value to prevent expensive recalculations.

### JavaScript/React vs Jac

**JavaScript/React:**

```javascript
const total = useMemo(() => {
  return items.reduce((sum, item) => sum + item.price, 0);
}, [items]);
```

**Jac:**

```jac
total = useMemo(
    lambda -> float {
        sum = 0;
        for item in items {
            sum = sum + item["price"];
        }
        return sum;
    },
    [items]
);
```

---

## useMemo Examples

### Computed Values

```jac
def ShoppingCart() -> any {
    [items, setItems] = useState([]);

    # Memoized calculation
    total = useMemo(
        lambda -> float {
            sum = 0;
            for item in items {
                sum = sum + item["price"] * item["quantity"];
            }
            return sum;
        },
        [items]
    );

    itemCount = useMemo(
        lambda -> int {
            count = 0;
            for item in items {
                count = count + item["quantity"];
            }
            return count;
        },
        [items]
    );

    return (
        <div>
            <p>Items: {itemCount}</p>
            <p>Total: ${total}</p>
        </div>
    );
}
```

### Filtered Lists

```jac
def UserList() -> any {
    [users, setUsers] = useState([]);
    [filter, setFilter] = useState("");

    # Memoized filtered list
    filteredUsers = useMemo(
        lambda -> list {
            if filter.trim() == "" {
                return users;
            }
            return users.filter(lambda user: dict -> bool {
                return user["name"].toLowerCase().includes(filter.toLowerCase());
            });
        },
        [users, filter]
    );

    def renderUser(user: dict, index: int) -> any {
        return <li key={user["id"]}>{user["name"]}</li>;
    }

    return (
        <div>
            <input
                value={filter}
                onChange={lambda e: any -> None { setFilter(e.target.value); }}
                placeholder="Filter users..."
            />
            <ul>{filteredUsers.map(renderUser)}</ul>
        </div>
    );
}
```

### Expensive Calculations

```jac
def Calculator() -> any {
    [numbers, setNumbers] = useState([1, 2, 3, 4, 5]);
    [multiplier, setMultiplier] = useState(2);

    # Expensive calculation memoized
    result = useMemo(
        lambda -> dict {
            console.log("Calculating...");  # Only logs when deps change

            sum = 0;
            for n in numbers {
                sum = sum + n;
            }

            product = 1;
            for n in numbers {
                product = product * n;
            }

            return {
                "sum": sum * multiplier,
                "product": product * multiplier,
                "average": (sum / numbers.length) * multiplier
            };
        },
        [numbers, multiplier]
    );

    return (
        <div>
            <p>Sum: {result["sum"]}</p>
            <p>Product: {result["product"]}</p>
            <p>Average: {result["average"]}</p>
            <button onClick={lambda: setMultiplier(multiplier + 1)}>
                Increase Multiplier ({multiplier})
            </button>
        </div>
    );
}
```

### Sorted Data

```jac
def SortedList() -> any {
    [items, setItems] = useState([]);
    [sortBy, setSortBy] = useState("name");
    [sortOrder, setSortOrder] = useState("asc");

    sortedItems = useMemo(
        lambda -> list {
            # Create copy to avoid mutating original
            sorted = items.slice();

            # Sort logic
            def compare(a: dict, b: dict) -> int {
                valA = a[sortBy];
                valB = b[sortBy];

                if valA < valB {
                    return (-1) if sortOrder == "asc" else (1);
                } elif valA > valB {
                    return (1) if sortOrder == "asc" else (-1);
                }
                return 0;
            }

            return sorted.sort(compare);
        },
        [items, sortBy, sortOrder]
    );

    return (
        <div>
            <select onChange={lambda e: any -> None { setSortBy(e.target.value); }}>
                <option value="name">Name</option>
                <option value="price">Price</option>
                <option value="date">Date</option>
            </select>
            <button onClick={lambda: setSortOrder(("desc") if sortOrder == "asc" else ("asc"))}>
                {sortOrder}
            </button>
            <ul>
                {sortedItems.map(lambda item: dict, i: int -> any {
                    return <li key={i}>{item["name"]}</li>;
                })}
            </ul>
        </div>
    );
}
```

---

## Combined Example

```jac
def Dashboard() -> any {
    [data, setData] = useState([]);
    [filter, setFilter] = useState("");
    [sortBy, setSortBy] = useState("name");

    # Memoized filtered and sorted data
    processedData = useMemo(
        lambda -> list {
            # Filter
            filtered = data;
            if filter.trim() != "" {
                filtered = data.filter(lambda item: dict -> bool {
                    return item["name"].toLowerCase().includes(filter.toLowerCase());
                });
            }

            # Sort
            def compare(a: dict, b: dict) -> int {
                if a[sortBy] < b[sortBy] { return -1; }
                if a[sortBy] > b[sortBy] { return 1; }
                return 0;
            }

            return filtered.slice().sort(compare);
        },
        [data, filter, sortBy]
    );

    # Memoized callbacks
    handleFilterChange = useCallback(
        lambda e: any -> None { setFilter(e.target.value); },
        []
    );

    handleSortChange = useCallback(
        lambda e: any -> None { setSortBy(e.target.value); },
        []
    );

    return (
        <div>
            <input value={filter} onChange={handleFilterChange} />
            <select onChange={handleSortChange}>
                <option value="name">Name</option>
                <option value="date">Date</option>
            </select>
            <p>Showing {processedData.length} items</p>
        </div>
    );
}
```

---

## When to Use

### useCallback

- Passing callbacks to optimized child components
- Callbacks in dependency arrays
- Event handlers that cause re-renders

### useMemo

- Expensive calculations
- Filtering/sorting large lists
- Complex data transformations
- Derived state

### When NOT to Use

- Simple values that are cheap to compute
- Values that change on every render anyway
- Premature optimization

---

## Summary

| Hook        | Purpose          | Syntax                                            |
| ----------- | ---------------- | ------------------------------------------------- |
| useCallback | Memoize function | `useCallback(lambda -> Type {}, [deps])`          |
| useMemo     | Memoize value    | `useMemo(lambda -> Type { return val; }, [deps])` |

---

## Next

- [useRef](04-useRef.md) - References and DOM access
