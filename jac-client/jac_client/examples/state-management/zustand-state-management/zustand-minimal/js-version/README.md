# Zustand State Management in Jac - Simple Counter

A beginner-friendly example showing how to use Zustand (a simple state manager) with Jac/OneLang.

## What Does This Do?

This example creates a counter app where:

- Multiple components share the same counter value
- Clicking buttons updates the count for everyone
- You can adjust the "step" (how much to add/subtract)
- Everything stays in sync automatically!

## Quick Start

```bash
npm install

npm install zustand

jac serve app.jac
```

Open your browser and you'll see:

- A big counter number
- Buttons to increase/decrease by steps
- An input to change the step size
- A live view of the entire store state

## How It Works

### 1. Create the Store (`store.jac`)

The store holds your state and actions in one place:

```jac
cl import from zustand { create }

cl {
    let counterStore = create(lambda setState: any -> dict {
        return {
            # State (the data)
            "count": 0,
            "step": 1,

            # Actions (functions that change the data)
            "increment": lambda -> None {
                setState(lambda state: any -> dict {
                    return {"count": state.count + state.step};
                });
            },

            "decrement": lambda -> None {
                setState(lambda state: any -> dict {
                    return {"count": state.count - state.step};
                });
            },

            "reset": lambda -> None {
                setState({"count": 0, "step": 1});
            }
        };
    });

    # Wrap it so it works like a React hook
    def useCounterStore(selector: any = None) -> any {
        if selector {
            return counterStore(selector);
        }
        return counterStore();
    }
}
```

**Key parts:**

- `create()` - Makes a new Zustand store
- `setState()` - Updates the store (always use `setState`, not `set`!)
- `lambda state: any -> dict` - Function that calculates new state
- `useCounterStore` - Wrapper so components can use it

### 2. Use in Components (`app.jac`)

Components grab what they need from the store:

```jac
cl import from .store { useCounterStore }

cl {
    def CounterValue() -> any {
        # Get just the count
        count = useCounterStore(lambda state: any { return state.count; });

        return <div>{count}</div>;
    }

    def CounterControls() -> any {
        # Get the action functions
        increment = useCounterStore(lambda state: any { return state.increment; });
        decrement = useCounterStore(lambda state: any { return state.decrement; });
        reset = useCounterStore(lambda state: any { return state.reset; });

        return <div>
            <button onClick={lambda -> None { decrement(); }}>− Step</button>
            <button onClick={lambda -> None { increment(); }}>+ Step</button>
            <button onClick={lambda -> None { reset(); }}>Reset</button>
        </div>;
    }
}
```

**What's happening:**

- `useCounterStore(lambda ...)` - Select specific data from the store
- Component only re-renders when that data changes
- Call action functions to update the store

### 3. The Magic: Selectors

Instead of passing data through props, components "select" what they need:

```jac
# Get specific state
count = useCounterStore(lambda state: any { return state.count; });

# Get specific action
increment = useCounterStore(lambda state: any { return state.increment; });

# Get everything
allState = useCounterStore();
```

## Why This is Cool

**Without Zustand (prop drilling):**

```
App → passes count → Header → passes count → Counter
           ↓
    passes increment → Buttons
```

**With Zustand (direct access):**

```
Counter → grabs count from store
Buttons → grabs increment from store
```

No passing props through 5 levels!

## Important: Always Use `setState`

```jac
# ✅ GOOD
let store = create(lambda setState: any -> dict { ... });

# ❌ BAD (will break!)
let store = create(lambda set: any -> dict { ... });
```

Why? In Jac, `set` conflicts with JavaScript internals. Always use `setState`.

## File Structure

```
├── app.jac    # UI components (CounterValue, CounterControls, etc.)
└── store.jac  # Zustand store with state + actions
```

## What You'll Learn

1. ✅ How to create a Zustand store in Jac
2. ✅ How to add state (count, step) and actions (increment, decrement)
3. ✅ How to use selectors to get specific data
4. ✅ How to call actions to update state
5. ✅ Why this is better than passing props everywhere

## Try This

Open the app and:

1. Click "+Step" a few times - watch the count increase
2. Change the step size to 5
3. Click "+Step" again - it jumps by 5!
4. Open the "Live store snapshot" - see the raw state object
5. Click "Reset" - everything goes back to zero

## Next Example

Ready for more? Check out `zustand-state-management-extended` to see how to organize bigger apps with **slices** (separate state domains like User, Settings, Cart).

Happy coding with Jac! 🚀
