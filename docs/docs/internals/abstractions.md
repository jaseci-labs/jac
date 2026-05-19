# Jac Abstractions: Architectural Inventory

This document is a complete inventory of every abstraction Jac exposes to user
code, organized into the three categories established in the design essay
[*Designing New Abstractions for Jac*](https://www.jac-lang.org/blog/designing_new_abstractions_for_jac/):

1. **Language-level keywords** -- first-class syntax, parsed into dedicated AST nodes.
2. **Builtins** -- names available without an import, resolved through the runtime.
3. **Standard library** -- modules that must be reached with an explicit `import from`.

For each abstraction, the table lists where it is *parsed*, where it is
*represented in the AST*, and where it is *implemented at runtime*. The intent
is to give contributors a single map from a user-facing concept to the file
that owns it, and to make architectural drift visible: when the same
abstraction is implemented two different ways, that shows up here.

---

## Category 1 -- Language-Level Keywords

All nine keywords flow through a single, unified pipeline: tokenized in
`jac0core/parser/tokens.na.jac`, parsed by `jac0core/parser/impl/parser.impl.jac`
into a small set of AST node types defined in `jac0core/unitree.jac`, and
implemented by `JacRuntimeInterface` in `jac0core/runtime.jac`. Both the
bootstrap compiler (`jac0.py`) and the full compiler share this front end.

| Keyword | Token | AST node | Runtime |
|---|---|---|---|
| `walker` | `KW_WALKER` -- [tokens.na.jac:48](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L48) | `Archetype` (discriminated by `arch_type`) -- [unitree.jac:636](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/unitree.jac#L636) | `WalkerArchetype` (constructs.jac); traversal in [`JacWalker`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L222) |
| `node` | `KW_NODE` -- [tokens.na.jac:46](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L46) | `Archetype` | `NodeArchetype` + `NodeAnchor` -- [archetype.jac:108](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/archetype.jac#L108) |
| `edge` | `KW_EDGE` -- [tokens.na.jac:47](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L47) | `Archetype` | `EdgeArchetype` + `EdgeAnchor` -- [archetype.jac:122](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/archetype.jac#L122) |
| `visit` | `KW_VISIT` -- [tokens.na.jac:88](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L88) | `VisitStmt` -- [unitree.jac:938](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/unitree.jac#L938) | [`JacWalker.visit`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L224) |
| `spawn` | `KW_SPAWN` -- [tokens.na.jac:89](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L89) | unpack-position modifier -- [parser.impl.jac:1309](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/impl/parser.impl.jac#L1309) | `spawn_call` / `spawn_walker` -- [runtime.jac:272,822](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L272) |
| `entry` | `KW_ENTRY` -- [tokens.na.jac:90](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L90) | `Ability` (in archetype) **or** module-level `with entry` block | `_jac_entry_funcs_` ClassVar; dispatched by `_execute_entries` -- [runtime.jac:239](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L239) |
| `exit` | `KW_EXIT` -- [tokens.na.jac:91](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L91) | `Ability` | `_jac_exit_funcs_` ClassVar; `_execute_exits` -- [runtime.jac:249](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L249) |
| `can` | `KW_CAN` -- [tokens.na.jac:50](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L50) | `Ability` -- [unitree.jac:688](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/unitree.jac#L688) | compiled to a plain Python method on the archetype class |
| `has` | `KW_HAS` -- [tokens.na.jac:49](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac#L49) | `HasVar` -- [unitree.jac:781](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/unitree.jac#L781) | dataclass field; wrapped by `JacField` (jac0) or `_.field()` (full compiler) |

**Notes**

- `walker` / `node` / `edge` share the same `Archetype` AST node. The keyword
  is preserved as the `arch_type: Token` discriminator rather than producing
  three distinct node types.
- `entry` is reused for two distinct purposes: a *walker lifecycle hook* inside
  an archetype (paired with `exit`) and a *module-level `with entry` block*.
  Both flow through the same token but produce different AST shapes.
- `spawn` is parsed as a modifier on the unpack form rather than as a
  standalone statement.

---

## Category 2 -- Builtins

Builtins are co-located in a single module
([`jaclang/runtimelib/builtin.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac))
and resolved through one mechanism -- except for `printgraph`, which is the
documented exception.

The pattern for every builtin except `printgraph`: a `def _get_X` thunk in
`builtin.jac`, an implementation in
[`runtimelib/impl/builtin.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac)
that returns `_get_jac().<method>`, and a module-level `__getattr__` that
resolves the public name on first access. Every backing implementation lives
on `JacRuntimeInterface` in `jac0core/runtime.jac`.

| Builtin | Declaration | Resolver | Runtime impl |
|---|---|---|---|
| `jid()` | [builtin.jac:33](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L33) `_get_jid` | [builtin.impl.jac:164](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L164) → `object_ref` | `JacRuntimeInterface.object_ref` -- [runtime.jac:390](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L390) |
| `jobj()` | [builtin.jac:35](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L35) | [builtin.impl.jac:159](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L159) → `get_object` | [runtime.jac:383](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L383) |
| `grant()` | [builtin.jac:37](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L37) | [builtin.impl.jac:154](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L154) → `perm_grant` | `JacAccessValidation.perm_grant` -- [runtime.jac:117](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L117) |
| `revoke()` | [builtin.jac:39](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L39) | [builtin.impl.jac:149](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L149) → `perm_revoke` | [runtime.jac:122](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L122) |
| `allroots()` | [builtin.jac:41](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L41) | [builtin.impl.jac:144](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L144) → `get_all_root` | [runtime.jac:526](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L526) |
| `save()` | [builtin.jac:43](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L43) | [builtin.impl.jac:139](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L139) → `save` | [runtime.jac:536](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L536) |
| `commit()` | [builtin.jac:45](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L45) | [builtin.impl.jac:100](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L100) → `commit` | [runtime.jac:373](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L373) |
| `store()` | [builtin.jac:47](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L47) | [builtin.impl.jac:105](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L105) → `store` | [runtime.jac:953](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L953) |
| `printgraph()` | [builtin.jac:55-65](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac#L55) -- direct `def` (not a thunk) | [builtin.impl.jac:36-63](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac#L36) -- full body, dispatches DOT vs JSON | [runtime.jac:345](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac#L345) |

`printgraph` is declared with a complete signature instead of a lazy thunk
because it has a rich keyword-argument surface (depth, traversal, edge type,
BFS toggle, edge/node limits, output file, format) that benefits from being
visible to IDE completion and the type checker. Functionally it still
delegates to `JacRuntimeInterface`.

The `__all__` in `builtin.jac` also exports adjacent names that fall outside
the blog post's nine but follow the same registration pattern: `llm`,
`archetype_alias`, the access-level singletons (`NoPerm`, `ReadPerm`,
`ConnectPerm`, `WritePerm`), and the decorators `restspec` and `schedule`.

---

## Category 3 -- Standard Library

Each package ships its own `lib.jac`-style module. The blog post's principle
-- *every standard-library abstraction needs an explicit `import from`* -- holds
across all packages. The *shape* of the library, however, varies.

### Core Jac (`jac/jaclang/`)

The user-facing entry point is
[`jaclang/lib.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/lib.jac),
which re-exports everything from
[`jac0core/jaclib.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/jaclib.jac).
The consolidated `__all__` covers:

- **Archetypes**: `Node`, `Edge`, `Walker`, `Obj`, `Root`, `GenericEdge`, `JsxElement`
- **Graph operations**: `spawn`, `visit`, `disengage`, `connect`, `disconnect`, `refs`, `arefs`, `filter_on`, `build_edge`, `destroy`
- **Walker support types**: `OPath`, `DSFunc`, `EdgeDir`
- **Context & root**: `root`, `create_j_context`, `get_context`
- **Lifecycle**: `on_entry`, `on_exit`
- **AI/MTIR**: `get_mtir`, `sem`, `call_llm`, `by_operator`
- **Concurrency**: `thread_run`, `thread_wait`
- **Compiler/test plumbing**: `field`, `impl_patch_filename`, `jac_test`, `jsx`, `log_report`, `assign_all`, `safe_subscript`

### byLLM (`jac-byllm/byllm/`)

[`byllm/lib.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-byllm/byllm/lib.jac)
exposes its own `__all__` under the `byllm` namespace:

- **Runtime**: `by` (the `by` operator entry point), `MockLLM`, `Model`, `ModelPool`, `MTIR`, `MTRuntime`
- **Message/tool types**: `Message`, `MessageRole`, `Tool`, `ToolCallResultMsg`, `Image`, `Video`, `StreamEvent`, `IterationAction`, `IterationContext`, `MockToolCall`
- **MCP**: `McpClient`, `McpTool`
- **Errors**: `ByLLMError`, `AuthenticationError`, `RateLimitError`, `ModelNotFoundError`, `OutputConversionError`, `UnknownToolError`, `FinishToolError`, `ConfigurationError`, `McpError`
- **Telemetry & batching**: `register_agent_callback`, `dispatch_batch`, `mark_serialize`

### jac-scale (`jac-scale/jac_scale/`)

[`jac_scale/lib.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/lib.jac)
is intentionally minimal -- a single `kvstore()` factory that returns a `Db`
instance backed by MongoDB or Redis. The substantive abstractions live in
[`jac_scale/abstractions/`](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-scale/jac_scale/abstractions)
as interface contracts:

- `database_provider.jac` -- provider interface
- `deployment_target.jac` -- deployment abstraction
- `image_registry.jac` -- container registry interface
- `logger.jac` -- logging abstraction
- `metrics.jac` -- metrics interface
- `models/` -- `deployment_result.jac`, `resource_status.jac`

### jac-client (`jac-client/jac_client/`)

No `lib.jac`. Client-side code is written in `.cl.jac` files that are
compiled to TypeScript/JavaScript by the client toolchain; the package
exposes its capabilities through the plugin system rather than a curated
re-export module.

### jac-mcp (`jac-mcp/jac_mcp/`)

No `lib.jac`. The package is structured around a plugin entry point
(`plugin.jac`) plus modules for `server.jac`, `tools.jac`, `resources.jac`,
`prompts.jac`, `mode.jac`, and `compiler_bridge.jac`.

---

## Cross-Category Consistency

**Keywords -- uniform.** All nine flow through the same parser, share a small
set of AST nodes (`Archetype`, `Ability`, `HasVar`, `VisitStmt`), and resolve
to methods on `JacRuntimeInterface`. There is no syntactic-sugar path that
bypasses the AST. Bootstrap and full compiler share the front end.

**Builtins -- near-uniform.** Eight of the nine use the lazy-thunk
registration pattern in `runtimelib/builtin.jac`. `printgraph` is the
deliberate exception, declared with a full signature for IDE/type-checker
ergonomics. All nine ultimately delegate to `JacRuntimeInterface`. The same
module also exports several adjacent names (`llm`, access levels, decorators)
that follow the builtin pattern but are not part of the canonical nine --
worth keeping in mind when reasoning about "what counts as a builtin".

**Standard library -- convention varies.** The `import from` requirement
holds everywhere, but the four library packages do not share a common shape:

| Package | `lib.jac` | Style |
|---|---|---|
| `jaclang` | yes | single consolidated `__all__` re-exporting `jac0core/jaclib.jac` |
| `byllm` | yes | own `__all__` in own namespace |
| `jac_scale` | yes (minimal) | `lib.jac` exposes only `kvstore`; substantive abstractions in `abstractions/` directory |
| `jac_client` | no | plugin-based, no curated re-export |
| `jac_mcp` | no | plugin-based, no curated re-export |

For someone learning the ecosystem, this means the surface for "what's
importable from this package" is discovered differently for each package. If
the goal is the blog post's vision of a uniform standard library, the gap
worth closing is giving each plugin a `lib.jac` with a curated `__all__`
analogous to `jac0core/jaclib.jac`.

---

## How to Update This Document

When adding a new abstraction:

1. **Keyword** -- add a row to Category 1. The token must be defined in
   [`jac0core/parser/tokens.na.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/parser/tokens.na.jac),
   the AST node must live in
   [`jac0core/unitree.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/unitree.jac),
   and the runtime entry point belongs on `JacRuntimeInterface` in
   [`jac0core/runtime.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/runtime.jac).
2. **Builtin** -- add the `_get_X` thunk in
   [`runtimelib/builtin.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/builtin.jac),
   the resolver in
   [`runtimelib/impl/builtin.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/runtimelib/impl/builtin.impl.jac),
   the implementation on `JacRuntimeInterface`, and the public name in `__all__`.
3. **Standard-library export** -- add it to the relevant package's `lib.jac`
   `__all__`. If the package does not yet have a `lib.jac`, consider adding
   one rather than relying on per-module imports.
