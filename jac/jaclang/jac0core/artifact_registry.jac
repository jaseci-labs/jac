import sys;

glob ARTIFACTS: dict[str, str] = {
         "llvm-shim": "jaclang.compiler.backends.native.llvm.shim_path:ShimArtifact",
         "c-floor": "jaclang.compiler.backends.native.floors:CFloorArtifact",
         "musl": "jaclang.compiler.backends.native.floors:MuslArtifact",
         "wasm-libc": "jaclang.compiler.backends.native.floors:WasmLibcArtifact",
         "typeshed": "jaclang.compiler.types.stubcat.locate:TypeshedArtifact",
         "stubcat": "jaclang.compiler.types.stubcat.locate:StubcatArtifact",
         "precompiled": "jaclang.dist.precompiled:PrecompiledArtifact",
         "kernel": "jaclang.compiler.backends.native.kernel_resolve:KernelArtifact",
         "llvm-cbe": "jaclang.toolchains.c_backend:CBackendArtifact",
         "bun": "jaclang.client.js_runtime:BunArtifact",
         "js-engine": "jaclang.client.js_runtime:JsEngineArtifact",
         "jacpython": "jaclang.dist.interpreter:JacPythonArtifact",
         "postgres": "jaclang.data.pg_dist:PostgresArtifact",
         "node": "jaclang.toolchains.tools:NodeArtifact",
         "jdk": "jaclang.toolchains.tools:JdkArtifact",
         "patchelf": "jaclang.toolchains.tools:PatchelfArtifact"
     },
     ROUTER_MODULES: tuple[str, ...] = (
         "jaclang.artifacts.model",
         "jaclang.artifacts.router",
         "jaclang.artifacts.kit"
     );

def _marks -> set[str];

def _record(marked: set[str]);

def building -> frozenset[str];

def begin(names: list[str]) -> list[str];

def end(names: list[str]);

def resolution_in_flight -> bool;
