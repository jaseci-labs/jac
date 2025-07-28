# Chapter 12: Persistence and the Root Node
---
In this chapter, we'll explore Jac's automatic persistence system and the fundamental concept of the root node. We'll build a simple counter application that demonstrates how Jac automatically maintains state when running as a service with a database backend.

!!! info "What You'll Learn"
    - Understanding Jac's automatic persistence mechanism with jac serve
    - The root node as the entry point for all persistent data
    - State consistency across API requests and service restarts
    - Building stateful applications with jac-cloud



## What is Automatic Persistence?
---

Traditional programming requires explicit database setup, connection management, and data serialization. Jac eliminates this complexity by making persistence a core language feature when running as a service. When you use `jac serve` with a database backend, nodes and their connections automatically persist across requests and service restarts.

### Persistence Benefits
- **Zero Configuration**: No manual database schema or ORM setup
- **Automatic State**: Data persists without explicit save/load operations
- **Graph Integrity**: Relationships between nodes are maintained
- **Type Safety**: Persistent data maintains type information
- **Instant Recovery**: Services resume exactly where they left off


## Simple Counter Application
---
To illustrate Jac's persistence, we'll create a simple counter application. This application will allow us to increment a counter, reset it, and check its value. The key feature is that the counter's state will persist across service restarts, thanks to Jac's automatic persistence.


### Counter Node Definition

First, we define a `Counter` node that holds an initial counter property that is set to 0 when the node is created. When the jac program is finished executing, this node will be automatically persisted in the database as long as it is connected to the `root` node.

```jac
node Counter {
    has value: int = 0;
    has status: str = "created";
    has created_at: str by postinit;

    def postinit() {
        self.created_at = datetime.now().isoformat();
    }

    def increment() -> int {
        self.value += 1;
        return self.value;
    }

    def reset() -> int {
        self.value = 0;
        return self.value;
    }
}
```

### Walkers for Counter Operations
We will create a `CounterAgent` walker that provides methods to get the counter, increment it, and reset it. This walker has a method that checks if a `Counter` node already exists in the graph. If it does, it returns that node; if not, it creates a new `Counter` node and connects it to the `root`.


```jac
walker CounterAgent{
    obj __specs__ {
        static has auth: bool = False;
    }

    def get_counter() -> Counter {
        counter_nodes = [root --> Counter];
        counter: Counter = None;

        if not counter_nodes {
            counter = Counter();
            root ++> counter;
        } else {
            counter = counter_nodes[0];
        }

        return counter;
    }
}
```

#### Get Counter Endpoint
The `get_counter` method retrieves the counter value and its status. If the counter is newly created, it sets the status to "created"; otherwise, it returns the existing counter's value and status.

