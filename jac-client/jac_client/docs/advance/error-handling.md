# Error Handling with JacClientErrorBoundary

Improve error resilience and user experience in your Jac Client  apps by leveraging `JacClientErrorBoundary` for fine-grained error containment and recovery.

## Overview

`JacClientErrorBoundary` is a specialized error boundary component for Jac Client apps. It catches rendering errors in its child component tree, logs them, and displays a fallback UI, preventing the entire app from crashing when a descendant component fails.

You can wrap any section of your component hierarchy with `JacClientErrorBoundary` to scope error isolation and customize recovery options.

## Quick Start

`JacClientErrorBoundary` is bundled with Jac Client. Import and wrap it around any subtree where you want to catch render-time errors:

```jsx
cl import from "@jac-client/utils" {JacClientErrorBoundary, ErrorFallback }

cl{
    def:pub app -> any {
        return (
            <JacClientErrorBoundary FallbackComponent={ErrorFallback}>
            <MainAppComponents />
            </JacClientErrorBoundary>
        );
    }
}
```

## Automatic Error Boundary Handling in jac-client

In Jac-client, the entire application is internally wrapped with `JacClientErrorBoundary` by default.

This means:

- You do not need to manually wrap your root App component with `JacClientErrorBoundary`.
- Even if the developer does not explicitly use `JacClientErrorBoundary`, it is still applied internally by jac-client.

### Behavior During Rendering Errors

When a rendering error occurs anywhere in the component tree:

- The error is caught by `JacClientErrorBoundary`
- The application does not crash
- A predefined Error Fallback UI is rendered instead of a blank screen or fatal crash

## ErrorBoundary Props & Customization

`JacClientErrorBoundary` supports the following props:

| Prop         |          Description             |
|--------------|----------------------------------|
| `fallback`   | Custom fallback UI to show on error       |
| `FallbackComponent`| Show default fallback UI with error    |

**Example with custom fallback:**

```jsx
<JacClientErrorBoundary fallback={<div>Oops! Something went wrong.</div>}>
  <ExpensiveWidget />
</JacClientErrorBoundary>
```

**Example with FallbackComponent:**

```jsx
<JacClientErrorBoundary  FallbackComponent={ErrorFallback}>
  <ExpensiveWidget />
</JacClientErrorBoundary>
```

## How It Works

- On error in any child component, `JacClientErrorBoundary`:
  1. Catches the error, stops it from propagating further up the DOM tree.
  2. Renders the `fallback` UI instead of crashing the entire app/subtree.
  3. Leaves siblings and parent components unaffected (if boundaries are nested).

## Typical Use Cases

1. **Isolate Failure-Prone Widgets**: Protect sections that fetch data, embed third-party code, or are unstable.
2. **Per-Page Protection**: Wrap top-level pages/routes to prevent the whole app from failing due to one error.
3. **Micro-Frontend/Widget Boundaries**: Nest boundaries around embeddables for fault isolation.

## Example: Nested Boundaries in Action

Given this structure:

```
<App>
  |
  |-- <JacClientErrorBoundary 1>
  |       |
  |     <HomePage>
  |       |
  |     <JacClientErrorBoundary 2>
  |            |
  |         <AboutPage>  ❌ Broken
```

If `<AboutPage>` throws a error while rendering, **only `<JacClientErrorBoundary 2>`** triggers its fallback UI, and the rest of the app (`<HomePage>`, etc.) continues functioning normally.

---
**Tip:** Use multiple, focused `JacClientErrorBoundary` components to provide clear user feedback and robust error recovery without affecting the whole application.
