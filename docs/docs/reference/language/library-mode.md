# Jac Library Mode

> **Part of:** [Part IX: Deployment](deployment.md)
>
> **Related:** [Python Integration](python-integration.md) | [Part III: OSP](osp.md)

---

## **Introduction**

Jac provides a library mode that enables developers to express all Jac language features as standard Python code. This mode provides complete access to Jac's object-spatial programming capabilities through the `jaclang.lib` package, allowing developers to work entirely within Python syntax.

Library mode is designed for:

- **Python-first teams** wanting to adopt Jac's graph-native and AI capabilities without learning new syntax
- **Existing Python codebases** that need object-spatial architectures and AI integration with zero migration friction
- **Understanding Jac's architecture** by exploring how its transpilation to Python works under the hood
- **Enterprise and corporate environments** where introducing standard Python libraries is more acceptable than adopting new language syntax

### **Converting Jac Code to Pure Python**

The `jac jac2py` command transpiles Jac source files into equivalent Python code. The generated output:

1. Provides clean, ergonomic imports from `jaclang.lib` with full IDE autocomplete support
2. Generates idiomatic Python code with proper type hints and docstrings
3. Ensures full compatibility with Python tooling, linters, formatters, and static analyzers

---

## **The Friends Network Example**

This section demonstrates Jac's object-spatial programming model through a complete example implementation in library mode.

### **The Jac Code**

The following example implements a social network graph with person nodes connected by friendship and family relationship edges:

```jac
node Person {
    has name: str;

    can announce with FriendFinder entry {
        print(f"{visitor} is checking me out");
    }
}

edge Friend {}
edge Family {
    can announce with FriendFinder entry {
        print(f"{visitor} is traveling to family member");
    }
}

with entry {
    # Build the graph
    p1 = Person(name="John");
    p2 = Person(name="Susan");
    p3 = Person(name="Mike");
    p4 = Person(name="Alice");
    root ++> p1;
    p1 +>: Friend :+> p2;
    p2 +>: Family :+> [p1, p3];
    p2 +>: Friend :+> p3;
}

walker FriendFinder {
    has started: bool = False;

    can report_friend with Person entry {
        if self.started {
            print(f"{here.name} is a friend of friend, or family");
        } else {
            self.started = True;
            visit [-->];
        }
        visit [edge ->:Family :->];
    }

    can move_to_person with `root entry {
        visit [-->];
    }
}

with entry {
    result = FriendFinder() spawn root;
    print(result);
}
```

### **The Library Mode Python Equivalent**

Run `jac jac2py friends.jac` to generate:

```python
from __future__ import annotations
from jaclang.lib import (
    Edge,
    Node,
    OPath,
    Root,
    Walker,
    build_edge,
    connect,
    on_entry,
    refs,
    root,
    spawn,
    visit,
)


class Person(Node):
    name: str

    @on_entry
    def announce(self, visitor: FriendFinder) -> None:
        print(f"{visitor} is checking me out")


class Friend(Edge):
    pass


class Family(Edge):

    @on_entry
    def announce(self, visitor: FriendFinder) -> None:
        print(f"{visitor} is traveling to family member")


# Build the graph
p1 = Person(name="John")
p2 = Person(name="Susan")
p3 = Person(name="Mike")
p4 = Person(name="Alice")
connect(left=root(), right=p1)
connect(left=p1, right=p2, edge=Friend)
connect(left=p2, right=[p1, p3], edge=Family)
connect(left=p2, right=p3, edge=Friend)


class FriendFinder(Walker):
    started: bool = False

    @on_entry
    def report_friend(self, here: Person) -> None:
        if self.started:
            print(f"{here.name} is a friend of friend, or family")
        else:
            self.started = True
            visit(self, refs(OPath(here).edge_out().visit()))
        visit(
            self,
            refs(
                OPath(here).edge_out(edge=lambda i: isinstance(i, Family)).edge().visit()
            ),
        )

    @on_entry
    def move_to_person(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))


result = spawn(FriendFinder(), root())
print(result)
```

---

## **Key Concepts Explained**

### **1. Nodes and Edges**

**In Jac:**

```jac
node Person {
    has name: str;
}

