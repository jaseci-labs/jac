**Special Comprehensions - Filter and Assign**

Special comprehensions are unique Jac constructs that provide concise filtering and bulk modification operations on collections. These are particularly powerful in Object-Spatial Programming for querying and manipulating nodes retrieved through graph traversal.

**Two Forms of Comprehensions**

| Type | Syntax | Purpose | Returns |
|------|--------|---------|---------|
| Filter | `collection(?condition1, condition2, ...)` | Select objects matching ALL conditions | New filtered collection |
| Assign | `collection(=attr1=val1, attr2=val2, ...)` | Bulk modify object attributes | Same collection (modified) |

**Basic Filter Comprehension**

Line 46 demonstrates the fundamental syntax: `filtered = items(?x >= 10, y < 15);`

The components are:
- `items` - The collection to filter
- `?` - Filter operator
- `x >= 10, y < 15` - Conditions (both must be true)
- Conditions reference object attributes directly without prefixes

Filter semantics:
1. For each object in the collection
2. Evaluate ALL conditions against that object's attributes
3. Include object only if ALL conditions are True (AND logic)
4. Return new filtered collection

Line 47 shows the result: filtering 10 items down to those where both `x >= 10` AND `y < 15`.

**Single Condition Filter**

Line 50 shows filtering with one condition: `high_x = items(?x > 15);`

Even with a single condition, the `?` operator is required. This finds all items where the `x` attribute exceeds 15.

**Multiple Conditions (AND Logic)**

Line 54 demonstrates multi-condition filtering: `complex_filter = items(?x >= 5, x <= 15, y > 10);`

All three conditions must be satisfied:
- `x >= 5` - Lower bound on x
- `x <= 15` - Upper bound on x
- `y > 10` - Constraint on y

Objects are included only when ALL conditions pass. This implements conjunction (AND). For OR logic, use multiple filter calls or combine results.

**Comparison Operators**

Lines 158-167 demonstrate all available operators:

| Operator | Example | Meaning |
|----------|---------|---------|
| `==` | `(?x == 5)` | Attribute equals value |
| `!=` | `(?x != 5)` | Attribute not equals value |
| `>` | `(?x > 5)` | Attribute greater than value |
| `>=` | `(?x >= 5)` | Attribute greater than or equal |
| `<` | `(?x < 5)` | Attribute less than value |
| `<=` | `(?x <= 5)` | Attribute less than or equal |

**Basic Assign Comprehension**

Lines 64-65 demonstrate attribute assignment: `objs(=y=100, z=200);`

The syntax pattern is:
- `objs` - Collection to modify
- `=` prefix - Indicates assign comprehension
- `y=100, z=200` - Attribute assignments (comma-separated)

Assign semantics:
1. For each object in the collection
2. Set each specified attribute to its value
3. Mutations occur in-place on original objects
4. Return the collection (now modified)

Line 65 confirms this is a mutating operation - the original objects are changed.

**Chained Filter and Assign**

Line 76 demonstrates powerful composition: `people(?age >= 30)(=score=95);`

Execution flow:
1. `people(?age >= 30)` - Filter people with age >= 30
2. Returns filtered subset (Bob and Charlie)
3. `(=score=95)` - Assign score=95 to filtered objects
4. Only filtered objects are modified

Lines 78-80 show results: only Bob and Charlie (age >= 30) have scores updated to 95, while Alice (age 25) retains her original score of 80. This enables selective bulk updates: "find all X matching condition, then update them."

**Multiple Chained Filters**

Line 85 shows sequential filtering: `result = data(?x > 2)(?y < 15)(?z >= 6);`

Each filter narrows results:
1. `(?x > 2)` - First filter
2. `(?y < 15)` - Applied to previous result
3. `(?z >= 6)` - Final filter on remaining items

Order matters - each filter receives output of the previous filter. Line 86 shows the progressive reduction from 10 items to the final filtered count.

**Filter on Edge Traversal Results**

