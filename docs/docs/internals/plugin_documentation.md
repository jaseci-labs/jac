#  Plugin Foundation Documentation

## Overview

The `machine.py` file forms the **foundation of plugin functionality** in the Jaseci Cloud architecture. It leverages the **Pluggy** library to define a flexible and modular **plugin system** using a **hook mechanism**.

This document provides a detailed breakdown of how plugins are structured and implemented in `machine.py`, including all relevant classes and static methods. It is designed to help contributors and maintainers understand this file independently, without needing a full view of the entire Jaseci codebase.

---

##  What is Pluggy?

**Pluggy** is a lightweight plugin system library used extensively in projects like **pytest**. It allows defining:

- **Hook specifications** (`@hookspec`) — method signatures to be implemented.
- **Hook implementations** (`@hookimpl`) — actual logic for the hooks.
- **Plugin Manager** to register, manage, and dispatch hook calls dynamically.

---

##  Plugin Architecture class implementation

### Classes Implemented

| Class   | Role                                                                 |
|---------|----------------------------------------------------------------------|
| `Spec`  | Defines placeholder methods that plugin implementations must implement.For declaring the method interfaces. It doesn't do anything itself but tells pluggy what hooks are available. |
| `Impl`  | For registering actual implementations using `@hookimpl`|
| `Proxy` | For calling plugin methods from the outside, through plugin_manager.hook.<method>() |

---

## good example to understand the 3 classes and use of proxy class
You're building a plugin-driven data pipeline framework.
Each plugin can implement one or more of:

- load_data(source: str) -> dict

- transform_data(data: dict) -> dict

- save_data(data: dict, target: str) -> None

We will:

- Declare a hook spec

- Implement two plugins (one for CSV, one for JSON)

- Dynamically generate a proxy interface

- Run a pipeline using the proxy

Lets implement the 2 plugins CSVPlugin and JSONPlugin

```python
import pluggy

hookspec = pluggy.HookspecMarker("pipeline")
hookimpl = pluggy.HookimplMarker("pipeline")

class PipelineSpec:
    @hookspec(firstresult=True)
    def load_data(self, source: str) -> dict:
        """Loads data from a source."""

    @hookspec
    def transform_data(self, data: dict) -> dict:
        """Transforms the given data."""

    @hookspec
    def save_data(self, data: dict, target: str) -> None:
        """Saves data to the target."""

class CSVPlugin:
    @hookimpl
    def load_data(self, source: str) -> dict:
        if source.endswith(".csv"):
            print(f"Loading CSV from {source}")
            return {"data": [1, 2, 3]}
        return None

    @hookimpl
    def transform_data(self, data: dict) -> dict:
        print("Transforming CSV data by squaring...")
        data["data"] = [x * x for x in data["data"]]
        return data

class JSONPlugin:
    @hookimpl
    def load_data(self, source: str) -> dict:
        if source.endswith(".json"):
            print(f"Loading JSON from {source}")
            return {"data": [10, 20, 30]}
        return None

    @hookimpl
    def save_data(self, data: dict, target: str) -> None:
        print(f"Saving data to {target}: {data}")

```

Lets register the plugins and create a dynamic proxy that can help to decide what plugin method to implement

```python
import pluggy
from specs import PipelineSpec, CSVPlugin, JSONPlugin

plugin_manager = pluggy.PluginManager("pipeline")
plugin_manager.add_hookspecs(PipelineSpec)
plugin_manager.register(CSVPlugin())
plugin_manager.register(JSONPlugin())

def make_proxy_method(name):
    def proxy_method(self, *args, **kwargs):
        return getattr(self.plugin_manager.hook, name)(*args, **kwargs)
    return proxy_method

def generate_proxy_class(hook_names: list[str]):
    methods = {name: make_proxy_method(name) for name in hook_names}
    methods["__init__"] = lambda self, plugin_manager: setattr(self, "plugin_manager", plugin_manager)
    return type("Proxy", (), methods)

hook_names = ["load_data", "transform_data", "save_data"]
Proxy = generate_proxy_class(hook_names)


```

