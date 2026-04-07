# Object-Spatial Programming — Nodes, Edges, Walkers

## Node Definition

Nodes are data containers that live in the graph. Connected to `root`, they auto-persist (SQLite).

```jac
node Session {
    has id: str = "";
    has chat_history: list[dict] = [];

    def postinit {
        if not self.id { self.id = str(uuid4()); }
    }
}

node City {
    has name: str;
    has population: int = 0;
}
```

## Edge Definition

Edges define typed relationships between nodes.

```jac
edge Road {
    has distance: float = 0.0;
}

edge Knows {
    has since: int;
    has strength: float = 1.0;
}
```

## Graph Construction and Connection

```jac
# Connect with default edge
a ++> b;

# Connect with typed edge
alice +>:Knows(since=2020):+> bob;

# Create + connect in one step (returns list — use [0])
new_node = (here ++> Session(id="abc"))[0];

# Chain connections
root() ++> Router() ++> BuildHandler();

# Connect to root (auto-persists)
root() ++> City(name="NYC", population=8_300_000);
```

## Graph Querying

```jac
# Query all connected nodes of a type
sessions = [-->][?:Session];
cities = [root()-->][?:City];

# Query with filter condition
active = [-->][?:Session](?status == "active");
big_cities = [root()-->][?:City](?population > 1_000_000);

# Query by edge type
friends = [->:Knows:->];

# Chained query
handlers = [root()-->][?:Router]-->[?:BuildHandler];

# Delete edge
a del--> b;

# Delete node
del node;
```

## Walker Definition

Walkers traverse the graph and execute abilities on each visited node.

```jac
walker Explorer {
    has visited: list[str] = [];

    can visit_city with City entry {
        self.visited.append(here.name);
        print(f"Visiting {here.name}");
        visit [-->];           # continue to connected nodes
    }
}

# Spawn walker from root
result = root spawn Explorer();
```

## Walker Traversal Commands

```jac
visit [-->];                       # Visit all outgoing nodes
visit [-->][?:City];               # Visit only City nodes
visit [<--];                       # Back-traverse (incoming)
visit [-->][?:Router] else {       # Fallback if none found
    router = (here ++> Router())[0];
    visit router;
};

report {"data": value};            # Emit data from walker
disengage;                         # Stop walker entirely
```

## Context Keywords

| Keyword | Meaning | Used In |
|---------|---------|---------|
| `here` | Current node being visited | Walker abilities |
| `visitor` | The walker visiting this node | Node abilities |
| `self` | The archetype instance | Any method |
| `root` | Graph root node | Anywhere |

```jac
# Walker ability — here is the node, self is the walker
walker Collector {
    has items: list = [];
    can collect with DataNode entry {
        self.items.append(here.value);
        visit [-->];
    }
}

# Node ability — here is this node, visitor is the walker
node DataNode {
    has value: int;
    can respond with Collector entry {
        print(f"Walker has {len(visitor.items)} items");
    }
}
```

## disengage vs return

- `return` — exits current ability only. Walker continues to next queued node.
- `disengage` — stops walker entirely. No more traversal.

```jac
walker Search {
    has target: str;
    can check with Item entry {
        if here.name == self.target {
            report here;
            disengage;    # found it, stop everything
        }
        visit [-->];      # keep searching
    }
}
```

## Walker Spawn and Reports

```jac
# Spawn walker and get result
result = root spawn GetData();
data = result.reports[0];          # Access first reported value

# Walker that reports
walker GetData {
    can fetch with Root entry {
        items = [{"id": str(i.id)} for i in [-->][?:Item]];
        report {"items": items};
    }
}
```

## Lazy Graph Creation Pattern

```jac
visit [-->][?:Router] else {
    router = (here ++> Router())[0];
    visit router;
};
```

## Walker as REST Endpoint

```jac
walker :pub search_items {
    has query: str;
        static has as_query: list = ["query"];  # for GET params
    can find with Root entry {
        matches = [i for i in [-->][?:Item] if self.query in i.name];
        report {"results": matches};
    }
}
```

## Parent-Child Graph Patterns

```jac
node Category { has name: str; }
node Item { has title: str; }

# Hierarchy: root → Category → Item
def:pub add_category(name: str) -> dict {
    cat = (root() ++> Category(name=name))[0];
    return {"name": cat.name};
}

def:pub add_item(category_name: str, title: str) -> dict {
    for cat in [root()-->][?:Category] {
        if cat.name == category_name {
            item = (cat ++> Item(title=title))[0];
            return {"title": item.title};
        }
    }
    return {"error": "Category not found"};
}

def:pub get_items_by_category(category_name: str) -> list {
    for cat in [root()-->][?:Category] {
        if cat.name == category_name {
            return [{"title": i.title} for i in [cat-->][?:Item]];
        }
    }
    return [];
}
```
