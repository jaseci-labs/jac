#  Jac Plugins

## What is a JAC Plugin?
JAC is a powerful language that can be extended with plugins. JAC plugins are Python packages that extend the functionality of JAC. You can create custom commands, functions, and modules that can be used in JAC scripts.

## How is it enabled by Jaseci?

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

- `JacAccessValidation`: Static functions related to access/permission managment in Jac
- `JacNode`: Static functions related to nodes
- `JacEdge`: Static functions related to edges
- `JacWalker` : Static functions related to managing the traversal and control flow of Jac walkers
- `JacClassReferences`: Centralized reference holder for core Jaseci class and type aliases
- `JacBuiltin`: Jac Builtins
- `JacCmd`: Static functions related to cmd implementation
- `JacBasics` :  Core utility class providing basic operations for managing Jac execution context and graph lifecycle.
- `JacUtils`: utility functions

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

| **Function**                  | **Description**                                                                 |
|-------------------------------|---------------------------------------------------------------------------------|
| `setup`                       | Set Class References|
| `get_context`                 | Get current execution context|
| `set_context`                 | Set the context for the machin|
| `reset_graph`                 | Purge current or target graph|
| `get_object`                  | Get object given id|
| `object_ref`                  | Get object reference id|
| `make_archetype`              | Create a obj archetype|
| `impl_patch_filename`         | Override a function’s filename in tracebacks with a custom path using a decorator|
| `jac_import`                  | Dynamically import a Jac or Python module|
| `jac_test`                    | Create a test|
| `run_test`                    | Run the test suite in the specified .jac file|
| `refs`                        | Retrieve node and edge references via a DataSpatialPath|
| `filter`                      | filter by archetype|
| `connect`                     | Jac's connect operator feature.Defines how 2 nodes should be connected|
| `disconnect`                  | Jac's disconnect operator feature|
| `assign`                      | Jac's assign comprehension feature|
| `root`                        | Jac's root getter|
| `get_all_root`                | Get all the roots|
| `build_edge`                  | Build and connect an edge between two nodes|
| `save`                        | Save an Archetype or Anchor object into the current execution context memory|
| `destroy`                     | Destroy one or more Archetype or Anchor objects|
| `entry`                       | Mark a method as jac entry using decorator|
| `exit`                        | Mark a method as jac exit using decorator|
| `sem`                         | Attach the semstring to the given object with this decorator|
| `call_llm`                    |Call the LLM model|
| `attach_program`              | Attach a JacProgram to the machine|
| `load_module`                 | Load a module into the machine|
| `list_modules`                | List all loaded modules|
| `list_walkers`                |List all walkers in a specific module |
| `list_nodes`                  | List all nodes in a specific module|
| `load_edges`                  | List all edges in a specific module|
| `create_archetype_from_source`| Dynamically creates archetypes (nodes, walkers, etc.) from Jac source code|
| `update_walker`               | Reload and update a previously loaded Jac module|
| `spawn_node`                  |Spawn a node instance of the given node_name with attributes|
| `spawn_walker`                | pawn a walker instance of the given walker_name|
| `get_archetype`               |Retrieve an archetype class from a module|
| `thread_run`                  |Run a function in a thread|
| `thread_wait`                 |Wait for a thread to finish|
| `set_base_path`               | Set the base path for the machine|
| `reset_machine`               |Reset the machine|
| `elevate_root`                | Elevate context root to system_root|
| `allow_root`                  | Allow all access from target root graph to current Archetype|
| `disallow_root`               | Disallow all access from target root graph to current Archetype|
| `perm_grant`                  | Grant the specified access level to all users for the given Archetype|
| `perm_revoke`                 | Revoke all access permissions on the given Archetype, effectively disallowing others|
| `check_read_access`           | Read Access Validation for anchor|
| `check_write_access`          | Write Access Validation for anchor|
| `check_connect_access`        | Connect Access Validation for anchor|
| `check_access_level`          |Determine the access level for given|
| `node_dot`                    | Generate Dot file for visualizing nodes and edges|
| `get_edges`                   | Get edges connected to the node|
| `get_edges_with_node`         | Get edges connected to the origin node and the desitnation node|
| `edges_to_nodes`              | Get set of nodes connected to this node|
| `remove_edge`                 | Remove an edge reference from a node's edge list without sync checks|
| `jac_test`                    | Create a test|
| `run_test`                    | Run the test suite in the specified .jac file|
| `visit`                       | Jac's visit stmt feature|
| `ignore`                      | Jac's visit stmt feature|
| `report`                      | Jac's report stmt feature|
| `disengage`                   | Jac's disengage stmt feature|
| `spawn_call`                  | Execute the walker’s traversal starting from the given node or edge|
| `async_spawn_call`            | Execute the walker’s traversal starting from the given node or edge asynchronously|
| `spawn`                       | Schedule the walker to traverse one or more target archetypes without immediate execution|
| `printgraph`                  | Generate graph for visualizing nodes and edges |
| `create_cmd`                  | Create Jac CLI cmds |

## How to Create a JAC Plugin?

Let's create a simple plugin that will add a new command to Jac CLI. The command will be called `hello` and will print `Hello, World!` to the console.

**Step 1: Create a new directory for your plugin.** I will call mine `my_plugin`.
```bash
mkdir my_plugin
cd my_plugin
```

**Step 2: Install necessary dependencies.** (It is recommended to use a virtual environment)
```bash
pip install poetry
```

**Step 3: Create a new Python package.**
```bash
poetry init
# Fill in the details
# for compatible python version, use 3.12
```

**Step 4: Add necessary dependencies.**
```bash
poetry add jaclang
poetry add pytest --group dev
```

**Step 5: Create the necessary folders and files.**
```bash
mkdir my_plugin # Use the name of your plugin. This is where the plugin code will go.
touch my_plugin/__init__.py
touch my_plugin/plugin.py
```

**Step 6: Link your plugin to Jaclang.**
Open the `pyproject.toml` file and add the following lines before `[build-system]`
```toml
[tool.poetry.plugins."jac"]
"my_plugin" = "my_plugin.plugin:JacCmd"
```

**Step 7: Implement the plugin.**
Open `my_plugin/plugin.py` and add the following code.
```python
from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.default import hookimpl

class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Creating Jac CLI cmds."""

        @cmd_registry.register
        def hello():
            """Prints Hello, World!"""
            print("Hello, World!")
```

**Step 8: Install the plugin.**
```bash
poetry install
```

**Step 9: Run the plugin.**
```bash
jac hello
```

You should see `Hello, World!` printed to the console.

That's it! You have created your first JAC plugin. You can now extend JAC with your own custom commands.

### Next Steps
- Now you can publish your plugin to PyPI and share it with the world. Follow the [Publishing Python Packages](https://packaging.python.org/tutorials/packaging-projects/) guide to learn how to publish your plugin.
- Don't forget to create a nice README and add some examples to help users understand how to use your plugin.

> **Note:**
> For more examples, check out the [JAC Plugin Examples](https://github.com/Jaseci-Labs/jaclang/tree/main/examples/plugins)

>Check out the [MTLLM Plugin](https://github.com/Jaseci-Labs/mtllm) for a more complex example. Where we have created a plugin that adds LLM functionality to JAC.

If you have any questions, feel free to ask in the [Community Channel]().