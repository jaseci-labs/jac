# Troubleshooting

Common issues and their solutions when working with Jac.

---

## Installation Issues

### ModuleNotFoundError: No module named 'jaclang'

**Cause:** Jac is not installed in your current Python environment.

**Solution:**

```bash
pip install jaseci
```

If using a virtual environment, make sure it's activated:

```bash
source .venv/bin/activate  # Linux/Mac
.venv\Scripts\activate     # Windows
```

### Plugin not found: byllm / jac-client / jac-scale

**Cause:** Plugin not installed or not enabled.

**Solution:**

```bash
# Install the plugin
pip install byllm        # For AI features
pip install jac-client   # For full-stack
pip install jac-scale    # For production deployment

# Or install all at once
pip install jaseci
```

### Command 'jac' not found

**Cause:** Jac CLI not in PATH or not installed.

**Solution:**

```bash
# Verify installation
pip show jaclang

# If installed but not in PATH, use python -m
python -m jaclang run myfile.jac
```

---

## Syntax Errors

### Unexpected token 'entry' / Missing handler

**Error:**

```
Walker did not execute any abilities
```

**Cause:** Walker spawned at root but missing `with Root entry` handler.

**Wrong:**

```jac
walker Greeter {
    can greet with Person entry {
        print(f"Hello, {here.name}!");
    }
}

with entry {
    root spawn Greeter();  # Nothing happens!
}
```

**Fix:** Add a root entry handler:

```jac
walker Greeter {
    can start with Root entry {
        visit [-->];  # Start visiting connected nodes
    }

    can greet with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];  # Continue to next nodes
    }
}
```

### Cannot assign: missing 'glob' keyword

**Error:**

```
Cannot assign to variable without 'glob' keyword in client context
```

**Cause:** Global variable assignment in `cl {}` block requires `glob`.

**Wrong:**

```
cl {
    AuthContext = createContext(None);  # Error!
}
```

**Fix:**

```jac
cl {
    glob AuthContext = createContext(None);  # Correct
}
```

### Enumerate unpacking syntax

**Error:**

```
Unexpected token 'i'
```

**Cause:** Enumerate unpacking needs parentheses.

**Wrong:**

```
for i, name in enumerate(names) {
    print(f"{i}: {name}");
}
```

**Fix:**

```jac
def example() {
    names = ["Alice", "Bob", "Charlie"];
    for (i, name) in enumerate(names) {
        print(f"{i}: {name}");
    }
}
```

### Non-default argument follows default argument

**Error:**

```
Non-default argument 'created_at' follows default argument 'completed'
```

**Cause:** Node/object attributes with defaults must come after required attributes.

**Wrong:**

```
node Task {
    has title: str;
    has completed: bool = False;
    has created_at: str;  # Error: non-default after default
}
```

**Fix:**

```jac
node Task {
    has title: str;
    has created_at: str;           # Required first
    has completed: bool = False;   # Defaults last
}
```

### Type name conflicts with Python builtin

**Error:**

```
'any' shadows built-in name
```

**Cause:** Using a type name that conflicts with Python builtins like `any`, `all`, `list`, etc.

**Fix:** Use a different variable name or explicit type:

```jac
obj Example {
    # Instead of: has value: any;
    has value: object;  # Or a specific type
}
```

---

## Cache & Setup Issues

### Bytecode Cache Problems

**Common symptoms:**

- `No module named 'jaclang.pycore'`
- Setup stalling during first-time compilation
- Strange errors after upgrading packages

**Solution:**

```bash
jac purge
```

This clears the global bytecode cache. Works even when the cache is corrupted.

> **💡 Tip:** Always run `jac purge` after upgrading Jaseci packages.

---

## Runtime Errors

### Walker reports are empty

**Cause:** Walker didn't visit any nodes or didn't call `report`.

**Debug steps:**

1. Verify nodes are connected to root:

```jac
with entry {
    print(f"Nodes connected to root: {len([-->])}");
}
```

1. Add debug prints in walker:

```jac
walker Debug {
    can start with Root entry {
        print("At root");
        print(f"Connected: {[-->]}");
        visit [-->];
    }

    can process with entry {
        print(f"Visiting: {here}");
    }
}
```

1. Ensure `report` is called:

```jac
can find with Person entry {
    print(f"Found: {here.name}");
    report here;  # Don't forget this!
    visit [-->];
}
```

### Graph query returns empty list

**Cause:** No nodes match the query filter.

**Debug:**

```jac
with entry {
    # Check all connections (no filter)
    all_nodes = [-->];
    print(f"All connected: {len(all_nodes)}");

    # Check with filter
    people = [-->](?:Person);
    print(f"People: {len(people)}");
}
```

**Common issues:**

- Nodes not connected to the right parent
- Type filter doesn't match (check spelling)
- Using wrong direction (`[-->]` vs `[<--]`)