```jac
walker get_counter(CounterAgent) {
    can get_counter_endpoint with `root entry {
        counter: Counter = self.get_counter();

        if counter.status == "created" {
            counter.status = "existing";
            report {"value": counter.value, "status": "created"};
        } else {
            report {"value": counter.value, "status": counter.status};
        }
    }
}
```

#### Increment Counter Endpoint
The `increment_counter` method increments the counter's value and returns the new value along with the previous value.

```jac
walker increment_counter(CounterAgent) {
    can increment_counter_endpoint with `root entry {
        counter: Counter = self.get_counter();

        new_value = counter.increment();
        report {"value": new_value, "previous": new_value - 1};
    }
}
```

#### Reset Counter Endpoint
The `reset_counter` method resets the counter's value to 0 and returns the reset status.

```jac
walker reset_counter(CounterAgent) {
    can reset_counter_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if counter_nodes {
            counter = counter_nodes[0];
            counter.reset();
            report {"value": counter.value, "status": "reset"};
        } else {
            report {"value": 0, "status": "no_counter_found"};
        }
    }
}
```

### Complete Jac Code for Counter Application

```jac
import from datetime { datetime }

# main.jac
node Counter {
    has value: int = 0;
    has created_at: str by postinit;

    def postinit() {
        self.created_at = datetime.now().isoformat();
    }

    def increment() -> int {
        self.value += 1;
        return self.value;
    }

    def reset() -> int {
        self.value = 0;
        return self.value;
    }
}

walker CounterAgent{
    obj __specs__ {
        static has auth: bool = False;
    }
}

walker get_counter(CounterAgent) {
    can get_counter_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if not counter_nodes {
            counter = Counter();
            root ++> counter;
            report {"value": 0, "status": "created"};
        } else {
            counter = counter_nodes[0];
            report {"value": counter.value, "status": "existing"};
        }
    }
}

walker increment_counter(CounterAgent) {
    can increment_counter_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if not counter_nodes {
            counter = Counter();
            root ++> counter;
        } else {
            counter = counter_nodes[0];
        }
        new_value = counter.increment();
        report {"value": new_value, "previous": new_value - 1};
    }
}

walker reset_counter(CounterAgent) {
    can reset_counter_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if counter_nodes {
            counter = counter_nodes[0];
            counter.reset();
            report {"value": 0, "status": "reset"};
        } else {
            report {"value": 0, "status": "no_counter_found"};
        }
    }
}
```


### Running the Service

```bash
# Start the service with database persistence
jac serve main.jac

# Service starts on http://localhost:8000
# API documentation available at http://localhost:8000/docs
```

### Testing Persistence

```bash
# First request - Create counter
curl -X POST http://localhost:8000/walker/get_counter \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"value": 0, "status": "created"}]}

# Increment the counter
curl -X POST http://localhost:8000/walker/increment_counter \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"value": 1, "previous": 0}]}

# Increment again
curl -X POST http://localhost:8000/walker/increment_counter \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"value": 2, "previous": 1}]}

# Check counter value
curl -X POST http://localhost:8000/walker/get_counter \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"value": 2, "status": "existing"}]}

# Restart the service (Ctrl+C, then jac serve main.jac again)

# Counter value persists after restart
curl -X POST http://localhost:8000/walker/get_counter \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"value": 2, "status": "existing"}]}
```

!!! tip "Persistence in Action"
    Notice how the counter value persists between requests and even service restarts when using `jac serve` with a database!


## State Consistency
---
Jac maintains state consistency through its graph-based persistence model when running as a service. All connected nodes and their relationships are automatically maintained across requests and service restarts.

### Enhanced Counter with History

Let's enhance our counter to track increment history:


```jac
# main.jac - Enhanced with history
import from datetime { datetime }

node Counter {
    has created_at: str;
    has value: int = 0;

    def increment() -> int {
        old_value = self.value;
        self.value += 1;

        # Create history entry
        history = HistoryEntry(
            timestamp=str(datetime.now()),
            old_value=old_value,
            new_value=self.value
        );
        self ++> history;
        return self.value;
    }

    def get_history() -> list[dict] {
        history_nodes = [self --> HistoryEntry];
        return [
            {
                "timestamp": h.timestamp,
                "old_value": h.old_value,
                "new_value": h.new_value
            }
            for h in history_nodes
        ];
    }
}

node HistoryEntry {
    has timestamp: str;
    has old_value: int = 0;
    has new_value: int = 0;
}

walker get_counter_with_history {
    obj __specs__ {
        static has auth: bool = False;
    }

    can get_counter_with_history_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if not counter_nodes {
            counter = Counter(created_at=str(datetime.now()));
            root ++> counter;
            report {
                "value": 0,
                "status": "created",
                "history": []
            };
        } else {
            counter = counter_nodes[0];
            report {
                "value": counter.value,
                "status": "existing",
                "history": counter.get_history()
            };
        }
    }
}

walker increment_with_history {
    obj __specs__ {
        static has auth: bool = False;
    }

    can increment_with_history_endpoint with `root entry {
        counter_nodes = [root --> Counter];
        if not counter_nodes {
            counter = Counter(created_at=str(datetime.now()));
            root ++> counter;
        } else {
            counter = counter_nodes[0];
        }

        new_value = counter.increment();
        report {
            "value": new_value,
            "history": counter.get_history()
        };
    }
}
```

### Testing History Persistence

```bash
# Start fresh service
jac serve main.jac

# Multiple increments to build history
curl -X POST http://localhost:8000/walker/increment_with_history \
  -H "Content-Type: application/json" \
  -d '{}'

curl -X POST http://localhost:8000/walker/increment_with_history \
  -H "Content-Type: application/json" \
  -d '{}'

curl -X POST http://localhost:8000/walker/increment_with_history \
  -H "Content-Type: application/json" \
  -d '{}'

# Check counter with complete history
curl -X POST http://localhost:8000/walker/get_counter_with_history \
  -H "Content-Type: application/json" \
  -d '{}'
# Response includes value and complete history array

# Restart service - history persists
# jac serve main.jac (after restart)
curl -X POST http://localhost:8000/walker/get_counter_with_history \
  -H "Content-Type: application/json" \
  -d '{}'
# All history entries remain intact
```

## Building Stateful Applications
---
The automatic persistence enables building sophisticated stateful applications. Let's create a multi-counter management system:


```jac
# main.jac - Multi-counter system
import from datetime { datetime }

