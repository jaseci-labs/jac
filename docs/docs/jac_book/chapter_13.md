# Chapter 13: Persistence and the Root Node

In this chapter, you will learn about one of Jac's most powerful features: automatic persistence. We will build a simple counter application to show you how Jac can automatically save your program's state when running as a service, eliminating the need for a traditional database setup.

!!! info "What You'll Learn"
    -   What "persistence" means and why it's a common challenge.
    - How Jac automatically saves your data when using the jac serve command.
    - The role of the root node as the anchor for all saved data.
    - How to build stateful applications that remember information between API calls.

Imagine you have a simple calculator application. When you run the program, it works perfectly. But as soon as you close the terminal, it forgets everything. The next time you run it, it starts from scratch. Its memory is temporary; it only exists while the program is running.

Persistence is the solution to this problem. Persistence is the ability of an application to save its state (its data, variables, and objects) so that the information survives after the program has been closed.

In traditional programming, achieving persistence is a significant task. You typically need to,

    1. Set up an external database (like PostgreSQL or MongoDB).
    2. Write code to connect your application to the database.
    3. Write "save" logic to convert your objects into a format the database can store.
    4. Write "load" logic to retrieve that data and turn it back into objects when your application starts again.

This is a lot of extra work just to make your application remember things.

---

## What is Automatic Persistence?

