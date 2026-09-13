def application_edges(
    entry_path: str, app_name: str, app_kind: str, project_root: str
) -> list[tuple[str, str]] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
    prog = JacProgram();
    prog.compile(
        entry_path,
        options=CompileOptions(
            no_cgen=True,
            target_app=app_name,
            app_kind=app_kind,
            project_root=project_root
        )
    );
    if prog.errors_had {
        first = prog.errors_had[0];
        raise ValueError(
            f"app '{app_name}' entry '{entry_path}' does not compile: {first}"
        );
    }
    edges: list[tuple[str, str]] = [];
    seen: set[int] = set();
    while True {
        fresh: list[any] = [];
        for hub in list(prog._search_hubs()) {
            for mod in list(hub.values()) {
                if id(mod) not in seen {
                    seen.add(id(mod));
                    fresh.append(mod);
                }
            }
        }
        if not fresh {
            break;
        }
        for mod in fresh {
            if not (mod and mod.gen) {
                continue;
            }
            man = mod.gen.interop_manifest;
            if man is None {
                continue;
            }
            if not man.app_edges and not (man.walker_access or man.func_access) {
                try {
                    require_product(prog, mod, CompilationProduct.BOUNDARIES);
                    man = mod.gen.interop_manifest;
                } except Exception {
                    continue;
                }
                if man is None {
                    continue;
                }
            }
            for (consumer, provider) in list(man.app_edges) {
                edges.append((str(consumer), str(provider)));
            }
        }
    }
    return edges;
}