node CounterManager {
    has created_at: str;

    def create_counter(name: str) -> dict {
        # Check if counter already exists
        existing = [self --> Counter](?name == name);
        if existing {
            return {"status": "exists", "counter": existing[0].name};
        }

        new_counter = Counter(name=name, value=0);
        self ++> new_counter;
        return {"status": "created", "counter": name};
    }

    def list_counters() -> list[dict] {
        counters = [self --> Counter];
        return [
            {"name": c.name, "value": c.value}
            for c in counters
        ];
    }

    def get_total() -> int {
        counters = [self --> Counter];
        return sum([c.value for c in counters]);
    }
}

node Counter {
    has name: str;
    has value: int = 0;

    def increment(amount: int = 1) -> int {
        self.value += amount;
        return self.value;
    }
}

walker create_counter {
    has name: str;

    obj __specs__ {
        static has auth: bool = False;
    }

    can create_counter_endpoint with `root entry {
        manager_nodes = [root --> CounterManager];
        if not manager_nodes {
            manager = CounterManager(created_at=str(datetime.now()));
            root ++> manager;
        } else {
            manager = manager_nodes[0];
        }

        result = manager.create_counter(self.name);
        report result;
    }
}

walker increment_named_counter {
    has name: str;
    has amount: int = 1;

    obj __specs__ {
        static has auth: bool = False;
    }

    can increment_named_counter_endpoint with `root entry {
        manager_nodes = [root --> CounterManager];
        if not manager_nodes {
            report {"error": "No counter manager found"};
            return;
        }

        manager = manager_nodes[0];
        counters = [manager --> Counter](?name == self.name);

        if not counters {
            report {"error": f"Counter {self.name} not found"};
            return;
        }

        counter = counters[0];
        new_value = counter.increment(self.amount);
        report {"name": self.name, "value": new_value};
    }
}

walker get_all_counters {
    obj __specs__ {
        static has auth: bool = False;
    }

    can get_all_counters_endpoint with `root entry {
        manager_nodes = [root --> CounterManager];
        if not manager_nodes {
            report {"counters": [], "total": 0};
            return;
        }

        manager = manager_nodes[0];
        report {
            "counters": manager.list_counters(),
            "total": manager.get_total()
        };
    }
}
```

### API Usage Examples

```bash
# Create multiple counters
curl -X POST "http://localhost:8000/walker/create_counter" \
     -H "Content-Type: application/json" \
     -d '{"name": "page_views"}'

curl -X POST "http://localhost:8000/walker/create_counter" \
     -H "Content-Type: application/json" \
     -d '{"name": "user_signups"}'

# Increment specific counters
curl -X POST "http://localhost:8000/walker/increment_named_counter" \
     -H "Content-Type: application/json" \
     -d '{"name": "page_views", "amount": 5}'

curl -X POST "http://localhost:8000/walker/increment_named_counter" \
     -H "Content-Type: application/json" \
     -d '{"name": "user_signups", "amount": 2}'

# View all counters
curl -X POST http://localhost:8000/walker/get_all_counters \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"returns": [{"counters": [{"name": "page_views", "value": 5}, {"name": "user_signups", "value": 2}], "total": 7}]}
```


## Key Takeaways
---


**Persistence Fundamentals:**

- **Service requirement**: Persistence only works with `jac serve` and database backends
- **Root connection**: All persistent nodes must be connected to the root node
- **Automatic behavior**: Data persists without explicit save/load operations
- **Request isolation**: Each API request has access to the same persistent graph

**Root Node Concept:**

- **Graph anchor**: Starting point for all persistent data structures
- **Request context**: Available automatically in every API endpoint
- **Transaction boundary**: Changes persist at the end of each successful request
- **State consistency**: Maintains graph integrity across service restarts

**State Management:**

- **Automatic persistence**: Connected nodes survive service restarts
- **Graph integrity**: Relationships between nodes are maintained
- **Type preservation**: Node properties retain their types across persistence
- **Concurrent access**: Multiple requests can safely access the same data

**Development Patterns:**

- **Initialization checks**: Use filtering to find existing data before creating new
- **Unique identification**: Generate proper IDs for nodes that need them
- **Data validation**: Implement business rules at the application level
- **Error handling**: Graceful handling of missing or invalid data

!!! tip "Try It Yourself"
    Build persistent applications by creating:
    - A todo list API with persistent tasks
    - A blog system with posts and comments
    - An inventory management system
    - A user profile system with preferences

    Remember: Only nodes connected to root (directly or indirectly) will persist when using `jac serve`!

---

*Ready to explore cloud deployment? Continue to [Chapter 14: Jac Cloud Introduction](chapter_14.md)!*
