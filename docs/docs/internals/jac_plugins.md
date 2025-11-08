# **Jac Plugins**

## What is a JAC Plugin?
JAC is a powerful language that can be extended with plugins. JAC plugins are Python packages that extend the functionality of JAC. You can create custom commands, functions, and modules that can be used in JAC scripts.

> **TLDR**
> Checkout the examples in the [JAC Plugin Examples](https://github.com/Jaseci-Labs/jaclang/tree/main/examples/plugins) directory.

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

>Check out the [byLLM Plugin](https://github.com/jaseci/jac-byllm) for a more complex example. Where we have created a plugin that adds LLM functionality to JAC.

If you have any questions, feel free to ask in the [Community Channel]().