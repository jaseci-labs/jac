"""ModuleAnalysis runs inside the native compiler kernel.

`jc_analyze` takes the host's `KernelInputs` snapshot, installs a kernel-side
`KernelHost` with no host behind it, and runs the entry's analysis (parse, IR,
placement, analysis passes including type checking) natively; Python modules
cross as host-built interfaces. Its report (per-module flags and completed
passes, every diagnostic) must match the host's own `analyze_module` path. The
in-process case runs the same kernel code under Python and needs no kernel lib;
the native cases skip where no kernel with `jc_analyze` is loaded."""
import gc;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_BLOCKED,
    ANALYSIS_OK,
    AnalysisDiag,
    AnalysisReport,
    run_kernel_analysis
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.project.kernel_snapshot {
    call_kernel_analyze,
    host_analysis,
    kernel_analysis,
    kernel_analysis_json
}

glob CONFIG: str = '[project]\nname="kernel-demo"\n[apps.web]\nkind="web-app"\nentry-point="main"\n';

"""An annexed Jac module, a local Python module, stdlib imports, a shared
node, and two type errors in the entry (one only visible through the Python
module's signature)."""
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
            + 'with entry { x: str = go(); y: int = twice("a"); root ++> Item(label="a"); }\n'
    );
    (base / 'clean.jac').write_text(
        'import from util { helper }\n'
            + 'def total(xs: list[int]) -> int {\n'
            + '    acc = 0;\n'
            + '    for x in xs { acc += helper(x); }\n'
            + '    return acc;\n'
            + '}\n'
            + 'with entry { print(total([1, 2, 3])); }\n'
    );
}

def diag_rows(diags: list[AnalysisDiag], base: str) -> list[tuple[str, str, int]] {
    return sorted(
        (d.code, os.path.relpath(os.path.realpath(d.path), base), d.line) for d in diags
    );
}

"""What parity means: the entry's flags and completed passes, and every
diagnostic's code, file and line."""
def observe(outcome: AnalysisReport, entry_file: str, base: str) -> dict[str, any] {
    entry_module = outcome.module(entry_file);
    assert entry_module is not None , f"no report for {entry_file}: {outcome.to_json()}";
    return {
        "status": outcome.status,
        "parse_failed": entry_module.parse_failed,
        "blocked": entry_module.blocked,
        "passes": list(entry_module.passes),
        "errors": diag_rows(outcome.errors, base),
        "warnings": diag_rows(outcome.warnings, base)
    };
}

def host_view(base: Path, entry_name: str) -> dict[str, any] {
    entry_file = str(base / entry_name);
    outcome = host_analysis(
        active_host(), JacProgram(), entry_file, CompileOptions(no_cgen=True)
    );
    return observe(outcome, entry_file, str(base));
}

def kernel_json(base: Path, entry_name: str) -> str {
    return kernel_analysis_json(
        active_host(),
        JacProgram(),
        str(base / entry_name),
        CompileOptions(no_cgen=True)
    );
}

def loaded_kernel -> any {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None or not hasattr(kernel.lib, "jc_analyze") {
        return None;
    }
    return kernel;
}

def rss_kb -> (int | None) {
    try {
        with open("/proc/self/status", encoding="utf-8") as f {
            for line in f {
                if line.startswith("VmRSS:") {
                    return int(line.split()[1]);
                }
            }
        }
    } except OSError {
        return None;
    }
    return None;
}

test "the kernel's analysis code run in process matches the host path" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        expected = host_view(base, 'main.jac');
        assert expected["status"] == ANALYSIS_BLOCKED;
        assert ("E1001", "main.jac", 9) in expected["errors"];
        assert ("E1053", "main.jac", 9) in expected["errors"];
        entry_file = str(base / 'main.jac');
        outcome = run_kernel_analysis(kernel_json(base, 'main.jac'), entry_file, None);
        assert not outcome.misses , outcome.misses;
        assert observe(outcome, entry_file, str(base)) == expected;
        assert outcome.module(str(base / 'util.jac')) is not None;
    }
}

