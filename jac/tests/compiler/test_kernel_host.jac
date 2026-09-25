"""The kernel host answers ModuleAnalysis from a typed host snapshot.

`KernelInputs` is everything the host tells the analysis (config answers,
workspace specs, platform facts, a pre-resolved import table); the
`KernelHost` serves those answers, does its own file I/O, buffers events for
replay, and hands the few host-only services (compiler objects, Python
parsing, interface caches) back to the host. `JAC_KERNEL_HOST=1` routes every
user-module analysis through it, which must change nothing a user can see."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { KERNEL_HOST_ENV, active_host }
import from jaclang.compiler.frontend.kernel_host {
    KernelHost,
    kernel_census,
    reset_kernel_census
}
import from jaclang.compiler.frontend.kernel_inputs { ImportResolution, KernelInputs }
import from jaclang.project.compiler_host { ProjectHost }
import from jaclang.project.workspace_model { WorkspaceSpec }

glob CONFIG: str = '[project]\nname="kernel-demo"\n[apps.web]\nkind="web-app"\nentry-point="main"\n';

"""A small multi-module project: an annexed Jac module, a local Python
module, stdlib imports, a shared node, and one type error in the entry."""
def write_project(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'util.jac').write_text(
        'import os;\ndef helper(x: int) -> int;\nobj Point { has x: int = 0; }\n'
    );
    (base / 'util.impl.jac').write_text(
        'impl helper(x: int) -> int { return x + len(os.sep); }\n'
    );
    (base / 'pyhelp.py').write_text(
        'import json\n\ndef twice(x: int) -> int:\n    return 2 * x\n'
    );
    (base / 'shared.jac').write_text('node Item { has label: str = ""; }\n');
    (base / 'main.jac').write_text(
        'import from util { helper, Point }\n'
            + 'import from pyhelp { twice }\n'
            + 'import from shared { Item }\n'
            + 'import json;\n'
            + 'def go -> int {\n'
            + '    p = Point(x=1);\n'
            + '    return helper(p.x) + twice(2) + len(json.dumps({}));\n'
            + '}\n'
            + 'with entry { x: str = go(); root ++> Item(label="a"); }\n'
    );
}

"""Compile the project's entry and project what a user can observe: every
diagnostic and, per project module, its decided codespace, placement
summary and native verdict, with the project directory normalized away."""
def observe(base: Path, kernel: bool) -> dict[str, any] {
    import from jaclang.compiler.placement.placement { get_module_summary }
    previous = os.environ.get(KERNEL_HOST_ENV);
    if kernel {
        os.environ[KERNEL_HOST_ENV] = "1";
    } else {
        os.environ.pop(KERNEL_HOST_ENV, None);
    }
    try {
        program = JacProgram();
        program.compile(str(base / 'main.jac'), no_cgen=True);
    } finally {
        if previous is None {
            os.environ.pop(KERNEL_HOST_ENV, None);
        } else {
            os.environ[KERNEL_HOST_ENV] = previous;
        }
    }
    prefix = str(base);
    real_prefix = os.path.realpath(prefix);
    def norm(text: str) -> str {
        return text.replace(real_prefix, "<proj>").replace(prefix, "<proj>");
    }
    facts: dict[str, any] = {};
    for context in [program] + list(program.contexts.values()) {
        for (path, mod) in context.mod.hub.items() {
            if not os.path.realpath(path).startswith(real_prefix) {
                continue;
            }
            verdict = active_host().native_verdict(path, context);
            facts[norm(path)] = (
                mod.decided_codespace,
                norm(repr(get_module_summary(mod, context))),
                repr(verdict)
            );
        }
    }
    return {
        "errors": sorted(norm(str(e)) for e in program.errors_had),
        "warnings": sorted(norm(str(w)) for w in program.warnings_had),
        "facts": facts
    };
}

test "kernel inputs round-trip through JSON with their types intact" {
    with TemporaryDirectory() as td {
        base = Path(td);
        write_project(base);
        entry_file = str(base / 'main.jac');
        host = active_host();
        assert isinstance(host, ProjectHost);
        inputs = host.kernel_inputs(
            JacProgram(), entry_file, CompileOptions(no_cgen=True)
        );
        text = inputs.to_json();
        restored = KernelInputs.from_json(text);
        assert restored.to_json() == text;
        assert restored.project_defaults is not None;
        project_dir = os.path.realpath(td);
        spaces = [ws for ws in restored.workspaces.values()];
        assert spaces and all(isinstance(ws, WorkspaceSpec) for ws in spaces);
        assert any(
            os.path.realpath(ws.project_root) == project_dir and "web" in ws.apps
            for ws in spaces
        );
        targets = {r.target: r for r in restored.imports};
        assert "util" in targets and isinstance(targets["util"], ImportResolution);
        assert targets["util"].path.endswith("util.jac");
        assert targets["util"].language == "jac";
        assert "pyhelp.twice" in targets or "pyhelp" in targets;
        assert restored.layout.annex_folders == inputs.layout.annex_folders;
        assert restored.manifest.is_seed("compiler/frontend/host.jac");
        assert not restored.manifest.is_seed("compiler/frontend/kernel_host.jac");
        kernel = KernelHost(inputs=restored);
        assert kernel.resolve_module("util", entry_file)
            == (targets["util"].path, targets["util"].language);
        assert kernel.project_facts(entry_file) is not None;
        assert kernel.annex_files(str(base / 'util.jac'))
            == [str(Path(os.path.realpath(td)) / 'util.impl.jac')];
        try {
            kernel.resolve_module("not_in_the_snapshot", entry_file);
            assert False , "a snapshot without a host must not invent an answer";
        } except RuntimeError {}
        assert kernel.census.total_misses() == 1;
    }
}

test "analysis under the kernel host matches the host path and misses nothing" {
    with TemporaryDirectory() as host_dir {
        with TemporaryDirectory() as kernel_dir {
            write_project(Path(host_dir));
            write_project(Path(kernel_dir));
            expected = observe(Path(host_dir), kernel=False);
            reset_kernel_census();
            observed = observe(Path(kernel_dir), kernel=True);
            census = kernel_census();
            assert census.sessions >= 1 , "the kernel host never ran";
            assert census.calls.get("resolve_module", 0) > 0;
            assert census.calls.get("compile_module", 0) > 0;
            assert census.total_misses() == 0 , census.summary();
            assert expected["errors"]
                and any("Cannot assign int to str" in e for e in expected["errors"]);
            assert observed["errors"] == expected["errors"];
            assert observed["warnings"] == expected["warnings"];
            assert set(observed["facts"]) == set(expected["facts"]);
            assert len(expected["facts"]) >= 3;
            for path in expected["facts"] {
                assert observed["facts"][path] == expected["facts"][path] , path;
            }
        }
    }
}
