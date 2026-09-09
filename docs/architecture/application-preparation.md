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
Sealed applications continue to supply their prebuilt serving manifests.

The coordinator, executable-import discovery, and runtime revision record are
Jac modules. The Python import hook reads the revision registry only after that
module loads, avoiding a recursive import while bootstrapping the compiler.
Installed builds can load these modules from their precompiled artifacts.

The revision holds server bytecode, compiler restoration sections, endpoint
access and boundary metadata, client output and native output. The runtime
import hook consumes prepared bytecode and native bindings. A dynamic import
outside the prepared closure explicitly requests additional preparation and
prints the module responsible.

The revision cache lives in `.jac/cache/applications`. Its identity includes the
compiler generation, selected roots and targets, active profile, source inventory,
external dependency stamps, and generated output stamps. An unchanged revision
restores without frontend analysis or rebuilding its client/native outputs.
Missing outputs, changed inputs, unreadable revision records, and `JAC_REBUILD`
trigger preparation. The Python bytecode ABI is part of the revision identity.
A failed revision does not replace the previously published revision.

Workspace ownership has a separate persistent index in `.jac/cache/ownership.json`.
A preparation transaction supplies its inventory to the ownership consumer.
Nested cache-validation and placement queries reuse that transaction's snapshot.
Outside preparation, callers can use `workspace_snapshot()` to establish the same
scope. A new scope reconciles the filesystem again, so additions and deletions
are observed. Ownership records include compiler and workspace identities.

Development changes use the same preparation entry point. Prepared application
reloads currently reload the backend and signal a full browser reload after a
successful revision; individual client patching remains available to standalone
client compilation. This favors consistent application revisions over maintaining
two independent serving preparation paths.
Compilation errors leave the existing live modules registered; the next edit
can prepare and initialize a replacement.
