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
| `def:pub` in a server-anchored module | server (as an endpoint contract) |
| A `[placement.pins]` entry | its pinned space (immovable) |
| Membership in `[scale.microservices.routes]` | server (the module is a service) |

From those seeds, placement propagates along symbol references to a fixpoint:
an element referenced by client code follows it into the bundle when its whole
closure can (**pulled client**); requirement-free elements reached from both
spaces compile into each (**dual emission**); and a reference whose closure
cannot move **bridges** instead -- `def:pub` calls over RPC, archetypes as
wire types, native elements over the wasm edge. Cross-module pulls happen
before code generation, so `jac check` sees the same placements as
`jac build`.

The analysis proposes; lowering disposes. A module that prefers native but
fails to lower is demoted to the server with a note naming the cause, and a
client-pulled element that fails ES lowering demotes the same way (its call
sites bridge instead). The portability table
(`jaclang/jac0core/portability.jac`) is the curated fact base for which
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
a different home: `[scale.microservices.routes]` (see
[Microservice Interop](plugins/jac-scale-http.md#microservice-interop-sv-to-sv)).
Modules in the routes table are server-anchored by definition and their
imports lower to RPC service stubs.

## Seeing and reviewing placements

- `jac check --placements` prints every element's space with the evidence
  chain behind it ("seeded client: jsx construction", "dual client: pulled
  through plain import from app.jac", "demoted server: failed ES lowering"),
  plus an estimated boundary-crossing count.
- Editor hover shows `placement: <space> (inferred)` for any symbol, with a
  `dual` tag when the element is emitted into both spaces.

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
- `W6005` -- a function-typed parameter at an RPC call site.
- `W6006` -- a mutable glob would be dual-emitted (state fork).
- `W6007` -- client code uses a server-placed function as a value.

See [Diagnostics](diagnostics.md) for the full reference.
