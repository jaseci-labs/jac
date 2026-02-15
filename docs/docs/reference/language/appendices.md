# Appendices

**In this part:**

- [Appendix A: Complete Keyword Reference](#appendix-a-complete-keyword-reference) - All keywords
- [Appendix B: Operator Quick Reference](#appendix-b-operator-quick-reference) - Operators by category
- [Appendix C: Grammar Summary](#appendix-c-grammar-summary) - Simplified grammar
- [Appendix D: Common Gotchas](#appendix-d-common-gotchas) - Pitfalls to avoid
- [Appendix E: Migration from Python](#appendix-e-migration-from-python) - Conversion guide
- [Appendix F: LLM Provider Reference](#appendix-f-llm-provider-reference) - Model configuration

---

## Appendix A: Complete Keyword Reference

| Keyword | Category | Description |
|---------|----------|-------------|
| `abs` | Modifier | Abstract method/class (note: NOT `abstract`) |
| `and` | Operator | Logical AND (also `&&`) |
| `as` | Import | Alias |
| `assert` | Statement | Assertion |
| `async` | Modifier | Async function/walker |
| `await` | Expression | Await async |
| `break` | Control | Exit loop |
| `by` | Operator | Delegation operator (used by byllm for LLM) |
| `can` | Declaration | Ability (method on archetypes) |
| `case` | Control | Match/switch case |
| `cl` | Block | Client-side code block |
| `class` | Archetype | Python-style class definition |
| `continue` | Control | Next iteration |
| `def` | Declaration | Function |
| `default` | Control | Switch default case |
| `del` | Statement | Delete node/edge |
| `disengage` | OSP | Stop walker traversal |
| `edge` | Archetype | Edge type |
| `elif` | Control | Else if |
| `else` | Control | Else branch |
| `entry` | OSP | Entry event trigger |
| `enum` | Archetype | Enumeration |
| `except` | Control | Exception handler |
| `exit` | OSP | Exit event trigger |
| `finally` | Control | Finally block |
| `flow` | Concurrency | Start concurrent task |
| `for` | Control | For loop |
| `from` | Import | Import from |
| `glob` | Declaration | Global variable |
| `global` | Scope | Access global scope |
| `has` | Declaration | Instance field |
| `here` | OSP | Current node (in walker) |
| `if` | Control | Conditional |
| `impl` | Declaration | Implementation block |
| `import` | Module | Import |
| `in` | Operator | Membership |
| `include` | Module | Include/merge code |
| `init` | Method | Constructor |
| `is` | Operator | Identity |
| `lambda` | Expression | Anonymous function |
| `match` | Control | Pattern match |
| `node` | Archetype | Node type |
| `nonlocal` | Scope | Access nonlocal scope |
| `not` | Operator | Logical NOT |
| `obj` | Archetype | Object/class |
| `or` | Operator | Logical OR (also `\|\|`) |
| `override` | Modifier | Override method |
| `postinit` | Method | Post-constructor |
| `priv` | Access | Private |
| `props` | Reference | JSX props (client-side) |
| `protect` | Access | Protected |
| `pub` | Access | Public |
| `raise` | Statement | Raise exception |
| `report` | OSP | Report value from walker |
| `return` | Statement | Return value |
| `root` | OSP | Root node reference |
| `self` | Reference | Current instance |
| `sem` | Declaration | Semantic string |
| `skip` | Control | Skip (nested context) |
| `spawn` | OSP | Spawn walker |
| `static` | Modifier | Static member |
| `super` | Reference | Parent class |
| `sv` | Block | Server-side code block |
| `switch` | Control | Switch statement |
| `test` | Declaration | Test block |
| `to` | Control | For loop upper bound |
| `try` | Control | Try block |
| `visitor` | OSP | Visiting walker (in node) |
| `wait` | Concurrency | Wait for concurrent result |
| `walker` | Archetype | Walker type |
| `while` | Control | While loop |
| `with` | Statement | Context manager / entry block |
| `yield` | Statement | Generator yield |

**Notes:**

- The abstract keyword is `abs`, not `abstract`
- Logical operators have both word and symbol forms: `and`/`&&`, `or`/`||`
- `cl` and `sv` are block keywords for client/server code separation

---

## Appendix B: Operator Quick Reference

### Arithmetic

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `//` | Floor division |
| `%` | Modulo |
| `**` | Power |

### Comparison

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less or equal |
| `>=` | Greater or equal |

### Logical

| Operator | Description |
|----------|-------------|
| `and`, `&&` | Logical AND |
| `or`, `\|\|` | Logical OR |
| `not` | Logical NOT |

### Graph (OSP)

| Operator | Description |
|----------|-------------|
| `++>` | Forward connect |
| `<++` | Backward connect |
| `<++>` | Bidirectional connect |
| `+>:T:+>` | Typed forward |
| `<+:T:<+` | Typed backward |
| `<+:T:+>` | Typed bidirectional |
| `[-->]` | Outgoing edges |
| `[<--]` | Incoming edges |
| `[<-->]` | All edges |

### Pipe

| Operator | Description |
|----------|-------------|
| `\|>` | Forward pipe |
| `<\|` | Backward pipe |
| `:>` | Atomic forward |
| `<:` | Atomic backward |

---

## Appendix C: Grammar Summary

```
module        : STRING? element*              # Optional module docstring
element       : STRING? toplevel_stmt         # Optional statement docstring
toplevel_stmt : import | archetype | ability | impl | test | entry
              | (cl | sv) toplevel_stmt       # Client/server prefix
              | (cl | sv) "{" toplevel_stmt* "}"  # Client/server block

archetype     : async? (obj | node | edge | walker | enum) NAME inheritance? body
inheritance   : "(" NAME ("," NAME)* ")"
body          : "{" member* "}"

member        : has_stmt | ability | impl
has_stmt      : "has" (modifier)? NAME ":" type ("=" expr)? ";"
ability       : async? "can" NAME params? ("->" type)? event_clause? (body | ";")
event_clause  : "with" type_expr? (entry | exit)

import        : "import" (module | "from" import_path "{" names "}")
import_path   : (NAME ":")? dotted_name       # Optional namespace prefix (e.g., jac:module)
entry         : "with" "entry" (":" NAME)? body
test          : "test" NAME body
impl          : "impl" NAME "." NAME params body

visit_stmt    : "visit" (":" expr ":")? expr ("else" block)?  # Optional index selector
edge_ref      : "[" (edge | node)? edge_op filter? "]"

expr          : ... (standard expressions plus graph operators)

# Pattern matching
match_stmt    : "match" expr "{" case_clause* "}"
case_clause   : "case" pattern ":" stmt*
pattern       : literal | capture | sequence | mapping | class | as | or | star
```

---

## Appendix D: Common Gotchas

### 1. Semicolons Required

```jac
# Wrong - missing semicolons
# x = 5
# print(x)

# Correct
with entry {
    x = 5;
    print(x);
}
```

### 2. Braces Required for Blocks

```jac
# Wrong (Python style) - won't parse
# if condition:
#     do_something()

# Correct
def do_something() -> None {
    print("done");
}

with entry {
    condition = True;
    if condition {
        do_something();
    }
}
```

### 3. Type Annotations Required

```jac
# Wrong - missing type annotations
# def add(a, b) {
#     return a + b;
# }

# Correct
def add(a: int, b: int) -> int {
    return a + b;
}
```

### 4. `has` vs Local Variables

```jac
obj Example {
    has field: int = 0;  # Instance variable (with 'has')

    def method() {
        local = 5;  # Local variable (no 'has')
        self.field = local;
    }
}
```

### 5. Walker `visit` is Queued

```jac
walker Example {
    can traverse with Node entry {
        print("Visiting");
        visit [-->];  # Nodes queued, visited AFTER this method
        print("This prints before visiting children");
    }
}
```

### 6. `report` vs `return`

```jac
walker Example {
    can collect with Node entry {
        report here.value;  # Continues execution
        visit [-->];        # Still runs

        return here.value;  # Would stop here
    }
}
```

### 7. Global Modification Requires Declaration

```jac
glob counter: int = 0;

def increment -> None {
    global counter;  # Required!
    counter += 1;
}
```

---

## Appendix E: Migration from Python

### Class to Object

**Python:**

```python
class Person:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age

    def greet(self) -> str:
        return f"Hi, I'm {self.name}"
```

**Jac:**

```jac
obj Person {
    has name: str;
    has age: int;

    def greet() -> str {
        return f"Hi, I'm {self.name}";
    }
}

with entry {
    p = Person(name="Alice", age=30);
}
```

### Function

**Python:**

```python
def add(a: int, b: int) -> int:
    return a + b
```

**Jac:**

```jac
def add(a: int, b: int) -> int {
    return a + b;
}
```

### Control Flow

**Python:**

```python
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")
```

**Jac:**

```jac
with entry {
    x = 1;
    if x > 0 {
        print("positive");
    } elif x < 0 {
        print("negative");
    } else {
        print("zero");
    }
}
```

---

## Appendix F: LLM Provider Reference

| Provider | Model Names | Environment Variable |
|----------|-------------|---------------------|
| OpenAI | `gpt-4`, `gpt-4o`, `gpt-3.5-turbo` | `OPENAI_API_KEY` |
| Anthropic | `claude-3-opus`, `claude-3-sonnet` | `ANTHROPIC_API_KEY` |
| Google | `gemini-pro`, `gemini-ultra` | `GOOGLE_API_KEY` |
| Azure | `azure/gpt-4` | Azure config |
| Ollama | `ollama/llama2`, `ollama/mistral` | Local (no key) |

**Model Name Format:**

```
provider/model-name

Examples:
- gpt-4 (OpenAI, default provider)
- anthropic/claude-3-opus
- azure/gpt-4
- ollama/llama2
```

---

## Document Information

**Jac Language Reference**

Version: 3.1
Last Updated: January 2026

**Validation Status:** Validated against the Jac recursive descent parser (jaclang 0.10.0)

**Resources:**

- Website: [https://jaseci.org](https://jaseci.org)
- Documentation: [https://jac-lang.org](https://jac-lang.org)
- GitHub: [https://github.com/Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- Discord: [https://discord.gg/6j3QNdtcN6](https://discord.gg/6j3QNdtcN6)
