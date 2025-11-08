Code blocks and statements form the structural foundation of Jac programs, organizing executable code into logical units and providing the syntactic framework for all program operations.

#### Code Block Structure

Code blocks use curly brace delimiters to group related statements into executable units:

```jac
{
    statement1;
    statement2;
    nested_block {
        inner_statement;
    }
}
```

Code blocks establish scope boundaries for variables and provide organizational structure for complex operations. They can be nested arbitrarily deep, enabling hierarchical program organization.

#### Statement Categories

Jac supports several categories of statements that serve different purposes:

**Declaration Statements**: Define functions, variables, and archetypes within the current scope, establishing named entities that can be referenced by subsequent code.

**Expression Statements**: Execute expressions for their side effects, including function calls, assignments, and object-spatial operations.

**Control Flow Statements**: Direct program execution through conditionals, loops, and exception handling constructs.

**Object-Spatial Statements**: Control walker movement and graph traversal operations, including visit, ignore, and disengage statements.

#### Statement Termination

Most statements require semicolon termination to establish clear boundaries between executable units:

```jac
let value = compute_result();
print(value);
visit next_node;
```

Control structures and block statements typically do not require semicolons as their block structure provides natural termination.

#### Scope and Visibility

Code blocks create lexical scopes where variables and functions defined within the block are accessible to nested blocks but not to parent scopes:

```jac
with entry {
    let local_var = "accessible within this block";
    
    def helper_function() {
        # Can access local_var from enclosing scope
        return local_var.upper();
    }
    
    print(helper_function());
}
# local_var and helper_function not accessible here
```

#### Integration with Object-Spatial Constructs

Code blocks work seamlessly with object-spatial programming constructs, providing structured contexts for walker abilities and node operations:

```jac
walker Processor {
    can process with entry {
        # Code block within ability
        let result = analyze_data(here.data);
        
        if (result.is_valid) {
            visit here.neighbors;
        } else {
            report "Invalid data at node";
            disengage;
        }
    }
}
```

Code blocks provide the essential organizational structure that enables clear, maintainable Jac programs while supporting both traditional programming patterns and object-spatial computation models.
