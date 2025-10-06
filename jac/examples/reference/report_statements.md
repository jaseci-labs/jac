**Report Statements**

Report statements are a special feature in Jac's walker-based programming model that allow walkers to send data back to the caller without terminating execution. Unlike `return` statements which exit a function, `report` statements enable streaming results during graph traversal.

**Basic Report Syntax**

The simplest form appears on line 6: `report 42;`. The `report` keyword is followed by an expression, and that expression's value is sent back to the caller. The walker continues executing after the report statement.

**Reporting Different Value Types**

The example demonstrates reporting various types of values:

| Line | Expression | Type | Description |
|------|------------|------|-------------|
| 6 | `report 42;` | Integer | Reports a literal number |
| 9 | `report "hello";` | String | Reports a text message |
| 12 | `report 10 + 20;` | Expression | Evaluates arithmetic before reporting |
| 16 | `report x;` | Variable | Reports the value stored in variable x (100) |
| 19 | `report [1, 2, 3];` | List | Reports a collection |
| 22 | `report {"key": "value", "number": 123};` | Dictionary | Reports a structured object |
| 25 | `report {"result": 5 * 10, "status": "ok"};` | Complex | Reports dict with computed values |

**Walker Context**

Lines 3-29 define a walker named `Reporter` with the ability `process` that executes when entering the root node (line 4). This walker contains multiple report statements that execute sequentially, each sending its value back to the caller.

**Execution Flow**

```mermaid
graph TD
    A[root spawn Reporter] --> B[Walker enters root node]
    B --> C[report 42]
    C --> D[report "hello"]
    D --> E[report 10 + 20]
    E --> F[report x]
    F --> G[report list]
    G --> H[report dict]
    H --> I[report complex dict]
    I --> J[disengage - walker stops]
```

When `root spawn w;` executes on line 33, the walker runs and sends seven values back to the caller before disengaging on line 27.

**Report vs Return**

Understanding the difference between these two statements is crucial:

| Feature | `report` | `return` |
|---------|----------|----------|
| Terminates execution | No - continues running | Yes - exits immediately |
| Multiple calls | Yes - can report many times | No - only returns once |
| Primary usage | Walker abilities | Functions and methods |
| Value streaming | Yes - sends data during execution | No - single value at end |
| Graph traversal | Continues to next nodes | Stops traversal |

**Multiple Reports**

Lines 6-25 show a walker ability with seven different report statements. All of these execute in sequence, each sending their respective value back to the caller. This streaming capability is unique to report statements and enables walkers to communicate incremental results during graph traversal.

**Use Cases**

Report statements excel at:
- Collecting data from multiple nodes during a graph walk
- Streaming results without waiting for traversal completion
- Providing progress updates during long-running traversals
- Implementing data aggregation patterns across graph structures
- Building APIs that return multiple related values

**Practical Example**

The walker on lines 3-29 demonstrates a typical pattern:
1. Enter a node (root in this case)
2. Report various computed values (lines 6-25)
3. Disengage to stop the walker (line 27)

The caller can capture all reported values and process them as needed, making report statements ideal for building data collection and query systems.

**Integration with Walkers**

Report statements work seamlessly with Jac's walker traversal model. As walkers move through a graph using `visit` statements, they can report findings from each node, building up a collection of results that represents their journey through the data structure.