test "kernel inputs carry the client framework and the seam-warning setting" {
    import from jaclang.compiler.frontend.host { CheckSettings, ProjectDefaults }
    import from jaclang.compiler.frontend.kernel_host { KernelHost }
    import from jaclang.compiler.frontend.kernel_inputs { KernelInputs }
    quiet = CheckSettings(warn_native_seams=False);
    inputs = KernelInputs(
        project_defaults=ProjectDefaults(
            default_codespace="",
            native_closure_cap=0,
            native_require=[],
            native_target="",
            native_debug=False,
            native_opt=2,
            native_threads=4,
            native_link_mode="objects",
            memory_profile="managed",
            memory_enforce=[],
            memory_exempt=[],
            check=quiet,
            client_framework="solid"
        ),
        check_settings={"": quiet, "web": CheckSettings()}
    );
    restored = KernelInputs.from_json(inputs.to_json());
    assert restored.to_json() == inputs.to_json();
    kernel = KernelHost(inputs=restored);
    defaults = kernel.project_defaults();
    assert defaults is not None;
    assert defaults.client_framework == "solid";
    assert not defaults.check.warn_native_seams;
    assert not kernel.check_settings("").warn_native_seams;
    assert kernel.check_settings("web").warn_native_seams;
    assert kernel.census.total_misses() == 0;
}

test "native jc_analyze matches the host path" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        for entry_name in ('main.jac', 'clean.jac') {
            expected = host_view(base, entry_name);
            entry_file = str(base / entry_name);
            outcome = AnalysisReport.from_json(
                call_kernel_analyze(
                    kernel, kernel_json(base, entry_name), entry_file, None
                )
            );
            assert not outcome.misses , outcome.misses;
            assert observe(outcome, entry_file, str(base)) == expected , entry_name;
        }
        clean = kernel_analysis(
            active_host(),
            JacProgram(),
            str(base / 'clean.jac'),
            CompileOptions(no_cgen=True)
        );
        assert clean.status == ANALYSIS_OK;
        assert not clean.errors;
    }
}

test "repeated native jc_analyze calls do not grow memory without bound" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        inputs_json = kernel_json(base, 'main.jac');
        def run_once {
            outcome = AnalysisReport.from_json(
                call_kernel_analyze(kernel, inputs_json, entry_file, None)
            );
            assert outcome.status == ANALYSIS_BLOCKED , outcome.message;
        }
        for _ in range(3) {
            run_once();
        }
        gc.collect();
        start = rss_kb();
        rounds = 20;
        for _ in range(rounds) {
            run_once();
        }
        gc.collect();
        end = rss_kb();
        if start is None or end is None {
            return;
        }
        growth_mb = (end - start) / 1024.0;
        assert growth_mb < 256.0 , (
            f"{rounds} kernel analyses grew RSS by {growth_mb:.1f} MB"
        );
    }
}

def check_options -> CompileOptions {
    return CompileOptions(
        no_cgen=True, native_parity=True, iface_ok=True, strict_dependencies=True
    );
}

def rendered(alerts: list[any]) -> list[str] {
    return sorted(a.pretty_print() for a in alerts);
}

test "a diagnostic record rebuilds the host's alert exactly" {
    import json;
    import from jaclang.compiler.frontend.kernel_analyze { diag_from_dict, diag_of }
    import from jaclang.project.kernel_check { alert_of }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        program = JacProgram();
        program.compile(str(base / 'main.jac'), options=check_options());
        alerts = list(program.errors_had) + list(program.warnings_had);
        assert len(alerts) >= 3;
        for alert in alerts {
            record = diag_from_dict(json.loads(json.dumps(diag_of(alert).to_dict())));
            rebuilt = alert_of(record);
            assert str(rebuilt) == str(alert);
            assert rebuilt.pretty_print() == alert.pretty_print();
            assert rebuilt.code is alert.code;
            assert rebuilt.from_pass is alert.from_pass;
        }
    }
}

test "jac check adopts a kernel's diagnostics and they match the host's" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    import from jaclang.project.kernel_check { kernel_check }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        for entry_name in ('main.jac', 'clean.jac') {
            entry_file = str(base / entry_name);
            host_program = JacProgram();
            host_program.compile(entry_file, options=check_options());
            kernel_program = JacProgram();
            view = kernel_check(kernel_program, entry_file, check_options());
            assert view.adopted , view.failure or entry_name;
            assert rendered(kernel_program.errors_had)
                == rendered(host_program.errors_had) , entry_name;
            assert rendered(kernel_program.warnings_had)
                == rendered(host_program.warnings_had) , entry_name;
        }
    }
}
