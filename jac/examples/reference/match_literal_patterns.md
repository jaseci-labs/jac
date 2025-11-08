Match literal patterns in Jac enable direct matching against constant values including numbers, strings, and other literal expressions. These patterns provide the foundation for value-based pattern matching in match statements.

#### Basic Literal Pattern Syntax

```jac
match value {
    case 42 {
        print("The answer to everything");
    }
    case "hello" {
        print("Greeting detected");
    }
    case 3.14159 {
        print("Pi approximation");
    }
    case true {
        handle_true_case();
    }
    case None {
        handle_null_case();
    }
}
```

#### Supported Literal Types

**Numeric literals:**
```jac
match status_code {
    case 200 { handle_success(); }
    case 404 { handle_not_found(); }
    case 500 { handle_server_error(); }
}
```

**String literals:**
```jac
match command {
    case "start" { start_process(); }
    case "stop" { stop_process(); }
    case "status" { show_status(); }
}
```

**Different numeric bases:**
```jac
match flag_value {
    case 0xFF { handle_max_value(); }      # Hexadecimal
    case 0b1010 { handle_binary(); }       # Binary
    case 0o755 { handle_permissions(); }   # Octal
}
```

#### Object-Spatial Pattern Matching

```jac
walker StatusChecker {
    can check_node with entry {
        match here.status {
            case "active" {
                visit [-->];
            }
            case "inactive" {
                skip;
            }
            case "error" {
                report f"Error node: {here.id}";
            }
        }
    }
}
```

#### Complex Literal Matching

**Combining with guards:**
```jac
match user_input {
    case "admin" if user.has_admin_rights() {
        enter_admin_mode();
    }
    case "guest" {
        enter_guest_mode();
    }
}
```

**Multiple literals:**
```jac
match error_code {
    case 400 | 401 | 403 {
        handle_client_error(error_code);
    }
    case 500 | 502 | 503 {
        handle_server_error(error_code);
    }
}
```

#### Performance Considerations

- Literal patterns use efficient direct comparison
- Compiler may optimize multiple literals into jump tables
- Place most common cases first for better performance

#### Best Practices

1. Use meaningful literal values
2. Group related cases together
3. Consider using named constants for magic numbers
4. Combine with guards for complex conditions

Literal patterns provide a clean, efficient way to handle value-based branching in Jac programs, supporting both simple conditional logic and complex state-based processing. 