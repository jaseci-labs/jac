Match statements provide powerful pattern matching capabilities in Jac, enabling elegant handling of complex data structures and control flow based on value patterns. This feature supports structural pattern matching similar to modern programming languages.

#### Syntax

```jac
match expression {
    case pattern: 
        # statements
    case pattern if condition:
        # guarded pattern statements
}
```

#### Pattern Types

##### Literal Patterns
Match specific literal values:
```jac
match value {
    case 42:
        print("The answer");
    case 3.14:
        print("Pi approximation");
    case "hello":
        print("Greeting");
}
```

##### Capture Patterns
Bind matched values to variables:
```jac
match data {
    case x:
        print(f"Captured: {x}");
}
```

##### Sequence Patterns
Match lists and tuples:
```jac
match point {
    case [x, y]:
        print(f"2D point: ({x}, {y})");
    case [x, y, z]:
        print(f"3D point: ({x}, {y}, {z})");
    case [first, *rest]:
        print(f"First: {first}, Rest: {rest}");
}
```

##### Mapping Patterns
Match dictionary structures:
```jac
match config {
    case {"host": host, "port": port}:
        connect(host, port);
    case {"url": url, **options}:
        connect_url(url, options);
}
```

##### Class Patterns
Match object instances and extract attributes:
```jac
match shape {
    case Circle(radius=r):
        print(f"Circle area: {3.14 * r * r}");
    case Rectangle(width=w, height=h):
        print(f"Rectangle area: {w * h}");
}
```

##### OR Patterns
Match multiple patterns:
```jac
match command {
    case "quit" | "exit" | "q":
        terminate();
    case "help" | "h" | "?":
        show_help();
}
```

##### AS Patterns
Bind the entire match while matching pattern:
```jac
match data {
    case [x, y] as point:
        print(f"Point {point} has coordinates {x}, {y}");
}
```

#### Guard Conditions

Add conditions to patterns:
```jac
match user {
    case {"age": age, "role": role} if age >= 18:
        grant_access(role);
    case {"age": age} if age < 18:
        deny_access("Too young");
}
```

#### Singleton Patterns

Match None and boolean values:
```jac
match result {
    case None:
        print("No result");
    case True:
        print("Success");
    case False:
        print("Failure");
}
```

#### Practical Example

```jac
node RequestHandler {
    can handle(request: dict) {
        match request {
            case {"method": "GET", "path": path}:
                self.handle_get(path);
            
            case {"method": "POST", "path": path, "body": body}:
                self.handle_post(path, body);
            
            case {"method": "DELETE", "path": path} if self.can_delete():
                self.handle_delete(path);
            
            case {"method": method}:
                self.error(f"Unsupported method: {method}");
            
            case _:
                self.error("Invalid request format");
        }
    }
}
```

Match statements in Jac provide a declarative way to handle complex conditional logic, making code more readable and maintainable while reducing the need for nested if-elif chains.
