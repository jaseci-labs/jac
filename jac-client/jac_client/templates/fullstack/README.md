# {{name}}

A full-stack Jac application with user authentication and todo list functionality.

## Project Structure

```
{{name}}/
├── jac.toml              # Project configuration
├── main.jac              # Main entry point (combines server + client)
├── endpoints.sv.jac      # Server-side data models and walkers
├── frontend.cl.jac       # Client-side React UI (declarations + JSX)
├── frontend.impl.jac     # Client-side function implementations
├── components/           # Reusable client components
│   ├── AuthForm.cl.jac   # Login/signup form
│   ├── TodoItem.cl.jac   # Individual todo display
│   └── Button.cl.jac     # Reusable button component
└── assets/               # Static assets (images, fonts, etc.)
```

## Getting Started

Start the development server:

```bash
jac start main.jac
```

Then open your browser to the URL shown in the terminal.

## Features

- **User Authentication**: Sign up and log in with username/password
- **Personal Todo Lists**: Each user gets their own isolated todo list
- **CRUD Operations**: Create, read, update (toggle), and delete todos
- **Real-time UI**: Responsive React frontend with instant updates

## Architecture

This template demonstrates the full-stack Jac architecture:

- **Server (`.sv.jac`)**: Defines data models (`node Todo`) and walkers for API operations
- **Client (`.cl.jac`)**: React components with state declarations and JSX templates
- **Implementations (`.impl.jac`)**: Separated function bodies for clean code organization
- **Entry Point (`main.jac`)**: Combines server and client imports

### Jac Patterns Used

- **`can with entry`**: Lifecycle effects that replace React's `useEffect`
- **JSX Comprehensions**: `{[<Component /> for item in items]}` instead of `.map()`
- **Impl Separation**: Declarations in `.cl.jac`, implementations in `.impl.jac`

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```
