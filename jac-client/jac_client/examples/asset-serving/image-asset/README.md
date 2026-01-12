# Static Path Example

This example demonstrates how to serve static assets using direct `/static/` path references.

## Features

- Direct path references using `/static/assets/` URLs
- Simple and straightforward approach
- No build configuration required
- Works immediately without imports

## Project Structure

```
image-asset/
├── app.jac          # Main application file
├── assets/          # Static assets directory
│   └── burger.png   # Burger image
├── compiled/        # Compiled files (generated)
├── build/           # Build output (generated)
└── dist/            # Distribution output (generated)
```

## Running the Example

1. Make sure node modules are installed:

```bash
npm install
```

1. Run the Jac server:

```bash
jac start app.jac
```

1. Open your browser and navigate to:

```
http://localhost:8000/cl/app
```

## How It Works

### Static Path Syntax

```jac
<img src="/static/assets/burger.png" alt="Burger" />
```

### Server Configuration

The server automatically serves files from:

- `dist/` directory (Vite-bundled assets)
- `assets/` directory (user-provided static assets)

Both directories are checked when serving `/static/*` requests.

### Path Resolution

1. Request: `/static/assets/burger.png`
2. Server checks `dist/assets/burger.png` first
3. If not found, checks `assets/burger.png`
4. Serves file with appropriate MIME type
5. Sets cache headers for optimal performance

### Benefits

- **Simplicity**: No imports or build configuration needed
- **Immediate**: Works right away without build step
- **Flexible**: Easy to reference assets from anywhere
- **Quick Prototyping**: Perfect for rapid development

### Use Cases

**Direct Image References:**

```jac
<img src="/static/assets/logo.png" alt="Logo" />
```

**CSS Background Images:**

```jac
<div style={{backgroundImage: "url('/static/assets/hero.jpg')"}} />
```

**Dynamic Asset Paths:**

```jac
imagePath = `/static/assets/${imageName}.png`;
<img src={imagePath} />
```

## Best Practices

1. Use this method for quick prototypes
2. Organize assets in the `assets/` folder
3. Use descriptive file names
4. Keep assets reasonably sized
5. Consider using imports for production apps

## Limitations

- No automatic optimization
- No hash-based cache busting
- Manual cache control required
- No type safety for asset paths

## When to Use

**Choose Static Path if:**

- Building a quick prototype
- Assets don't need optimization
- Want immediate results
- Working with simple, small assets

**Consider Import Methods if:**

- Building for production
- Need automatic optimization
- Want cache busting
- Prefer type-safe references

Happy coding with Jac!
