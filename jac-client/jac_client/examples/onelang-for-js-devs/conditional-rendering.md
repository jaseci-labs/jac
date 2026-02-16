# Conditional Rendering in JAC-Lang (Onelang)

This guide covers conditional rendering patterns in JAC-lang for building dynamic React-like user interfaces.

> **Full Examples**: See the complete working examples at [jac-client-examples/conditional-rendering](https://github.com/jaseci-labs/jac-client-examples/tree/main/conditional-rendering)

---

## 1. If/Else with Early Return

The most basic conditional rendering pattern. Return different JSX based on a condition.

=== "JAC-Client"

    ```jac
    def IfElseExample(props: dict) -> JsxElement {
        isLoggedIn = props.isLoggedIn;
        if isLoggedIn {
            return <div>Welcome back, User!</div>;
        }
        return <div>Please sign in.</div>;
    }
    ```

=== "React"

    ```jsx
    function IfElseExample({ isLoggedIn }) {
      if (isLoggedIn) {
        return <div>Welcome back, User!</div>;
      }
      return <div>Please sign in.</div>;
    }
    ```

### Usage:

```jac
<IfElseExample isLoggedIn={True} />   # Shows: Welcome back, User!
<IfElseExample isLoggedIn={False} />  # Shows: Please sign in.
```

---

## 2. Ternary Operator (Python-style)

Inline conditional rendering using Python's ternary syntax.

=== "JAC-Client"

    ```jac
    # JAC uses Python-style: (value_if_true) if condition else (value_if_false)
    def TernaryExample(props: dict) -> JsxElement {
        isOnline = props.isOnline;
        return (
            <div>
                Status: {(<span style={{ color: "green" }}>Online</span>) if isOnline else (<span style={{ color: "red" }}>Offline</span>)}
            </div>
        );
    }
    ```

=== "React"

    ```jsx
    // React uses: condition ? value_if_true : value_if_false
    function TernaryExample({ isOnline }) {
      return (
        <div>
          Status:{" "}
          {isOnline ? (
            <span style={{ color: "green" }}>Online</span>
          ) : (
            <span style={{ color: "red" }}>Offline</span>
          )}
        </div>
      );
    }
    ```

### Important Note:

In JAC, **always wrap JSX elements in parentheses** when using ternary:

```jac
# Correct - wrapped in parentheses
{(<span>Yes</span>) if condition else (<span>No</span>)}

# Wrong - missing parentheses
{<span>Yes</span> if condition else <span>No</span>}
```

---

## 3. Complex Ternary (Chained If-Else)

For multiple conditions, chain ternary operators.

=== "JAC-Client"

    ```jac
    def ComplexTernaryExample(props: dict) -> JsxElement {
        condition1 = props.condition1;
        condition2 = props.condition2;
        return (
            <div>
                {(<span>Condition 1 is true</span>) if condition1 else ((<span>Condition 2 is true</span>) if condition2 else (<span>Both are false</span>))}
            </div>
        );
    }
    ```

=== "React"

    ```jsx
    function ComplexTernaryExample({ condition1, condition2 }) {
      return (
        <div>
          {condition1 ? (
            <span>Condition 1</span>
          ) : condition2 ? (
            <span>Condition 2</span>
          ) : (
            <span>Both false</span>
          )}
        </div>
      );
    }
    ```

---

## 4. Logical AND Operator

Show something only when a condition is true.

=== "JAC-Client"

    ```jac
    # JAC uses 'not' instead of '!'
    def LogicalAndExample(props: dict) -> JsxElement {
        hasNotifications = props.hasNotifications;
        count = props.count;
        return (
            <div>
                <span>Notifications: </span>
                {hasNotifications and count > 0 and (
                    <span style={{ color: "blue", fontWeight: "bold" }}>
                        You have {count} new messages!
                    </span>
                )}
                {not hasNotifications and <span>No new notifications</span>}
            </div>
        );
    }
    ```

=== "React"

    ```jsx
    function LogicalAndExample({ hasNotifications, count }) {
      return (
        <div>
          <span>Notifications: </span>
          {hasNotifications && count > 0 && (
            <span style={{ color: "blue", fontWeight: "bold" }}>
              You have {count} new messages!
            </span>
          )}
          {!hasNotifications && <span>No new notifications</span>}
        </div>
      );
    }
    ```

---

## 5. Logical OR Operator - Default Values

Provide fallback/default values when a value is falsy.

=== "JAC-Client"

    ```jac
    def LogicalOrExample(props: dict) -> JsxElement {
        username = props.username;
        return (
            <div>
                Hello, <strong>{username or "Guest"}</strong>!
            </div>
        );
    }
    ```

=== "React"

    ```jsx
    function LogicalOrExample({ username }) {
      return (
        <div>
          Hello, <strong>{username || "Guest"}</strong>!
        </div>
      );
    }
    ```

### Usage:

```jac
<LogicalOrExample username="John" />   # Shows: Hello, John!
<LogicalOrExample username="" />       # Shows: Hello, Guest!
<LogicalOrExample username={None} />   # Shows: Hello, Guest!
```

---

## 6. Switch Statement (NOT SUPPORTED)

> **Important:** Switch statements are NOT currently supported in JAC-lang for client-side rendering.

### React Example (NOT available in JAC):

```jsx
// This does NOT work in JAC
function SwitchExample({ status }) {
  switch (status) {
    case "success":
      return <span style={{ color: "green" }}>Success!</span>;
    case "error":
      return <span style={{ color: "red" }}>Error</span>;
    case "loading":
      return <span style={{ color: "orange" }}>Loading...</span>;
    default:
      return <span>Unknown</span>;
  }
}
```

### JAC Workarounds:

#### Option 1: Use If-Elif-Else Chain

```jac
def SwitchWorkaround1(props: dict) -> JsxElement {
    status = props.status;

    if status == "success" {
        return <span style={{ color: "green" }}>Success!</span>;
    }
    if status == "error" {
        return <span style={{ color: "red" }}>Error occurred</span>;
    }
    if status == "loading" {
        return <span style={{ color: "orange" }}>Loading...</span>;
    }
    return <span>Unknown status</span>;
}
```

#### Option 2: Use Object Lookup (Recommended)

```jac
def SwitchWorkaround2(props: dict) -> JsxElement {
    status = props.status;

    statusConfig = {
        "success": { "color": "green", "text": "Success!" },
        "error": { "color": "red", "text": "Error occurred" },
        "loading": { "color": "orange", "text": "Loading..." },
        "pending": { "color": "blue", "text": "Pending" }
    };

    defaultStatus = { "color": "gray", "text": "Unknown status" };
    current = statusConfig[status] if status in statusConfig else defaultStatus;

    return <span style={{ color: current["color"] }}>{current["text"]}</span>;
}
```

---

## 7. Object Lookup / Mapping

A powerful alternative to switch statements - map keys to values/components.

### JAC Syntax:

```jac
def ObjectLookupExample(props: dict) -> JsxElement {
    theme = props.theme;
    themes = {
        "light": { "bg": "#ffffff", "text": "#000000", "name": "Light" },
        "dark": { "bg": "#333333", "text": "#ffffff", "name": "Dark" },
        "sepia": { "bg": "#f4ecd8", "text": "#5c4033", "name": "Sepia" }
    };

    # Use 'in' to check if key exists
    currentTheme = themes[theme] if theme in themes else themes["light"];

    return (
        <div style={{
            backgroundColor: currentTheme["bg"],
            color: currentTheme["text"]
        }}>
            Current Theme: <strong>{theme or "light"}</strong>
        </div>
    );
}
```

### Key Pattern:

```jac
# Check if key exists in dictionary
value = dict[key] if key in dict else defaultValue;
```

---

## 8. Multiple If-Elif-Else

For complex branching logic, use helper functions.

### JAC Syntax:

```jac
def MultipleConditionsIfElse(props: dict) -> JsxElement {
    user = props.user;

    # Helper function for complex logic
    def getUserAccess() -> any {
        if not user {
            return <span>No user - Please login</span>;
        }
        if user["role"] == "admin" {
            return <span>Admin Dashboard Access</span>;
        }
        if user["role"] == "moderator" {
            return <span>Moderator Access</span>;
        }
        if user["role"] == "member" {
            return <span>Member Access</span>;
        }
        return <span>Guest Access</span>;
    }

    return <div>{getUserAccess()}</div>;
}
```

### Usage:

```jac
<MultipleConditionsIfElse user={None} />                    # No user
<MultipleConditionsIfElse user={{ "role": "admin" }} />     # Admin
<MultipleConditionsIfElse user={{ "role": "moderator" }} /> # Moderator
```

---

## 9. Rendering Nothing

Return an empty fragment to render nothing.

=== "JAC-Client"

    ```jac
    def RenderNothingExample(props: dict) -> JsxElement {
        shouldShow = props.shouldShow;
        if not shouldShow {
            return <></>;  # Empty fragment - renders nothing
        }
        return <div>I am visible!</div>;
    }
    ```

=== "React"

    ```jsx
    function RenderNothingExample({ shouldShow }) {
      if (!shouldShow) {
        return null; // React uses null
      }
      return <div>I am visible!</div>;
    }
    ```

### Key Difference:

| React          | JAC             |
| -------------- | --------------- |
| `return null;` | `return <></>;` |

---

## 10. Conditional CSS Classes

Build class strings dynamically.

### JAC Syntax:

```jac
def ConditionalClassesExample(props: dict) -> JsxElement {
    isActive = props.isActive;
    isPrimary = props.isPrimary;

    # Build class string with ternary
    baseClass = "btn";
    activeClass = " active" if isActive else "";
    colorClass = " primary" if isPrimary else " secondary";
    buttonClasses = baseClass + activeClass + colorClass;

    return (
        <div>
            <button className={buttonClasses}>
                {("Active") if isActive else ("Inactive")} Button
            </button>
            <small>Classes: {buttonClasses}</small>
        </div>
    );
}
```

---

## 11. Conditional Attributes/Props

Apply attributes conditionally.

### JAC Syntax:

```jac
def ConditionalAttributesExample(props: dict) -> JsxElement {
    isDisabled = props.isDisabled;
    isRequired = props.isRequired;

    placeholder = ("* Enter your name") if isRequired else ("Enter your name");

    return (
        <div>
            <input
                type="text"
                placeholder={placeholder}
                disabled={isDisabled}
                required={isRequired}
                style={{
                    opacity: (0.5) if isDisabled else (1),
                    border: ("2px solid red") if isRequired else ("1px solid gray")
                }}
            />
        </div>
    );
}
```

---

## 12. List Conditional Rendering

Handle empty lists gracefully.

### JAC Syntax:

```jac
def ListConditionalExample(props: dict) -> JsxElement {
    items = props.items;

    # Check for empty list
    if not items or items.length == 0 {
        return <div>No items found.</div>;
    }

    # Helper function for map
    def renderItem(item: any, index: int) -> any {
        return <li key={index}>{item}</li>;
    }

    return (
        <div>
            <strong>Items List:</strong>
            <ul>
                {items.map(renderItem)}
            </ul>
        </div>
    );
}
```

### Usage:

```jac
<ListConditionalExample items={["Apple", "Banana", "Cherry"]} />  # Shows list
<ListConditionalExample items={[]} />                              # Shows: No items
```

---

## 13. Conditional with Fragments

Use fragments (`<>...</>`) to group elements without extra DOM nodes.

### JAC Syntax:

```jac
def FragmentsExample(props: dict) -> JsxElement {
    user = props.user;
    showDetails = props.showDetails;

    userName = user["name"] if user else "Anonymous";

    return (
        <div>
            <strong>{userName}</strong>
            {showDetails and user and (
                <>
                    <br />
                    <span>Username: {user["username"]}</span>
                    <br />
                    <span>Phone: {user["phone"]}</span>
                </>
            )}
        </div>
    );
}
```

---

## 14. Multiple Conditions Combined

Handle loading, error, and data states.

### JAC Syntax:

```jac
def MultipleConditionsExample(props: dict) -> JsxElement {
    isLoading = props.isLoading;
    error = props.error;
    data = props.data;

    return (
        <div>
            {isLoading and <span>Loading data...</span>}
            {not isLoading and error and <span style={{ color: "red" }}>Error: {error}</span>}
            {not isLoading and not error and data and <span style={{ color: "green" }}>Data: {data}</span>}
            {not isLoading and not error and not data and <span>No data available</span>}
        </div>
    );
}
```

---

## 15. Interactive State Example

Use `useState` for interactive components.

### JAC Syntax:

```jac
cl import from react {useState}

def InteractiveExample(props: dict) -> JsxElement {
    (isVisible, setIsVisible) = useState(False);
    (count, setCount) = useState(0);

    return (
        <div>
            <button onClick={lambda: setIsVisible(not isVisible)}>
                {("Hide") if isVisible else ("Show")} Content
            </button>
            <button onClick={lambda: setCount(count + 1)}>
                Increment ({count})
            </button>

            {isVisible and (
                <div>
                    Hidden content is now visible!
                    {count > 5 and (
                        <div style={{ color: "blue" }}>
                            Bonus: Count is greater than 5!
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}
```

### Key Points:

- Use `has` variables for reactive state: `has count: int = 0;` (useState is auto-injected)
- Assignments to `has` variables automatically call the setter: `count = count + 1;`
- Use `lambda` for inline handlers: `onClick={lambda -> None { count = count + 1; }}`

---

## 16. Enum-Based Rendering

Map page/state names to content configurations.

### JAC Syntax:

```jac
def EnumBasedExample(props: dict) -> JsxElement {
    currentPage = props.currentPage;

    pageContent = {
        "home": { "title": "Home Page", "content": "Welcome!" },
        "about": { "title": "About Us", "content": "Learn more." },
        "contact": { "title": "Contact", "content": "Get in touch." }
    };

    defaultPage = { "title": "Not Found", "content": "Page not found." };
    page = pageContent[currentPage] if currentPage in pageContent else defaultPage;

    return (
        <div>
            <h4>{page["title"]}</h4>
            <p>{page["content"]}</p>
        </div>
    );
}
```

---

## Quick Reference: JAC vs React

| Feature            | React/JavaScript          | JAC-Lang            |
| ------------------ | ------------------------- | ------------------- |
| Ternary            | `a ? b : c`               | `(b) if a else (c)` |
| Logical AND        | `&&`                      | `and`               |
| Logical OR         | `\|\|`                    | `or`                |
| Logical NOT        | `!`                       | `not`               |
| Null check         | `null`                    | `None`              |
| Boolean true       | `true`                    | `True`              |
| Boolean false      | `false`                   | `False`             |
| Render nothing     | `return null`             | `return <></>`      |
| Arrow function     | `() => {}`                | `lambda: ...`       |
| Dict access        | `obj.key` or `obj["key"]` | `obj["key"]`        |
| Key exists         | `key in obj`              | `key in obj`        |
| Nullish coalescing | `??`                      | Not supported       |
| Switch statement   | `switch/case`             | Not supported       |

---

## Known Limitations

1. **Nullish Coalescing (`??`)** - Use explicit `None` check or `or` operator
2. **Switch Statement** - Use if-elif-else chains or object lookup pattern
3. **JSX in Ternary** - Always wrap in parentheses: `(<Component />) if cond else (<Other />)`
