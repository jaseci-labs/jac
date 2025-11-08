Match singleton patterns in Jac enable matching against singleton values including `None`, `True`, and `False`. These patterns are essential for handling null values and boolean states in pattern matching.

#### Singleton Pattern Syntax

```jac
match value {
    case None {
        handle_null_case();
    }
    case True {
        handle_true_case();
    }
    case False {
        handle_false_case();
    }
}
```

#### None Pattern Matching

```jac
match optional_user {
    case None {
        redirect_to_login();
    }
    case user {
        proceed_with_user(user);
    }
}
```

#### Boolean Pattern Matching

```jac
match user.is_authenticated() {
    case True {
        grant_access();
    }
    case False {
        deny_access();
    }
}
```

#### Object-Spatial Integration

```jac
walker ValidationWalker {
    can validate_node with entry {
        match here.data {
            case None {
                report f"Node {here.id} has no data";
                return;
            }
            case data {
                match data.is_valid() {
                    case True {
                        visit [-->];
                    }
                    case False {
                        report f"Invalid data at {here.id}";
                    }
                }
            }
        }
    }
}
```

#### Complex Singleton Usage

**Nested matching:**
```jac
match session.get("user") {
    case None {
        match session.get("guest_allowed") {
            case True { create_guest_session(); }
            case False { reject_session(); }
        }
    }
    case user_data {
        create_user_session(user_data);
    }
}
```

**With guards:**
```jac
match database_connection {
    case None if retry_count < max_retries {
        attempt_reconnection();
    }
    case None {
        fail_with_error("Database unavailable");
    }
    case connection {
        proceed_with_query(connection);
    }
}
```

#### Performance Considerations

- Uses fast identity checks for singletons
- No object creation overhead
- Optimized by compiler for common patterns

#### Best Practices

1. Always handle None cases explicitly
2. Use singleton patterns for explicit boolean logic
3. Combine with guards for complex conditions
4. Prefer singleton patterns over boolean expressions in match statements

Singleton patterns provide essential building blocks for robust pattern matching, enabling clean handling of null values and boolean states while maintaining type safety.
