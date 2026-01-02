# Advanced Conditional Patterns

Learn advanced techniques for conditional rendering in Jac.

---

## Object Lookup (Switch Alternative)

Jac doesn't have switch statements. Use object lookup instead:

### JavaScript Switch

```javascript
switch (status) {
  case "success":
    return <SuccessIcon />;
  case "error":
    return <ErrorIcon />;
  case "warning":
    return <WarningIcon />;
  default:
    return <InfoIcon />;
}
```

### Jac Object Lookup

```jac
def StatusIcon(status: str) -> any {
    icons = {
        "success": <span style={{ "color": "green" }}>OK</span>,
        "error": <span style={{ "color": "red" }}>X</span>,
        "warning": <span style={{ "color": "orange" }}>!</span>,
        "info": <span style={{ "color": "blue" }}>i</span>
    };

    return icons[status] or icons["info"];
}
```

---

## Component Mapping

```jac
def PageRenderer(page: str) -> any {
    pages = {
        "home": <HomePage />,
        "about": <AboutPage />,
        "contact": <ContactPage />,
        "settings": <SettingsPage />
    };

    return (
        <div>
            {pages[page] or <NotFoundPage />}
        </div>
    );
}
```

---

## Render Props Pattern

```jac
def ConditionalWrapper(wrap: bool, children: any) -> any {
    # Conditionally wrap content
    if wrap {
        return (
            <div className="wrapper">
                {children}
            </div>
        );
    }

    return children;
}

# Usage
<ConditionalWrapper wrap={needsWrapper}>
    <Content />
</ConditionalWrapper>
```

---

## Multiple Fragments

```jac
def ContentSections(showHeader: bool, showSidebar: bool, showFooter: bool) -> any {
    return (
        <>
            {showHeader and (
                <>
                    <header>Header</header>
                    <nav>Navigation</nav>
                </>
            )}

            <main>Content</main>

            {showSidebar and (
                <>
                    <aside>Sidebar</aside>
                    <div>Related</div>
                </>
            )}

            {showFooter and <footer>Footer</footer>}
        </>
    );
}
```

---

## Conditional Attributes

```jac
def Button(type: str, disabled: bool, className: str, id: str, children: any) -> any {
    # Build attributes conditionally
    buttonType = type or "button";
    isDisabled = disabled or False;
    buttonClass = className or "btn";

    return (
        <button
            type={buttonType}
            disabled={isDisabled}
            className={buttonClass}
            id={id}
        >
            {children}
        </button>
    );
}
```

---

## Enum-Based Rendering

```jac
def OrderStatus(status: str) -> any {
    statusConfig = {
        "pending": {
            "label": "Pending",
            "color": "#ffc107",
            "icon": "..."
        },
        "processing": {
            "label": "Processing",
            "color": "#17a2b8",
            "icon": "~"
        },
        "shipped": {
            "label": "Shipped",
            "color": "#007bff",
            "icon": ">"
        },
        "delivered": {
            "label": "Delivered",
            "color": "#28a745",
            "icon": "OK"
        },
        "cancelled": {
            "label": "Cancelled",
            "color": "#dc3545",
            "icon": "X"
        }
    };

    config = statusConfig[status] or statusConfig["pending"];

    return (
        <span style={{
            "backgroundColor": config["color"],
            "color": "white",
            "padding": "5px 10px",
            "borderRadius": "4px"
        }}>
            {config["icon"]} {config["label"]}
        </span>
    );
}
```

---

## Conditional List Rendering

```jac
def FilteredList(items: list, filter: str) -> any {
    itemList = items or [];

    # Apply different filters
    filteredItems = itemList;

    if filter == "active" {
        filteredItems = itemList.filter(lambda i: dict -> bool {
            return i["active"];
        });
    } elif filter == "completed" {
        filteredItems = itemList.filter(lambda i: dict -> bool {
            return i["completed"];
        });
    } elif filter == "important" {
        filteredItems = itemList.filter(lambda i: dict -> bool {
            return i["priority"] == "high";
        });
    }

    if filteredItems.length == 0 {
        return <p>No items match the filter</p>;
    }

    return (
        <ul>
            {filteredItems.map(lambda item: dict, i: int -> any {
                return <li key={item["id"]}>{item["name"]}</li>;
            })}
        </ul>
    );
}
```

---

## Polymorphic Components

```jac
def Text(variant: str, children: any) -> any {
    elementType = variant or "p";

    # Different elements based on variant
    if elementType == "h1" {
        return <h1>{children}</h1>;
    } elif elementType == "h2" {
        return <h2>{children}</h2>;
    } elif elementType == "h3" {
        return <h3>{children}</h3>;
    } elif elementType == "span" {
        return <span>{children}</span>;
    } else {
        return <p>{children}</p>;
    }
}

# Usage
<Text variant="h1">Title</Text>
<Text variant="p">Paragraph</Text>
<Text>Default paragraph</Text>
```

---

## Conditional Rendering with Hooks

```jac
def DataDisplay() -> any {
    [view, setView] = useState("list");
    [data, setData] = useState([]);

    # Different views
    if view == "list" {
        return (
            <div>
                <ViewToggle current={view} onChange={lambda v: str -> None { setView(v); }} />
                <ListView data={data} />
            </div>
        );
    } elif view == "grid" {
        return (
            <div>
                <ViewToggle current={view} onChange={lambda v: str -> None { setView(v); }} />
                <GridView data={data} />
            </div>
        );
    } elif view == "table" {
        return (
            <div>
                <ViewToggle current={view} onChange={lambda v: str -> None { setView(v); }} />
                <TableView data={data} />
            </div>
        );
    }

    return <></>;
}
```

---

## Compound Conditions

```jac
def Dashboard(user: dict, settings: dict) -> any {
    isAdmin = user["role"] == "admin";
    isPremium = user["subscription"] == "premium";
    hasNotifications = user["notifications"] > 0;
    darkMode = settings["theme"] == "dark";

    return (
        <div className={("dark") if darkMode else ("light")}>
            {# Admin features #}
            {isAdmin and (
                <>
                    <AdminPanel />
                    <UserManagement />
                </>
            )}

            {# Premium features #}
            {isPremium and not isAdmin and (
                <PremiumFeatures />
            )}

            {# Notifications - all users #}
            {hasNotifications and (
                <NotificationBadge count={user["notifications"]} />
            )}

            {# Basic content - always shown #}
            <MainContent />
        </div>
    );
}
```

---

## Summary

| Pattern           | Use Case                   |
| ----------------- | -------------------------- |
| Object lookup     | Replace switch statements  |
| Component mapping | Route-like rendering       |
| Fragments         | Group conditional elements |
| Enum config       | Status/state display       |
| Polymorphic       | Different HTML elements    |
| Compound          | Complex permission logic   |

---

## Next Section

- [Lists and Loops](../07-lists-and-loops/) - For loops, array methods
