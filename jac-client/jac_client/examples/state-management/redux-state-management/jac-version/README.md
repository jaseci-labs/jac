# 🔴 Redux State Management in Jac# redux-state-management

A comprehensive beginner-friendly example showing how to use **Redux Toolkit** and **React-Redux** with Jac/OneLang for global state management.## Running Jac Code

## 📚 What is Redux?make sure node modules are installed:

```bash

Redux is a predictable state management library that helps you manage application state in a centralized store. Think of it as a "single source of truth" for your entire app's data.npm install

```

**Why use Redux?**

- **Centralized State**: All your app's data lives in one placeTo run your Jac code, use the Jac CLI:

- **Predictable**: State changes happen through defined actions

- **Debuggable**: Time-travel debugging with Redux DevTools```bash

- **Scalable**: Perfect for large, complex applicationsjac serve app.jac

````

**Redux Toolkit** makes Redux easier by:

- Less boilerplate codeHappy coding with Jac!

- Built-in best practices
- Simpler setup

## 🚀 Quick Start

```bash
npm install

# Install Redux dependencies
npm install @reduxjs/toolkit react-redux

# Run the example
jac serve app.jac
````

Open your browser and you'll see:

- **Counter Section**: Increment/decrement with custom steps
- **Todo List**: Add, toggle, filter, and delete todos
- All state managed by Redux!

## 📖 What Does This Example Show?

This example demonstrates:

1. **Counter Slice** - Simple number state with actions
2. **Todos Slice** - Complex array state with filtering
3. **useSelector** - Reading state from Redux store
4. **useDispatch** - Dispatching actions to update state
5. **Provider** - Making Redux store available to components

## 🏗️ Project Structure

```
redux-state-management/
├── app.jac              # Main Jac components
├── store.js             # Redux store configuration
├── counterSlice.js      # Counter state + actions
├── todosSlice.js        # Todos state + actions
├── reduxExports.js      # Convenience exports for Jac
└── README.md            # This file
```

## 💡 How It Works

### Step 1: Create Slices (JavaScript)

Redux Toolkit uses "slices" - pieces of state with their own reducers and actions.

**Counter Slice** (`counterSlice.js`):

```javascript
import { createSlice } from "@reduxjs/toolkit";

const counterSlice = createSlice({
  name: "counter",
  initialState: {
    value: 0,
    step: 1,
  },
  reducers: {
    increment: (state) => {
      state.value += state.step;
    },
    decrement: (state) => {
      state.value -= state.step;
    },
    reset: (state) => {
      state.value = 0;
    },
    setStep: (state, action) => {
      state.step = action.payload;
    },
  },
});

export const { increment, decrement, reset, setStep } = counterSlice.actions;
export default counterSlice.reducer;
```

**Todos Slice** (`todosSlice.js`):

```javascript
const todosSlice = createSlice({
  name: "todos",
  initialState: {
    items: [],
    filter: "all",
  },
  reducers: {
    addTodo: (state, action) => {
      state.items.push({
        id: Date.now(),
        text: action.payload,
        completed: false,
      });
    },
    toggleTodo: (state, action) => {
      const todo = state.items.find((t) => t.id === action.payload);
      if (todo) {
        todo.completed = !todo.completed;
      }
    },
    deleteTodo: (state, action) => {
      state.items = state.items.filter((t) => t.id !== action.payload);
    },
  },
});
```

### Step 2: Configure Store (`store.js`)

Combine all slices into one store:

```javascript
import { configureStore } from "@reduxjs/toolkit";
import counterReducer from "./counterSlice";
import todosReducer from "./todosSlice";

const store = configureStore({
  reducer: {
    counter: counterReducer,
    todos: todosReducer,
  },
});

export default store;
```

### Step 3: Use in Jac Components (`app.jac`)

**Import Redux hooks and actions:**

```jac
cl import from "react-redux" {Provider, useSelector, useDispatch}
cl import from "./reduxExports.js" {
    store,
    increment,
    decrement,
    addTodo,
    toggleTodo
}
```

**Read state with `useSelector`:**

```jac
def CounterSection() -> any {
    let counterValue = useSelector(lambda state: any -> any {
        return state.counter.value;
    });
    let step = useSelector(lambda state: any -> any {
        return state.counter.step;
    });

    # Now use counterValue and step in your component...
}
```

**Dispatch actions with `useDispatch`:**

```jac
def CounterSection() -> any {
    let dispatch = useDispatch();

    return <button onClick={lambda e: any -> None {
        dispatch(increment());
    }}>
        Increment
    </button>;
}
```

**Wrap app with Provider:**

```jac
def app() -> any {
    return <Provider store={store}>
        <AppContent />
    </Provider>;
}
```

## 🎯 Key Concepts

### 1. **Store**

The single source of truth - holds all your application state.

```javascript
const store = configureStore({
  reducer: {
    counter: counterReducer,
    todos: todosReducer,
  },
});
```

### 2. **Slices**

Organized pieces of state with their own reducers and actions.

```javascript
const mySlice = createSlice({
  name: "myFeature",
  initialState: {
    /* initial values */
  },
  reducers: {
    myAction: (state, action) => {
      // Update state here
    },
  },
});
```

### 3. **Actions**

Plain objects that describe what happened. Automatically created by Redux Toolkit.

```javascript
// Defined in slice
increment: (state) => {
  state.value += 1;
};

// Used in component
dispatch(increment());
```

