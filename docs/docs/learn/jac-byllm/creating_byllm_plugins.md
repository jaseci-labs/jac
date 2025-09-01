# Creating byLLM Plugins

This document describes how to create plugins for byLLM (Multi-Modal Large Language Model), which is a plugin system for Jaclang's `by llm()` feature.

## Understanding the Plugin System

byLLM uses a plugin architecture based on [Pluggy](https://pluggy.readthedocs.io/), the same plugin system used by pytest. Plugins allow you to extend or modify how byLLM handles LLM calls in Jaclang programs.

### How Plugins Work

When Jaclang's `by llm()` syntax is used, the runtime system looks for registered plugins that implement the `call_llm` hook. This enables:

- Implement custom LLM providers
- Add preprocessing/postprocessing logic
- Implement caching mechanisms
- Add logging or monitoring
- Create mock implementations for testing

## Plugin Architecture Overview

The plugin system consists of three main components:

1. **Hook Specifications**: Define the interface that plugins must implement
2. **Hook Implementations**: Your plugin code that implements the hooks
3. **Plugin Registration**: How plugins are discovered and loaded

## Creating Your First Plugin

### Step 1: Set Up Your Plugin Package

Create a Python package for the plugin:

```
my-byllm-plugin/
├── pyproject.toml
├── README.md
└── my_byllm_plugin/
    ├── __init__.py
    └── plugin.py
```

### Step 2: Define Your Plugin Class

Create the plugin implementation in `my_byllm_plugin/plugin.py`:

```python
"""Custom byLLM Plugin."""

from typing import Callable

from jaclang.runtimelib.machine import hookimpl
from byllm.llm import Model


class MybyllmMachine:
    """Custom byLLM Plugin Implementation."""

    @staticmethod
    @hookimpl
    def call_llm(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Custom LLM call implementation."""
        # Custom logic implementation
        print(f"Custom plugin intercepted call to: {caller.__name__}")
        print(f"Arguments: {args}")

        # Option 1: Modify the call and delegate to the original model
        result = model.invoke(caller, args)

        # Option 2: Implement completely custom logic
        # result = your_custom_llm_logic(caller, args)

        print(f"Result: {result}")
        return result
```

### Step 3: Configure Package Registration

Register the plugin using entry points in `pyproject.toml`:

```toml
[tool.poetry]
name = "my-byllm-plugin"
version = "0.1.0"
description = "My custom byLLM plugin"
authors = ["Your Name <your.email@example.com>"]

[tool.poetry.dependencies]
python = "^3.11"
byllm = "*"
jaclang = "*"

[tool.poetry.plugins."jac"]
my-byllm-plugin = "my_byllm_plugin.plugin:MybyllmMachine"

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"
```

### Step 4: Install and Test Your Plugin

1. Install the plugin in development mode:
   ```bash
   pip install -e .
   ```

2. Create a test Jaclang file to verify plugin functionality:
   ```jaclang
   import:py from byllm, Model;

   glob llm = Model(model_name="gpt-3.5-turbo");

   can test_plugin {
       result = get_answer("What is 2+2?") by llm();
       print(result);
   }

   can get_answer(question: str) -> str by llm();

   with entry {
       test_plugin();
   }
   ```

3. Run the test:
   ```bash
   jac run test.jac
   ```

## Advanced Plugin Examples

### Example 1: Caching Plugin

```python
"""Caching byLLM Plugin."""

import hashlib
import json
from typing import Callable, Any

from jaclang.runtimelib.machine import hookimpl
from byllm.llm import Model


class CachingbyllmMachine:
    """Plugin that caches LLM responses."""

    _cache: dict[str, Any] = {}

    @staticmethod
    @hookimpl
    def call_llm(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Cache LLM responses."""
        # Create cache key from function and arguments
        cache_key = hashlib.md5(
            json.dumps({
                "function": caller.__name__,
                "args": str(args),
                "model": model.model_name
            }, sort_keys=True).encode()
        ).hexdigest()

        # Check cache first
        if cache_key in CachingbyllmMachine._cache:
            print(f"Cache hit for {caller.__name__}")
            return CachingbyllmMachine._cache[cache_key]

        # Call original implementation
        result = model.invoke(caller, args)

        # Store in cache
        CachingbyllmMachine._cache[cache_key] = result
        print(f"Cached result for {caller.__name__}")

        return result
```

### Example 2: Logging Plugin

```python
"""Logging byLLM Plugin."""

import time
from typing import Callable

from jaclang.runtimelib.machine import hookimpl
from byllm.llm import Model


class LoggingbyllmMachine:
    """Plugin that logs all LLM calls."""

    @staticmethod
    @hookimpl
    def call_llm(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Log LLM calls with timing information."""
        start_time = time.time()

        print(f"[LLM CALL] Starting: {caller.__name__}")
        print(f"[LLM CALL] Model: {model.model_name}")
        print(f"[LLM CALL] Args: {args}")

        try:
            result = model.invoke(caller, args)
            duration = time.time() - start_time

            print(f"[LLM CALL] Completed: {caller.__name__} in {duration:.2f}s")
            print(f"[LLM CALL] Result: {result}")

            return result

        except Exception as e:
            duration = time.time() - start_time
            print(f"[LLM CALL] Failed: {caller.__name__} after {duration:.2f}s")
            print(f"[LLM CALL] Error: {e}")
            raise
```

### Example 3: Custom Model Provider

```python
"""Custom Model Provider Plugin."""

from typing import Callable

from jaclang.runtimelib.machine import hookimpl
from byllm.llm import Model


class CustomProviderMachine:
    """Plugin that implements a custom model provider."""

    @staticmethod
    @hookimpl
    def call_llm(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Handle custom model providers."""

        # Check if this is a custom model
        if model.model_name.startswith("custom://"):
            return CustomProviderMachine._handle_custom_model(
                model, caller, args
            )

        # Delegate to default implementation
        return model.invoke(caller, args)

    @staticmethod
    def _handle_custom_model(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Implement custom model logic."""
        model_type = model.model_name.replace("custom://", "")

        if model_type == "echo":
            # Simple echo model for testing
            return f"Echo: {list(args.values())[0]}"
        elif model_type == "random":
            # Random response model
            import random
            responses = ["Yes", "No", "Maybe", "I don't know"]
            return random.choice(responses)
        else:
            raise ValueError(f"Unknown custom model: {model_type}")
```

## Plugin Hook Reference

### call_llm Hook

The primary hook that all byLLM plugins implement:

```python
@hookimpl
def call_llm(
    model: Model,
    caller: Callable,
    args: dict[str | int, object]
) -> object:
    """
    Called when Jaclang executes a 'by llm()' statement.

    Args:
        model: The Model instance with configuration
        caller: The function being called with LLM
        args: Arguments passed to the function

    Returns:
        The result that should be returned to the Jaclang program
    """
```

## Best Practices

### 1. Handle Errors Gracefully

```python
@hookimpl
def call_llm(model: Model, caller: Callable, args: dict[str | int, object]) -> object:
    try:
        return model.invoke(caller, args)
    except Exception as e:
        # Log error and provide fallback
        print(f"LLM call failed: {e}")
        return "Error: Unable to process request"
```

### 2. Preserve Original Functionality

Unless you're completely replacing the LLM functionality, always delegate to the original implementation:

```python
@hookimpl
def call_llm(model: Model, caller: Callable, args: dict[str | int, object]) -> object:
    # Your pre-processing logic
    result = model.invoke(caller, args)  # Delegate to original
    # Your post-processing logic
    return result
```

### Use Configuration

Configure plugin behavior:

```python
class ConfigurableMachine:
    def __init__(self):
        self.config = self._load_config()

    def _load_config(self):
        # Load from environment, file, etc.
        return {"enabled": True, "log_level": "INFO"}

    @hookimpl
    def call_llm(self, model: Model, caller: Callable, args: dict[str | int, object]) -> object:
        if not self.config["enabled"]:
            return model.invoke(caller, args)

        # Plugin logic implementation
```

### 4. Testing Your Plugin

Create comprehensive tests:

```python
import pytest
from byllm.llm import Model
from my_byllm_plugin.plugin import MybyllmMachine

def test_plugin():
    machine = MybyllmMachine()
    model = Model("mockllm", outputs=["test response"])

    def test_function(x: str) -> str:
        """Test function."""
        pass

    result = machine.call_llm(model, test_function, {"x": "test input"})
    assert result == "test response"
```

## Plugin Discovery and Loading

Plugins are automatically discovered and loaded when:

1. They're installed as Python packages
2. They register the `"jac"` entry point in their `pyproject.toml`
3. Jaclang is imported or run

The discovery happens in `jaclang/__init__.py`:

```python
plugin_manager.load_setuptools_entrypoints("jac")
```

## Debugging Plugins

### Enable Debug Logging

Set environment variables to see plugin loading:

```bash
export JAC_DEBUG=1
jac run your_script.jac
```

### Verify Plugin Registration

Check if the plugin is loaded:

```python
from jaclang.runtimelib.machine import plugin_manager

# List all registered plugins
for plugin in plugin_manager.get_plugins():
    print(f"Loaded plugin: {plugin}")
```

## Common Pitfalls

1. **Not using `@hookimpl` decorator**: Methods won't be recognized as hook implementations
2. **Incorrect entry point name**: Must be `"jac"` for discovery
3. **Wrong hook signature**: Must match exactly: `call_llm(model, caller, args)`
4. **Forgetting to delegate**: If `model.invoke()` is not called, original functionality is lost

## Conclusion

byLLM plugins extend Jaclang's LLM capabilities through a clean, extensible plugin system. Plugins can add caching, logging, custom providers, and other functionality to enhance the LLM experience.

Key considerations:
- Follow the hook specification exactly
- Test thoroughly with different scenarios
- Document plugin functionality
- Consider backward compatibility
- Handle errors gracefully

For more examples and advanced use cases, see the [official byLLM plugin](https://github.com/Jaseci-Labs/jaclang/tree/main/jac-byllm) implementation.
