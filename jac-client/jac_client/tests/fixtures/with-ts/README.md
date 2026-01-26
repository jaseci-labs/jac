# with-ts

## Running Jac Code

Make sure packages are installed:

```bash
bun install
```

To run your Jac code, use the Jac CLI:

```bash
jac start app.jac
```

## TypeScript Support

This project includes TypeScript support. You can create TypeScript components in the `components/` directory and import them in your Jac files.

Example:

```jac
cl import from ".components/Button.tsx" { Button }
```

See `components/Button.tsx` for an example TypeScript component.

For more information, see the [TypeScript guide](../../docs/working-with-ts.md).

Happy coding with Jac and TypeScript!
