# Build a Jac Plugin

Extend the `jac` CLI with your own command, develop it with an editable install, and see it show up in `jac --help` -- the complete plugin dev loop. The [plugin authoring reference](../../reference/plugin-authoring.md) documents everything a plugin can do (runtime hooks, config schemas, templates); this tutorial gets your first plugin running.

**What you'll do:**

1. Create a plugin package with one CLI command
2. Register it via a `jac` entry point in `jac.toml`
3. Install it editable and iterate

**Time:** ~15 minutes

---

## 1. Lay out the plugin

A plugin is an ordinary package with a class that implements Jac's plugin hooks. Create this structure:

```
jac-hello/
├── jac.toml
└── jac_hello/
    └── plugin.jac
```

**`jac-hello/jac.toml`** -- the `[entrypoints.jac]` table is what makes this a *plugin*: it's the `jac` entry-point group the plugin loader queries at CLI startup:

```toml
[project]
name = "jac-hello"
version = "0.1.0"

[entrypoints.jac]
hello = "jac_hello.plugin:JacCmd"
```

**`jac-hello/jac_hello/plugin.jac`** -- a class with a `@hookimpl`-decorated `create_cmd`, which the CLI calls once at startup. Inside it, register commands exactly the way core commands are registered:

```jac
import from jaclang.cli.command { Arg, ArgKind, CommandPriority }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.console { console }
import from jaclang.jac0core.runtime { hookimpl }

"""Jac CLI extensions for jac-hello."""
class JacCmd {
    """Register the `hello` command on CLI startup."""
    @hookimpl
    static def create_cmd -> None {
        registry = get_registry();

        @registry.command(
            name="hello",
            help="Say hello to someone",
            args=[
                Arg.create(
                    "name",
                    kind=ArgKind.POSITIONAL,
                    default="world",
                    help="Who to greet"
                ),
                Arg.create(
                    "shout",
                    typ=bool,
                    default=False,
                    help="Use uppercase",
                    short="s"
                ),
            ],
            group="general",
            priority=CommandPriority.PLUGIN,
            source="jac-hello"
        )
        def hello(name: str = "world", shout: bool = False) -> int {
            greeting = f"Hello, {name}!";
            if shout {
                greeting = greeting.upper();
            }
            console.print(greeting);
            return 0;
        }
    }
}
```

Note what is *not* here: no dependency on `jaclang`. The `jac` binary is the host runtime that loads your plugin -- `jaclang` never belongs in a plugin's dependencies.

## 2. Install it editable and run it

From any Jac project (or a scratch one -- `jac create tryout --kind cli`):

```bash
jac install -e ../jac-hello
```

```
✔ Linked /path/to/jac-hello
✔ Editable install complete.
```

The plugin is discovered on the next CLI startup:

```bash
jac hello Alice --shout
```

```
HELLO, ALICE!
```

`jac --help` now lists `hello` in the *general* group, and `jac plugins list` shows the `jac-hello` package. Because the install is editable, edits to `plugin.jac` take effect on the next `jac` invocation -- no reinstall, no rebuild.

!!! warning "Declare the entry point in `jac.toml`, not `pyproject.toml`"
    `jac install -e` reads the plugin's **`jac.toml`**. A plugin folder carrying only a `pyproject.toml` with `[project.entry-points."jac"]` will link without error but the entry point is never registered -- your command silently won't appear. (A `pyproject.toml` entry point still works for plugins installed from PyPI with `pip`; for the `jac`-native dev loop and `jac bundle` publishing, declare it in `jac.toml`.)

## 3. Where to go from here

One command is the smallest possible plugin. The same package can also:

- **Extend existing commands** with new flags (`registry.extend_command`) -- how jac-client adds `--client` to `jac start`
- **Override runtime behavior** through `JacRuntimeInterface` hooks (user managers, servers, consoles)
- **Declare a config schema** so `[plugins.yourplugin]` in consumers' `jac.toml` gets validation and `jac config` support
- **Ship project templates** that appear in `jac create --list_jacpacks`

Each has a copy-paste recipe in the [plugin authoring reference](../../reference/plugin-authoring.md). When you're ready to share it, `jac bundle` packages the plugin like any library -- see [Publish a Library](publish-a-library.md); the `[entrypoints.jac]` table travels with the wheel, so `jac install jac-hello` activates it automatically for consumers.
