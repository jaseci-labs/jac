# Jac Library Mode

> **Part of:** [Part IX: Deployment](../plugins/jac-scale.md)
>
> **Related:** [Python Integration](python-integration.md) | [Part III: OSP](osp.md)

---

## **Introduction**

Jac provides a library mode that enables developers to express all Jac language features as standard Python code. This mode provides complete access to Jac's object-spatial programming capabilities through the `jaclang.lib` package, allowing developers to work entirely within Python syntax.

This page focuses on what is unique to library mode: the `jaclang.lib` API surface and the `jac jac2py` workflow. For how Jac compiles to and interoperates with Python in general (bytecode transpilation, bidirectional imports, type-only imports), see [Python Integration](python-integration.md#jac-compiles-to-python-bytecode). Library mode itself corresponds to adoption [Pattern 5: Pure Python + Jac Library](python-integration.md#pattern-5-pure-python-jac-library).

Library mode is designed for:

- **Python-first teams** wanting to adopt Jac's graph-native and AI capabilities without learning new syntax
- **Existing Python codebases** that need object-spatial architectures and AI integration with zero migration friction
- **Understanding Jac's architecture** by exploring how its transpilation to Python works under the hood
- **Enterprise and corporate environments** where introducing standard Python libraries is more acceptable than adopting new language syntax

!!! note "`root` is a function in library mode"
    In `.jac` source, `root` is a reserved keyword and writing `root()` emits warning **W0062** (deprecated; use bare `root`). In **library mode**, `root` is a Python function imported from `jaclang.lib`, so it **must** be called as `root()` -- the bare reference is just the function object. The same applies to other graph builtins (`spawn`, `connect`, `get_all_root`). The deprecation in [breaking-changes.md](../../community/breaking-changes.md#1-root-is-a-reserved-keyword-again-specialvarref) only governs `.jac` source.

### **Converting Jac Code to Pure Python**

The `jac jac2py` command transpiles Jac source files into equivalent Python code, emitting clean `jaclang.lib` imports with type hints and docstrings so the output works with standard Python IDEs, linters, and formatters. (The same transpilation pipeline underpins all Jac→Python compilation -- see [How it Works: Transpilation to Native Python](python-integration.md#how-it-works-transpilation-to-native-python).)

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

    can move_to_person with Root entry {
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

??? example "Generated Python code"
    ```python
    from **future** import annotations
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

!!! note
    The transpiler outputs `from jaclang.jac0core.jaclib import ...` internally; the public `jaclang.lib` re-exports the same symbols and is the recommended import path. See [Python Integration](python-integration.md#how-it-works-transpilation-to-native-python).

---

## **Key Concepts Explained**

The mappings below show how each Jac construct is expressed against the `jaclang.lib` API. This is the inverse of the general transpilation reference in [Python Integration](python-integration.md#jac-compiles-to-python-bytecode) -- here the focus is the hand-written library-mode form, not the compiler output.

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

Subclass `Node` for graph nodes and `Edge` for relationships; declare data fields as standard typed class attributes.

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

Subclass `Walker` for traversal agents that navigate the graph and run logic at each visited node or edge.

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

`@on_entry`/`@on_exit` mark methods that run when a walker enters or exits a node or edge. `here` is the current node/edge; `visitor` (in node/edge abilities) is the traversing walker.

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

`connect()` creates directed edges; `edge` names the edge class (generic if omitted), and `right` accepts a single node or a list.

### **5. Spawning Walkers**

**In Jac:**

```jac
walker FriendFinder {
    can find with Root entry {
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

`spawn()` starts a walker at a node and returns the walker after traversal; `root()` returns the current graph's root node.

### **6. Visiting Nodes**

**In Jac:**

```jac
edge Family {}

walker Visitor {
    can traverse with Root entry {
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

`OPath(node)` builds a traversal path: `edge_out()`/`edge_in()` select direction, `edge()` keeps edges only (no destination nodes), and `visit()` marks the path; `refs()` resolves it to concrete node/edge references for `visit()`.

---

## **Complete Library Interface Reference**

!!! warning "API Scope Notice"
    The following reference includes both public API functions available via `from jaclang.lib import ...` and internal runtime functions that may not be directly importable. Core functions available for import include: `connect`, `disconnect`, `spawn`, `root`, `node`, `edge`, `walker`, `obj`, `Anchor`, `NodeAnchor`, `EdgeAnchor`, `WalkerAnchor`, `Root`. Other functions listed below may be internal to the runtime and subject to change.

### **Type Aliases & Constants**

| Name | Type | Description |
|------|------|-------------|
| `TYPE_CHECKING` | bool | Python typing constant; guards type-only references to break circular imports (see [Type-Only Imports](python-integration.md#type-only-imports)). |
| `EdgeDir` | Enum | Edge direction enum (IN, OUT, ANY) |
| `DSFunc` | Type | Object spatial function type alias |

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
| `by_operator(model)` | Decorator for LLM-powered functions | `@by_operator(model) def func(): ...` |
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

Standard Python hygiene applies: annotate fields for IDE support, and import only the `jaclang.lib` names you use (avoid `from jaclang.lib import *`). The patterns below are specific to library-mode object-spatial code.

### **1. Walker State**

Keep walker state minimal and immutable when possible:

```python
class Counter(Walker):
    count: int = 0  # Simple state

    @on_entry
    def increment(self, here: Node) -> None:
        self.count += 1
```

### **2. Path Filtering**

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

> The full Jac syntax → library-mode mapping is covered in [Key Concepts Explained](#key-concepts-explained) above. For the general Jac↔Python interop story (importing `.jac` files, inline Python, type compatibility), see [Python Integration](python-integration.md#seamless-interoperability-import-jac-files-like-python-modules).

---

## **Summary**

Library mode provides a pure Python implementation of Jac's object-spatial programming model through the `jaclang.lib` package, distinguished by:

- **Complete Feature Parity**: All Jac language features are accessible through the library interface
- **Idiomatic Python**: Standard Python classes, decorators, and functions with full tooling support (type hints, IDE autocomplete, static analysis)
- **Zero-Friction Integration**: Drop into existing Python projects with no build-system changes

Use it when you want Jac's graph-native and AI-integrated programming model while staying entirely in Python syntax.
