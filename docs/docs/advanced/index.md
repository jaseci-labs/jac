# Advanced Topics

Deep dives into advanced Jac features and patterns.

## Concurrency

### Flow and Wait

Jac provides `flow` and `wait` keywords for concurrent execution:

```jac
import from time { sleep }

def slow_task(n: int) -> int {
    print(f"Task {n} started");
    sleep(1);
    print(f"Task {n} done");
    return n * 2;
}

def compute(x: int, y: int) -> int {
    sleep(1);
    return x + y;
}

# Flow - start concurrent execution (returns future)
glob task1 = flow compute(5, 10),
     task2 = flow compute(3, 7),
     task3 = flow slow_task(42);

with entry {
    print("All tasks started concurrently");
}

# Wait - wait for completion and get result
glob result1 = wait task1,
     result2 = wait task2,
     result3 = wait task3;

with entry {
    print(f"Results: {result1}, {result2}, {result3}");
}
```

### Async/Await

Standard async/await for asynchronous operations:

```jac
import asyncio;

async def fetch_data(id: int) -> str {
    await asyncio.sleep(0.1);
    return f"Data from {id}";
}

async def process_all() -> list[str] {
    # Concurrent async calls
    results = await asyncio.gather(
        fetch_data(1),
        fetch_data(2),
        fetch_data(3)
    );
    return results;
}

with entry {
    results = asyncio.run(process_all());
    print(results);
}
```

### Async Walkers

Walkers can be async for concurrent graph traversal:

```jac
async walker AsyncFetcher {
    has results: list = [];

    can start with `root entry {
        visit [-->];
    }

    can fetch with DataNode entry {
        data = await here.fetch_async();
        self.results.append(data);
        visit [-->];
    }
}
```

---

## Persistence Deep Dive

### Memory Hierarchy

Jac uses a three-tier memory architecture:

```
L1: VolatileMemory (In-Process)
    ↓ read-through / write-through
L2: LocalCacheMemory (Optional Cache)
    ↓ read-through / write-through
