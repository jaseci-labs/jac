Global variables provide module-level data storage that persists throughout program execution and can be accessed across different scopes within a Jac program. Jac offers two declaration keywords with distinct semantic meanings and access control capabilities.

#### Declaration Keywords

**`let` Keyword**: Declares module-level variables with lexical scoping semantics, suitable for configuration values and module-local state that may be reassigned during execution.

**`glob` Keyword**: Explicitly declares global variables with program-wide scope, emphasizing their global nature and intended use for shared state across multiple modules or components.

#### Access Control Modifiers

Jac provides three access control levels for global variables:

- **`:priv`**: Private to the current module, preventing external access
- **`:pub`**: Publicly accessible from other modules and external code
- **`:protect`**: Protected access with limited external visibility

When no access modifier is specified, variables default to module-level visibility with standard scoping rules.

#### Syntax and Usage

```jac
let:priv config_value = "development";
glob:pub shared_counter = 0;
glob:protect system_state = "initialized";
glob default_timeout = 30;
```

#### Integration with Entry Points

Global variables integrate seamlessly with entry blocks and named execution contexts:

```jac
let:priv module_data = initialize_data();
glob:pub api_version = "2.1";

with entry:main {
    print(f"Module data: {module_data}");
    print(f"API Version: {api_version}");
    
    # Global variables remain accessible throughout execution
    process_with_globals();
}
```

#### Common Usage Patterns

**Configuration Management**: Global variables provide centralized configuration storage accessible across the entire program without parameter passing.

**Shared State**: Multiple components can access and modify shared program state through globally accessible variables.

**Module Interfaces**: Public global variables create clean interfaces between modules, exposing necessary data while maintaining encapsulation through access controls.

**System Constants**: Global variables store system-wide constants and settings that remain consistent throughout program execution.

Global variables complement Jac's object-spatial programming model by providing persistent state that walkers and other computational entities can access during graph traversal and distributed computation operations.
