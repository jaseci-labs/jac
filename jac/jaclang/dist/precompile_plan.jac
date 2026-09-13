"""Plan package work from compiler dependency facts, grouping import cycles."""

import os;
import from pathlib { Path }
import from jaclang.compiler.driver.compilation_context {
    CompilationSession,
    SourceStore,
    cache_scope
}
import from jaclang.compiler.driver.dependency_graph { dependency_groups }
import from jaclang.compiler.driver.jir {
    get_module_cache_path,
    is_module_cache_valid,
    read_dep_rows,
    read_section_bytes,
    SEC_DEPS
}

obj PrecompilePlan {
    has groups: list[list[str]],
        prerequisites: dict[int, set[int]],
        sources: SourceStore,
        measurements: dict[str, any];
}

def plan_precompile(
    paths: list[str], package_root: str, app: str = ""
) -> PrecompilePlan {
    import from jaclang.dist.precompile_bytecode { precompile_context }
    import from jaclang.compiler.frontend.parser.frontend { annex_sources }
    import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
    import from jaclang.bootstrap_manifest { is_native_only_seed }
    session = CompilationSession();
    dependencies_graph = session.program.deps;
    edges: dict[str, list[str]] = {};
    pending = sorted(set(paths), reverse=True);
    package_path = Path(package_root).resolve();
    while pending {
        path = os.path.realpath(pending.pop());
        if path in edges {
            continue;
        }
        program = precompile_context(path, package_root, session.program, app);
        dependencies: set[str] | None = None;
        with cache_scope(program.context_key, program.options) {
            cache = get_module_cache_path(path);
            if is_module_cache_valid(path, cache) {
                try {
                    data = cache.read_bytes();
                    if read_section_bytes(data, SEC_DEPS) is not None {
                        dependencies = {dep for (dep, _, _) in read_dep_rows(data)};
                    }
                } except OSError {}
            }
        }
        if dependencies is None {
            try {
                unit = program.source_store.load(
                    read_file_with_encoding(path), path, program, annex_sources(path)
                );
                dependencies_graph.record_module(unit.syntax);
                dependencies = dependencies_graph.dependencies.get(path, set());
            } except (OSError, ValueError) {
                # The requested unit still runs and reports its normal compiler diagnostic.
                dependencies = set();
            }
        }
        edges[path] = sorted(
            dep
            for dep in dependencies
            if dep.endswith(".jac")
                and Path(dep).is_relative_to(package_path)
                and Path(dep).is_file()
                and not is_native_only_seed(
                    Path(dep).relative_to(package_path).as_posix()
                )
        );
        pending.extend(reversed(edges[path]));
    }
    groups = dependency_groups(edges, paths);
    owners = {path: idx for (idx, members) in enumerate(groups) for path in members};
    prerequisites = {
        idx: {
            owners[dep] for path in members
            for dep in edges[path]
            if owners[dep] != idx
        } for (idx, members) in enumerate(groups)
    };
    measurements = {
        "groups": len(groups),
        "modules": len(edges),
        "syntax_parses": session.program.source_store.parses,
        "retained_syntax": len(session.program.source_store.units),
        "analysis": [program.analysis.measurements() for program in session.programs()]
    };
    # Only bounded pristine syntax crosses fork; no evaluated program is retained.
    return PrecompilePlan(
        groups, prerequisites, session.program.source_store, measurements
    );
}