### AttributeError: 'NoneType' has no attribute

**Cause:** Trying to access attributes on a None value.

**Debug:**

```jac
can process with entry {
    if here is not None {
        print(here.name);
    } else {
        print("here is None!");
    }
}
```

---

## Full-Stack Issues

### Server won't start: Address already in use

**Cause:** Port 8000 (default) is already in use.

**Solution:**

```bash
# Use a different port
jac start main.jac --port 8001

# Or find and kill the process using the port
lsof -i :8000  # Linux/Mac
netstat -ano | findstr :8000  # Windows
```

### Frontend not updating after changes

**Cause:** Hot Module Replacement (HMR) not working or cache issue.

**Solutions:**

1. Ensure you're using `--dev` flag:

```bash
jac start main.jac --dev
```

1. Hard refresh the browser: `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)

2. Clear browser cache and restart server

### API endpoint returns 401 Unauthorized

**Cause:** Walker requires authentication but request has no token.

**Solutions:**

1. Make walker public for testing:

```jac
walker:pub my_walker {  # Add :pub modifier
    # ...
}
```

1. Or include auth token in request:

```bash
curl -X POST http://localhost:8000/walker/my_walker \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### CORS error in browser console

**Cause:** Frontend and backend on different origins.

**Solution:** Configure CORS in `jac.toml`:

```toml
[plugins.scale.cors]
allow_origins = ["http://localhost:5173", "http://localhost:3000"]
allow_methods = ["GET", "POST", "PUT", "DELETE"]
allow_headers = ["*"]
```

### useWalker returns undefined

**Cause:** Walker response not being accessed correctly.

**Debug:**

```jac
cl {
    def MyComponent() {
        result = useWalker(my_walker, {});

        # Check the full response
        print("Result:", result);
        print("Reports:", result?.reports);

        # Access reports array
        if result and result.reports {
            for item in result.reports {
                print(item);
            }
        }
    }
}
```

See [Walker Responses](../reference/language/walker-responses.md) for details on the response structure.

---

## AI Integration Issues

### API key not found

**Error:**

```
AuthenticationError: No API key provided
```

**Solution:**

Set the environment variable for your LLM provider in the same terminal where you run `jac`:

```bash
# Anthropic (used in the tutorials)
export ANTHROPIC_API_KEY="sk-ant-..."

# OpenAI
export OPENAI_API_KEY="sk-..."

# Google
export GOOGLE_API_KEY="..."
```

### Rate limit exceeded

**Error:**

```
RateLimitError: Rate limit reached
```

**Solutions:**

1. Add delays between requests
2. Use a smaller/cheaper model for testing:

```jac
glob llm = Model(model_name="gpt-4o-mini");  # Cheaper than gpt-4
```

1. Implement caching for repeated queries

### Model not responding / timeout

**Cause:** Network issues or model overloaded.

**Solutions:**

1. Check your internet connection
2. Verify API key is valid
3. Try a different model:

```jac
# Try different providers
glob llm = Model(model_name="claude-3-haiku");  # Anthropic
glob llm = Model(model_name="gpt-4o-mini");     # OpenAI
```

### LLM returns unexpected format

**Cause:** Model not following the expected output structure.

**Solution:** Use structured outputs with type hints:

```jac
"""Extract person info from text."""
def extract_person(text: str) -> PersonInfo by llm();

obj PersonInfo {
    has name: str;
    has age: int;
    has occupation: str;
}
```

See [Structured Outputs](ai/structured-outputs.md) for more details.

---

## Getting More Help

### Debug Mode

Run with debug output:

```bash
jac run myfile.jac --verbose
```

### Check Syntax

Validate code without running:

```bash
jac check myfile.jac
```

### Community Resources

- **Discord:** [Join the Jac community](https://discord.gg/jaseci)
- **GitHub Issues:** [Report bugs](https://github.com/Jaseci-Labs/jaseci/issues)
- **JacGPT:** [Ask questions](https://jac-gpt.jaseci.org)

---

## Quick Reference: Common Fixes

| Error | Quick Fix |
|-------|-----------|
| Cache/setup errors (`jaclang.pycore`, `NodeAnchor`, stalling) | Run `jac purge` |
| Walker doesn't run | Add `can start with Root entry { visit [-->]; }` |
| Missing glob keyword | Use `glob var = value;` in `cl {}` blocks |
| Enumerate unpacking | Use `for (i, x) in enumerate(...)` |
| Attribute order | Put required attributes before defaults |
| Empty reports | Check node connections and `report` calls |
| 401 Unauthorized | Add `:pub` modifier to walker or include auth token |
| CORS error | Configure `[plugins.scale.cors]` in jac.toml |
| API key missing | Set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GOOGLE_API_KEY` environment variable |
