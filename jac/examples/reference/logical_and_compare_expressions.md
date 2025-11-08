Logical and comparison expressions in Jac provide the foundation for conditional logic, enabling programs to make decisions based on data relationships and boolean conditions with enhanced type safety and null-aware comparisons.

#### Comparison Operators

```jac
a == b          # Equal to
a != b          # Not equal to
a < b           # Less than
a <= b          # Less than or equal to
a > b           # Greater than
a >= b          # Greater than or equal to
a is b          # Identity comparison
a in collection # Membership test
```

#### Logical Operators

```jac
condition1 and condition2    # Logical AND
condition1 or condition2     # Logical OR
not condition               # Logical NOT
condition1 && condition2    # Alternative AND syntax
condition1 || condition2    # Alternative OR syntax
```

#### Short-Circuit Evaluation

```jac
# Safe evaluation - second expression not evaluated if first is false
user and user.is_active()

# Efficient computation - avoids expensive call if cached
cached_result or expensive_computation()
```

#### Chained Comparisons

```jac
# Range checking
if 0 <= value <= 100 {
    print("Value is in valid range");
}

# Multiple conditions
if min_age <= user.age < max_age and user.is_verified() {
    grant_access();
}
```

#### Object-Spatial Integration

```jac
walker GraphValidator {
    can validate with entry {
        neighbors = [-->];
        
        if here.value < 0 or here.value > 100 {
            report f"Invalid value: {here.value}";
        }
        
        if len(neighbors) > 5 and here.is_hub() {
            visit neighbors.filter(lambda n: Node : n.priority > 0);
        }
    }
}
```

#### Type-Safe Comparisons

```jac
let count: int = 5;
let limit: int = 10;
if count < limit {  # Type-compatible comparison
    proceed();
}
```

#### Performance Considerations

- Order cheaper conditions first for short-circuit efficiency
- Use parentheses for complex logical expressions
- Avoid repeated expensive function calls in conditions

#### Elvis Operator

Jac offers a concise conditional expression using the Elvis operator `?:`.  The
expression `a ?: b` evaluates to `a` if it is not `None`, otherwise it yields
`b`:

```jac
let name = input_name ?: "anonymous";
```

This operator provides the common ternary pattern without repeating the tested
value, improving readability for simple defaulting logic.

Logical and comparison expressions provide the decision-making foundation for Jac programs, enabling sophisticated conditional logic while maintaining type safety and performance optimization.
