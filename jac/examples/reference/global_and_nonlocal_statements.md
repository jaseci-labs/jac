**Global and Nonlocal Statements**

The `global` and `nonlocal` statements control variable scope, allowing functions to modify variables from outer scopes rather than creating local shadows.

**Module-Level Global Variables**

Lines 3-4 declare module-level global variables. These variables exist at module scope and are accessible throughout the module.

**Global Statement - Single Variable**

Lines 6-11 demonstrate the `global` statement. Line 8: `global x` declares that `x` refers to the module-level global variable (line 3). Without this statement, line 9's assignment would create a new local variable instead of modifying the global.

**Global Statement - Multiple Variables**

Lines 13-19 show declaring multiple global variables. Line 15: `global a, b` is more concise than separate `global` statements for each variable.

**Nonlocal Statement - Single Variable**

Lines 21-34 demonstrate the `nonlocal` statement for nested functions. Line 26: `nonlocal y` declares that `y` refers to the enclosing function's variable (line 22), not a global or new local. Line 27's assignment modifies the outer function's `y`.

**Nonlocal Statement - Multiple Variables**

Lines 36-52 show declaring multiple nonlocal variables. Line 43: `nonlocal p, q, r` modifies all three variables from the enclosing scope.

**Scope Resolution Rules**

Without `global` or `nonlocal`, assignments create new local variables. These keywords alter this behavior:

| Keyword | Accesses | Scope Level | Use Case |
|---------|----------|-------------|----------|
| `global` | Module-level variables | Global | Modify module state from functions |
| `nonlocal` | Enclosing function variables | Enclosing | Closures, nested function state |

**Execution Flow**

Lines 54-65 demonstrate the execution and effects:

**Variable Modification Flow**

```mermaid
flowchart TD
    Start([Assignment in Function]) --> Check{global or<br/>nonlocal<br/>declared?}
    Check -->|global| ModGlobal[Modify module-level<br/>global variable]
    Check -->|nonlocal| ModEnclosing[Modify enclosing<br/>function variable]
    Check -->|Neither| CreateLocal[Create new<br/>local variable]
    ModGlobal --> Done([Assignment Complete])
    ModEnclosing --> Done
    CreateLocal --> Done
```

**Scope Levels Example**

```mermaid
flowchart TD
    Global[Global Scope<br/>x, a, b] --> Outer1[outer function<br/>y variable]
    Outer1 --> Inner1[inner function<br/>accesses y with nonlocal]
    Global --> Outer2[outer_multi function<br/>p, q, r variables]
    Outer2 --> Inner2[inner_multi function<br/>accesses p,q,r with nonlocal]
    Global --> TestGlobal[test_global function<br/>accesses x with global]
```

**Common Patterns**

**Modifying module state:**

**Closure with state:**

**Multiple scope levels:**

**Key Differences**

**Global vs Nonlocal:**
- `global` reaches to module level (skips all intermediate scopes)
- `nonlocal` reaches to the nearest enclosing function scope (not global)
- `global` can declare variables that don't exist yet
- `nonlocal` requires the variable to exist in an enclosing scope

**Important Rules**

1. **Without declaration**: Assignments create new local variables
2. **With global**: Assignments modify module-level variables
3. **With nonlocal**: Assignments modify enclosing function's variables
4. **Reading vs Writing**: You can read outer scope variables without declarations; declarations are needed for assignment
5. **Multiple names**: Both statements support comma-separated variable lists
