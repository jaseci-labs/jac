# Introduction to JAC-Client (Onelang)

Build full-stack web applications with Jac - one language for frontend and backend.

Jac Client enables you to write React-like components, manage state, and build interactive UIs all in Jac. No need for separate frontend frameworks, HTTP clients, or complex build configurations.

## Who is this guide for?

This documentation is intended for:

- React developers learning Jac for the first time
- Beginners who understand basic programming concepts

Each topic includes side-by-side comparisons of React/JavaScript and JAC-Client syntax, making it easy to understand the differences and similarities.

## Documentation Structure

This guide covers the following topics:

| Document                                            | Description                                       |
| --------------------------------------------------- | ------------------------------------------------- |
| [Lambda Functions](./arrow-functions.md)            | How arrow functions translate to lambda functions |
| [Conditional Rendering](./conditional-rendering.md) | Patterns for rendering UI conditionally           |
| [Exception Handling](./exception-handling.md)       | Error handling with try/except                    |
| [List Handling](./list-utills.md)                   | Array methods and list operations                 |
| [Loops](./loops.md)                                 | Loop syntax including for, while, and for-in      |

## Quick Syntax Comparison

Before diving into specific topics, here is a quick overview of the main syntax differences:

### Variables and Types

=== "JavaScript"

    ```javascript
    const name = "Alice";
    count = 0;
    ```

=== "JAC-Client"

    ```jac
    name = "Alice";
    count = 0;
    ```

### Functions

=== "JavaScript"

    ```javascript
    function greet(name) {
      return `Hello, ${name}!`;
    }

    const double = (n) => n * 2;
    ```

=== "JAC-Client"

    ```jac
    def greet(name: str) -> str {
        return "Hello, " + name + "!";
    }

    double = lambda n: int -> int { return n * 2; };
    ```

### Conditionals

=== "JavaScript"

    ```javascript
    const status = isOnline ? "Online" : "Offline";
    ```

=== "JAC-Client"

    ```jac
    status = ("Online") if isOnline else ("Offline");
    ```

### Components

=== "React"

    ```javascript
    function Greeting({ name }) {
      return <div>Hello, {name}!</div>;
    }
    ```

=== "JAC-Client"

    ```jac
    def Greeting(props: dict) -> JsxElement {
        name = props.name;
        return <div>Hello, {name}!</div>;
    }
    ```

## Getting Help

If you encounter issues or have questions:

- Review the example repositories linked in each document
- Check the main Jac documentation for language reference
- Explore the examples in the [jac-client-examples](https://github.com/jaseci-labs/jac-client-examples) repository

## Next Steps

Start with the topic most relevant to your needs:

- If you use arrow functions frequently, begin with [Lambda Functions](./arrow-functions.md)
- If you need to render content conditionally, see [Conditional Rendering](./conditional-rendering.md)
- If you work with arrays and lists, check [List Handling](./list-utills.md)
- If you need to handle errors, read [Exception Handling](./exception-handling.md)
- If you need to iterate over data, see [Loops](./loops.md)
