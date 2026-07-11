import os;

import from pathlib { Path }
import from jaclang.cli.console { console }

impl build(
    filename: str = "",
    projection: str = "jab",
    output: str = "dist",
    no_typecheck: bool = False,
    check_only: bool = False,
    client: str = "",
    platform: str | None = None
) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.kinds { resolve_entry }

    if client {
        import from jaclang.runtimelib.client.cli { run_client_build }
        return run_client_build(filename, client, platform);
    }

    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if cfg is None or cfg.project_root is None {
        console.error(
            "jac build needs a project.",
            hint="Run inside a Jac project (jac.toml), or scaffold one with jac create."
        );
        return 1;
    }
    project_root = str(cfg.project_root);

    entry_path = filename or resolve_entry(cfg, project_root);
    if entry_path and not os.path.isabs(entry_path) {
        entry_path = os.path.join(project_root, entry_path);
    }

    if not no_typecheck {
        import from jaclang.cli.commands.analysis { check }
        console.print("  Running whole-program type-check", style="muted");
        gate_rc = check(
            paths=[project_root],
            ignore=[".jac", ".jachome", ".venv", "venv", "node_modules", ".git"]
        );
        if gate_rc != 0 {
            console.error(
                "Build gate failed: the project does not type-check.",
                hint="Fix the errors above, or bypass once with --no-typecheck."
            );
            return gate_rc;
        }
        console.print("  ✔ Gate passed", style="success");
    }
    if check_only {
        return 0;
    }

    if projection in ["jab", "sealed", "binary", "wheel", "npm"] {
        import from jaclang.cli.commands.project { bundle }
        return bundle(output=output, target=projection);
    }
    if projection == "source" {
        import from jaclang.cli.commands.eject { eject }
        return eject(
            source=project_root,
            output=(output if output != "dist" else ""),
            force=False
        );
    }
    if projection == "native" {
        import from jaclang.cli.commands.nacompile { nacompile }
        if not entry_path or not os.path.isfile(entry_path) {
            console.error(
                "No entry file for the native projection.",
                hint="Set [project] entry-point or pass one: jac build main.na.jac --as native"
            );
            return 1;
        }
        stem = os.path.splitext(os.path.basename(entry_path))[0].split(".")[0];
        os.makedirs(output, exist_ok=True);
        return nacompile(filename=entry_path, output=os.path.join(output, stem));
    }
    console.error(f"Unknown projection: '{projection}'");
    return 1;
}
