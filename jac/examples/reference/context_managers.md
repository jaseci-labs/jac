Context managers in Jac provide automatic resource management through `with` statements, ensuring proper acquisition and release of resources. This feature supports the context management protocol for clean handling of files, connections, locks, and other resources.

#### Syntax

```jac
with expression as variable {
    # code using the resource
}

# Multiple context managers
with expr1 as var1, expr2 as var2 {
    # code using both resources
}

# Async context managers
async with async_expression as variable {
    # async code using the resource
}
```

#### Basic Usage

```jac
# File handling
with open("data.txt", "r") as file {
    content = file.read();
    process(content);
}  # File automatically closed

# Database connection
with get_connection() as conn {
    cursor = conn.cursor();
    cursor.execute("SELECT * FROM users");
    results = cursor.fetchall();
}  # Connection automatically closed
```

#### Multiple Context Managers

Manage multiple resources simultaneously:

```jac
with open("input.txt", "r") as infile,
     open("output.txt", "w") as outfile {
    
    data = infile.read();
    processed = transform(data);
    outfile.write(processed);
}  # Both files automatically closed
```

#### Custom Context Managers

Create your own context managers:

```jac
obj TimedOperation {
    has name: str;
    has start_time: float;
    
    can __enter__(self) {
        self.start_time = time.now();
        print(f"Starting {self.name}");
        return self;
    }
    
    can __exit__(self, exc_type, exc_val, exc_tb) {
        duration = time.now() - self.start_time;
        print(f"{self.name} took {duration}s");
        return False;  # Don't suppress exceptions
    }
}

# Usage
with TimedOperation("data_processing") as timer {
    process_large_dataset();
}
```

#### Graph Lock Management

Context managers for thread-safe graph operations:

```jac
node ThreadSafeNode {
    has lock: Lock = Lock();
    has data: dict = {};
    
    can safe_update(key: str, value: any) {
        with self.lock {
            old_value = self.data.get(key);
            self.data[key] = value;
            log_change(key, old_value, value);
        }
    }
}
```

#### Transaction Management

Database-style transactions:

```jac
obj Transaction {
    has operations: list = [];
    has committed: bool = False;
    
    can __enter__(self) {
        self.begin();
        return self;
    }
    
    can __exit__(self, exc_type, exc_val, exc_tb) {
        if exc_type is None {
            self.commit();
        } else {
            self.rollback();
        }
        return False;
    }
    
    can add_operation(op: func) {
        self.operations.append(op);
    }
    
    can commit(self) {
        for op in self.operations {
            op();
        }
        self.committed = True;
    }
    
    can rollback(self) {
        # Undo operations
        print("Transaction rolled back");
    }
}
```

#### Walker State Management

Manage walker state during traversal:

```jac
obj WalkerContext {
    has walker: walker;
    has original_state: dict;
    
    can __enter__(self) {
        self.original_state = self.walker.get_state();
        return self.walker;
    }
    
    can __exit__(self, exc_type, exc_val, exc_tb) {
        if exc_type {
            # Restore state on error
            self.walker.set_state(self.original_state);
        }
        return False;
    }
}

walker StatefulWalker {
    has state: dict = {};
    
    can process with entry {
        with WalkerContext(self) as ctx {
            # Modify state during processing
            ctx.state["processing"] = True;
            
            # Process node
            result = here.complex_operation();
            
            # State automatically restored on error
        }
    }
}
```

#### Async Context Managers

For asynchronous resource management:

```jac
async with acquire_async_resource() as resource {
    data = await resource.fetch_data();
    processed = await process_async(data);
    await resource.save(processed);
}
```

#### Graph Session Management

```jac
obj GraphSession {
    has graph: node;
    has changes: list = [];
    
    can __enter__(self) {
        self.changes = [];
        return self;
    }
    
    can __exit__(self, exc_type, exc_val, exc_tb) {
        if exc_type is None {
            # Apply all changes
            for change in self.changes {
                change.apply();
            }
        } else {
            # Discard changes on error
            print(f"Discarding {len(self.changes)} changes");
        }
        return False;
    }
    
    can add_node(self, node: node) {
        self.changes.append(AddNodeChange(node));
    }
    
    can add_edge(self, src: node, dst: node, edge_type: type) {
        self.changes.append(AddEdgeChange(src, dst, edge_type));
    }
}

# Usage
with GraphSession(root) as session {
    n1 = DataNode(value=10);
    n2 = DataNode(value=20);
    
    session.add_node(n1);
    session.add_node(n2);
    session.add_edge(n1, n2, DataEdge);
}  # Changes committed atomically
```

#### Temporary State Changes

```jac
obj TemporaryState {
    has target: obj;
    has attr: str;
    has new_value: any;
    has old_value: any;
    
    can __enter__(self) {
        self.old_value = getattr(self.target, self.attr);
        setattr(self.target, self.attr, self.new_value);
        return self.target;
    }
    
    can __exit__(self, exc_type, exc_val, exc_tb) {
        setattr(self.target, self.attr, self.old_value);
        return False;
    }
}

# Usage
node ConfigNode {
    has debug: bool = False;
    
    can process_with_debug {
        with TemporaryState(self, "debug", True) {
            # Debug is True here
            self.process_data();
        }
        # Debug restored to False
    }
}
```

#### Best Practices

1. **Always Use With**: For resources that need cleanup
2. **Don't Suppress Exceptions**: Return False from __exit__
3. **Minimal Scope**: Keep with blocks focused
4. **Document Side Effects**: Clear about what's managed
5. **Test Error Cases**: Ensure cleanup on exceptions

#### Common Patterns

##### Resource Pool
```jac
with get_resource_from_pool() as resource {
    # Use resource
    resource.execute(operation);
}  # Resource returned to pool
```

##### Nested Contexts
```jac
with outer_context() as outer {
    # Outer resource acquired
    with inner_context() as inner {
        # Both resources available
        process(outer, inner);
    }  # Inner released
}  # Outer released
```

##### Optional Context
```jac
context = get_optional_context() if condition else nullcontext();
with context as ctx {
    # Works whether context exists or not
    process_data(ctx);
}
```

Context managers in Jac provide a robust pattern for resource management, ensuring proper cleanup even in the presence of errors, making code more reliable and maintainable.
