# Source application preparation

`jac run` resolves the selected application and its colocated services, prepares
an executable revision, initializes its modules, and starts the server. Source
analysis happens before application initialization. The server requires serving
metadata and does not compile source to recover missing metadata.

The compiler entry point is
`jaclang.compiler.driver.application.prepare_application(entry, program, root,
services=(), client=False, dev=True)`. It returns a `PreparedApplication` and
publishes it only after all required artifacts succeed. The runtime entry point
is `jaclang.runtime.prepared.initialize_application(prepared, config, served)`.
Programmatic servers must prepare their source application before loading it.
`JacTestClient` and the in-process scale host perform preparation themselves.
Sealed applications load their executable closure, native sections, serving
manifest, and client distribution directly from the image. They never enter
source analysis or rebuild their client bundle at startup. Sealing follows both
bytecode imports and serving exports so shared server dependencies are included
even when placement also assigns them to the client. Deployment bundles bake
the serving manifest before sealing; extracted images are registered and verified
before preparation reads their artifacts. Package initializers are prepared with
the entry module. The serving payload stores a `module_manifests` table keyed by
project-relative source paths, including colocated service entries. Each module
retains its app identity and public/private endpoint metadata. Endpoint contract
validation uses the target module's app identity. Rebuild older sealed
applications to produce this serving payload.
Initialization uses the manifest's module identities, and the
server receives the initialized entry's identity, so an entry such as `app.jac`
cannot be confused with its enclosing sealed package named `app`.
When an image's package name is already occupied by another module (for example,
Python's `site`), its manifest entries load under an image-specific namespace.
The existing module remains intact, and both CLI and in-process serving retain
the initialized entry's name.
Static assets also resolve relative to the sealed image, including configured
asset directories outside its client distribution.

The coordinator, executable-import discovery, and runtime revision record are
Jac modules. The Python import hook reads the revision registry only after that
module loads, avoiding a recursive import while bootstrapping the compiler.
Installed builds can load these modules from their precompiled artifacts.

The revision holds server bytecode, compiler restoration sections, endpoint
access and boundary metadata, client output and native output. The runtime
import hook consumes prepared bytecode and native bindings. A dynamic import
outside the prepared closure explicitly requests additional preparation and
prints the module responsible. Hidden runtime directories, virtual environments,
and installed dependency directories do not belong to this source boundary.

The revision cache lives in `.jac/cache/applications`. Its identity includes the
compiler generation, selected roots and targets, active profile, source inventory,
external dependency stamps, and generated output stamps. An unchanged revision
restores without frontend analysis or rebuilding its client/native outputs.
Missing outputs, changed inputs, unreadable revision records, and `JAC_REBUILD`
trigger preparation. The Python bytecode ABI is part of the revision identity.
A failed revision does not replace the previously published revision.
Runtime logs and database files do not invalidate the source inventory.
Production client builds finish before initialization; a failed build aborts
startup and a corrected application can be prepared on the next run.

Apps declare `entry-point` modules. Directory-based app inference, the source consumer scan,
`ownership.json`, and default-app inference have been removed. The declaration
reader reads configuration only. The selected entry establishes an app compilation
context; ordinary imports inherit it, while another declared entry establishes a
boundary. `default-app` selects a CLI default and does not assign shared modules.

`compiler/driver/pipeline.jac` owns the phase order, pass lists, typed contracts,
product requests, and pass execution. `pipeline_types.jac` defines analysis facts,
products, and task states. `pipeline_runner.jac` implements the phase actions.
Context and import facts are explicit scheduled passes. Backend and tooling
consumers request named products through this pipeline rather than invoking passes.

`compilation_context.jac` holds parsed source revisions and context-specific
programs. A source revision is parsed once per session and cloned before semantic
mutation. App, entry, UI, codespace, and target settings distinguish compilation
contexts and disk artifact namespaces. A symbol-only dependency can progress
through the remaining passes without reparsing or repeating completed passes.
Native and client outputs retain target-specific analysis and code generation.

Preparation produces a revision for each selected app and publishes the set only
after every app succeeds. Source applications load in namespaces derived from
their entries, so colocated apps do not accidentally share module globals through
Python's import cache. Sealed applications use their image's manifest identities.
Web builds compile the entry and bundle its artifacts without executing its entry
block or module initialization.

Development changes use the same preparation entry point. Prepared application
reloads currently reload the backend and signal a full browser reload after a
successful revision; individual client patching remains available to standalone
client compilation. This favors consistent application revisions over maintaining
two independent serving preparation paths.
Compilation errors leave the existing live modules registered; the next edit
can prepare and initialize a replacement.

## Editable source products

`jac build <app> --as source` writes `dist/source` (or `-o <directory>`). It
prepares the selected application and its services through the same coordinator,
then exports Python source, the client compiler's JavaScript workspace, and C
source for native code. `project.json` retains each application's module identity,
serving contracts, native bindings, and client output paths. The prepared cache
also retains the client's native dependency inventory and page-routing state.
`compiler/driver/source_products.jac` owns Python source extraction for application
export, runtime vendoring, and wheel transpilation. Prepared origin mappings retain
the original app identity after `.jac` modules become `.py`.
Client compilation receives the selected entry and compiler program explicitly; it does not infer
another application's pages from mutable runtime target state.

The output contains `requirements.txt`, `build.py`, and `main.py`. Install the
requirements with Python, run `python build.py`, then `python main.py`. Server
applications accept `--host` and `--port`; `--app` selects an exported application.
CLI arguments are forwarded to Python and native executable entries. JavaScript
builds use Node/npm or Bun. C builds use Clang (overridable through `CC`), with a
WASI sysroot for WebAssembly (`WASI_SYSROOT`). Jac is not required in the exported
build or runtime environment. Original project resources remain available to
applications that serve source files or other data.

The Python runtime is a transitive projection of the actual infrastructure,
including package initialization and module-declared `__jac_resources__` data.
Runtime modules own execution; optional build services own compiler operations.
There is no separately maintained server adapter. Module resolution and project
paths live under `jaclang.project`; semantic metadata lives under `jaclang.runtime`.

Native C is produced from the existing native backend's LLVM IR. Binary and source
products share lowering validation, entry initialization, and callback bindings.
`dist/native_product.jac` packages both forms. Wheels use the existing native
shared-library emitter directly and do not require the C projection toolchain.
The C projection uses a pinned LLVM C backend and a versioned compatibility patch;
its provenance and license ship with exports. The generated C retains the selected
target ABI and external native library requirements. Exporting C requires CMake and LLVM
22 development files, or an explicit `JAC_LLVM_CBE` executable. Unsupported lowering
fails at export instead of substituting a Python implementation.

Prepared applications isolate their project imports under a private namespace.
Exported runtime packages retain their public package namespace and ordinary
Python import rules; their artifact records explicitly disable project import
scoping. Both use the same loader for executable code, native bindings, and
semantic metadata.

The `jac-pack-eject` CI job rebuilds the full `jaclang_org` site without Jac and runs
the shared browser journey, including native game frames. It also rebuilds the
existing native arena replay from C and compares its six state snapshots. This is
an integration compatibility gate; it does not exhaustively cover every Jac
feature, external library, or target platform.
