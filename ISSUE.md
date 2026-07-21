The PR does not yet represent the right long-term fix. The uncommitted follow-up moves in the correct direction by using the established ESTree import mechanism, but the implementation still combines compiler-owned imports with regex-based consumer finalization. That duplicates responsibility, misses compiler paths, and introduces an npm publishing regression.

Findings

1. Critical: npm publishing can emit duplicate runtime imports

[collect_npm_sources](file:///home/jac/repos/jac2js-bug/jac/jaclang/publish/impl/npm_sources.impl.jac#L181-L200) now finalizes generated JS with an import from @jac/runtime. Later, [_wire_externals](file:///home/jac/repos/jac2js-bug/jac/jaclang/publish/impl/npm_sources.impl.jac#L31-L49) detects the same referenced symbols and prepends another import from the configured package, normally @jaseci/runtime.

A JSX module can therefore become:

import { __jacJsx } from "@jaseci/runtime";
import { __jacJsx } from "@jac/runtime";

That is invalid ESM because __jacJsx is bound twice. It also leaves the compiler-internal @jac/runtime package in published output.

Long-term fix: codegen should emit the import once. The npm publisher should remap that import’s module source to the configured runtime package rather than rediscovering runtime symbols with regex. Add an assertion that published JS:

- contains exactly one __jacJsx import;
- contains the configured runtime package;
- does not contain @jac/runtime.

2. High: normal React and Preact JSX is still not fixed at the producer

The new compiler-side call in [_jsx_fragment](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac#L3396-L3413) only handles compiler-created fragments.

Normal JSX goes through [exit_jsx_element](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac#L3475-L3499), which injects only backend.view_runtime_symbols(view). React currently returns an empty list, even though its lowering emits __jacJsx. Preact inherits that behavior.

Consequently, raw mod.gen.js for ordinary React/Preact JSX can still lack the import. The finalizers in the CLI, MCP, bundle builder, and publisher merely hide that producer bug.

Smallest fix: have ReactBackend.view_runtime_symbols() return its JSX factory symbol. Preact then inherits the fix. Test raw mod.gen.js, without any finalizer.

3. High: the shared fragment implementation is not backend-neutral

[_jsx_fragment](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac#L3396-L3422) emits a factory call and now imports that factory. Solid inherits React’s jsx_factory_name, but Solid normally lowers fragments to native JSX syntax and declares only __jacSpawn as a required global.

View returns, skips, awaiting blocks, or exception fragments can therefore make Solid output import __jacJsx, even though the Solid runtime does not provide that symbol.

Long-term fix: represent compiler-created fragments using the existing neutral ViewElement/FragmentTag IR and let each backend lower it:

- React/Preact → __jacJsx;
- Solid → native <>...</> JSX.

Avoid encoding React’s factory model in a shared EsastGenPass helper.

4. High: the regex finalizer repeats established compiler functionality

[js_runtime_globals.jac](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/js_runtime_globals.jac#L19-L85) reparses emitted JavaScript with regex while the compiler already has a typed ESTree import system in [_inject_runtime_import](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac#L3531-L3554).

The regex implementation is brittle:

- identifiers in comments and strings count as references;
- only exact function name( declarations count as local definitions;
- imports from another source can cause duplicate local bindings;
- import aliases and more complex formatting are only partially handled;
- merging into an existing import can leave a doubled semicolon because the matching pattern excludes the original semicolon;
- it uses the currently active backend, not necessarily the backend that produced the JS;
- its object backend parameter discards Jac’s type-safety benefits.

Once JSX and spawn coverage is complete in codegen, delete this finalizer and remove consumer calls from the CLI, MCP, bundle builder, publisher, HMR, eject, test runner, and JacToJSCompiler.

The new spawn injection in [_build_spawn_runtime_call](file:///home/jac/repos/jac2js-bug/jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac#L5730-L5740) does follow the established pattern and appears correctly placed.

5. Medium: the regression suite is oversized and locks in the workaround

The test called “JacProgram.compile gen.js” does not inspect mod.gen.js; it recompiles through [ClientBundleBuilder._compile_to_js](file:///home/jac/repos/jac2js-bug/jac/tests/runtimelib/client/test_js_runtime_globals_emission.jac#L125-L132), which applies the finalizer. That is why the missing producer import is not exposed.

The source-text test at [test_js_runtime_globals_emission.jac](file:///home/jac/repos/jac2js-bug/jac/tests/runtimelib/client/test_js_runtime_globals_emission.jac#L220-L242) is particularly brittle. It requires a hard-coded list of consumers to contain finalize_js_for_emission, institutionalizing the duplication instead of testing behavior.

The file also includes an unused shutil import.

Replace most of this suite with focused behavior tests:

1. Raw React JSX imports __jacJsx.
2. Raw Preact JSX imports __jacJsx.
3. Raw Solid JSX does not reference/import __jacJsx.
4. Solid compiler-created fragments remain backend-native.
5. Remote spawn imports __jacSpawn.
6. Runtime source does not self-import.
7. Published npm JS remaps the runtime import exactly once.

CONTRIBUTING.md compliance

- The compiler-side _inject_runtime_import calls are idiomatic, typed ESTree changes.
- The regex finalizer and repeated consumer calls conflict with the guidance to avoid bloat and duplication.
- The release-note fragment exists locally, but it is currently untracked and therefore is not part of the pushed PR.
- git diff --check passes.
- The focused test run reported 10 failures and 2 passes, primarily because the current checkout hits an unrelated compiler scheduling error involving OwnershipCheckPass. jac check was blocked by the same scheduler issue, so the Jac lint/type-check result could not be established.

Recommended design

┌───────────────────┐
│ Jac source        │
└─────────┬─────────┘
          ▼
┌────────────────────────────────────┐
│ EsastGenPass                       │
│ - backend lowers runtime operation │
│ - _inject_runtime_import owns ESM  │
└─────────┬──────────────────────────┘
          ▼
┌──────────────────────────┐
│ emission-ready mod.gen.js│
└─────────┬────────────────┘
          ▼
┌────────────────────────────────────┐
│ Consumers                          │
│ CLI / MCP / Vite / HMR / publisher│
│ consume output without finalizing  │
└────────────────────────────────────┘

In short: finish the compiler-owned ESTree solution and remove the consumer-owned regex solution. That is the established, maintainable, scalable pattern in this codebase
