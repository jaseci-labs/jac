# multi_segment_app

A Jac client-side application.

## Project Structure

```
multi_segment_app/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.jac        # Example Jac component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac run main.jac
```

## Components

Create Jac components in `components/` as `.jac` files and import them:

```jac
import from .components.Button { Button }
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac install --npm some-package
```
