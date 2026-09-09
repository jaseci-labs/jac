# Placement

Where each top-level element of your program runs -- server, client (browser),
or native -- is a **derived compiler fact**, computed by a whole-program
placement solver. You write plain Jac; the solver reads the evidence and
places every element. There is no placement syntax: the old `cl` / `sv` /
`na` markers were removed and no longer parse (run `jac fix placement` to
migrate marker-era code). When a decision must be overridden, the override
lives in `jac.toml` under `[placement.pins]`, not in the source.

## How placement is decided

Every module gets a **placement summary**: per top-level element, the
capability evidence it carries, its references to sibling elements, and its
value-flow escapes. Summaries are serialized into the module's `.jir` next to
the bytecode. The solver consumes summaries and owns every decision:

| Evidence | Pins toward |
|---|---|
| JSX construction, browser globals (`window`, `Date`, `setTimeout`, ...) | client |
| String-path (npm) imports | client |
| `root` access, node/edge/walker archetypes | server |
| Python imports not covered by the portability table | server |
| extern C declarations (clib imports) | native |
| `def:pub` in a server-anchored module, **in an app whose kind has a server** | server (as an endpoint contract) |
| A `[placement.pins]` entry (base table or the owning app's `[apps.<name>.placement.pins]` overlay) | its pinned space (immovable) |
| The entry file of a file-rooted `service` app | server (the module is owned by that app) |

`def:pub` is the one row that depends on the **app kind**, because `pub` means
*export* client-side and *endpoint* server-side: it has no settled meaning until
placement does. In a kind that has a server (`web-app`, `service`,
`service-mesh`, and the default when no kind is declared) it is endpoint
evidence, exactly as before -- an evidence-free `pub` there is deliberately an
endpoint. In a kind with no server (`js-package`, whose codespace is `client`;
`web-static`, `mobile`, `desktop`, `cli`) there is no server for it to mean,
so it is not evidence at all: everything lands client, `pub` means export, and
code carrying genuine server evidence is `E5087` rather than a server
placement that could only fail at runtime. The kind comes from the app that
claims the module (`[apps.<name>] kind`, or `[project] kind` for the implicit
app); a module outside every app root is shared and takes the facts of the
program being compiled.

## App facts

Placement is computed **per app**. Before any other stamp, the driver reads
the nearest `jac.toml` and stamps four *app facts* onto every module: `app`
(the app that claims it, or none for shared code), `app_root`, `app_kind`, and
`owner_app` (the app whose server a server-placed shared module runs on -- see
[Ownership](apps.md#ownership-one-owner-per-server-placed-shared-module)).
`jac check` compiles one rooted program per app entry with that app's facts,
so the same shared module can be placed once for `web` (where it is pulled
into the bundle) and once for `cli` (where it is bridged). No pass reads
`jac.toml`; the stamps are the only channel.

The facts are part of the program. The `.jir` placement-summary cache key
carries an **app-fact digest** -- a hash over the app's name, kind, root,
entry, route, platform, its merged pins, and its npm names -- so editing an
app table invalidates exactly the modules that app claims.

Two laws consume the facts at every symbol use (`E2039`/`W2039`,
`E2040`/`W2040`): an app may use another app's declarations only through the
bridge surface, and shared code may not import from any app. Whether a
cross-module import is a plain in-process import, a client bridge, a
**service bridge** (server code importing server-placed elements owned by a
different app), or a native binding is decided by one classifier over the same
facts; see [Cross-Codespace Interop](../internals/interop.md#one-cross-app-import-rule).

**Variant agreement.** A `.native.jac` variant is selected for a `mobile`
app's native platforms (android / ios; the base `.jac` serves its web
platform), never by its filename alone, and stands in for its sibling `.jac`
module. The two must expose the same public surface -- the
same names, kinds of declaration, parameter names and annotations, `has`
fields -- and each disagreement is `E5105`, reported on the variant.

**Portability by kind.** Whether a Python module may follow its referents
into another codespace is answered by `runtime/portability.jac`'s
`supports(module, space, kind)`: unrestricted on the server for every kind;
empty for the client space of every client-capable kind (honestly: nothing
lowers yet); the native table for native. So every Python import still pins
server, in every app.

From those seeds, placement propagates along symbol references to a fixpoint:
an element referenced by client code follows it into the bundle when its whole
closure can (**pulled client**); requirement-free elements reached from both
spaces compile into each (**dual emission**); and a reference whose closure
cannot move **bridges** instead -- `def:pub` over RPC, archetypes as wire
types, native elements over the wasm edge. Cross-module pulls happen before
code generation, so `jac check` sees the same placements as `jac build`.

The RPC bridge is a *binding*, not a call-site rewrite: a `def:pub` endpoint
reachable from client code is emitted into the bundle as an `async` forwarder
that calls it over HTTP, so the name works in every position -- called,
passed as a callback, stored, returned, re-exported. Because the forwarder is
async, its result is a `Promise<T>` where the server function's is `T`, which
`W6009` reports for value-returning endpoints. A client-side name that no
binding can cover is `E5086` at build time rather than a `ReferenceError` at
module load.

The analysis proposes; lowering disposes. A module that prefers native but
fails to lower is demoted to the server with a note naming the cause, and a
client-pulled element that fails ES lowering demotes the same way (its call
sites bridge instead). The portability table
(`jaclang/runtime/portability.jac`) is the curated fact base for which
python modules may follow their referents into another space -- it is
honestly empty for the client today, so every python import pins server.

## Overriding placement: `[placement.pins]`

The escape hatch is a table in `jac.toml`. Keys are
[fnmatch](https://docs.python.org/3/library/fnmatch.html) patterns matched
against the element's dotted path (`module` or `module.element`, relative to
the project root); values are `"server"`, `"client"`, or `"native"`:

```toml
[placement.pins]
"app.API_KEY"   = "server"    # one element
"kernels.*"     = "server"    # every element of a module
helpers         = "client"    # module-level pin
```

A pin feeds the solver exactly like a source marker used to: the pinned
element is immovable and everything else re-solves around it. Pins are part
of the program -- changing them invalidates the compilation cache, and the
evidence chain reports them (`pinned 'server' ([placement.pins])`).

A **module-level `"server"` pin** carries boundary semantics beyond
placement: client imports of that module become full service-boundary
imports -- non-`:pub` items stay callable with auth and boundary types are
collected -- the trust-boundary shape.

Declaring that a module runs as its own **service** is a different fact with
a different home: an `[apps.<name>]` table with `kind = "service"` and the
module as its `entry-point` (see [Workspaces & Apps](apps.md)). Its
elements are server-anchored by definition and owned by that app; imports of
them from any other app lower to typed-async bridge stubs.

## Seeing and reviewing placements

- `jac check --placements` prints every element's space with the evidence
  chain behind it ("seeded client: jsx construction", "dual client: pulled
  through plain import from app.jac", "demoted server: failed ES lowering"),
  plus an estimated boundary-crossing count.
- Editor hover shows `placement: <space> (inferred)` for any symbol, with a
  `dual` tag when the element is emitted into both spaces.

## Consuming placement: the facts API

The solver is the only thing that computes placement; everything else reads
its verdict. The single query surface is
`jaclang.compiler.placement.placement_facts`:

- `module_spaces(mod)` rolls a compiled module's element-level verdicts up to
  the set of codespaces it emits into (`{"server"}`, `{"client"}`, a mixed
  set, ...); `is_client_only(mod)` / `emits_server_code(mod)` are the common
  questions asked of that rollup.
- `discover_spaces(paths)` answers the same question for a batch of source
  files by running the stamps-only placement compile (no codegen); the deploy
  seal uses it to skip client-only modules -- pinned *and* inferred -- instead
  of parsing them into pod bytecode.
- `sealed_spaces_for(path)` answers from a sealed image's
  `_precompiled/MANIFEST.json`, which persists the per-module verdict at seal
  time (manifest format 5), so post-build tools never re-derive placement.
- `pinned_module_space(path)` exposes the raw `[placement.pins]` *input*
  (base table merged with the owning app's overlay) for the few places that
  need explicit user intent rather than the solved verdict (app-kind
  inference, trust-boundary import handling).
- `compiler/placement/workspace.jac` is the compiler-side workspace reader:
  `app_for_path`, `owner_app_for_path`, `serving_apps`, `app_fact_digest`. It
  parses `[apps]` permissively (validation is the project layer's job) and
  synthesizes the implicit app when there is no `[apps]` table.

Tools must not read `[placement.pins]` directly as if it were the placement
verdict -- pins are one input to the solver, and most client modules carry no
pin at all. Direct `placement_pins` imports are restricted to the solver
layer and enforced by a repository test.

## When do I still pin?

Pins are never *placement* facts -- the solver can infer those. They are
*meaning* facts dataflow cannot see:

| Category | Why inference cannot decide | Surface |
|---|---|---|
| Trust boundaries | A pure function can be *placeable* client-side yet *unsafe* there (secrets, price computation, validation) | `[placement.pins]` entry -> `"server"` |
| API contracts | An endpoint is a promise (auth, serialization, versioning) to parties outside the program | `def:pub` in a server-anchored module |
| Stateful identity | Fork-per-space vs single-home for a mutable glob are different programs; both sound | home the glob with its writers via a pin (see W6006) |
| Environment-dependent semantics | Clock / RNG / env / fs mean different things per space; dual emission changes observable behavior | pin an explicit home |
| Foreign-boundary facts | Ecosystem portability is not program dataflow | portability table + clib declarations |
| Cost mandates | The solver optimizes an average; you hold hard constraints it cannot know | a `"native"` pin as a performance mandate |
| Stability pins | A correct placement flip can still be operationally disruptive | a pin to hold an element where it is |

Punchline: placement syntax is unnecessary. What survives is the
pin-as-trust-boundary, `def:pub`-as-contract, and state / environment / FFI
declarations -- which were never placement markers to begin with.

## Related diagnostics

- `E5082` -- a plain client import references a symbol with no client-side
  presence (dead import).
- `E5084` -- client code uses a symbol from a bare (Python-ecosystem) import;
  the import stays server-placed, so the client bundle never binds the name.
  Quote the module for npm packages: `import from "react" { useRef }`.
- `E5086` -- client code names one of the module's own declarations that the
  bundle never binds. The build fails instead of shipping a `ReferenceError`.
- `E5087` -- an app whose kind has no server contains code that needs one.
- `E2039` / `E2040` -- app isolation and shared layering (see
  [Workspaces & Apps](apps.md#dir-rooted-file-rooted-and-shared)).
- `E5107` / `E5104` / `E5105` / `E5106` -- ownership, the app DAG, variant
  agreement, and the `pub` bridge surface.
- `W6005` -- a function-typed parameter at an RPC call site.
- `W6006` -- a mutable glob would be dual-emitted (state fork).
- `W6007` -- client code uses a server-placed function as a value and no
  forwarder is possible.
- `W6009` -- the client-side forwarder for an endpoint is async, so it returns
  a `Promise<T>` where the server function returns `T`.

See [Diagnostics](diagnostics.md) for the full reference.