Lines 115-117 demonstrate the critical spatial programming pattern. This is where comprehensions become essential for OSP:
- `[-->]` traverses outgoing edges, returns target nodes
- Result is a collection of nodes (Employee objects)
- `(?salary > 75000)` filters nodes by attribute
- Enables declarative spatial queries

```mermaid
graph LR
    A[Current Node] -->|[--&gt;]| B[Get Connected Nodes]
    B --> C[Filter by Attributes]
    C --> D[Filtered Node Collection]
```

**Typed Edge with Node Filter**

Lines 121-123 combine edge type filtering with node attribute filtering. Workflow:
- `[->:ReportsTo:->]` - Traverse only ReportsTo-typed edges
- Returns nodes connected via those specific edges
- `(?department == "Engineering")` - Filter nodes by attribute

This dual-level filtering (structural + property) is a hallmark of Jac's spatial model.

**Assign on Edge Results**

Lines 129-130 demonstrate spatial bulk updates. Pattern:
1. Get nodes via edge traversal: `[-->]`
2. Modify all retrieved nodes in bulk

This enables graph-wide updates: traverse to find nodes, then update them. Common for propagating changes through graph structures.

**Complete Spatial Pattern**

Lines 137-141 show the quintessential three-step pattern. This can be written as one expression: `[-->](?salary >= 75000)(=salary=90000);`

The pattern is: navigate, filter, act.

**Empty Collection Handling**

Lines 177-180 show edge cases. Both comprehensions handle empty collections gracefully without errors.

**Return Value Semantics**

Lines 184-190 clarify return behavior:

| Type | Behavior | Example |
|------|----------|---------|
| Filter | Returns NEW collection (subset) | `filtered = original(?x > 0)` |
| Assign | Returns SAME collection (modified) | `assigned = original(=y=50)` |

After assign, `original[0].y` is 50 - the original objects were mutated, not copied.

**Comprehension Composition Patterns**

Supported composition patterns based on the examples:

| Pattern | Syntax | Use Case |
|---------|--------|----------|
| Filter → Filter | `coll(?c1)(?c2)` | Sequential filtering |
| Filter → Assign | `coll(?cond)(=attr=val)` | Filter then modify |
| Edge → Filter | `[-->](?cond)` | Spatial query |
| Edge → Filter → Assign | `[-->](?cond)(=attr=val)` | Complete spatial update |

**Comparison with Python**

Traditional Python list comprehension:

Jac filter comprehension:

Differences:
- Jac: More concise, no explicit iteration
- Jac: Direct attribute access (no `obj.` prefix)
- Jac: Integrates seamlessly with edge traversal
- Jac: Special assign syntax for bulk updates

For assignment, Python requires explicit loop:

Jac:

**Use Cases**

Filter comprehensions excel at:
- Finding specific nodes: `[-->](?dept=="Engineering")`
- Graph queries: "find all X connected to Y where Z"
- Selecting subsets: `candidates(?score > threshold)`
- Filtering walker targets: `visit [-->](?active==True);`

Assign comprehensions excel at:
- Bulk state updates: `affected_nodes(=processed=True)`
- Initialization: `new_nodes(=status="pending", priority=0)`
- Propagating changes: `downstream(=needs_update=True)`
- Resetting attributes: `session_nodes(=active=False)`

**Performance Considerations**

- Filter creates new collections (allocation cost)
- Assign mutates in-place (no allocation)
- Each chained comprehension iterates the collection
- Minimize chaining: `coll(?a, b, c)` better than `coll(?a)(?b)(?c)`
- Edge traversal + filter optimized in runtime

**Integration with Object-Spatial Programming**

Special comprehensions are designed for Jac's spatial model:

1. Edge traversal returns collections
2. Comprehensions filter/modify collections
3. Natural composition creates fluent API

Example: `visit [->:Friend:->](?age > 25, score > 80)(=notified=True);`

Meaning: "Visit friends over age 25 with score over 80, mark them as notified"

This makes Jac particularly expressive for graph-based computation and declarative spatial queries.
