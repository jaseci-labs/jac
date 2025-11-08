Match capture patterns in Jac enable binding values to variables during pattern matching, allowing programs to extract and use matched values within case blocks. Capture patterns provide the foundation for destructuring complex data structures.

#### Basic Capture Syntax

```jac
match user_input {
    case username {
        # 'username' now contains the matched value
        print(f"Hello, {username}!");
    }
}
```

#### Capture with Guards

```jac
match temperature {
    case temp if temp > 100 {
        handle_overheating(temp);
    }
    case temp if temp < 0 {
        handle_freezing(temp);
    }
    case temp {
        normal_operation(temp);
    }
}
```

#### Object-Spatial Integration

```jac
walker PatternProcessor {
    can process_node with entry {
        match here.node_type {
            case "data" {
                # Capture and process data nodes
                visit [-->];
            }
            case node_type {
                # Capture unknown node types
                log_unknown_type(node_type, here);
            }
        }
    }
}
```

#### Complex Structure Capture

**Sequence patterns:**
```jac
match coordinates {
    case [x, y] {
        distance = (x**2 + y**2)**0.5;
        return distance;
    }
    case coords {
        # Capture any other format
        return None;
    }
}
```

**Dictionary patterns:**
```jac
match config_data {
    case {"type": config_type, "settings": settings} {
        apply_settings(settings);
    }
    case config {
        apply_default_config(config);
    }
}
```

#### Multiple Capture Patterns

```jac
match response {
    case {"success": True, "data": result} {
        return result;
    }
    case {"success": False, "error": error_msg} {
        handle_error(error_msg);
        return None;
    }
    case response_data {
        log_unexpected_response(response_data);
        return None;
    }
}
```

#### Scope and Performance

- Captured variables are scoped to their case blocks
- Variables reference original matched values (no copying)
- No performance penalty for simple captures

#### Best Practices

1. Use meaningful variable names for captured values
2. Remember that captured variables are case-scoped
3. Combine captures with guards for complex conditions
4. Always include a capture pattern for unmatched cases

Capture patterns provide essential functionality for extracting and working with matched values in Jac's pattern matching system, enabling elegant data destructuring in both traditional and object-spatial programming contexts.
