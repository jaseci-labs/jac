# Graph Operations Reference

This reference covers the core graph operations in Jac for creating, connecting, traversing, and deleting nodes.

> **Related:**
>
> - [Walker Responses](walker-responses.md) - Understanding `.reports` and response handling
> - [Part III: OSP](osp.md) - Walker and node fundamentals
> - [Build a Todo App](../../tutorials/fullstack/todo-app.md) - Full tutorial using these patterns

---

## Node Creation and Connection

### Create and Connect (`++>`)

The `++>` operator creates a new node and connects it to the source node:

```jac
node Todo {
    has id: str;
    has title: str;
    has completed: bool = False;
}

walker CreateTodo {
    can create with Root entry {
        # Create a Todo node and connect it to the current node (here)
        new_node = here ++> Todo(
            id="123",
            title="Buy groceries",
            completed=False
        );

        # The result is a list containing the new node
        created_todo = new_node[0];
        report created_todo;
    }
}
```

**Key points:**

- Returns a **list** containing the created node(s)
- Access the node with `[0]` index
- The new node is automatically connected to `here` with an edge
- Works with any node type

### Connect Existing Nodes

```jac
node MyNode {
    has name: str;
}

edge EdgeType {}

with entry {
    node_a = MyNode(name="A");
    node_b = MyNode(name="B");

    # Connect two existing nodes
    node_a ++> node_b;

    # Connect with edge type
    node_a +>: EdgeType() :+> node_b;
}
```

## Node Traversal

### Visit Outgoing Edges (`[-->]`)

```jac
can traverse with Root entry {
    visit [-->];  # Visit all nodes connected by outgoing edges
}
```

### Visit Incoming Edges (`[<--]`)

```jac
can traverse with SomeNode entry {
    visit [<--];  # Visit all nodes with incoming edges to here
}
```

### Visit Both Directions (`[<-->]`)

```jac
can traverse with SomeNode entry {
    visit [<-->];  # Visit all connected nodes regardless of direction
}
```

### Visit with Edge Type Filter

```jac
edge MyEdgeType {
    has weight: int = 0;
}

walker FilteredTraversal {
    can traverse with Root entry {
        # Only visit nodes connected by a specific edge type
        visit [->:MyEdgeType:->];
    }

    can traverse_weighted with Root entry {
        # Visit with edge condition
        visit [->:MyEdgeType:weight > 10:->];
    }
}
```

## Context Keywords

### `here` - Current Node

`here` refers to the node the walker is currently visiting:

```jac
can process with Todo entry {
    # Read properties
    print(here.title);
    print(here.completed);

    # Modify properties
    here.completed = True;
    here.title = "Updated title";
}
```

### `self` - Walker Instance

`self` refers to the walker itself:

```jac
walker:priv MyWalker {
    has search_term: str;
    has results: list = [];

    can search with Item entry {
        if self.search_term in here.name {
            self.results.append(here);
        }
    }
}
```

### `root` - User's Root Node

`root` is the entry point for the user's graph:

```jac
node SomeNode {}

walker MyWalker {
    can work with Root entry {
        report "done";
    }
}

walker GetRootData {
    can get with Root entry {
        report "root data";
    }
}

walker ProcessNode {
    # In a walker, access root explicitly
    can process with SomeNode entry {
        root_data = root spawn GetRootData();
    }
}

with entry {
    # Spawn a walker from root
    result = root spawn MyWalker();
}
```

## Node Deletion

### Delete Current Node (`del here`)

```jac
can delete_if_done with Todo entry {
    if here.completed {
        node_id = here.id;  # Capture ID before deletion
        del here;  # Remove this node from the graph
        report {"deleted": node_id};
    }
}
```

### Cascade Deletion Pattern

Delete a node and all its related nodes:

```jac
walker:priv DeleteWithChildren {
    has parent_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete with Todo entry {
        # Delete if this is the target or a child of the target
        if here.id == self.parent_id or here.parent_id == self.parent_id {
            del here;
        }
    }
}
```

## Walker Entry/Exit Points

### Entry Points

