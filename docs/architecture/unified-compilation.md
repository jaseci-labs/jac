# Unified compilation

The compiler uses typed phase and product lists. The authoritative definitions
and executor live in `jac/jaclang/compiler/driver/pipeline.jac`; phase actions
live in `pipeline_runner.jac`, and the shared enums and contracts live in
`pipeline_types.jac`.

## Entry modules and contexts

```toml
[apps.web]
kind = "web-app"
entry-point = "web.main"

[apps.api]
kind = "service"
entry-point = "core.api"
```

An app declaration identifies an entry module, not a directory. CLI selection
establishes the compilation context. Ordinary imports inherit that context;
another app's declared entry establishes a boundary. `default-app` chooses the
CLI default and does not give shared modules a global app context. A program retains
its entry context across dependency requests; callers select a new entry
explicitly. Imports outside the project's directory retain that context too;
their location does not select a different application. App-level placement
pins choose codespaces and do not establish app context.

A private implementation file imported directly participates in the importing
app's compilation. Use the declared entry as the cross-app contract. The compiler
cannot infer an undeclared private boundary from an entry alone.

The terminology is explicit: **app context** identifies the application a module
is compiled for; **placement** identifies its server, client, or native codespace;
**ownership** refers to memory ownership and borrowing. `Module.app` is the sole
app identity stamp. Entry points are dotted module names resolved locally through
the compiler resolver; no source is executed during resolution.

## Pipeline

```mermaid
flowchart TD
    A[CLI entry and target selection] --> B[Contextual compilation request]
    B --> C[Parse source revision or reuse syntax]
    C --> D[App context, imports, symbols and IR]
    D --> E[Placement]
    E --> F[Types and semantic checks]
    F --> G[Boundary and endpoint facts]
    G --> N[Native checks]
    N --> H[Client dependency products]
    H --> Q[Interface product when checking]
    Q --> I[Requested code generation]
    I --> J[Prepared app artifacts]
    J --> K[Initialize modules and start runtime]
```

The pipeline includes explicit app-context, absorbed-import, boundary-fact, and
native-import-fact passes. Pass requirements and provided facts use `AnalysisFact`.
Products use `CompilationProduct`; demand tasks record running, successful,
failed, or cancelled states. Utility products cover formatting, AST conversion,
and introspection, so these consumers do not select passes independently.

The executor validates requirements before running a pass list, records completed
passes and timings, and observes cancellation. Backend consumers request the
products they need. Client dependency traversal belongs to the compiler driver;
the client emitter writes the returned artifacts and copies their assets.
Boundary analysis is a host pass: requests for provider declarations, boundary
types, and WASM host contracts use the driver's dependency loader. There is no
separate parser or global syntax memo for boundary types.

`compile_application` owns the application import worklist for both preparation
and workspace checking. It starts at declared entries, includes package
initializers and conventional page roots, and advances imported modules in their
selected contexts. Checking does not start a second compiler for every helper.
Sealing an explicitly declared app uses this same compilation closure and its
placement facts. It excludes unrelated apps, retains each dependency's selected
app context, and packages the resulting bytecode. Toolchain and implicit package
seals retain package-wide source enumeration.

An interface is an explicit product. Symbol-only dependency loading stops before
body checking; interface preparation requests the flow facts needed to encode
exported types. Cache persistence writes already prepared products and does not
silently schedule analysis.

Bootstrap remains an explicit constraint: compiler modules needed to construct a
schedule must load before that schedule executes. The seed manifest and bootstrap
dependency declarations keep the compiler from recursively compiling itself with
an unavailable pass. A compiler module finishing its loader import cannot evict
analysis data compiled in an enclosing compilation. These are compiler-loading
constraints, not app discovery.
Nested projects shipped inside `jaclang`, such as the admin UI, retain their app
context instead of sharing the compiler's internal program.

## Source reuse and artifact identity

`SourceStore` in `compilation_context.jac` retains one current syntax revision per
source path, including annex contents. Requests in another context clone the
syntax before semantic mutation. Parsed source is shared; app-specific analyzed
IR and target artifacts are distinct.

Context identity includes the selected entry and app, UI and codespace settings,
and analysis/code-generation options. In-memory programs and disk artifact slots
use that identity. Imported symbol trees can progress through remaining passes
without repeating completed stages. Changed source invalidates the affected
module's products. Placement changes and native fallback invalidate the client
product through the scheduler, clearing its completion record, generated output,
and cached artifact together so emission and diagnostics can run again.

Host and WASM still require different target products. A unified pipeline removes
independent frontends and scheduling; it does not make different ABIs equivalent.

## Preparation and runtime

Preparation completes the selected apps before publishing their revisions. It
collects bytecode imports, manifests, client output and native bindings before
initialization. Web builds compile and bundle without executing application code.
Source apps load in namespaces derived from their entry modules, keeping shared
source instantiated in different apps from sharing mutable module globals.
Sealed images retain their manifest module identities.

The application revision cache retains its source inventory and dependency/output
stamps. This inventory detects added routes, assets, and dynamic roots; it does
not parse files to infer app context. A failed preparation leaves the published
revision intact. Startup progress begins before source compilation.

## Removed infrastructure

- Directory-rooted app declarations and directory containment rules.
- Workspace consumer-graph parsing and `ownership.json` snapshots.
- Default-app context inference and E5107 workspace-app validation.
- Pass-class string contracts scattered among individual pass implementations.
- Hidden pass selection in native inference, interface flow recovery, layout,
  client code generation, and compiler tools.
- The unused nominal compile schedule separate from actual execution.
- Executing the web entry as a prerequisite for building client output.

Typed lists keep the order inspectable. An OSP scheduler is unnecessary for this
serial implementation; a future task graph can use the same product identities
if parallel scheduling proves useful. It must preserve context identity, cycles,
cancellation, and failure handling rather than introduce another scheduling path.
