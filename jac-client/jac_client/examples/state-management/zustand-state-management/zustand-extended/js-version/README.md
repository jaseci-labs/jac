# Zustand State Management in Jac

A simple guide to using Zustand (a lightweight state manager) with Jac/OneLang.

## What is This Example?

This shows how to organize app state by **slices** (separate chunks of related data):

- **User Slice**: Login, logout, user profile
- **Settings Slice**: Theme, language, notifications
- **Cart Slice**: Shopping cart items and total

Each slice is independent but they all live in one global store.

## Quick Start

```bash
npm install

npm install zustand

jac serve app.jac
```

Open your browser and you'll see three panels where you can:

- Login/logout as a user
- Change theme settings
- Add/remove items from a cart

All state updates happen instantly across components!

## How It Works

### 1. Create a Slice (Feature Domain)

Each slice is a function that returns state + actions:

```jac
# userSlice.jac
cl {
    def createUserSlice(setState: any, getState: any, store: any) -> dict {
        return {
            # State
            "user": None,
            "isAuthenticated": False,

            # Actions
            "login": lambda username: str, role: str -> None {
                setState(lambda state: any -> dict {
                    return {
                        **state,
                        "user": {"username": username, "role": role},
                        "isAuthenticated": True
                    };
                });
            },

            "logout": lambda -> None {
                setState(lambda state: any -> dict {
                    return {**state, "user": None, "isAuthenticated": False};
                });
            }
        };
    }
}
```

**Key parts:**

- `setState` - Function to update the store
- `**state` - Spread operator to keep other state unchanged
- Return a dict with state fields and action functions

### 2. Combine Slices into One Store

```jac
# store.jac
cl import from zustand { create }
cl import from .userSlice { createUserSlice }
cl import from .settingsSlice { createSettingsSlice }
cl import from .cartSlice { createCartSlice }

cl {
    let appStore = create(lambda setState: any, getState: any, store: any -> dict {
        return {
            **createUserSlice(setState, getState, store),
            **createSettingsSlice(setState, getState, store),
            **createCartSlice(setState, getState, store)
        };
    });

    def useAppStore(selector: any = None) -> any {
        if selector {
            return appStore(selector);
        }
        return appStore();
    }
}
```

The `**` spread operator merges all slices together!

### 3. Use in Components

```jac
# app.jac
cl import from .store { useAppStore }

cl {
    def UserPanel() -> any {
        # Get specific state
        user = useAppStore(lambda state: any { return state.user; });
        isAuthenticated = useAppStore(lambda state: any { return state.isAuthenticated; });

        # Get actions
        login = useAppStore(lambda state: any { return state.login; });
        logout = useAppStore(lambda state: any { return state.logout; });

        # Use them!
        return <div>
            {isAuthenticated and
                <button onClick={lambda -> None { logout(); }}>Logout</button>
            or
                <button onClick={lambda -> None { login("demo", "admin"); }}>Login</button>
            }
        </div>;
    }
}
```

## Important Rule

**Always use `setState` (not `set`)** when creating stores in Jac:

```jac
# ✅ GOOD
let store = create(lambda setState: any -> dict { ... });

# ❌ BAD (causes errors)
let store = create(lambda set: any -> dict { ... });
```

Why? `set` conflicts with JavaScript's built-in Set constructor.

## File Structure

```
├── app.jac              # Main UI with UserPanel, SettingsPanel, CartPanel
├── store.jac            # Combines all slices
├── userSlice.jac        # User authentication
├── settingsSlice.jac    # App preferences
└── cartSlice.jac        # Shopping cart
```

## Why Slices?

**Without slices (messy):**

```jac
let store = create(lambda setState: any -> dict {
    return {
        "user": None,
        "theme": "light",
        "items": [],
        "total": 0,
        # 50 more fields...
        # 100 more actions...
    };
});
```

**With slices (clean):**

- Each feature has its own file
- Easy to find and update code
- Teams can work on different slices without conflicts
- Components only re-render when their slice changes

## What You'll Learn

1. How to create a Zustand store in Jac
2. How to split state into logical slices
3. How to use selectors to get data
4. How to call actions to update state
5. The spread operator (`**state`) for immutable updates

## Next Steps

- Open the State Debugger in the UI to see the full store
- Try adding a new slice (e.g., "products" or "notifications")
- Experiment with cross-slice actions (one slice reading another's data)
- Add persistence (save state to localStorage)

Happy coding with Jac! 🚀
