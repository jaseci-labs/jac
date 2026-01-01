# Building a Full-Stack Todo App with Jac: Complete Walkthrough

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - All `def` functions are **automatically exported** - no `:pub` needed
> - You **cannot export variables** (globals) - only functions can be exported
>
> **For jac-client >= 0.2.4:**
>
> - Functions and variables **must be explicitly exported** with `:pub`
> - The `app()` function must be `def:pub app()` to be accessible
> - This guide assumes version 0.2.4 or later

Welcome! This guide will teach you how to build a **complete full-stack Todo application** using Jac - perfect for **complete beginners**.

## What is Full-Stack Development?

Think of building a house:

- **Frontend** = The interior design (what users see and interact with)
- **Backend** = The plumbing and electricity (where data is stored and processed)
- **Full-Stack** = Building both the interior AND the infrastructure

Traditionally, you'd need:

- **JavaScript/React** for frontend
- **Python/Node.js** for backend
- **SQL** for database
- **REST APIs** to connect them

With **Jac**, you write **everything in one language**, in **one file**!

## What You'll Build

By the end of this guide, you'll have a fully functional Todo app with:

- **Beautiful UI** - Modern, responsive interface
- **User Authentication** - Signup and login
- **Protected Routes** - Private pages only for logged-in users
- **Full CRUD** - Create, Read, Update, Delete todos
- **Real Backend** - Data persists even after refresh
- **Filtering** - View all, active, or completed todos
- **Multiple Pages** - Routing without page reloads

All of this in approximately **735 lines of Jac code**!

## Prerequisites

Before starting, you should have:

- **Python 3.12 or higher** installed on your system
  - Download: [https://www.python.org/downloads/](https://www.python.org/downloads/)
- **Node.js 20 or higher** and npm installed (required for frontend dependencies)
  - Download: [https://nodejs.org/](https://nodejs.org/) (npm is included with Node.js)
- A code editor (VS Code recommended with Jac extension)
  - Download: [https://code.visualstudio.com/](https://code.visualstudio.com/)
- Basic Python knowledge
- Basic understanding of HTML/CSS concepts (helpful but not required)

### Quick Setup Check

Verify your environment is ready by running:

```bash
python --version    # Should show Python 3.12+
node --version      # Should show Node 20+
npm --version       # Should show npm
jac --version       # Should show Jac is installed
```

If Jac is not installed, run:

```bash
pip install jac-client
```

> **Note:** If you have previously installed `jaclang`, please uninstall it first using `pip uninstall jaclang`. The required version of `jaclang` will be installed automatically as a dependency of `jac-client`, so you do not need to install it separately.

## How This Guide Works

Each step builds on the previous one, gradually creating the complete app. Every step has **two parts**:

1. **Part 1: Building the App** - Hands-on coding, building the actual app
2. **Part 2: Understanding the Concepts** - Optional deeper knowledge

**Want to just build?** Follow only Part 1 of each step and skip all Part 2 sections. You'll still have a working app!

**Want to learn deeply?** Read both parts to understand *why* things work, not just *how*.

## Learning Path

We'll build the app in 11 progressive steps:

1. **[Step 1: Project Setup](./step-01-setup.md)** - Create your first Jac project
2. **[Step 2: First Component](./step-02-components.md)** - Create and organize components
3. **[Step 3: Styling](./step-03-styling.md)** - Make your components beautiful
4. **[Step 4: Todo UI](./step-04-todo-ui.md)** - Build the complete todo interface
5. **[Step 5: Local State](./step-05-local-state.md)** - Add interactivity with state
6. **[Step 6: Event Handlers](./step-06-events.md)** - Handle user clicks and input
7. **[Step 7: Effects](./step-07-effects.md)** - Load data when the app starts
8. **[Step 8: Walkers](./step-08-walkers.md)** - Create the backend with walkers
9. **[Step 9: Authentication](./step-09-authentication.md)** - Add user signup and login
10. **[Step 10: Routing](./step-10-routing.md)** - Add multiple pages
11. **[Step 11: Final Integration](./step-11-final.md)** - Complete working app

## Learning Tips

- **Follow in order** - Each step builds on the previous one
- **Type the code** - Don't just copy/paste. Typing helps you learn!
- **Experiment** - Try changing things to see what happens
- **Use the "Understanding" sections** - Read them when you want to know *why* something works

## Time to Complete

- **Just building**: 2-3 hours
- **Building + learning**: 4-6 hours

## Getting Help

- Each step has a **"Common Issues"** section
- Complete final code available in Step 11
- Check the [Jac Documentation](https://www.jac-lang.org) for API details

## Ready to Start?

Let's build your first full-stack app!

 **[Continue to Step 1: Project Setup](./step-01-setup.md)**
