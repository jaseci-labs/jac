# all-in-one

This example demonstrates a comprehensive Jac application combining:

- **React Router** - Client-side routing
- **CSS Styling** - Pure CSS with asset references
- **Asset Serving** - Static assets (images, etc.)
- **Nested Folder Imports** - Organizing Jac components
- **TypeScript Components** - TypeScript component integration

## Running Jac Code

Make sure node modules are installed:

```bash
npm install
```

To run your Jac code, use the Jac CLI:

```bash
jac start app.jac
```

## TypeScript Support

This example includes TypeScript support with a `Card` component (`components/Card.tsx`). The TypeScript component is imported and used in the Jac code:

```jac
cl import from ".components/Card.tsx" { Card }
```

See the TypeScript component in action on the Home page!

Happy coding with Jac!