edge Friend {}
```

**In Library Mode:**

```python
from jaclang.lib import Node, Edge


class Person(Node):
    name: str


class Friend(Edge):
    pass
```

Graph nodes are implemented by inheriting from the `Node` base class, while relationships between nodes inherit from the `Edge` base class. Data fields are defined using standard Python class attributes with type annotations.

### **2. Walkers**

**In Jac:**

```jac
walker FriendFinder {
    has started: bool = False;
}
```

**In Library Mode:**

```python
from jaclang.lib import Walker


class FriendFinder(Walker):
    started: bool = False
```

Walkers are graph traversal agents implemented by inheriting from the `Walker` base class. Walkers navigate through the graph structure and execute logic at each visited node or edge.

### **3. Abilities (Event Handlers)**

**In Jac:**

```jac
can report_friend with Person entry {
    print(f"{here.name} is a friend");
}
```

**In Library Mode:**

```python
from jaclang.lib import on_entry


@on_entry
def report_friend(self, here: Person) -> None:
    print(f"{here.name} is a friend")
```

Abilities define event handlers that execute when a walker interacts with nodes or edges. The `@on_entry` decorator marks methods that execute when a walker enters a node or edge, while `@on_exit` marks exit handlers. The `here` parameter represents the current node or edge being visited, and the `visitor` parameter (in node/edge abilities) represents the traversing walker.

### **4. Connecting Nodes**

**In Jac:**

```jac
node Person {
    has name: str;
}

edge Friend {}
edge Family {}

with entry {
    p1 = Person(name="John");
    p2 = Person(name="Susan");
    p3 = Person(name="Mike");
    root ++> p1;                      # Connect root to p1
    p1 +>: Friend :+> p2;             # Connect p1 to p2 with Friend edge
    p2 +>: Family :+> [p1, p3];       # Connect p2 to multiple nodes
}
```

**In Library Mode:**

```python
from jaclang.lib import connect, root

connect(left=root(), right=p1)
connect(left=p1, right=p2, edge=Friend)
connect(left=p2, right=[p1, p3], edge=Family)
```

The `connect()` function creates directed edges between nodes. The `edge` parameter specifies the edge type class, defaulting to a generic edge if omitted. The function supports connecting a single source node to either a single target node or a list of target nodes.

### **5. Spawning Walkers**

**In Jac:**

```jac
walker FriendFinder {
    can find with `root entry {
        visit [-->];
    }
}

with entry {
    result = FriendFinder() spawn root;
}
```

**In Library Mode:**

```python
from jaclang.lib import spawn, root

result = spawn(FriendFinder(), root())
```

The `spawn()` function initiates a walker at a specified node and begins traversal. The `root()` function returns the root node of the current graph. The `spawn()` function returns the walker instance after traversal completion.

### **6. Visiting Nodes**

**In Jac:**

```jac
edge Family {}

walker Visitor {
    can traverse with `root entry {
        visit [-->];                      # Visit all outgoing edges
        visit [->:Family:->];             # Visit only Family edges
    }
}
```

**In Library Mode:**

```python
from jaclang.lib import visit, refs, OPath

