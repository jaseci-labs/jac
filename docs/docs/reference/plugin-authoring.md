# Plugin Authoring Guide

This guide is for developers who want to write a Jaclang plugin: a Python (or Jac) package that extends the `jac` CLI, replaces parts of the runtime, ships project templates, or otherwise customizes how Jac behaves on a user's machine. If you just want to *use* an existing plugin like `jac-scale` or `jac-client`, see its page under [CLI Plugins](plugins/jac-scale.md) instead.

The five plugins shipped in the Jaclang monorepo -- [jac-scale](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-scale), [jac-client](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-client), [jac-byllm](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm), [jac-super](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-super), and [jac-mcp](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-mcp) -- between them exercise every extension point in this guide. Where a recipe references a real plugin, the file:line citations point to the canonical implementation you can read alongside the explanation.

## What a plugin can do

A Jaclang plugin can:

- **[Add a new CLI command](#recipe-1-add-a-new-cli-command)** (e.g., `jac mcp`, `jac destroy`).
- **[Extend an existing CLI command](#recipe-2-extend-an-existing-cli-command)** by injecting new flags and pre/post hooks (e.g., `jac start --scale`, `jac eject --client desktop`).
- **[Override runtime behavior](#recipe-3-override-runtime-behavior)** like the API server class, the user manager, the storage backend, or the console (e.g., jac-scale swapping in a FastAPI server).
- **[Define `jac.toml` config schemas](#recipe-4-define-plugin-config-in-jactoml)** with validation, defaults, and `[plugins.<name>]` sections.
- **[Ship project templates](#recipe-5-ship-a-project-template)** that show up in `jac create --use <name>`.
- **[Register custom dependency types](#recipe-6-register-a-custom-dependency-type)** like `npm` alongside the built-in PyPI dependency handler.

All of these are layered on the same hook system: a plugin is a class whose methods are decorated with `@hookimpl`, registered as an entry point in `pyproject.toml` under the `jac` group, and discovered by jaclang at startup via [pluggy](https://pluggy.readthedocs.io/).

## Project layout

A canonical Jac plugin looks like this:

```
jac-myplugin/
├── jac_myplugin/
│   ├── __init__.jac          # (or .py) -- package marker
│   ├── plugin.jac            # CLI extension (`JacCmd.create_cmd` hook)
│   ├── plugin_config.jac     # Config schema, templates, dep types
│   └── impl/                 # Implementation modules
└── pyproject.toml            # Dependencies + [project.entry-points."jac"]
```

The two files that matter to jaclang are `plugin.jac` (containing a `JacCmd` class with the CLI hooks) and `plugin_config.jac` (containing a `Jac<Name>PluginConfig` class with metadata, schema, templates, and dependency types). Both are registered as entry points in `pyproject.toml`:

```toml
[project.entry-points."jac"]
myplugin = "jac_myplugin.plugin:JacCmd"
myplugin_plugin_config = "jac_myplugin.plugin_config:JacMypluginPluginConfig"
```

The entry-point group `"jac"` is the only group jaclang scans. Each entry's *name* is just a unique identifier within the group; what matters is that the value points at a class whose methods are `@hookimpl`-decorated. A single plugin package usually registers two entries -- one for runtime/CLI hooks and one for config -- but you can register as many as makes sense (jac-client registers three: `serve`, `cli`, and `plugin_config`).

## How extension works at a glance

Jaclang uses pluggy under the hood. At startup it:

1. Loads every entry point under the `jac` group via `plugin_manager.load_setuptools_entrypoints("jac")` ([jac/jaclang/**init**.py:41](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/__init__.py#L41)).
2. Skips any plugin listed in the `JAC_DISABLED_PLUGINS` env var or the `[plugins].disabled` array in `jac.toml`.
3. Registers each remaining plugin class with the global `plugin_manager`.
4. Calls hook collection points (e.g., `JacCmd.create_cmd()`) at the right moments. Pluggy invokes every plugin's implementation of that hook in registration order.

There are three "layers" of hooks a plugin can implement, defined as classes in [jac/jaclang/jac0core/runtime.jac](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac):

| Layer | Hook class | Purpose |
|---|---|---|
| **CLI** | `JacCmd` | A single hook (`create_cmd`) called once at CLI startup. Inside it, plugins call `registry.command(...)` and `registry.extend_command(...)` to register or modify commands. |
| **Runtime** | `JacRuntimeInterface` (and its mixins: `JacAPIServer`, `JacConsole`, `JacClientBundle`, `JacByLLM`, …) | Many hooks called throughout program execution. Plugins override individual methods (`get_user_manager`, `create_server`, `get_console`, …) to swap in their own implementations. |
| **Config / packaging** | `JacPluginConfig` | Metadata, jac.toml schema, project templates, and custom dependency types. Called by `jac plugins`, `jac create`, `jac add`, and config validation. |

A plugin class implements whatever subset of hooks it needs. You don't have to implement all three layers -- `jac-super` only implements `get_console`, `jac-byllm` only implements LLM-related runtime hooks, and `jac-mcp` only adds a CLI command.

## Recipes

### Recipe 1: Add a new CLI command

The smallest possible plugin: a `jac hello [name]` command that prints a greeting.

**`jac_hello/plugin.jac`**

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
            examples=[
                ("jac hello", "Greet the world"),
                ("jac hello Alice", "Greet Alice"),
                ("jac hello Alice --shout", "GREET ALICE"),
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

**`pyproject.toml`**

```toml
[project]
name = "jac-hello"
version = "0.1.0"
dependencies = ["jaclang"]

[project.entry-points."jac"]
hello = "jac_hello.plugin:JacCmd"
```

After `pip install -e .`, `jac --help` will list `hello` in the *general* group and `jac hello Alice --shout` will print `HELLO, ALICE!`.

A few things worth noticing:

- **`@registry.command` lives inside `create_cmd`**, not at module level. The `create_cmd` hook is called once at CLI startup, and registering inside it gives you access to whatever state you want to capture in the closure. (Module-level registration also works -- see [Recipe 2](#recipe-2-extend-an-existing-cli-command) -- but the `create_cmd` pattern is preferred for plain new commands.)
- **`source="jac-hello"`** is metadata used by `jac plugins` to attribute the command to your package; pass your plugin's name.
- **`priority=CommandPriority.PLUGIN`** tells the registry that this is a plugin command (vs. a `CORE` jaclang command or a `USER`-level override). It affects conflict resolution if two plugins try to register the same command name.
- **The function returns an `int`** -- that's the process exit code the CLI propagates.

**Real reference**: [jac-scale's `destroy` command](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/plugin.jac#L244-L371) is a fuller example of this exact pattern.

### Recipe 2: Extend an existing CLI command

When you want to *add a flag* to an existing core command and run your own logic when the user passes it, use `registry.extend_command(...)`. This is how `jac-scale` adds `--scale` to `jac start`, how `jac-client` adds `--client desktop` to `jac start` and `jac build`, and how `jac-client` adds `--npm` to `jac add` and `jac remove`.

**`jac_verbose/plugin.jac`** -- adds a `--trace` flag to `jac run`:

```jac
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.console { console }
import from jaclang.jac0core.runtime { hookimpl }

"""Jac CLI extensions for jac-verbose."""
class JacCmd {
    @hookimpl
    static def create_cmd -> None {
        registry = get_registry();
        registry.extend_command(
            command_name="run",
            args=[
                Arg.create(
                    "trace",
                    typ=bool,
                    default=False,
                    help="Print every walker spawn before it runs",
                    short="t"
                ),
            ],
            pre_hook=_run_pre_hook,
            post_hook=_run_post_hook,
            source="jac-verbose"
        );
    }
}

"""Pre-hook: enable tracing if --trace was passed."""
def _run_pre_hook(ctx: HookContext) -> None {
    if ctx.get_arg("trace", False) {
        import os;
        os.environ["JAC_TRACE_WALKERS"] = "1";
        console.print("[verbose] tracing enabled", style="muted");
    }
}

"""Post-hook: print elapsed time after the command finishes."""
def _run_post_hook(ctx: HookContext, return_code: int) -> int {
    if ctx.get_arg("trace", False) {
        console.print(
            f"[verbose] command exited with {return_code}", style="muted"
        );
    }
    return return_code;
}
```

The lifecycle when a user runs `jac run main.jac --trace`:

1. The executor builds a `HookContext` with the parsed args (`{"filename": "main.jac", "trace": True}`).
2. `_run_pre_hook(ctx)` runs. It can mutate `ctx.args`, set `ctx.data` keys, or short-circuit the command (see below).
3. The `run` command's normal handler runs.
4. `_run_post_hook(ctx, return_code)` runs and may return a different return code.

Pre-hook order, handler invocation, and post-hook order are all in [jac/jaclang/cli/impl/executor.impl.jac:11-86](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/cli/impl/executor.impl.jac#L11-L86).

**Pattern A -- augment**: the pre-hook does some setup (env vars, logging), the default handler runs, the post-hook does some teardown. This is the example above.

**Pattern B -- replace**: the pre-hook does the entire job and short-circuits the default handler. This is how `jac-scale` handles `jac start --scale`: when the flag is set, the pre-hook does the full Kubernetes deployment and tells the executor to skip the normal `start` impl. The cancel mechanism is two `ctx.set_data` keys:

```jac
def _scale_pre_hook(ctx: HookContext) -> None {
    if not ctx.get_arg("scale", False) {
        return;
    }
    # ... do the scale-flavored work ...
    ctx.set_data("cancel_execution", True);
    ctx.set_data("cancel_return_code", 0);
}
```

When `cancel_execution` is `True`, the executor skips the handler and returns immediately with `cancel_return_code` (default `1`). Post-hooks still run.

**HookContext API**

| Member | Type | Purpose |
|---|---|---|
| `command_name` | `str` | The command being executed (e.g., `"run"`). |
| `args` | `dict[str, Any]` | Parsed CLI arguments -- a copy, so mutating is safe. |
| `data` | `dict[str, Any]` | Hook-to-hook scratch space. |
| `get_arg(name, default=None)` | method | Read a parsed argument. |
| `set_data(key, value)` | method | Write to the scratch dict (for cancel keys, hook chaining, etc.). |
| `get_data(key, default=None)` | method | Read from the scratch dict. |

**Reserved `data` keys**

| Key | Type | Effect |
|---|---|---|
| `cancel_execution` | `bool` | If `True`, skip the command handler entirely. |
| `cancel_return_code` | `int` | Return code to use when execution was cancelled (default `1`). |
| `cancel_on_hook_error` | `bool` | If `True`, abort the pre-hook chain when a hook raises (default `False` -- errors log a warning and other hooks still run). |

**Real references**:

- [jac-scale extending `jac start --scale`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/plugin.jac#L25-L242) -- the canonical "replace" pattern.
- [jac-client extending `jac add --npm`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-client/jac_client/plugin/cli.jac#L119-L132) and [`jac start --client`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-client/jac_client/plugin/cli.jac#L162-L179) -- multiple flags on multiple commands from the same plugin.

### Recipe 3: Override runtime behavior

The `JacRuntimeInterface` exposes a set of hooks that the jaclang runtime calls at well-defined points. A plugin can override any of them by implementing the corresponding `@hookimpl` method. The hook lookup uses pluggy's first-result-wins semantics, so the plugin override completely replaces the default implementation.

The most commonly overridden hooks:

| Hook | Signature | What it controls |
|---|---|---|
| `get_api_server_class` | `() -> type` | The class used by `jac start` for the HTTP server. Default: `JacAPIServer` (stdlib `HTTPServer`). jac-scale returns its FastAPI-based `JFastApiServer`. |
| `create_server` | `(jac_server, host, port, max_retries=10) -> HTTPServer` | The actual server *instance* used by `jac start`. Plugins can return a custom server with different lifecycle semantics. |
| `get_user_manager` | `(base_path: str) -> UserManager` | The user manager used for register/login/auth. Default: SQLite-backed `UserManager`. jac-scale returns a JWT/SSO-backed implementation. |
| `store` | `(base_path='./storage', create_dirs=True) -> Storage` | The graph/object storage backend. Default: `LocalStorage`. jac-scale returns S3/GCS/Azure backends from `[plugins.scale]` config. |
| `get_console` | `() -> ConsoleImpl` | The console used for all CLI output. jac-super returns a Rich-backed implementation with colors, panels, and spinners. |
| `get_client_bundle_builder` | `() -> ClientBundleBuilder` | The bundler used to compile `.cl.jac` modules to JS. jac-client returns a Vite-backed builder. |
| `render_page` | `(introspector, function_name, args, username) -> dict[str, Any]` | Server-side rendering of client components. jac-client implements full SSR. |
| `format_build_error` | `(error_output: str, project_dir: Path, config) -> str` | Pretty error messages for client build failures. |
| `ensure_sv_service` | `(module_name: str, base_path: str) -> None` | Lazy spawn an `sv import`-ed microservice provider when `sv_client.call()` first needs it. |
| `get_mtir`, `call_llm`, `by`, `by_operator` | various | Hooks the byllm plugin uses to implement the `by llm()` language feature. |

The full list and signatures live in [jac/jaclang/jac0core/runtime.jac:861-888](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L861-L888) (the `JacRuntimeInterface` class) plus its mixins (`JacAPIServer`, `JacConsole`, `JacClientBundle`, `JacByLLM`, …).

**Example**: a plugin that wraps the console with a timestamp prefix.

**`jac_timestamp/plugin.jac`**

```jac
import from jaclang.cli.console { JacConsole }
import from jaclang.jac0core.runtime { hookimpl }
import from typing { Any }
import datetime;

"""Console wrapper that prefixes every line with a timestamp."""
obj TimestampConsole(JacConsole) {
    has _wrapped: JacConsole;

    def init(wrapped: JacConsole) -> None {
        self._wrapped = wrapped;
    }
    def print(*args: Any, **kwargs: Any) -> None {
        ts = datetime.datetime.now().strftime("%H:%M:%S");
        self._wrapped.print(f"[{ts}]", *args, **kwargs);
    }
    # Forward other methods to the wrapped console...
}

"""Runtime hook implementations for jac-timestamp."""
class JacTimestampPlugin {
    @hookimpl
    static def get_console -> JacConsole {
        return TimestampConsole(wrapped=JacConsole());
    }
}
```

**`pyproject.toml`**

```toml
[project.entry-points."jac"]
timestamp = "jac_timestamp.plugin:JacTimestampPlugin"
```

A plugin class can implement multiple runtime hooks side-by-side; jac-scale's [`JacRuntimeInterfaceImpl`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/plugin.jac#L430-L476) overrides `create_j_context`, `create_server`, `get_api_server_class`, `get_user_manager`, and `store` in a single class.

**A note on first-result-wins**: pluggy returns the first non-`None` result it sees, in reverse registration order. If two plugins both implement `get_console`, the most recently registered one wins. There is currently no fine-grained priority system for runtime hooks (only for CLI commands), so plugins that override the same runtime hook need to coordinate or use the `JAC_DISABLED_PLUGINS` env var to opt out of one of them.

### Recipe 4: Define plugin config in `jac.toml`

If your plugin reads configuration from the user's `jac.toml`, declare a config class. The benefits over reading the TOML manually:

- The schema appears in `jac plugins info <name>` so users can see what knobs exist.
- `validate_config()` lets you reject malformed input at startup with clear error messages.
- Default values and `env_var` overrides are handled for you.

**`jac_myplugin/plugin_config.jac`**

```jac
import from jaclang.jac0core.runtime { hookimpl }
import from typing { Any }

"""Plugin config for jac-myplugin."""
class JacMypluginPluginConfig {
    """Plugin metadata for `jac plugins info`."""
    @hookimpl
    static def get_plugin_metadata -> dict[str, Any] {
        return {
            "name": "myplugin",
            "version": "0.1.0",
            "description": "Example plugin showing how config works"
        };
    }

    """Schema for the [plugins.myplugin] section of jac.toml."""
    @hookimpl
    static def get_config_schema -> dict[str, Any] {
        return {
            "section": "myplugin",
            "options": {
                "endpoint": {
                    "type": "str",
                    "default": "https://api.example.com",
                    "description": "Remote endpoint URL",
                    "env_var": "MYPLUGIN_ENDPOINT",
                    "required": False
                },
                "max_retries": {
                    "type": "int",
                    "default": 3,
                    "description": "Number of retries on failure"
                },
                "tags": {
                    "type": "list",
                    "default": [],
                    "description": "Tags applied to outgoing requests"
                }
            }
        };
    }

    """Validate the loaded config and return a list of error messages."""
    @hookimpl
    static def validate_config(config: dict[str, Any]) -> list[str] {
        errors: list[str] = [];
        retries = config.get("max_retries", 3);
        if retries < 0 {
            errors.append("max_retries must be >= 0");
        }
        return errors;
    }
}
```

The user's `jac.toml` then looks like:

```toml
[plugins.myplugin]
endpoint = "https://prod.example.com"
max_retries = 5
tags = ["production", "us-east"]
```

**Reading the config at runtime**

From any plugin code (a CLI hook, a runtime hook, anywhere):

```jac
import from jaclang.project.config { get_config }

with entry {
    cfg = get_config();
    if cfg {
        myplugin_cfg = cfg.get_plugin_config("myplugin");
        endpoint = myplugin_cfg.get("endpoint", "https://api.example.com");
        retries = myplugin_cfg.get("max_retries", 3);
    }
}
```

`get_config()` discovers `jac.toml` from the current working directory upward; it returns `None` if there's no project. `get_plugin_config(name)` returns the merged `[plugins.<name>]` section as a plain dict.

**Schema option types**

The `type` field accepts `"str"`, `"int"`, `"float"`, `"bool"`, `"list"`, or `"dict"`. The `env_var` field, if set, lets the user override the value from the environment without touching `jac.toml`. The `required` field marks an option as mandatory; missing required options surface as validation errors at startup.

**Real references**:

- [jac-byllm's config schema](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-byllm/byllm/plugin_config.jac#L25-L103) -- concise example with model selection, API keys, and LiteLLM passthrough.
- [jac-scale's config schema](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/plugin_config.jac#L19-L328) -- large, multi-section schema (`jwt`, `sso`, `database`, `kubernetes`, `secrets`, `monitoring`, `sandbox`).
- [jac-mcp's three-tier fallback](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-mcp/jac_mcp/plugin.jac#L78-L97) -- pre-hook that resolves CLI arg → jac.toml → CLI default in priority order.

### Recipe 5: Ship a project template

If your plugin scaffolds a project structure (e.g., a fullstack app, a starter kit), register a template via the `register_project_template` hook. Templates are exposed to users through `jac create --use <name>`.

**`jac_myplugin/plugin_config.jac`** (continuing from Recipe 4)

```jac
"""Plugin config for jac-myplugin."""
class JacMypluginPluginConfig {
    # ... get_plugin_metadata, get_config_schema, validate_config from Recipe 4 ...

    """Register a 'starter' template for `jac create --use starter`."""
    @hookimpl
    static def register_project_template -> dict[str, Any] | None {
        return {
            "name": "starter",
            "description": "Minimal starter project for jac-myplugin",
            "config": {
                "project": {
                    "name": "{{name}}",
                    "version": "0.1.0",
                    "entry-point": "main.jac"
                },
                "plugins": {
                    "myplugin": {
                        "endpoint": "https://api.example.com"
                    }
                }
            },
            "files": {
                "main.jac": '"""{{name}} - Entry point."""\n\nwith entry {\n    print("Hello from {{name}}!");\n}\n',
                ".gitignore": ".jac/\n*.pyc\n"
            },
            "directories": [".jac", "data"],
            "post_create": _post_create_starter
        };
    }
}

"""Post-create hook called after the template is scaffolded on disk."""
def _post_create_starter(project_path: Any, project_name: str) -> None {
    # Run `npm install`, copy assets, anything else.
    return;
}
```

**Template dict shape**

| Key | Type | Purpose |
|---|---|---|
| `name` | `str` | The identifier users pass to `jac create --use <name>`. |
| `description` | `str` | Shown in `jac create --list-jacpacks`. |
| `config` | `dict` | Becomes the new project's `jac.toml`. `{{name}}` placeholders in any string value are replaced with the user-supplied project name. |
| `files` | `dict[str, str]` | Maps relative path → file content. `{{name}}` placeholders in content are replaced. Binary files use the `"base64:..."` prefix. |
| `directories` | `list[str]` | Empty directories created alongside the file tree. |
| `post_create` | `Callable[[Path, str], None]` | Optional callback run after files are written. Receives `(project_path, project_name)`. |

**Real reference**: [jac-client ships two templates (`client` and `fullstack`)](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-client/jac_client/plugin/plugin_config.jac#L120-L133) by loading them from disk via `load_template_from_directory(...)`. The post-create hook for jac-client installs Bun and runs `bun install` to bootstrap the frontend. If your template is large, prefer the disk-loading approach over inlining `files` in code.

### Recipe 6: Register a custom dependency type

The core `jac add` and `jac install` commands manage Python dependencies via PyPI. If your plugin manages packages from a different registry -- npm, Cargo, gem, Helm chart repos, anything -- register a custom dependency type so users can do `jac add <pkg> --<your-flag>` and `jac install` will pick it up too.

```jac
"""Plugin config for jac-myplugin."""
class JacMypluginPluginConfig {
    # ... other hooks ...

    """Register a 'cargo' dependency type for Rust crates."""
    @hookimpl
    static def register_dependency_type -> dict[str, Any] | None {
        return {
            "name": "cargo",
            "dev_name": "cargo.dev",
            "cli_flag": "--cargo",
            "install_dir": ".jac/cargo",
            "install_handler": _cargo_install,
            "remove_handler": _cargo_remove
        };
    }
}

"""Install one or more cargo packages declared in jac.toml."""
def _cargo_install(packages: list[str], dev: bool, install_dir: str) -> int {
    # Run `cargo install <pkg>` for each package.
    return 0;
}

"""Remove one or more cargo packages."""
def _cargo_remove(packages: list[str], dev: bool, install_dir: str) -> int {
    return 0;
}
```

This adds a `[dependencies.cargo]` section to `jac.toml`, a `--cargo` flag to `jac add` and `jac remove`, and routes installation through your handlers when `jac install` runs.

**Real reference**: [jac-client's npm dependency type](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-client/jac_client/plugin/plugin_config.jac#L106-L117) is the only dependency type currently in the monorepo. Its handlers shell out to `bun` (or `npm` if Bun isn't available) to manage the project's frontend packages.

## API reference

### `jaclang.cli.registry.CommandRegistry`

The registry is the central point for command registration and extension. Get the global instance with `from jaclang.cli.registry import get_registry`.

**`registry.command(name, help, args=None, examples=None, group="general", priority=CommandPriority.CORE, source="jaclang") -> Callable`**

A decorator factory. Wrap a function definition to register it as a CLI command.

| Parameter | Type | Purpose |
|---|---|---|
| `name` | `str` | Command name (e.g., `"hello"`). The user invokes it as `jac hello`. |
| `help` | `str` | One-line summary shown in `jac --help`. |
| `args` | `list[Arg]` | Argument schema (see the `Arg` reference below). |
| `examples` | `list[tuple[str, str]]` | `(invocation, description)` pairs shown in `jac <name> --help`. |
| `group` | `str` | Section header in `jac --help`. Common groups: `general`, `project`, `build`, `tools`, `deployment`. |
| `priority` | `CommandPriority` | `CORE` (built-in), `PLUGIN` (plugin-provided), or `USER` (highest). Affects conflict resolution. |
| `source` | `str` | Plugin name for attribution; shown in `jac plugins`. |

The decorated function becomes the command's handler. Its signature must accept the parsed arguments as keyword arguments and return an `int` exit code.

**`registry.extend_command(command_name, args=None, pre_hook=None, post_hook=None, source="unknown") -> None`**

Add arguments and/or hooks to an *existing* command.

| Parameter | Type | Purpose |
|---|---|---|
| `command_name` | `str` | Name of the command to extend. The command must already be registered (use `registry.has_command(name)` if you're not sure). |
| `args` | `list[Arg]` | Additional arguments to inject. They appear alongside the core args in `--help`. |
| `pre_hook` | `Callable[[HookContext], None]` | Function called *before* the handler runs. May mutate args, set `data` keys, or short-circuit via `cancel_execution`. |
| `post_hook` | `Callable[[HookContext, int], int]` | Function called *after* the handler runs. Receives the return code and may return a different one. |
| `source` | `str` | Plugin name for attribution. |

You can call `extend_command` multiple times for the same target command -- both the args and the hooks accumulate.

**Other registry methods**

| Method | Signature | Purpose |
|---|---|---|
| `has_command(name)` | `(str) -> bool` | Check whether a command is registered. |
| `get(name)` | `(str) -> CommandSpec \| None` | Retrieve a command's spec. |
| `get_all(group=None)` | `(str \| None) -> list[CommandSpec]` | List commands, optionally filtered by group. |

### `jaclang.cli.command.Arg`

A command-line argument descriptor. Construct via `Arg.create(name, ...)`.

| Field | Type | Purpose |
|---|---|---|
| `name` | `str` | Argument name (becomes the parameter name on the handler function). |
| `kind` | `ArgKind` | `POSITIONAL`, `OPTION` (default -- `--name VALUE`), `FLAG` (`--name`, no value), `MULTI` (collects multiple values), or `REMAINDER` (everything after `--`). |
| `typ` | `type` | Python type for conversion (`str`, `int`, `float`, `bool`, …). |
| `default` | `Any` | Default value if the user doesn't pass the flag. |
| `help` | `str` | Help text for the argument. |
| `short` | `str \| None` | Short flag (e.g., `"f"` for `-f`). Pass `""` to disable the auto-generated short flag. |
| `choices` | `list[Any] \| None` | Restricted set of valid values (argparse `choices`). |
| `required` | `bool` | Whether the argument is required. |
| `metavar` | `str \| None` | Display name in `--help`. |

`Arg.create(...)` is a static factory that fills in sensible defaults for fields you don't pass.

### `jaclang.cli.command.HookContext`

Mutable context passed to pre and post hooks.

| Field / method | Type | Purpose |
|---|---|---|
| `command_name` | `str` | The name of the command currently executing. |
| `args` | `dict[str, Any]` | A copy of the parsed CLI arguments. Mutating is safe but does not change what the handler sees -- for that, use `set_data` and have the handler read it back. |
| `data` | `dict[str, Any]` | Hook-to-hook scratch space. Persists across pre-hook → handler → post-hook. |
| `get_arg(name, default=None)` | method | Read an argument by name. |
| `set_data(key, value)` | method | Write to the scratch dict. |
| `get_data(key, default=None)` | method | Read from the scratch dict. |

**Reserved `data` keys**

| Key | Type | Set by | Effect |
|---|---|---|---|
| `cancel_execution` | `bool` | pre-hook | If `True`, the executor skips the command handler. |
| `cancel_return_code` | `int` | pre-hook | Return code used when execution is cancelled (default `1`). |
| `cancel_on_hook_error` | `bool` | pre-hook | If `True`, abort the pre-hook chain when a hook raises (default `False` -- errors log a warning and other hooks still run). |

### Command lifecycle

For every `jac <command>` invocation, the executor ([jac/jaclang/cli/impl/executor.impl.jac:11-86](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/cli/impl/executor.impl.jac#L11-L86)) does the following:

1. Build a `HookContext` with the parsed args.
2. Run **all pre-hooks** in registration order. If any hook sets `cancel_execution = True`, stop immediately and skip to step 4 with `return_code = cancel_return_code`. If a hook raises, log a warning and continue (unless `cancel_on_hook_error = True`).
3. Run **the command handler**. Catch exceptions, log them, and set `return_code = 1`.
4. Run **all post-hooks** in registration order. Each receives `(ctx, return_code)` and may return a new `return_code`. Errors during a post-hook log a warning and don't change the return code.
5. Return the final `return_code` to the shell.

### `JacRuntimeInterface` runtime hooks

A condensed list of every hook plugins can override. The full definitions are in [jac/jaclang/jac0core/runtime.jac](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac).

**API server (`JacAPIServer` mixin):**

| Hook | Signature |
|---|---|
| `get_api_server_class` | `() -> type` |
| `create_server` | `(jac_server, host: str, port: int, max_retries: int = 10) -> HTTPServer` |
| `ensure_sv_service` | `(module_name: str, base_path: str) -> None` |
| `render_page` | `(introspector, function_name: str, args: dict, username: str) -> dict` |
| `get_client_js` | `(introspector) -> str` |

**User and storage:**

| Hook | Signature |
|---|---|
| `get_user_manager` | `(base_path: str) -> UserManager` |
| `store` | `(base_path: str = "./storage", create_dirs: bool = True) -> Storage` |

**Console (`JacConsole` mixin):**

| Hook | Signature |
|---|---|
| `get_console` | `() -> ConsoleImpl` |

**Client bundling (`JacClientBundle` mixin):**

| Hook | Signature |
|---|---|
| `get_client_bundle_builder` | `() -> ClientBundleBuilder` |
| `build_client_bundle` | `(module, force: bool = False) -> ClientBundle` |
| `format_build_error` | `(error_output: str, project_dir: Path, config) -> str` |

**LLM integration (`JacByLLM` mixin):**

| Hook | Signature |
|---|---|
| `get_mtir` | `(caller, args, call_params) -> MTRuntime` |
| `call_llm` | `(model, mt_run) -> Any` |
| `by` | `(model) -> Callable` |
| `by_operator` | `(lhs, rhs) -> Any` |
| `filter_visitable_by` | `(connected_nodes, model, descriptions: str = "") -> list` |

**CLI (`JacCmd` mixin):**

| Hook | Signature |
|---|---|
| `create_cmd` | `() -> None` |

### `JacPluginConfig` hooks

| Hook | Signature | Purpose |
|---|---|---|
| `get_plugin_metadata` | `() -> dict \| None` | Return `{name, version, description}`. |
| `get_config_schema` | `() -> dict \| None` | Return the `jac.toml` schema (see Recipe 4). |
| `on_config_loaded` | `(config: dict) -> None` | Called after the user's config is loaded -- useful for caching parsed values. |
| `validate_config` | `(config: dict) -> list[str]` | Return a list of error messages (empty if valid). |
| `register_dependency_type` | `() -> dict \| None` | Register a custom dependency manager (see Recipe 6). |
| `register_project_template` | `() -> dict \| None` | Register a `jac create` template (see Recipe 5). |

## Distribution

### Building and publishing

A Jaclang plugin is a regular Python package. The minimum `pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "jac-myplugin"
version = "0.1.0"
description = "What this plugin does"
requires-python = ">=3.12"
dependencies = ["jaclang>=0.13"]

[project.entry-points."jac"]
myplugin = "jac_myplugin.plugin:JacCmd"
myplugin_plugin_config = "jac_myplugin.plugin_config:JacMypluginPluginConfig"
```

Build a wheel with `python -m build` and publish with `twine upload`. The plugin becomes active in any environment that has both your wheel and `jaclang` installed -- no other registration step is required.

### `jac plugins` command

Users see and manage installed plugins through the `jac plugins` family of commands ([jac/jaclang/cli/commands/impl/config.impl.jac:25-275](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/cli/commands/impl/config.impl.jac#L25-L275)):

```bash
jac plugins                       # List all installed plugins
jac plugins info myplugin         # Show metadata + config schema
jac plugins disable myplugin      # Disable for this project (writes to jac.toml)
jac plugins enable myplugin       # Re-enable
jac plugins disable '*'           # Disable every external plugin
```

The disabled list is stored under `[plugins].disabled` in `jac.toml`. The `JAC_DISABLED_PLUGINS` environment variable provides a per-invocation override (useful for tests, CI, and reproducible bug reports).

## Tour of existing plugins

Each plugin in the monorepo exercises a different subset of the extension surface. Read them as canonical examples:

| Plugin | What it adds | What to study it for |
|---|---|---|
| [**jac-scale**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-scale) | Cloud deployment, FastAPI server, JWT/SSO auth, MongoDB/Redis storage, Kubernetes deploys via `--scale`. | The "replace a CLI command via pre-hook" pattern (`_scale_pre_hook` for `jac start`), the most extensive runtime-hook overrides (`get_user_manager`, `create_server`, `store`), and a multi-section config schema with secrets and env-var resolution. |
| [**jac-client**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-client) | Full-stack web framework: JSX components, Vite dev server, client-side rendering, npm dependency type, project templates. | Multiple plugin entry points (`serve`, `cli`, `plugin_config`), dependency-type registration, project template loading from disk with post-create hooks, and the polymorphic `TargetFactory` pattern for desktop/web/PWA build targets. |
| [**jac-byllm**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm) | The `by llm()` language feature -- annotate a function and have an LLM implement it at runtime. | Pure runtime-hook plugin with no CLI commands. Shows how to bridge compile-time IR to runtime via `get_mtir`, and how a single hook (`call_llm`) can dispatch across many providers via LiteLLM. |
| [**jac-super**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-super) | Rich-formatted console output (colors, panels, spinners). | The smallest possible plugin -- a single `@hookimpl` for `get_console`, no CLI, no config. A great copy-paste starting point. |
| [**jac-mcp**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-mcp) | An MCP (Model Context Protocol) server that exposes the Jac project to AI coding assistants. | Single new CLI command (`jac mcp`) with the "module-level `@registry.command` + pre-hook" pattern, three-tier config fallback (CLI arg → `jac.toml` → default), and an `--inspect` mode that dumps the server's resources/tools/prompts. |

## See also

- [Codebase Guide § Plugin Architecture](../community/codebase-guide.md) -- high-level architectural notes on where plugins fit in the broader Jaclang codebase.
- [CLI Reference](cli/index.md) -- every built-in CLI command with its full argument schema.
- Per-plugin reference pages: [jac-scale](plugins/jac-scale.md), [jac-client](plugins/jac-client.md), [byllm](plugins/byllm.md).
