# Step 1: Project Setup

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this first step, you'll create your Jac project and understand the basic file structure.

---

## Part 1: Building the App

### Step 1.1: Create Your Project

Open your terminal and run:

```bash
jac create --use client todo-app
```

This creates a new directory called `todo-app` with an organized project structure.

### Step 1.2: Navigate to Your Project

```bash
cd todo-app
```

### Step 1.3: Understand the Structure

Your project now has these files:

```
todo-app/
├── jac.toml              # Project configuration
├── main.jac              # Your main application file (we'll work here!)
├── components/           # Reusable components
│   └── Button.tsx        # Example TypeScript component
├── assets/               # Static assets
└── build/                # Build output (generated)
```

**Important**: We'll write our main code in `main.jac`!

### Step 1.4: Create Your First App

Open `main.jac` in your code editor and replace everything with this:

```jac
cl {
    def:pub app() -> any {
        return <div>
            <h1>Hello, Jac!</h1>
            <p>My first full-stack app</p>
        </div>;
    }
}
```

### Step 1.5: Run Your App

In your terminal, run:

```bash
jac start main.jac
```

You'll see output like:

```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8000
```

### Step 1.6: View in Browser

Open your browser and go to:

```
http://localhost:8000/cl/app
```

You should see "Hello, Jac!" and "My first full-stack app"

---

**⏭ Want to skip the theory?** Jump to [Step 2: First Component](./step-02-components.md)

---

## Part 2: Understanding the Concepts

### What is `cl { ... }`?

`cl` stands for "client" - it means this code runs in the **browser** (frontend).

```jac
cl {
    # Everything here runs on the client-side (browser)
}
```

Think of it like this:

- Code **inside** `cl { }` → Runs in the browser (frontend)
- Code **outside** `cl { }` → Runs on the server (backend)

### What is `def app() -> any`?

This is your **main entry point** - the function that Jac calls first.

```jac
def:pub app() -> any {
    return <div>...</div>;
}
```

**Requirements:**

- Must be named `app` (by convention)
- Must return JSX (HTML-like syntax)
- Located inside `cl { }` block

**Python analogy:**

```python
# Python
if __name__ == "__main__":
    run_app()

# Jac
def:pub app() -> any {
    # Start here
}
```

### What is JSX?

JSX lets you write HTML directly in your Jac code:

```jac
return <div>
    <h1>This is HTML!</h1>
    <p>But written in Jac code</p>
</div>;
```

**Key rules:**

1. Must have **one root element**

   ```jac
   #  Correct
   return <div><h1>Title</h1><p>Text</p></div>;

   #  Wrong (two root elements)
   return <h1>Title</h1><p>Text</p>;
   ```

2. Self-closing tags need `/`

   ```jac
   <img src="photo.jpg" />    #  Correct
   <img src="photo.jpg">       #  Wrong
   ```

3. Use `{}` to insert Jac code

   ```jac
    name = "Alice";
   return <h1>Hello, {name}!</h1>;  # Shows: Hello, Alice!
   ```

### How `jac start` Works

When you run `jac start main.jac`:

1. **Jac compiler** reads your `.jac` file
2. **Frontend code** (inside `cl`) → Compiled to JavaScript
3. **Backend code** (outside `cl`) → Stays as Python-like backend code
4. **Single server** serves both on port 8000

It's like running a Flask/FastAPI server, but it ALSO compiles and serves your React frontend - all in one command!

### Hot Module Replacement (HMR)

For faster development, use `--watch` mode:

```bash
jac start main.jac --watch
```

With HMR enabled:

- **File watcher** monitors `*.jac` files for changes
- **Backend** automatically recompiles when you save
- **Frontend** hot-reloads without full page refresh
- **No more manual restarts!**

**Note:** HMR requires the `watchdog` package. Install dev dependencies with:

```bash
jac install --dev
```

### File Organization

For now, everything goes in `main.jac`. As your app grows, you can split into multiple files:

```
todo-app/
├── main.jac          # Main app
├── components.jac    # Reusable components
└── walkers.jac       # Backend logic
```

But for this tutorial, we'll keep everything in one file for simplicity.

---

## What You've Learned

- How to create a Jac project
- Project structure basics
- What `cl { }` means (client-side code)
- The `def app()` entry point
- JSX basics (HTML in code)
- Running your app with `jac start`

---

## Common Issues

### Issue: `jac: command not found`

**Solution**: Install jac-client:

```bash
pip install jac-client
```

### Issue: Port 8000 already in use

**Solution**: Use a different port:

```bash
jac start main.jac --port 8080
```

Then visit `http://localhost:8080/cl/app`

### Issue: Blank page in browser

**Check:**

- Did you visit `/cl/app` (not just `/`)?
- Check terminal for errors
- Make sure `app()` has a `return` statement

### Issue: Changes not showing

**Best solution**: Use HMR mode for automatic reloading:

```bash
jac start main.jac --watch
```

**Alternative** (if not using HMR):

- Stop the server (Ctrl+C)
- Restart: `jac start main.jac`
- Refresh browser

---

## Quick Exercise

Before moving on, try changing the text:

```jac
cl {
    def:pub app() -> any {
        return <div>
            <h1>My Todo App</h1>
            <p>Built with Jac</p>
        </div>;
    }
}
```

Save, refresh your browser, and see the changes!

---

## Next Step

Great! You have a running Jac app. Now let's learn about **components** - the building blocks of any UI.

**[Continue to Step 2: First Component](./step-02-components.md)**
