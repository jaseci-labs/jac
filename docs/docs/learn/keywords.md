# Jac Programming Language Keyword Reference

 Keywords are special reserved words that have a specific meaning and purpose in the language and cannot be used as identifiers for variables, functions, or other objects. In Jac, all the keywords that exist in Python can also be used.

---

## 1. Archetype and Data Structure Keywords

These keywords define the core data and structural elements in Jac, forming the foundation for graph-based and object-oriented programming.

**Core Archetype Keywords**

| Keyword | Description |
| --- | --- |
| [`obj`](jac-ref/functions-objects.md) | Defines a standard object, similar to a Python class, for holding data and behaviors. |
| [`node`](jac-ref/osp.md) |Represents a vertex or location in a graph, capable of storing data.|
| [`edge`](jac-ref/osp.md)|Defines a directed connection between two nodes, which can have its own attributes and logic. |
| [`walker`](jac-ref/osp.md) | A mobile computational agent that traverses the graph of nodes and edges to process data. |
| [`class`](jac-ref/functions-objects.md)  |Defines a standard Python-compatible class, allowing for seamless integration with the Python ecosystem. |
| [`enum`](jac-ref/foundation.md) |Creates an enumeration, a set of named constants. |

---

## 2. Variable and State Declaration Keywords

These keywords are used for declaring variables and managing their state and scope.

**Variable Declaration**

| Keyword | Description |
| --- | --- |
| [`has`](jac-ref/functions-objects.md) | Declares an instance variable within an archetype, with mandatory type hints. |
| [`let`](jac-ref/foundation.md) | Declares a module-level variable with lexical (module-level) scope. |
| [`glob`](jac-ref/foundation.md) | Declares a global variable accessible across all modules. |
| [`global`](jac-ref/foundation.md) | Modifies a global variable from within a local scope. |
| [`nonlocal`](jac-ref/foundation.md) | Modifies a variable from a nearby enclosing scope that isn't global. |

---

## 3. Ability and Function Keywords

These keywords define callable units of code, such as functions and methods associated with archetypes.

**Function and Method Definition**

| Keyword | Description |
| --- | --- |
| [`can`](jac-ref/functions-objects.md) | Defines an "ability" (a method) for an archetype. |
| [`def`](jac-ref/functions-objects.md) | Defines a standard function with mandatory type annotations. |
| [`impl`](jac-ref/functions-objects.md) | Separates the implementation of a construct from its declaration. |
| [`yield`](jac-ref/advanced.md) | Pauses a function, returns a value, and creates a generator. |

---

## 4. Control Flow and Logic Keywords

These keywords direct the path of execution, enabling conditional logic, loops, and error handling.

**Control Flow Statements**

| Keyword | Description |
| --- | --- |
| [`if` / `elif` / `else`](jac-ref/foundation.md) | Executes code blocks conditionally. |
| [`for`](jac-ref/foundation.md) | Iterates over a sequence. |
| [`while`](jac-ref/foundation.md) | Creates a loop that executes as long as a condition is true. |
| [`match` / `case`](jac-ref/foundation.md) | Implements structural pattern matching. |
| [`try` / `except` / `finally`](jac-ref/advanced.md) | Handles exceptions. |
| [`break`](jac-ref/foundation.md) | Exits the current loop. |
| [`continue`](jac-ref/foundation.md) | Proceeds to the next iteration of a loop. |
| [`raise`](jac-ref/advanced.md) | Triggers an exception. |

---

## 5. Walker-Specific Control Keywords

These keywords are used exclusively to control the traversal behavior of `walker` agents on a graph.

**Walker Navigation**

| Keyword | Description |
| --- | --- |
| [`visit`](jac-ref/osp.md) | Directs a walker to traverse to a node or edge. |
| [`spawn`](jac-ref/osp.md) | Creates and starts a walker on a graph. |
| [`ignore`](jac-ref/osp.md)  |Excludes a node or edge from a walker's traversal. |
| [`disengage`](jac-ref/osp.md) | Immediately terminates a walker's traversal. |
| [`report`](jac-ref/osp.md) | Sends a result from a walker back to its spawning context. |
| [`with entry`](jac-ref/foundation.md) | Defines the main execution block for a module. |

---

## 6. Concurrency and Asynchronous Keywords

These keywords are used to manage concurrent and asynchronous operations for non-blocking execution.

**Asynchronous Operations**

| Keyword | Description |
| --- | --- |
| [`flow`](jac-ref/concurrency.md)  |Initiates a concurrent, non-blocking execution of an expression. |
| [`wait`](jac-ref/concurrency.md) | Pauses execution to await the completion of a concurrent operation. |
| [`async`](jac-ref/concurrency.md) | Declares a function or ability as asynchronous. |

---

## 7. AI and Language Model Integration

These keywords facilitate the integration of AI and Large Language Models (LLMs) directly into the language.

**AI Integration**

| Keyword | Description |
| --- | --- |
| [`sem`](jac-ref/ai-integration.md)  |Associates a natural language "semantic string" with a code element for AI interpretation. |
| [`by`](jac-ref/ai-integration.md) | Defers a task to an LLM instead of providing a manual implementation. |

---

## 8. Miscellaneous Keywords

This section covers other essential keywords used for various operations.

**Other Essential Keywords**

| Keyword | Description |
| --- | --- |
| [`del`](jac-ref/foundation.md) | Deletes objects, properties, or elements. |
| [`assert`](jac-ref/advanced.md) | Verifies if a condition is true, raising an error if not. |
| [`<keyword>`](jac-ref/foundation.md) | Used to escape reserved keywords when you want to use them as variable or attribute names, e.g., `<>node= 90;`, `<>dict = 8;`|
|[`test`](jac-ref/advanced.md)|Defines test cases for code validation and unit testing. |

---

!!! tip "Keyword Usage Guidelines"
    - **Reserved words**: Keywords cannot be used as variable or function names
    - **Case sensitive**: All keywords must be written in lowercase
    - **Context matters**: Some keywords are only valid in specific contexts (e.g., walker keywords)
    - **Type safety**: Many keywords work with Jac's type system for better code reliability
