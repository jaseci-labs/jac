# If/Else Rendering

Learn conditional rendering with if/else in JAC-Client.

---

## Early Return Pattern

The most common pattern for conditional rendering:

```jac
def UserProfile(props: dict) -> any {
    # Early return if no user
    if props["user"] == None {
        return <p>No user found</p>;
    }

    # Main render
    return (
        <div>
            <h1>{props["user"]["name"]}</h1>
            <p>{props["user"]["email"]}</p>
        </div>
    );
}
```

---

## Multiple Conditions

```jac
def StatusDisplay(props: dict) -> any {
    status = props["status"];

    if status == "loading" {
        return <p>Loading...</p>;
    }

    if status == "error" {
        return <p style={{ "color": "red" }}>Error occurred!</p>;
    }

    if status == "empty" {
        return <p>No data available</p>;
    }

    # Default: success
    return <div>{props["data"]}</div>;
}
```

---

## If/Elif/Else Chain

```jac
def GradeDisplay(props: dict) -> any {
    score = props["score"];

    if score >= 90 {
        return <p style={{ "color": "green" }}>A - Excellent!</p>;
    } elif score >= 80 {
        return <p style={{ "color": "blue" }}>B - Good!</p>;
    } elif score >= 70 {
        return <p style={{ "color": "orange" }}>C - Average</p>;
    } elif score >= 60 {
        return <p style={{ "color": "darkorange" }}>D - Below Average</p>;
    } else {
        return <p style={{ "color": "red" }}>F - Failing</p>;
    }
}
```

---

## Loading States

```jac
def DataLoader() -> any {
    [data, setData] = useState(None);
    [loading, setLoading] = useState(True);
    [error, setError] = useState(None);

    useEffect(lambda -> None {
        async def fetchData() {
            try {
                response = await fetch("/api/data");
                result = await response.json();
                setData(result);
            } except {
                setError("Failed to load data");
            } finally {
                setLoading(False);
            }
        }
        fetchData();
    }, []);

    # Loading state
    if loading {
        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <p>Loading...</p>
            </div>
        );
    }

    # Error state
    if error {
        return (
            <div style={{ "color": "red", "padding": "20px" }}>
                <p>Error: {error}</p>
                <button onClick={lambda: location.reload()}>Retry</button>
            </div>
        );
    }

    # Empty state
    if data == None or data.length == 0 {
        return <p>No data found</p>;
    }

    # Success state
    return (
        <ul>
            {data.map(lambda item: dict, i: int -> any {
                return <li key={i}>{item["name"]}</li>;
            })}
        </ul>
    );
}
```

---

## Guard Clauses

Check invalid states first, then render the main content:

```jac
def ProtectedContent(props: dict) -> any {
    # Guard: Not logged in
    if not props["isLoggedIn"] {
        return <p>Please log in to view this content</p>;
    }

    # Guard: No permission
    if not props["hasPermission"] {
        return <p>You don't have permission to view this</p>;
    }

    # Guard: Suspended account
    if props["isSuspended"] {
        return <p>Your account is suspended</p>;
    }

    # All guards passed - render content
    return (
        <div>
            <h1>Protected Content</h1>
            <p>Welcome, {props["username"]}!</p>
        </div>
    );
}
```

---

## Inline Conditions with If Blocks

```jac
def ItemCard(props: dict) -> any {
    item = props["item"];

    # Build content conditionally
    badge = <></>;
    if item["isNew"] {
        badge = <span style={{ "color": "green" }}>NEW</span>;
    }

    discount = <></>;
    if item["discount"] > 0 {
        discount = <span style={{ "color": "red" }}>{item["discount"]}% OFF</span>;
    }

    return (
        <div>
            <h3>{item["name"]} {badge}</h3>
            <p>${item["price"]} {discount}</p>
        </div>
    );
}
```

---

## Return Nothing

Use empty fragment to return nothing:

```jac
def MaybeShow(props: dict) -> any {
    if not props["visible"] {
        return <></>;  # Return nothing
    }

    return <div>Visible content</div>;
}
```

---

## Summary

| Pattern | Use Case |
|---------|----------|
| Early return | Check for null/invalid state first |
| If/elif/else | Multiple exclusive conditions |
| Guard clauses | Check permissions/validation |
| Empty fragment | Return nothing: `return <></>` |

---

## Next

- [Ternary Operator](02-ternary.md) - Python-style conditionals