Lets use the proxy to call the plugins methods adoptively

```python
proxy = Proxy(plugin_manager)

# Step 1: Load data
source = "file.csv"
data = proxy.load_data(source)

# Step 2: Transform (all plugins get to contribute)
data = proxy.transform_data(data)

# Step 3: Save (only plugins with save_data do it)
proxy.save_data(data, "output.json")


```
It will return

```text
Loading CSV from file.csv
Transforming CSV data by squaring...
Saving data to output.json: {'data': [1, 4, 9]}

```
You can see it calls the transforming and saving method dynamically but for loading data it calls the CSVPlugin instead of JSONPlugin. The reason is CSVPlugin is registered first. Give it a try by changing the order of registration. In jaclang we have implemented internally for the proxy to use the last registered method instead of first implementation.c
## What does JacmachineInterface class do

This class is the core **interface layer** of the plugin system. It:

- Inherits and composes multiple core classes like `JacClassReferences`, `JacNode`, `JacEdge`, etc.
- Bridges access between static utility classes and plugin-enabled logic.
- Allows static access patterns for interacting with various components like walkers, access control, etc.

### Inherited Static Classes

- `JacClassReferences`
- `JacAccessValidation`: Static functions related to access/permission managment in Jac are implemented
- `JacNode`: Static functions related to nodes are implemented
- `JacEdge`: Static functions related to edges are implemented(only one function can be merged with JacNode)
- `JacWalker` : Missing documentation.
- `JacBuiltin`: Centralized reference holder for core Jaseci class and type aliases.
- `JacCmd`: Static functions related to cmd implementation
- `JacBasics` : Missing documentation.
- `JacUtils`: utility functions related to Jac are implemented

---

## How to Implement a Plugin

### Step 1: Define an Implementation Method with `@hookimpl`

```python
from jaclang.runtimelib.machine import hookimpl

@hookimpl
def get_edges_with_node(...):
```


### Step 2: Register Your Plugin with the Plugin Manager
```python
plugin_manager.register(YourPluginClass())
```

## Static Methods that can be plugged in

The following static methods are exposed through the plugin interface and can be improved using hook implementation

| **Function**             | **Notes**                                                                 |
|--------------------------|---------------------------------------------------------------------------|
| `connect`                | Needs better description — what kind of connection? What parameters?      |
| `disconnect`             | Clarify whether it's object-to-object disconnection or session-related.   |
| `perm_grant`             | Rename or clarify — it grants permission to everyone.                     |
| `perm_revoke`            | Removes all permissions — state scope and cascading effects.              |
| `check_read_access`      | Widely used — should include examples and return behavior.                |
| `check_write_access`     | Add detailed context on when and why it’s triggered.                      |
| `check_connect_access`   | Explain with use case and expected outcome.                               |
| `check_access_level`     | Critical access logic — needs detailed breakdown.                         |
| `get_edges_with_node`    | Clarify difference from `get_edges`. Add real-world usage scenarios.      |
| `edges_to_nodes`         | Misleading name — it means “get connected nodes”. Rename or explain.      |
| `remove_edge`            | Common function — include code samples or visual diagrams.                |
| `visit` / `ignore`       | Missing docstrings — clarify usage context and purpose.                   |
| `spawn_call`             | Describe lifecycle and execution flow clearly.                            |
| `async_spawn_call`       | Needs distinct async-specific explanation (currently same as `spawn_call`).|
| `disengage`              | Explain context — e.g., walker termination, access cleanup, etc.          |
| `setup`                  | Clarify what is being setup — graph, context, permissions, etc.?          |
| `reset_graph`            | Clarify whether it's a full or partial reset — and when to use it.        |
| `make_archetype`         | Add explanation about its role in object/class/type creation.             |
| `impl_patch_filename`    | Explain purpose — dynamic patching, hot reloading, etc.                   |
| `jac_import`             | Key function — handles `.jac` and `.py` imports. Needs examples and context. |
