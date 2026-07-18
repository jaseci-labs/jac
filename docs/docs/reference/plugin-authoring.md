# Plugins (Removed)

Jaclang no longer has a plugin system. The pluggy-style hook mechanism
(`plugin_manager`, `@hookable`/`@hookspec`/`@hookimpl`, entry-point discovery,
`JAC_DISABLED_PLUGINS`, the `[plugins].disabled/enabled/discovery` keys, and the
`jac plugins` command) has been removed.

The subsystems that were previously plugins -- the deployment/scale provider
(`jaclang.scale`), the byLLM feature (`jaclang.byllm`), the `jac mcp` server
(`jaclang.cli.mcp`), the shadcn/ui integration, and the client/desktop
framework (`jaclang.runtimelib.client`) -- are now built directly into `jaclang`
core. Core invokes them through ordinary function calls rather than hook
dispatch, and their heavy dependencies still install on demand via the
capability system (declare the relevant `[<feature>]` section in `jac.toml` and
run `jac install`).

External, third-party plugins are no longer supported. To customize runtime
behavior, contribute to the relevant built-in subsystem in the
[jaclang monorepo](https://github.com/Jaseci-Labs/jaseci) directly.

## Configuration

Feature configuration lives in top-level `jac.toml` tables -- `[byllm]`,
`[scale]`, `[client]`, `[mcp]`, `[desktop]` -- not under the former
`[plugins.<name>]` namespace.

## Custom persistence backends

`TieredMemory` resolves its L3 store through
`JacRuntime.get_persistent_memory(config)`, which returns `None` by default (so
core falls back to `SqliteMemory`). To supply a custom backend -- for example in
an ejected standalone backend -- call
`JacRuntime.set_persistent_memory_provider(fn)` with a callable that takes the
config dict and returns a `PersistentMemory` implementation.
