# Jac Programming Language Keyword Reference

 Keywords are special reserved words that have a specific meaning and purpose in the language and cannot be used as identifiers for variables, functions, or other objects. In Jac, all the keywords that exist in Python can also be used.

---

## 1. Archetype and Data Structure Keywords

These keywords define the core data and structural elements in Jac, forming the foundation for graph-based and object-oriented programming.

**Core Archetype Keywords**

| Keyword | Description |
| --- | --- |
| [`obj`](https://www.jac-lang.org/learn/jac_ref/#archetype-types) | Defines a standard object, similar to a Python class, for holding data and behaviors. |
| [`node`](https://www.jac-lang.org/learn/jac_ref/#archetype-types) |Represents a vertex or location in a graph, capable of storing data.|
| [`edge`](https://www.jac-lang.org/learn/jac_ref/#archetype-types)|Defines a directed connection between two nodes, which can have its own attributes and logic. |
| [`walker`](https://www.jac-lang.org/learn/jac_ref/#archetype-types) | A mobile computational agent that traverses the graph of nodes and edges to process data. |
| [`class`](https://www.jac-lang.org/learn/jac_ref/#archetype-types)  |Defines a standard Python-compatible class, allowing for seamless integration with the Python ecosystem. |
| [`enum`](https://www.jac-lang.org/learn/jac_ref/#enumerations)  |Creates an enumeration, a set of named constants. |

---

## 2. Variable and State Declaration Keywords

These keywords are used for declaring variables and managing their state and scope.

**Variable Declaration**

| Keyword | Description |
| --- | --- |
| [`has`](https://www.jac-lang.org/learn/jac_ref/#constructor-rules-and-has-variables) | Declares an instance variable within an archetype, with mandatory type hints. |
| [`let`](https://www.jac-lang.org/learn/jac_ref/#declaration-keywords) | Declares a module-level variable with lexical (module-level) scope. |
| [`glob`](https://www.jac-lang.org/learn/jac_ref/#declaration-keywords) | Declares a global variable accessible across all modules. |
| [`global`](https://www.jac-lang.org/learn/jac_ref/#global-and-nonlocal-statements) | Modifies a global variable from within a local scope. |
| [`nonlocal`](https://www.jac-lang.org/learn/jac_ref/#global-and-nonlocal-statements) | Modifies a variable from a nearby enclosing scope that isn't global. |

---

## 3. Ability and Function Keywords

These keywords define callable units of code, such as functions and methods associated with archetypes.

**Function and Method Definition**

| Keyword | Description |
| --- | --- |
| [`can`](https://www.jac-lang.org/learn/jac_ref/#functions-and-abilities) | Defines an "ability" (a method) for an archetype. |
| [`def`](https://www.jac-lang.org/learn/jac_ref/#functions-and-abilities) | Defines a standard function with mandatory type annotations. |
| [`impl`](https://www.jac-lang.org/learn/jac_ref/#implementations) | Separates the implementation of a construct from its declaration. |
| [`yield`](https://www.jac-lang.org/learn/jac_ref/#yield-statements) | Pauses a function, returns a value, and creates a generator. |

---

## 4. Control Flow and Logic Keywords

These keywords direct the path of execution, enabling conditional logic, loops, and error handling.

**Control Flow Statements**

| Keyword | Description |
| --- | --- |
| [`if` / `elif` / `else`](https://www.jac-lang.org/learn/jac_ref/#if-statements) | Executes code blocks conditionally. |
| [`for`](https://www.jac-lang.org/learn/jac_ref/#for-statements) | Iterates over a sequence. |
| [`while`](https://www.jac-lang.org/learn/jac_ref/#while-statements) | Creates a loop that executes as long as a condition is true. |
| [`match` / `case`](https://www.jac-lang.org/learn/jac_ref/#match-statements) | Implements structural pattern matching. |
| [`try` / `except` / `finally`](https://www.jac-lang.org/learn/jac_ref/#try-statements) | Handles exceptions. |
| [`break`](https://www.jac-lang.org/learn/jac_ref/#while-statements) | Exits the current loop. |
| [`continue`](https://www.jac-lang.org/learn/jac_ref/#while-statements) | Proceeds to the next iteration of a loop. |
| [`raise`](https://www.jac-lang.org/learn/jac_ref/#raise-statements) | Triggers an exception. |

---

## 5. Walker-Specific Control Keywords

These keywords are used exclusively to control the traversal behavior of `walker` agents on a graph.

**Walker Navigation**

| Keyword | Description |
| --- | --- |
| [`visit`](https://www.jac-lang.org/learn/jac_ref/#visit-statement) | Directs a walker to traverse to a node or edge. |
| [`spawn`](https://www.jac-lang.org/learn/jac_ref/#object-spatial-spawn-expressions) | Creates and starts a walker on a graph. |
| [`ignore`](https://www.jac-lang.org/learn/jac_ref/#ignore-statement)  |Excludes a node or edge from a walker's traversal. |
| [`disengage`](https://www.jac-lang.org/learn/jac_ref/#disengage-statement) | Immediately terminates a walker's traversal. |
| [`report`](https://www.jac-lang.org/learn/jac_ref/#report-statements) | Sends a result from a walker back to its spawning context. |
| [`with entry`](https://www.jac-lang.org/learn/jac_ref/#integration-with-entry-points) | Defines the main execution block for a module. |


---

## 6. Concurrency and Asynchronous Keywords

These keywords are used to manage concurrent and asynchronous operations for non-blocking execution.

**Asynchronous Operations**

| Keyword | Description |
| --- | --- |
| [`flow`](https://www.jac-lang.org/learn/jac_ref/#flow-modifier)  |Initiates a concurrent, non-blocking execution of an expression. |
| [`wait`](https://www.jac-lang.org/learn/jac_ref/#flow-modifier) | Pauses execution to await the completion of a concurrent operation. |
| [`async`](https://www.jac-lang.org/learn/jac_ref/#flow-modifier) | Declares a function or ability as asynchronous. |

---


## 7. AI and Language Model Integration

These keywords facilitate the integration of AI and Large Language Models (LLMs) directly into the language.


**AI Integration**


| Keyword | Description |
| --- | --- |
| [`sem`](https://www.jac-lang.org/learn/jac_ref/#semstrings)  |Associates a natural language "semantic string" with a code element for AI interpretation. |
| [`by`](https://www.jac-lang.org/learn/jac-byllm/usage/) | Defers a task to an LLM instead of providing a manual implementation. |

---

## 8. Miscellaneous Keywords

This section covers other essential keywords used for various operations.


**Other Essential Keywords**

| Keyword | Description |
| --- | --- |
| [`del`](https://www.jac-lang.org/learn/jac_ref/#delete-statements) | Deletes objects, properties, or elements. |
| [`assert`](https://www.jac-lang.org/learn/jac_ref/#assert-statements) | Verifies if a condition is true, raising an error if not. |
| [`<keyword>`](https://www.jac-lang.org/learn/jac_ref/#keyword-escaping) | Used to escape reserved keywords when you want to use them as variable or attribute names, e.g., `<>node= 90;`, `<>dict = 8;`|
|[`test`](https://www.jac-lang.org/learn/jac_ref/#test-implementations)|Defines test cases for code validation and unit testing. |


---

!!! tip "Keyword Usage Guidelines"
    - **Reserved words**: Keywords cannot be used as variable or function names
    - **Case sensitive**: All keywords must be written in lowercase
    - **Context matters**: Some keywords are only valid in specific contexts (e.g., walker keywords)
    - **Type safety**: Many keywords work with Jac's type system for better code reliability