visit(self, refs(OPath(here).edge_out().visit()))
visit(
    self, refs(OPath(here).edge_out(edge=lambda i: isinstance(i, Family)).edge().visit())
)
```

The `OPath()` class constructs traversal paths from a given node. The `edge_out()` method specifies outgoing edges to follow, while `edge_in()` specifies incoming edges. The `edge()` method filters the path to include only edges, excluding destination nodes. The `visit()` method marks the constructed path for the walker to traverse, and `refs()` converts the path into concrete node or edge references.

---

## **Complete Library Interface Reference**

### **Type Aliases & Constants**

| Name | Type | Description |
|------|------|-------------|
| `TYPE_CHECKING` | bool | Python typing constant for type checking blocks |
| `EdgeDir` | Enum | Edge direction enum (IN, OUT, ANY) |
| `DSFunc` | Type | Data spatial function type alias |

### **Base Classes**

| Class | Description | Usage |
|-------|-------------|-------|
| `Obj` | Base class for all archetypes | Generic archetype base |
| `Node` | Graph node archetype | `class MyNode(Node):` |
| `Edge` | Graph edge archetype | `class MyEdge(Edge):` |
| `Walker` | Graph traversal agent | `class MyWalker(Walker):` |
| `Root` | Root node type | Entry point for graphs |
| `GenericEdge` | Generic edge when no type specified | Default edge type |
| `OPath` | Object-spatial path builder | `OPath(node).edge_out()` |

### **Decorators**

| Decorator | Description | Usage |
|-----------|-------------|-------|
| `@on_entry` | Entry ability decorator | Executes when walker enters node/edge |
| `@on_exit` | Exit ability decorator | Executes when walker exits node/edge |
| `@sem(doc, fields)` | Semantic string decorator | AI/LLM integration metadata |

### **Graph Construction**

| Function | Description | Parameters |
|----------|-------------|------------|
| `connect(left, right, edge, undir, conn_assign, edges_only)` | Connect nodes with edge | `left`: source node(s)<br>`right`: target node(s)<br>`edge`: edge class (optional)<br>`undir`: undirected flag<br>`conn_assign`: attribute assignments<br>`edges_only`: return edges instead of nodes |
| `disconnect(left, right, dir, filter)` | Remove edges between nodes | `left`: source node(s)<br>`right`: target node(s)<br>`dir`: edge direction<br>`filter`: edge filter function |
| `build_edge(is_undirected, conn_type, conn_assign)` | Create edge builder function | `is_undirected`: bidirectional flag<br>`conn_type`: edge class<br>`conn_assign`: initial attributes |
| `assign_all(target, attr_val)` | Assign attributes to list of objects | `target`: list of objects<br>`attr_val`: tuple of (attrs, values) |

### **Graph Traversal & Walker Operations**

| Function | Description | Parameters |
|----------|-------------|------------|
| `spawn(walker, node)` | Start walker at node | `walker`: Walker instance<br>`node`: Starting node |
| `spawn_call(walker, node)` | Internal spawn execution (sync) | `walker`: Walker anchor<br>`node`: Node/edge anchor |
| `async_spawn_call(walker, node)` | Internal spawn execution (async) | Same as spawn_call (async version) |
| `visit(walker, nodes)` | Visit specified nodes | `walker`: Walker instance<br>`nodes`: Node/edge references |
| `disengage(walker)` | Stop walker traversal | `walker`: Walker to stop |
| `refs(path)` | Convert path to node/edge references | `path`: ObjectSpatialPath |
| `arefs(path)` | Async path references (placeholder) | `path`: ObjectSpatialPath |
| `filter_on(items, func)` | Filter archetype list by predicate | `items`: list of archetypes<br>`func`: filter function |

### **Path Building (Methods on OPath class)**

| Method | Description | Returns |
|--------|-------------|---------|
| `OPath(node)` | Create path from node | ObjectSpatialPath |
| `.edge_out(edge, node)` | Filter outgoing edges | Self (chainable) |
| `.edge_in(edge, node)` | Filter incoming edges | Self (chainable) |
| `.edge_any(edge, node)` | Filter any direction | Self (chainable) |
| `.edge()` | Edges only (no nodes) | Self (chainable) |
| `.visit()` | Mark for visit traversal | Self (chainable) |

### **Node & Edge Operations**

| Function | Description | Parameters |
|----------|-------------|------------|
| `get_edges(origin, destination)` | Get edges connected to nodes | `origin`: list of nodes<br>`destination`: ObjectSpatialDestination |
| `get_edges_with_node(origin, destination, from_visit)` | Get edges and connected nodes | `origin`: list of nodes<br>`destination`: destination spec<br>`from_visit`: include nodes flag |
| `edges_to_nodes(origin, destination)` | Get nodes connected via edges | `origin`: list of nodes<br>`destination`: destination spec |
| `remove_edge(node, edge)` | Remove edge reference from node | `node`: NodeAnchor<br>`edge`: EdgeAnchor |
| `detach(edge)` | Detach edge from both nodes | `edge`: EdgeAnchor |

### **Data Access & Persistence**

| Function | Description | Returns |
|----------|-------------|---------|
| `root()` | Get current root node | Root node instance |
| `get_all_root()` | Get all root nodes | List of roots |
| `get_object(id)` | Get archetype by ID string | Archetype or None |
| `object_ref(obj)` | Get hex ID string of archetype | String |
| `save(obj)` | Persist archetype to database | None |
| `destroy(objs)` | Delete archetype(s) from memory | None |
| `commit(anchor)` | Commit data to datasource | None |
| `reset_graph(root)` | Purge graph from memory | Count of deleted items |

### **Access Control & Permissions**

| Function | Description | Parameters |
|----------|-------------|------------|
| `perm_grant(archetype, level)` | Grant public access to archetype | `archetype`: Target archetype<br>`level`: AccessLevel (READ/CONNECT/WRITE) |
| `perm_revoke(archetype)` | Revoke public access | `archetype`: Target archetype |
| `allow_root(archetype, root_id, level)` | Allow specific root access | `archetype`: Target<br>`root_id`: Root UUID<br>`level`: Access level |
| `disallow_root(archetype, root_id, level)` | Disallow specific root access | Same as allow_root |
| `check_read_access(anchor)` | Check read permission | `anchor`: Target anchor |
| `check_write_access(anchor)` | Check write permission | `anchor`: Target anchor |
| `check_connect_access(anchor)` | Check connect permission | `anchor`: Target anchor |
| `check_access_level(anchor, no_custom)` | Get access level for anchor | `anchor`: Target<br>`no_custom`: skip custom check |

### **Module Management & Archetypes**

| Function | Description | Parameters |
|----------|-------------|------------|
| `jac_import(target, base_path, ...)` | Import Jac/Python module | `target`: Module name<br>`base_path`: Search path<br>`absorb`, `mdl_alias`, `override_name`, `items`, `reload_module`, `lng`: import options |
| `load_module(module_name, module, force)` | Load module into machine | `module_name`: Name<br>`module`: Module object<br>`force`: reload flag |
| `attach_program(program)` | Attach JacProgram to runtime | `program`: JacProgram instance |
| `list_modules()` | List all loaded modules | Returns list of names |
| `list_nodes(module_name)` | List nodes in module | `module_name`: Module to inspect |
| `list_walkers(module_name)` | List walkers in module | `module_name`: Module to inspect |
| `list_edges(module_name)` | List edges in module | `module_name`: Module to inspect |
| `get_archetype(module_name, archetype_name)` | Get archetype class from module | `module_name`: Module<br>`archetype_name`: Class name |
| `make_archetype(cls)` | Convert class to archetype | `cls`: Class to convert |
| `spawn_node(node_name, attributes, module_name)` | Create node instance by name | `node_name`: Node class name<br>`attributes`: Init dict<br>`module_name`: Source module |
| `spawn_walker(walker_name, attributes, module_name)` | Create walker instance by name | `walker_name`: Walker class<br>`attributes`: Init dict<br>`module_name`: Source module |
| `update_walker(module_name, items)` | Reload walker from module | `module_name`: Module<br>`items`: Items to update |
| `create_archetype_from_source(source_code, ...)` | Create archetype from Jac source | `source_code`: Jac code string<br>`module_name`, `base_path`, `cachable`, `keep_temporary_files`: options |

### **Testing & Debugging**

| Function | Description | Parameters |
|----------|-------------|------------|
| `jac_test(func)` | Mark function as test | `func`: Test function |
| `run_test(filepath, ...)` | Run test suite | `filepath`: Test file<br>`func_name`, `filter`, `xit`, `maxfail`, `directory`, `verbose`: test options |
| `report(expr, custom)` | Report value from walker | `expr`: Value to report<br>`custom`: custom report flag |
| `printgraph(node, depth, traverse, edge_type, bfs, edge_limit, node_limit, file, format)` | Generate graph visualization | `node`: Start node<br>`depth`: Max depth<br>`traverse`: traversal flag<br>`edge_type`: filter edges<br>`bfs`: breadth-first flag<br>`edge_limit`, `node_limit`: limits<br>`file`: output path<br>`format`: 'dot' or 'mermaid' |

### **LLM & AI Integration**

| Function | Description | Use Case |
|----------|-------------|----------|
| `by(model)` | Decorator for LLM-powered functions | `@by(model) def func(): ...` |
| `call_llm(model, mtir)` | Direct LLM invocation | Advanced LLM usage |
| `get_mtir(caller, args, call_params)` | Get method IR for LLM | LLM internal representation |
| `sem(semstr, inner_semstr)` | Semantic metadata decorator | `@sem("doc", {"field": "desc"})` |

### **Runtime & Threading**

| Function | Description | Parameters |
|----------|-------------|------------|
| `setup()` | Initialize class references | No parameters |
| `get_context()` | Get current execution context | Returns ExecutionContext |
| `field(factory, init)` | Define dataclass field | `factory`: Default factory<br>`init`: Include in init |
| `impl_patch_filename(file_loc)` | Patch function file location | `file_loc`: File path for stack traces |
| `thread_run(func, *args)` | Run function in thread | `func`: Function<br>`args`: Arguments |
| `thread_wait(future)` | Wait for thread completion | `future`: Future object |
| `create_cmd()` | Create CLI commands | No parameters (placeholder) |

---

## **Best Practices**

### **1. Type Hints**

Always use type hints for better IDE support:

```python
from typing import Optional


