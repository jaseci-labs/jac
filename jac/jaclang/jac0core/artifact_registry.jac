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

def _marks -> set[str] {
    marked = handoff().get("building");
    if isinstance(marked, list) {
        return {str(name) for name in marked};
    }
    return set();
}

def _record(marked: set[str]) {
    update_handoff(building=sorted(marked) or None);
}

def building -> frozenset[str] {
    return frozenset(_marks());
}

def begin(names: list[str]) -> list[str] {
    marked = _marks();
    added = [
        name
        for name in names
        if name not in marked
    ];
    _record(marked | set(added));
    return added;
}

def end(names: list[str]) {
    _record(_marks() - set(names));
}

def resolution_in_flight -> bool {
    names = set(ROUTER_MODULES);
    for target in ARTIFACTS.values() {
        names.add(target.split(":", 1)[0]);
    }
    for name in names {
        module = sys.modules.get(name);
        spec = module?.__spec__ if module is not None else None;
        if spec is not None and getattr(spec, "_initializing", False) {
            return True;
        }
    }
    return False;
}
