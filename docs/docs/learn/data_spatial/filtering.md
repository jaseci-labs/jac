# Node and Edge Filtering

JacLang provides flexible filtering mechanisms to control graph traversal and operations, allowing precise selection of nodes and edges based on specific criteria. These filters enable developers to optimize traversal and focus only on relevant parts of the graph.

---

## Node-Based Filtering

Node-based filtering restricts traversal to specific nodes that satisfy predefined conditions. This is useful when you need to:

- Limit traversal to nodes with certain attributes or properties.
- Filter nodes dynamically based on walker state or external context.

### Example:

We can filter specific types of nodes from a list of visitable nodes based on their type, and further apply conditions on node attributes to refine the results.
=== "Jac"
    <div class="code-block">
    ```jac
    --8<-- "jac/examples/data_spatial/filtering.jac"
    ```
    </div>
??? example "Graph"
    ```mermaid
    flowchart LR
    0 -->|"a()"| 1
    1 -->|"b()"| 2
    2 -->|"c()"| 3
    2 -->|"c()"| 4
    5 -->|"a()"| 4
    1 -->|"b()"| 5
    0["Root()"]
    1["A(val=5)"]
    2["B(val=10)"]
    3["C(val=15)"]
    4["C(val=25)"]
    5["A(val=20)"]
    ```

## Edge-Based Filtering

Edge filtering in JacLang allows developers to control traversal by selecting edges based on specific attributes or conditions. This is especially useful in scenarios where certain edges in the graph are more relevant to the task at hand, such as weighted graphs or context-sensitive connections.

---

### Example:
We can filter nodes based on specific edge attributes, such as filtering by edge values to retrieve a subset of connected nodes.
=== "Jac"
    <div class="code-block">
    ```jac
    --8<-- "jac/examples/data_spatial/edge_filtering.jac"
    ```
    </div>

??? example "Graph"
    ```mermaid
    flowchart LR
    0 -->|"a(val=10)"| 1
    0 -->|"a(val=20)"| 2
    0 -->|"b(val=30)"| 3
    0["Root()"]
    1["A(val=10)"]
    2["A(val=20)"]
    3["A(val=30)"]
    ```