class Person(Node):
    name: str
    age: Optional[int] = None
```

### **2. Walker State**

Keep walker state minimal and immutable when possible:

```python
class Counter(Walker):
    count: int = 0  # Simple state

    @on_entry
    def increment(self, here: Node) -> None:
        self.count += 1
```

### **3. Path Filtering**

Use lambda functions for flexible filtering:

```python
# Filter by edge type
visit(
    self,
    refs(OPath(here).edge_out(edge=lambda e: isinstance(e, (Friend, Family))).visit()),
)

# Filter by node attribute
visit(
    self,
    refs(OPath(here).edge_out(node=lambda n: hasattr(n, "active") and n.active).visit()),
)
```

### **4. Clean Imports**

Import only what you need:

```python
# Good
from jaclang.lib import Node, Walker, spawn, visit, on_entry

# Avoid
from jaclang.lib import *
```

---

## **Migration Guide**

### **From Jac to Library Mode**

| Jac Syntax | Library Mode Python |
|------------|---------------------|
| `node Person { has name: str; }` | `class Person(Node):`<br>&nbsp;&nbsp;&nbsp;&nbsp;`name: str` |
| `edge Friend {}` | `class Friend(Edge):`<br>&nbsp;&nbsp;&nbsp;&nbsp;`pass` |
| `walker W { has x: int; }` | `class W(Walker):`<br>&nbsp;&nbsp;&nbsp;&nbsp;`x: int` |
| `root ++> node` | `connect(root(), node)` |
| `a +>: Edge :+> b` | `connect(a, b, Edge)` |
| `W() spawn root` | `spawn(W(), root())` |
| `visit [-->]` | `visit(self, refs(OPath(here).edge_out().visit()))` |
| `visit [<--]` | `visit(self, refs(OPath(here).edge_in().visit()))` |
| `visit [--]` | `visit(self, refs(OPath(here).edge_any().visit()))` |
| `can f with T entry {}` | `@on_entry`<br>`def f(self, here: T): ...` |
| `disengage;` | `disengage(self)` |

---

## **Summary**

Library mode provides a pure Python implementation of Jac's object-spatial programming model through the `jaclang.lib` package. This approach offers several advantages:

- **Complete Feature Parity**: All Jac language features are accessible through the library interface
- **Idiomatic Python**: Implementation uses standard Python classes, decorators, and functions without runtime magic
- **Full Tooling Support**: Generated code includes proper type hints, enabling IDE autocomplete, static analysis, and debugging
- **Seamless Integration**: The library can be incorporated into existing Python projects without requiring build system modifications
- **Maintainable Output**: Transpiled code is readable and follows Python best practices

Library mode enables developers to leverage Jac's graph-native and AI-integrated programming model while maintaining full compatibility with the Python ecosystem and development workflow.
