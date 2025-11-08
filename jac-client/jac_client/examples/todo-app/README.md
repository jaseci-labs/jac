# Todo App Example

A complete todo application built with Jac, demonstrating state management, routing, authentication, and backend integration.

---

## 🚀 Quick Start

### Prerequisites

Before running this example, make sure you have:
- **Jac Client** installed (`pip install jac-client`)
- **Node.js** and **npm** installed
- Followed the **[Getting Started Tutorial](../../docs/README.md)** if you're new to Jac

### Running the App

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Start the server:**
   ```bash
   jac serve app.jac
   ```

3. **Open your browser:**
   Visit `http://localhost:8000`

---

## 📚 Learning Resources

If you haven't followed the tutorial yet, we highly recommend checking out:

- **[Complete Beginner's Guide](../../docs/README.md)** - Step-by-step tutorial covering all the basics
- **[Routing Guide](../../docs/routing.md)** - Learn about multi-page applications
- **[Lifecycle Hooks](../../docs/lifecycle-hooks.md)** - Component lifecycle management
- **[Advanced State](../../docs/advanced-state.md)** - Managing complex state
- **[Imports Guide](../../docs/imports.md)** - Importing libraries and modules

---

## 🎯 What This Example Demonstrates

- ✅ State management with `createState()`
- ✅ Component creation and composition
- ✅ Event handling
- ✅ Routing with `initRouter()`
- ✅ Authentication (login/signup)
- ✅ Backend integration with `__jacSpawn()`
- ✅ Graph database operations
- ✅ No HTTP client needed!

---

## 📁 Project Structure

```
todo-app/
├── app.jac          # Main application file
├── package.json     # Node.js dependencies
└── static/          # Compiled assets
```

---

## 💡 Key Features

- **Create Todos**: Add new todo items
- **Toggle Status**: Mark todos as done/undone
- **Filter Todos**: View all, active, or completed todos
- **Remove Todos**: Delete individual todos
- **Clear Completed**: Remove all completed todos
- **User Authentication**: Login and signup functionality
- **Persistent Data**: Todos stored in graph database

---

Happy coding! 🎉

