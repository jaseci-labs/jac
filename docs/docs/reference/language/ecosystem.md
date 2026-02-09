# Part VIII: Ecosystem

**In this part:**

- [CLI Reference](#cli-reference) - Execution, compilation, testing commands
- [Plugin System](#plugin-system) - Installing and managing plugins
- [Project Configuration](#project-configuration) - jac.toml settings
- [Python Interoperability](#python-interoperability) - Using Python from Jac
- [JavaScript/TypeScript Interoperability](#javascripttypescript-interoperability) - Using JS from Jac

---

The Jac ecosystem includes the `jac` CLI tool, a plugin system for extending functionality, and seamless interoperability with Python and JavaScript. This part covers the practical tools you'll use daily when developing with Jac.

## CLI Reference

The `jac` command is your primary interface to the Jac toolchain. It handles execution, compilation, testing, formatting, and project management. Most commands work on `.jac` files directly.

### 1 Execution Commands

| Command | Description |
|---------|-------------|
| `jac run <file>` | Execute Jac program |
| `jac enter <file> <entry>` | Run named entry point |
| `jac start [file]` | Start web server |
| `jac debug <file>` | Run in debug mode |

### 2 Analysis Commands

| Command | Description |
|---------|-------------|
| `jac check` | Type check code |
| `jac format` | Format source files |
| `jac test` | Run test suite |

### 3 Transform Commands

| Command | Description |
|---------|-------------|
| `jac py2jac <file>` | Convert Python to Jac |
| `jac jac2py <file>` | Convert Jac to Python |
| `jac js <file>` | Compile to JavaScript |

### 4 Project Commands

| Command | Description |
|---------|-------------|
| `jac create` | Create new project |
| `jac install` | Install all dependencies (pip, git, plugins) |
| `jac add <pkg>` | Add dependency |
| `jac remove <pkg>` | Remove dependency |
| `jac update [pkg]` | Update dependencies to latest compatible versions |
| `jac clean` | Clean build artifacts |
| `jac script <name>` | Run project script |

### 5 Tool Commands

| Command | Description |
|---------|-------------|
| `jac dot <file>` | Generate graph visualization |
| `jac lsp` | Start language server |
| `jac config` | Manage configuration |
| `jac plugins` | Manage plugins |

---

## Plugin System

### 1 Available Plugins

| Plugin | Package | Description |
|--------|---------|-------------|
| byllm | `pip install byllm` | LLM integration |
| jac-client | `pip install jac-client` | Full-stack web development |
| jac-scale | `pip install jac-scale` | Production deployment |
| jac-super | `pip install jac-super` | Enhanced console output |

### 2 Managing Plugins

```bash
# List plugins
jac plugins list

# Enable plugin
jac plugins enable byllm

# Disable plugin
jac plugins disable byllm

# Plugin info
jac plugins info byllm
```

### 3 Plugin Configuration

In `jac.toml`:

```toml
[plugins.byllm]
enabled = true
default_model = "gpt-4"

[plugins.client]
port = 5173
typescript = false

[plugins.scale]
replicas = 3
```

---

## Project Configuration

### 1 jac.toml Structure

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry = "main.jac"

[dependencies]
numpy = "^1.24.0"
pandas = "^2.0.0"

[dependencies.dev]
pytest = "^7.0.0"

[dependencies.npm]
react = "^18.0.0"
"@mui/material" = "^5.0.0"

[plugins.byllm]
default_model = "gpt-4"

[plugins.client]
port = 5173

[scripts]
dev = "jac start main.jac --dev"
test = "jac test"
build = "jac build"

[environments.production]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
```

### 2 Running Scripts

```bash
jac script dev
jac script test
jac script build
```

### 3 Configuration Profiles

Jac supports multi-file configuration with profile-based overrides.

**File loading order** (lowest to highest priority):

| File | When loaded | Git tracked? |
|------|-------------|--------------|
| `jac.toml` | Always | Yes |
| `jac.<profile>.toml` | When `--profile` or `JAC_PROFILE` is set | Yes |
| `[environments.<profile>]` in `jac.toml` | When profile is set | Yes |
| `jac.local.toml` | Always if present | No (gitignored) |

**Using profiles:**

```bash
# Via --profile flag
jac run app.jac --profile prod
jac start --profile staging

# Via JAC_PROFILE environment variable
JAC_PROFILE=ci jac test

# Via jac.toml default
# [environment]
# default_profile = "dev"
```

**Example `jac.prod.toml`:**

```toml
[serve]
port = 80

[plugins.byllm]
default_model = "gpt-4"
```

**Example `jac.local.toml`** (gitignored, developer-specific):

```toml
[serve]
port = 9000

[run]
cache = false
```

> **Note:** `JAC_ENV` is deprecated. Use `JAC_PROFILE` instead.

### 4 Environment Variables

**Server-side:**

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `REDIS_HOST`, `REDIS_PORT` | Redis connection |
| `MONGO_URI`, `MONGO_DB` | MongoDB connection |
| `JWT_SECRET` | JWT signing secret |

**Client-side (Vite):**

Variables prefixed with `VITE_` are exposed to client:

```toml
# .env
VITE_API_URL=https://api.example.com
```

```jac
cl {
    def:pub app() -> any {
        api_url = import.meta.env.VITE_API_URL;
        return <div>{api_url}</div>;
    }
}
```

---

## Python Interoperability

> **Deep Dive:** For comprehensive coverage of Python integration patterns, adoption strategies, and transpilation details, see [Python Integration](python-integration.md).

### 1 Using Python Libraries

```jac
import numpy as np;
import pandas as pd;
import from sklearn.linear_model { LinearRegression }

with entry {
    # NumPy
    arr = np.array([1, 2, 3, 4, 5]);
    print(f"Mean: {np.mean(arr)}");

    # Pandas
    df = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]});
    print(df.describe());

    # Scikit-learn
    model = LinearRegression();
}
```

### 2 Inline Python Blocks

```jac
::py::
import numpy as np

def complex_calculation(data):
    """Pure Python for performance-critical code."""
    arr = np.array(data)
    return arr.mean(), arr.std()
::py::

with entry {
    (mean, std) = complex_calculation([1, 2, 3, 4, 5]);
    print(f"Mean: {mean}, Std: {std}");
}
```

**When to use inline Python:**

- Complex Python-only APIs
- Performance-critical numerical code
- Legacy code integration

**When NOT to use:**

- Simple imports (use `import` instead)
- New code that could use Jac features

### 3 Type Compatibility

| Jac Type | Python Type |
|----------|-------------|
| `int` | `int` |
| `float` | `float` |
| `str` | `str` |
| `bool` | `bool` |
| `list` | `list` |
| `dict` | `dict` |
| `tuple` | `tuple` |
| `set` | `set` |
| `None` | `None` |

### 4 Using Jac from Python

```python
from jaclang import jac_import

# Import Jac module
my_module = jac_import("my_module.jac")

# Use exported functions/classes
result = my_module.my_function(arg1, arg2)
instance = my_module.MyClass()
```

---

## JavaScript/TypeScript Interoperability

### 1 npm Packages

```jac
cl {
    import from react { useState, useEffect, useCallback }
    import from "@tanstack/react-query" { useQuery, useMutation }
    import from lodash { debounce, throttle }
    import from axios { default as axios }
}
```

### 2 TypeScript Support

Enable in `jac.toml`:

```toml
[plugins.client]
typescript = true
```

### 3 Browser APIs

```jac
cl {
    def:pub app() -> any {
        # Window
        width = window.innerWidth;

        # LocalStorage
        window.localStorage.setItem("key", "value");
        value = window.localStorage.getItem("key");

        # Document
        element = document.getElementById("my-id");

        return <div>{width}</div>;
    }

    # Fetch
    async def load_data() -> None {
        response = await fetch("/api/data");
        data = await response.json();
    }
}
```

---