```jac
walker:priv MyWalker {
    # Runs when entering the root node
    can on_root with Root entry {
        visit [-->];
    }

    # Runs when entering any Todo node
    can on_todo with Todo entry {
        process(here);
    }

    # Runs when entering any node (generic)
    can on_any with entry {
        log("Visited a node");
    }
}
```

### Exit Points

```jac
walker:priv MyWalker {
    has collected: list = [];

    can collect with Item entry {
        self.collected.append(here.data);
    }

    # Runs when exiting root (after all traversal complete)
    can finish with Root exit {
        report self.collected;
    }

    # Runs when exiting any node
    can leaving with exit {
        log("Left a node");
    }
}
```

## Common Graph Patterns

### Pattern 1: CRUD Walker

```jac
# Create
walker:priv CreateItem {
    has name: str;
    can create with Root entry {
        new_item = here ++> Item(name=self.name);
        report new_item[0];
    }
}

# Read (List)
walker:priv ListItems {
    has items: list = [];
    can collect with Root entry { visit [-->]; }
    can gather with Item entry { self.items.append(here); }
    can finish with Root exit { report self.items; }
}

# Update
walker:priv UpdateItem {
    has item_id: str;
    has new_name: str;
    can find with Root entry { visit [-->]; }
    can update with Item entry {
        if here.id == self.item_id {
            here.name = self.new_name;
            report here;
        }
    }
}

# Delete
walker:priv DeleteItem {
    has item_id: str;
    can find with Root entry { visit [-->]; }
    can remove with Item entry {
        if here.id == self.item_id {
            del here;
            report {"deleted": self.item_id};
        }
    }
}
```

### Pattern 2: Search Walker

```jac
node Item {
    has id: str;
    has name: str;
}

def calculate_relevance(item: Item, query: str) -> int {
    return 1;
}

walker:priv SearchItems {
    has query: str;
    has matches: list = [];

    can start with Root entry {
        visit [-->];
    }

    can check with Item entry {
        if self.query.lower() in here.name.lower() {
            self.matches.append({
                "id": here.id,
                "name": here.name,
                "score": calculate_relevance(here, self.query)
            });
        }
    }

    can finish with Root exit {
        # Sort by relevance
        self.matches.sort(key=lambda x: any: x["score"], reverse=True);
        report self.matches;
    }
}
```

### Pattern 3: Hierarchical Traversal

```
walker:priv GetTree {
    can build_tree(node: any) -> dict {
        children = [];
        for child in [node -->] {
            children.append(self.build_tree(child));
        }
        return {
            "id": node.id,
            "name": node.name,
            "children": children
        };
    }

    can start with Root entry {
        tree = self.build_tree(here);
        report tree;
    }
}
```

### Pattern 4: Aggregate Walker

```jac
walker:priv GetStats {
    has total: int = 0;
    has completed: int = 0;

    can count with Root entry {
        visit [-->];
    }

    can tally with Todo entry {
        self.total += 1;
        if here.completed {
            self.completed += 1;
        }
    }

    can summarize with Root exit {
        report {
            "total": self.total,
            "completed": self.completed,
            "pending": self.total - self.completed,
            "completion_rate": (self.completed / self.total * 100) if self.total > 0 else 0
        };
    }
}
```

## Edge Operations

### Define Edge Types

```jac
edge Owns {
    has since: str;
}

edge ChildOf {
    has order: int = 0;
}
```

### Create Typed Edges

```jac
node Todo {
    has id: str;
    has title: str;
}

edge ChildOf {
    has order: int = 0;
}

walker ProcessWithEdge {
    can setup with Root entry {
        parent = here ++> Todo(id="1", title="Parent");
        child = here ++> Todo(id="2", title="Child");
        # Connect with edge type and data
        parent[0] +>: ChildOf(order=1) :+> child[0];
    }

    # Access edge data during traversal
    can process with Todo entry {
        # Access via edges in traversal filter
        print(f"Processing Todo: {here.title}");
    }
}
```

## Best Practices

1. **Use specific entry points** - `with Todo entry` is more efficient than generic `with entry`
2. **Accumulate then report** - Collect data during traversal, report once at exit
3. **Handle empty graphs** - Always check if traversal found anything
4. **Use meaningful node types** - Makes code self-documenting
5. **Keep walkers focused** - One walker, one responsibility
