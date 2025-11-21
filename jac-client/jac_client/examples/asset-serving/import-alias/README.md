# Import Alias Example

This example demonstrates how to import static assets using the `@jac-client/assets` alias pattern.

## Features

- Imports image using `@jac-client/assets` alias
- Vite processes and optimizes the asset
- Automatic hash generation for cache busting
- Type-safe asset references

## Project Structure

```
import-alias/
├── app.jac          # Main application file
├── assets/          # Static assets directory
│   └── burger.png   # Burger image
├── src/             # Source files (generated)
├── build/           # Build output (generated)
└── dist/            # Distribution output (generated)
```

## Running the Example

1. Make sure node modules are installed:
```bash
npm install
```

2. Run the Jac server:
```bash
jac serve app.jac
```

3. Open your browser and navigate to:
```
http://localhost:8000/page/app
```

## How It Works

### Import Syntax

```jac
cl import from "@jac-client/assets/burger.png" { default as burgerImage }
<img src={burgerImage} />
```

### Configuration

The alias is configured in `vite.config.js`:

```javascript
resolve: {
  alias: {
    "@jac-client/assets": path.resolve(__dirname, "src/assets"),
  },
}
```

### Build Process

1. Assets from root `assets/` folder are copied to `src/assets/` during build
2. Vite processes the import and generates optimized asset URLs
3. Assets are bundled with hash-based filenames for cache invalidation
4. The imported variable contains the processed asset URL

### Benefits

- **Type Safety**: Import errors caught at build time
- **Optimization**: Vite automatically optimizes assets
- **Cache Busting**: Hash-based filenames prevent stale cache
- **Code Splitting**: Assets can be code-split automatically

## Best Practices

1. Use this method for production applications
2. Organize assets in the `assets/` folder
3. Let Vite handle optimization and caching
4. Use descriptive variable names for imported assets

Happy coding with Jac! 🍔
