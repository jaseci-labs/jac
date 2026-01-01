# Logical Operators

Learn how to use `and`, `or`, and `not` for conditional rendering in JAC-Client.

---

## Quick Reference

| JavaScript | JAC-Client |
|-----------|------------|
| `&&` | `and` |
| `\|\|` | `or` |
| `!` | `not` |

---

## AND Operator (`and`)

Show content only when condition is true:

### JavaScript

```jsx
{isLoggedIn && <Dashboard />}
```

### JAC-Client

```jac
{isLoggedIn and <Dashboard />}
```

### Examples

```jac
def App() -> any {
    [isLoggedIn, setIsLoggedIn] = useState(False);
    [hasMessages, setHasMessages] = useState(True);
    [count, setCount] = useState(5);

    return (
        <div>
            {# Show if logged in #}
            {isLoggedIn and <Dashboard />}

            {# Show if has messages #}
            {hasMessages and <MessageIcon />}

            {# Show if count > 0 #}
            {count > 0 and <p>You have {count} items</p>}

            {# Multiple conditions #}
            {isLoggedIn and hasMessages and <NotificationBadge />}
        </div>
    );
}
```

---

## OR Operator (`or`)

Provide default/fallback values:

### JavaScript

```jsx
{username || "Guest"}
```

### JAC-Client

```jac
{username or "Guest"}
```

### Examples

```jac
def Profile(props: dict) -> any {
    return (
        <div>
            {# Default username #}
            <h1>{props["username"] or "Anonymous"}</h1>

            {# Default avatar #}
            <img src={props["avatar"] or "/default-avatar.png"} />

            {# Default bio #}
            <p>{props["bio"] or "No bio provided"}</p>

            {# Default array #}
            {(props["items"] or []).map(lambda item: any, i: int -> any {
                return <li key={i}>{item}</li>;
            })}
        </div>
    );
}
```

---

## NOT Operator (`not`)

Negate a condition:

### JavaScript

```jsx
{!isLoading && <Content />}
```

### JAC-Client

```jac
{not isLoading and <Content />}
```

### Examples

```jac
def Content() -> any {
    [isLoading, setIsLoading] = useState(True);
    [isEmpty, setIsEmpty] = useState(False);
    [hasError, setHasError] = useState(False);

    return (
        <div>
            {# Show when not loading #}
            {not isLoading and <DataView />}

            {# Show when not empty #}
            {not isEmpty and <ItemList />}

            {# Show when no error #}
            {not hasError and <SuccessMessage />}

            {# Combined: not loading AND not error #}
            {not isLoading and not hasError and <MainContent />}
        </div>
    );
}
```

---

## Combining Operators

### AND + NOT

```jac
{# Show content when loaded and no error #}
{not isLoading and not hasError and <Content />}

{# Show when logged in and not suspended #}
{isLoggedIn and not isSuspended and <Dashboard />}
```

### OR + AND

```jac
{# Show if admin OR (logged in AND has permission) #}
{(isAdmin or (isLoggedIn and hasPermission)) and <ProtectedContent />}
```

### Complex Conditions

```jac
def Navigation(props: dict) -> any {
    isLoggedIn = props["isLoggedIn"];
    isAdmin = props["isAdmin"];
    hasNotifications = props["notifications"] > 0;

    return (
        <nav>
            {# Always show home #}
            <a href="/">Home</a>

            {# Show if logged in #}
            {isLoggedIn and <a href="/profile">Profile</a>}

            {# Show notification badge #}
            {isLoggedIn and hasNotifications and (
                <span className="badge">{props["notifications"]}</span>
            )}

            {# Admin only #}
            {isLoggedIn and isAdmin and <a href="/admin">Admin</a>}

            {# Show login if not logged in #}
            {not isLoggedIn and <a href="/login">Login</a>}
        </nav>
    );
}
```

---

## Practical Patterns

### Loading State

```jac
def DataComponent() -> any {
    [loading, setLoading] = useState(True);
    [data, setData] = useState(None);

    return (
        <div>
            {loading and <Spinner />}
            {not loading and data and <DataView data={data} />}
            {not loading and not data and <EmptyState />}
        </div>
    );
}
```

### Permission Check

```jac
def ActionButtons(props: dict) -> any {
    canEdit = props["canEdit"];
    canDelete = props["canDelete"];
    isOwner = props["isOwner"];

    return (
        <div>
            {(canEdit or isOwner) and <button>Edit</button>}
            {(canDelete or isOwner) and <button>Delete</button>}
            {isOwner and <button>Transfer</button>}
        </div>
    );
}
```

### Feature Flags

```jac
def Features(props: dict) -> any {
    features = props["features"];

    return (
        <div>
            {features["darkMode"] and <DarkModeToggle />}
            {features["beta"] and <BetaFeatures />}
            {features["notifications"] and <NotificationSettings />}
        </div>
    );
}
```

### Empty State

```jac
def ItemList(props: dict) -> any {
    items = props["items"] or [];

    return (
        <div>
            {items.length > 0 and (
                <ul>
                    {items.map(lambda item: dict, i: int -> any {
                        return <li key={i}>{item["name"]}</li>;
                    })}
                </ul>
            )}
            {items.length == 0 and (
                <p>No items found. <a href="/add">Add one?</a></p>
            )}
        </div>
    );
}
```

---

## AND vs Ternary

### Use AND When

- Only showing/hiding content
- No alternative content needed

```jac
{isVisible and <Content />}
```

### Use Ternary When

- Need to show different content for each case

```jac
{(<ContentA />) if isTypeA else (<ContentB />)}
```

---

## Common Gotchas

### Falsy Values

`and` returns the first falsy value or the last value:

```jac
# If count is 0, this renders "0" (not ideal!)
{count and <p>Count: {count}</p>}

# Better: explicit check
{count > 0 and <p>Count: {count}</p>}
```

### Empty Strings

```jac
# If name is "", this doesn't render (which might be intended)
{name and <p>Hello, {name}</p>}

# If you want to show even for empty string
{name != None and <p>Hello, {name or "Anonymous"}</p>}
```

---

## Summary

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Show if true | `{x && <Y />}` | `{x and <Y />}` |
| Default value | `{x \|\| "default"}` | `{x or "default"}` |
| Show if false | `{!x && <Y />}` | `{not x and <Y />}` |
| Combined | `{x && y && <Z />}` | `{x and y and <Z />}` |

---

## Next

- [Advanced Patterns](04-advanced-patterns.md) - Object lookup, fragments