L3: PersistentMemory (ShelfDB, MongoDB, Redis)
```

### Memory Tiers

| Tier | Implementation | Speed | Durability | Use Case |
|------|---------------|-------|------------|----------|
| L1 | VolatileMemory | Fastest | None | Hot data, current session |
| L2 | LocalCacheMemory | Fast | None | Frequently accessed data |
| L3 | ShelfMemory | Moderate | File-based | Local persistence |
| L3 | MongoDB | Moderate | Database | Production persistence |
| L2 | Redis | Fast | Optional | Distributed cache |

### Configuring Persistence

```toml
# jac.toml
[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"
redis_url = "redis://localhost:6379/0"
shelf_db_path = ".jac/data/anchor_store.db"
```

### Persistent Nodes

All nodes connected to root are automatically persisted:

```jac
node UserData {
    has username: str;
    has email: str;
}

with entry {
    # This node is persisted (connected to root)
    user = root ++> UserData(username="alice", email="alice@example.com");

    # Detached nodes are NOT persisted
    temp = UserData(username="temp", email="temp@example.com");
}
```

### Session Management

```bash
# Run with named session
jac run main.jac -s my_session

# Session data stored at:
# .jac/data/anchor_store.db (default)
```

### Clearing Persisted State

```bash
# Remove all persisted state
rm -rf .jac/data/

# Or remove specific session
rm .jac/data/anchor_store.db
```

---

## Access Control

### Multi-Root Architecture

Each user gets their own root node for isolated data:

```jac
node UserRoot {
    has user_id: str;
}

node PrivateData {
    has data: str;
}

# Each user has isolated graph
with entry {
    # User A's data
    user_a_root = root ++> UserRoot(user_id="user_a");
    user_a_root ++> PrivateData(data="User A's secret");

    # User B's data
    user_b_root = root ++> UserRoot(user_id="user_b");
    user_b_root ++> PrivateData(data="User B's secret");
}
```

### Permission Levels

| Level | Value | Description |
|-------|-------|-------------|
| NO_ACCESS | -1 | No access allowed |
| READ | 0 | Can read node data |
| CONNECT | 1 | Can traverse edges |
| WRITE | 2 | Can modify node data |

### Access in Multi-User Apps

When using `jac start`, each authenticated user automatically gets:

- Their own root node
- Isolated graph space
- Permissions checked on every access

---

## Python Interoperability

### Library Mode

Use Jac features from pure Python:

```python
from jaclang.lib import (
    Node, Edge, Walker,
    connect, root, on_entry, refs
)

# Define nodes
class Person(Node):
    name: str

# Define walkers
class Greeter(Walker):
    @on_entry(Person)
    def greet(self, here: Person):
        print(f"Hello, {here.name}!")

# Build graph
p1 = Person(name="Alice")
connect(root(), p1)

# Spawn walker
Greeter().spawn(root())
```

### Converting Jac to Python

```bash
# Generate Python equivalent
jac jac2py main.jac

# Output: main.py with library imports
```

### Importing Jac from Python

```python
from jaclang import jac_import

# Import a Jac module
my_module = jac_import("my_module.jac")

# Use exported functions/classes
result = my_module.my_function()
```

### Converting Python to Jac

```bash
# Convert Python file to Jac
jac py2jac main.py

# Output: main.jac
```

---

## Plugin Development

### Plugin Structure

```
my-plugin/
├── pyproject.toml
├── my_plugin/
│   ├── __init__.py
│   ├── plugin.jac       # Plugin entry point
│   └── plugin_config.jac
```

### Plugin Registration

```toml
# pyproject.toml
[project.entry-points.jac]
my_plugin = "my_plugin"
```

### Plugin Hooks

```jac
# plugin.jac
import from jaclang.plugin.spec { hookimpl }

class MyPlugin {
    @hookimpl
    static def custom_hook(arg: str) -> str {
        return f"Processed: {arg}";
    }
}
```

### Plugin Configuration

```jac
# plugin_config.jac
import from jaclang.project { PluginConfigBase }

class MyPluginConfig(PluginConfigBase) {
    def get_plugin_name() -> str {
        return "my_plugin";
    }

    def get_default_config() -> dict[str, any] {
        return {
            "option1": "default_value",
            "option2": 42
        };
    }
}
```

### Using Plugin Config

```toml
# jac.toml
[plugins.my_plugin]
option1 = "custom_value"
option2 = 100
```

---

## Performance Optimization

### Efficient Graph Traversal

```jac
walker EfficientTraverser {
    has max_depth: int = 5;
    has current_depth: int = 0;

    can traverse with entry {
        # Limit depth to avoid infinite traversal
        if self.current_depth >= self.max_depth {
            disengage;
        }

        self.current_depth += 1;
        visit [-->];
        self.current_depth -= 1;
    }
}
```

### Edge Filtering

```jac
walker FilteredVisitor {
    can visit_specific with entry {
        # Only follow specific edge types
        visit [-->:FriendEdge:];

        # Filter by edge attributes
        visit [-->:Knows:since > 2020:];

        # Filter by target node type
        visit [-->(`?Person)];
    }
}
```

### Batch Operations

```jac
with entry {
    # Create multiple nodes efficiently
    people: list[Person] = [];
    for name in ["Alice", "Bob", "Carol"] {
        people.append(root ++> Person(name=name));
    }

    # Batch edge creation
    for i = 0 to i < len(people) - 1 by i += 1 {
        people[i][0] +>:Knows:+> people[i + 1][0];
    }
}
```

### Caching Strategies

```toml
# jac.toml
[cache]
enabled = true

[build]
dir = ".jac"  # Cache directory
```

---

## Advanced OSP Patterns

### Multi-Hop Traversal

```jac
walker FriendOfFriend {
    has hop_count: int = 0;

    can first_hop with `root entry {
        visit [-->];
    }

    can find_friends with Person entry {
        if self.hop_count == 0 {
            self.hop_count = 1;
            visit [-->:Friend:];
        } elif self.hop_count == 1 {
            print(f"Friend of friend: {here.name}");
        }
    }
}
```

### Bidirectional Traversal

```jac
walker Navigator {
    can explore with entry {
        # Forward edges
        visit [-->];

        # Backward edges
        visit [<--];

        # Both directions
        visit [<-->];
    }
}
```

### Conditional Disengage

```jac
walker Searcher {
    has target: str;
    has found: bool = False;

    can search with Person entry {
        if here.name == self.target {
            self.found = True;
            print(f"Found: {here.name}");
            disengage;  # Stop all traversal
        }
        visit [-->];
    }
}
```

---

## Learn More

| Topic | Resource |
|-------|----------|
| Persistence | [Chapter 13](../jac_book/chapter_13.md) |
| Multi-User | [Chapter 14](../jac_book/chapter_14.md) |
| Performance | [Chapter 19](../jac_book/chapter_19.md) |
| Library Mode | [Full Guide](../learn/library_mode.md) |
| Jac Specification | [Reference](../learn/jac-ref/index.md) |
| Python Migration | [Chapter 20](../jac_book/chapter_20.md) |
