import os;
import time;
import from pathlib { Path }
import from jaclang.compiler.driver.compilation_context {
    CompilationSession,
    SourceStore
}
import from jaclang.compiler.driver.dependency_graph { dependency_groups }
import from jaclang.compiler.driver.jir { read_dep_rows, read_section_bytes, SEC_DEPS }

obj PrecompilePlan {
    has groups: list[list[str]],
        prerequisites: dict[int, set[int]],
        sources: SourceStore,
        measurements: dict[str, any];

    def work_queue -> tuple[list[str], dict[int, set[int]]] {
        paths: list[str] = [];
        first: dict[int, int] = {};
        last: dict[int, int] = {};
        for (group, members) in enumerate(self.groups) {
            first[group] = len(paths);
            paths.extend(members);
            last[group] = len(paths) - 1;
        }
        prerequisites: dict[int, set[int]] = {};
        for group in first {
            prerequisites[first[group]] = {
                last[dependency] for dependency in self.prerequisites.get(group, set())
            };
            for index in range(first[group] + 1, last[group] + 1) {
                prerequisites[index] = {index - 1};
            }
        }
        return (paths, prerequisites);
    }
}

def plan_precompile(
    paths: list[str], package_root: str, app: str = ""
) -> PrecompilePlan {
    started = time.monotonic();
    import from jaclang.dist.precompile_bytecode { precompile_context }
    import from jaclang.compiler.frontend.parser.frontend { annex_sources }
    import from jaclang.project.source { read_file_with_encoding }
    import from jaclang.bootstrap_manifest { is_native_only_seed }
    with CompilationSession() as session {
        dependencies_graph = session.program.deps;
        edges: dict[str, list[str]] = {};
        pending = sorted(set(paths), reverse=True);
        package_path = Path(package_root).resolve();
        dependency_hits = 0;
        while pending {
            path = os.path.realpath(pending.pop());
            if path in edges {
                continue;
            }
            program = precompile_context(path, package_root, session.program, app);
            dependencies: set[str] | None = None;
            found = program.iface_registry()._module_jir(path);
            if found is not None {
                (data, base_dir) = found;
                if read_section_bytes(data, SEC_DEPS) is not None {
                    dependencies = {
                        dep for (dep, _, _) in read_dep_rows(data, base_dir)
                    };
                    dependency_hits += 1;
                }
            }
            if dependencies is None {
                try {
                    unit = program.source_store.load(
                        read_file_with_encoding(path),
                        path,
                        program,
                        annex_sources(path)
                    );
                    with program.analysis.measure(path, "frontend:dependencies") {
                        dependencies_graph.record_module(unit.syntax);
                    }
                    dependencies = dependencies_graph.dependencies.get(path, set());
                } except (OSError, ValueError) {
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
        owners = {
            path: idx for (idx, members) in enumerate(groups) for path in members
        };
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
            "dependency_hits": dependency_hits,
            "seconds": time.monotonic() - started,
            "analysis": [
                program.analysis.measurements() for program in session.programs()
            ]
        };
        sources = session.program.source_store;
        session.program.source_store = SourceStore();
        return PrecompilePlan(groups, prerequisites, sources, measurements);
    }
}