Jac is designed to make this process effortless. When you run your Jac program as a service (using the jac serve command, persistence becomes an automatic feature of the language.

!!! warning "Persistence Requirements"
    - **Database Backend**: Persistence requires `jac serve` with a configured database
    - **Service Mode**: `jac run` executions are stateless and don't persist data
    - **Root Connection**: Nodes must be connected to root to persist
    - **API Context**: Persistence works within the context of API endpoints

!!! success "Persistence Benefits"
    - **Zero Configuration**: No manual database schema or ORM setup
    - **Automatic State**: Data persists without explicit save/load operations
    - **Graph Integrity**: Relationships between nodes are maintained
    - **Type Safety**: Persistent data maintains type information
    - **Instant Recovery**: Services resume exactly where they left off

### Traditional vs Jac Persistence

!!! example "Persistence Comparison"
    === "Traditional Approach"
        ```python
        # counter_api.py - Manual database setup required
        from flask import Flask, jsonify, request
        import sqlite3
        import os

        app = Flask(__name__)

        class Counter:
            def __init__(self):
                self.db_path = "counter.db"
                self.init_db()

            def init_db(self):
                conn = sqlite3.connect(self.db_path)
                cursor = conn.cursor()
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS counter (
                        id INTEGER PRIMARY KEY,
                        value INTEGER
                    )
                ''')
                cursor.execute('SELECT value FROM counter WHERE id = 1')
                if not cursor.fetchone():
                    cursor.execute('INSERT INTO counter (id, value) VALUES (1, 0)')
                conn.commit()
                conn.close()

            def get_value(self):
                conn = sqlite3.connect(self.db_path)
                cursor = conn.cursor()
                cursor.execute('SELECT value FROM counter WHERE id = 1')
                value = cursor.fetchone()[0]
                conn.close()
                return value

            def increment(self):
                conn = sqlite3.connect(self.db_path)
                cursor = conn.cursor()
                cursor.execute('UPDATE counter SET value = value + 1 WHERE id = 1')
                conn.commit()
                conn.close()
                return self.get_value()

        counter = Counter()

        @app.route('/counter')
        def get_counter():
            return jsonify({"value": counter.get_value()})

        @app.route('/counter/increment', methods=['POST'])
        def increment_counter():
            new_value = counter.increment()
            return jsonify({"value": new_value})

        if __name__ == "__main__":
            app.run(debug=True)
        ```

    === "Jac Automatic Persistence"
        ```jac
        # main.jac - No database setup needed
        node Counter {
            has value: int = 0;

            def increment() -> int {
                self.value += 1;
                return self.value;
            }

            def get_value() -> int {
                return self.value;
            }
        }

        walker get_counter {
            obj __specs__ {
                static has auth: bool = False;
            }

            can get_counter_endpoint with `root entry {
                counter_nodes = [root --> Counter];


                if not counter_nodes {
                    counter = Counter();
                    root ++> counter;
                } else {
                    counter = counter_nodes[0];
                }

                report {"value": counter.get_value()};
            }
        }

        walker increment_counter {
            obj __specs__ {
                static has auth: bool = False;
            }

            can increment_counter_endpoint with `root entry {
                counter_nodes = [root --> Counter];
                if not counter_nodes {
                    counter = Counter();
                    root ++> counter;
                } else {
                    counter = counter_nodes[0];
                }
                new_value = counter.increment();
                report {"value": new_value};
            }
        }
        ```

---

## Setting Up a Jac Cloud Project

To demonstrate persistence, we need to create a proper jac-cloud project structure:

!!! example "Project Structure"
    ```
    counter-app/
    ├── .env                 # Environment configuration
    ├── main.jac            # Main application logic
    ├── server.py           # Optional custom server setup
    └── requirements.txt    # Python dependencies
    ```

Let's create our counter application:

!!! example "Complete Counter Project"
    === ".env"
        ```bash
        # .env - Database configuration
        DATABASE_URL=sqlite:///./app.db
        SECRET_KEY=your-secret-key-here
        ```

    === "main.jac"
        ```jac
        # main.jac
        node Counter {
            has value: int = 0;
            has created_at: str;

            can increment() -> int {
                self.value += 1;
                return self.value;
            }

            can reset() -> int {
                self.value = 0;
                return self.value;
            }
        }

        walker get_counter {
            can get_counter_endpoint with `root entry {
                counter_nodes = [root --> Counter];
                if not counter_nodes {
                    counter = Counter(created_at="2024-01-15");
                    root ++> counter;
                    report {"value": 0, "status": "created"};
                } else {
                    counter = counter_nodes[0];
                    report {"value": counter.value, "status": "existing"};
                }
            }
        }

        walker increment_counter {
            can increment_counter_endpoint with `root entry {
                counter_nodes = [root --> Counter];
                if not counter_nodes {
                    counter = Counter(created_at="2024-01-15");
                    root ++> counter;
                } else {
                    counter = counter_nodes[0];
                }
                new_value = counter.increment();
                report {"value": new_value, "previous": new_value - 1};
            }
        }

        walker reset_counter {
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

    === "requirements.txt"
        ```
        jaclang
        fastapi
        uvicorn
        python-dotenv
        ```

---

## The Root Node Concept

The root node is Jac's fundamental concept for persistent data organization. When running with `jac serve`, every request has access to a special `root` node that serves as the entry point for all persistent graph structures.

### Understanding Root Node

!!! info "Root Node Properties"
    - **Request Context**: Available in every API request when using jac serve
    - **Persistence Gateway**: Starting point for all persistent data
    - **Graph Anchor**: All persistent nodes must be reachable from root
    - **Automatic Creation**: Exists automatically with database backend
    - **Transaction Boundary**: Changes persist at the end of each request

### Running the Service

```bash
# Navigate to project directory
cd counter-app

# Install dependencies
pip install -r requirements.txt

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

---

## State Consistency

Jac maintains state consistency through its graph-based persistence model when running as a service. All connected nodes and their relationships are automatically maintained across requests and service restarts.

### Enhanced Counter with History

Let's enhance our counter to track increment history:

!!! example "Counter with History Tracking"
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

---

## Building Stateful Applications

The automatic persistence enables building sophisticated stateful applications. Let's create a multi-counter management system:

!!! example "Multi-Counter Management System"
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

---

## Best Practices

!!! summary "Persistence Guidelines"
    - **Service mode only**: Use `jac serve` for persistent applications, not `jac run`
    - **Connect to root**: All persistent data must be reachable from root
    - **Initialize gracefully**: Check for existing data before creating new instances
    - **Use proper IDs**: Generate unique identifiers for nodes that need them
    - **Plan for concurrency**: Consider multiple users accessing the same data
    - **Database configuration**: Set up proper database connections for production

## Key Takeaways

!!! summary "What We've Learned"
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
