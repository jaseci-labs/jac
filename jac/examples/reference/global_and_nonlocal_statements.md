Global and nonlocal statements in Jac provide mechanisms for accessing and modifying variables from outer scopes. These statements enable controlled access to variables defined outside the current function or ability scope.

#### Global Statement

The global statement declares that variables refer to globally scoped names:

```jac
# Using :g: prefix
:g: counter, total;

# Using :global: prefix  
:global: config, state;
```

##### Basic Usage

```jac
# Global variable
glob state: dict = {};

obj Controller {
    can update_state(key: str, value: any) {
        :g: state;
        state[key] = value;
    }
    
    can get_state -> dict {
        :g: state;
        return state;
    }
}
```

##### Multiple Global Variables

```jac
glob counter: int = 0;
glob total: float = 0.0;
glob items: list = [];

can process_item(value: float) {
    :g: counter, total, items;
    
    counter += 1;
    total += value;
    items.append(value);
}
```

#### Nonlocal Statement

The nonlocal statement declares that variables refer to names in the nearest enclosing scope:

```jac
# Using :nl: prefix
:nl: local_var;

# Using :nonlocal: prefix
:nonlocal: outer_counter;
```

##### Nested Function Scopes

```jac
can create_counter -> (func) {
    count = 0;
    
    can increment -> int {
        :nl: count;
        count += 1;
        return count;
    }
    
    return increment;
}
```

##### In Walker Abilities

```jac
walker StateTracker {
    has visited: list = [];
    
    can track with entry {
        visited_count = 0;
        
        can log_visit {
            :nl: visited_count;
            visited_count += 1;
            self.visited.append(here);
        }
        
        # Visit nodes and track
        for node in [-->] {
            visit node;
            log_visit();
        }
        
        report f"Visited {visited_count} nodes";
    }
}
```

#### Scope Resolution Rules

##### Global Scope
- Variables declared at module level
- Accessible throughout the module
- Require explicit `global` declaration to modify

##### Nonlocal Scope
- Variables in enclosing function/ability scope
- Not global, not local
- Require explicit `nonlocal` declaration to modify

##### Local Scope
- Variables defined within current function/ability
- Default scope for assignments
- Shadow outer scope variables

#### Common Patterns

##### Configuration Management
```jac
glob config: dict = {
    "debug": False,
    "timeout": 30
};

obj App {
    can set_debug(enabled: bool) {
        :g: config;
        config["debug"] = enabled;
    }
    
    can with_timeout(seconds: int) -> func {
        can run_with_timeout(fn: func) {
            :g: config;
            old_timeout = config["timeout"];
            config["timeout"] = seconds;
            result = fn();
            config["timeout"] = old_timeout;
            return result;
        }
        return run_with_timeout;
    }
}
```

##### Counter Patterns
```jac
can create_id_generator -> func {
    next_id = 1000;
    
    can generate -> int {
        :nl: next_id;
        id = next_id;
        next_id += 1;
        return id;
    }
    
    return generate;
}
```

##### State Accumulation
```jac
walker Collector {
    can collect with entry {
        results = [];
        errors = [];
        
        can process_node {
            :nl: results, errors;
            
            try {
                data = here.process();
                results.append(data);
            } except as e {
                errors.append({"node": here, "error": e});
            }
        }
        
        # Process all nodes
        for node in [-->] {
            process_node();
        }
        
        report {"results": results, "errors": errors};
    }
}
```

#### Best Practices

1. **Minimize Global State**: Use sparingly for truly global concerns
2. **Prefer Parameters**: Pass values explicitly when possible
3. **Document Side Effects**: Clear comments for global modifications
4. **Use Nonlocal for Closures**: Appropriate for nested function state
5. **Consider Alternatives**: Class attributes or node properties

#### Integration with Object-Spatial

In object-spatial contexts, consider using node/edge properties instead of global state:

```jac
# Instead of global state
glob graph_metadata: dict = {};

# Prefer node-based state
node GraphRoot {
    has metadata: dict = {};
}

walker Processor {
    can process with entry {
        # Access via node instead of global
        root.metadata["processed"] = True;
    }
}
```

Global and nonlocal statements provide necessary escape hatches for scope management, but should be used judiciously in favor of Jac's more structured object-spatial approaches.