### 4. **Reducers**

Functions that specify how state changes in response to actions.

```javascript
// Redux Toolkit uses Immer, so you can "mutate" state directly
increment: (state) => {
  state.value += 1; // Looks like mutation, but it's safe!
};
```

### 5. **useSelector**

Hook to read data from the Redux store.

```jac
let value = useSelector(lambda state: any -> any {
    return state.counter.value;
});
```

### 6. **useDispatch**

Hook to send actions to the store.

```jac
let dispatch = useDispatch();
dispatch(increment());
```

## 🆚 Redux vs Zustand

| Feature        | Redux                        | Zustand                  |
| -------------- | ---------------------------- | ------------------------ |
| Setup          | More verbose, separate files | Simpler, all in one file |
| Boilerplate    | Medium (with Redux Toolkit)  | Minimal                  |
| DevTools       | Excellent built-in support   | Supported via middleware |
| Learning Curve | Steeper                      | Gentler                  |
| Best For       | Large, complex apps          | Small to medium apps     |
| Ecosystem      | Huge, mature                 | Growing                  |

**When to use Redux:**

- Large team collaboration
- Complex state logic
- Need middleware (sagas, thunks)
- Time-travel debugging is important

**When to use Zustand:**

- Smaller projects
- Want quick setup
- Don't need extensive middleware

## 🚨 Important Notes for OneLang

### 1. JavaScript Files for Redux Logic

OneLang doesn't support all JavaScript patterns, so Redux slices and store configuration live in `.js` files:

```
counterSlice.js  ← JavaScript
todosSlice.js    ← JavaScript
store.js         ← JavaScript
app.jac          ← Jac components
```

### 2. No Ternary in JSX Attributes

OneLang doesn't support ternary operators in JSX attributes:

```jac
# ❌ Wrong
<button style={{"color": isActive ? "red" : "blue"}}>Click</button>

# ✅ Correct - Calculate value first
let buttonColor = "#ecf0f1";
if isActive {
    buttonColor = "#3498db";
}
<button style={{"color": buttonColor}}>Click</button>
```

### 3. Boolean Comparisons

Use explicit comparisons instead of negation:

```jac
# ❌ Wrong
return !todo.completed;

# ✅ Correct
return todo.completed == false;
```

### 4. Action Payloads

Pass data to actions using the payload:

```jac
# Simple value
dispatch(setStep(5));

# String value
dispatch(addTodo("Buy milk"));

# Object value (in JavaScript)
dispatch(updateUser({ id: 1, name: "John" }));
```

## 🎓 Common Patterns

### Pattern 1: Simple Counter

```jac
def SimpleCounter() -> any {
    let dispatch = useDispatch();
    let count = useSelector(lambda s: any -> any { return s.counter.value; });

    return <div>
        <h1>{count}</h1>
        <button onClick={lambda e: any -> None { dispatch(increment()); }}>+</button>
        <button onClick={lambda e: any -> None { dispatch(decrement()); }}>-</button>
    </div>;
}
```

### Pattern 2: Form Input

```jac
def TodoInput() -> any {
    let dispatch = useDispatch();
    let [text, setText] = useState("");

    let handleSubmit = lambda -> None {
        if text.trim() != "" {
            dispatch(addTodo(text));
            setText("");
        }
    };

    return <div>
        <input
            value={text}
            onChange={lambda e: any -> None { setText(e.target.value); }}
        />
        <button onClick={handleSubmit}>Add</button>
    </div>;
}
```

### Pattern 3: Filtered Lists

```jac
def FilteredTodos() -> any {
    let dispatch = useDispatch();
    let allTodos = useSelector(lambda s: any -> any { return s.todos.items; });
    let filter = useSelector(lambda s: any -> any { return s.todos.filter; });

    # Filter based on current filter setting
    let visibleTodos = allTodos;
    if filter == "active" {
        visibleTodos = allTodos.filter(lambda t: any -> bool {
            return t.completed == false;
        });
    }

    return <div>
        {visibleTodos.map(lambda todo: any -> any {
            return <div key={todo.id}>{todo.text}</div>;
        })}
    </div>;
}
```

## 🛠️ Redux DevTools

Install the [Redux DevTools Extension](https://github.com/reduxjs/redux-devtools) for Chrome/Firefox to get:

- **Time-travel debugging**: Step backwards through state changes
- **Action history**: See every action dispatched
- **State inspection**: Explore your entire state tree
- **Action replay**: Replay actions to reproduce bugs

It's automatically enabled with Redux Toolkit - just install the browser extension!

## 📚 Learn More

- [Redux Toolkit Official Docs](https://redux-toolkit.js.org/)
- [React-Redux Hooks](https://react-redux.js.org/api/hooks)
- [Redux Style Guide](https://redux.js.org/style-guide/)
- [Redux DevTools](https://github.com/reduxjs/redux-devtools)

## 🎯 Try This!

1. Add a "double" button to the counter
2. Add a "Clear All" button for todos
3. Create a "priority" field for todos
4. Add filtering by multiple criteria
5. Persist state to localStorage
6. Add undo/redo functionality

## 💻 Running the Example

```bash
# Make sure dependencies are installed
npm install

# Run the Jac development server
jac serve app.jac
```

Open `http://localhost:3000` in your browser and start experimenting!

---

**Happy Redux State Managing! 🎉**
