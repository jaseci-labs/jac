"""Native inspection must prevent known conflicts before executing bodies."""

import copy;
import platform;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.cli.commands.native_build { native_build }
import from jaclang.project.config { get_config, set_config }

glob STATS = """
import from c {
    def __jac_spec_get_attempts -> int;
    def __jac_spec_get_inspections -> int;
    def __jac_spec_get_unknown -> int;
    def __jac_spec_get_deferrals -> int;
    def __jac_spec_get_validation_failures -> int;
}
with entry {
    print("stats", __jac_spec_get_attempts(), __jac_spec_get_inspections(),
        __jac_spec_get_unknown(), __jac_spec_get_deferrals(),
        __jac_spec_get_validation_failures());
}
""";

test "multi-hop filters and helper aliases defer B while retaining C" {
    if platform.system() != "Linux"
        or platform.machine() not in ("x86_64", "aarch64") {
        return;
    }
    code = (
        Path(TESTS_DIR) / "compiler/backends/native/fixtures/walker_dependencies.jac"
    ).read_text();
    previous = get_config();
    assert previous is not None;
    cfg = copy.deepcopy(previous);
    cfg.native.debug = False;
    cfg.native.threads = 2;
    outputs: list[str] = [];
    stats: dict[str, list[int]] = {};
    try {
        set_config(cfg);
        with tempfile.TemporaryDirectory() as tmp {
            for (name, mode, inspection) in [
                ("serial", "off", False),
                ("optimistic", "auto", False),
                ("dependencies", "auto", True)
            ] {
                cfg.native.walker_speculation = mode;
                cfg.native.walker_dependency_inspection = inspection;
                source = Path(tmp) / (name + ".jac");
                source.write_text(code + (STATS if mode == "auto" else ""));
                binary = str(Path(tmp) / name);
                assert native_build(str(source), output=binary, memory="rc") == 0;
                ran = subprocess.run(
                    [binary], capture_output=True, text=True, timeout=30
                );
                assert ran.returncode == 0 , ran.stderr;
                lines = ran.stdout.splitlines();
                if mode == "auto" {
                    row = lines.pop().split();
                    assert row[0] == "stats";
                    stats[name] = [int(v) for v in row[1:]];
                }
                outputs.append("\n".join(lines));
            }
        }
    } finally {
        set_config(previous);
    }
    assert outputs == ["0\n7\n17"] * 3;
    assert stats["dependencies"] == [3, 4, 0, 1, 0];
    assert stats["optimistic"][1:4] == [0, 0, 0];
    assert stats["optimistic"][4] == 1;
}

test "mutable filters references and retired containers preserve serial semantics" {
    if platform.system() != "Linux"
        or platform.machine() not in ("x86_64", "aarch64") {
        return;
    }
    code = (
        Path(TESTS_DIR)
        / "compiler/backends/native/fixtures/walker_dependency_mutation.jac"
    ).read_text();
    previous = get_config();
    assert previous is not None;
    cfg = copy.deepcopy(previous);
    cfg.native.debug = False;
    cfg.native.threads = 2;
    outputs: list[str] = [];
    try {
        set_config(cfg);
        with tempfile.TemporaryDirectory() as tmp {
            for (name, mode, inspection) in [
                ("serial", "off", False),
                ("optimistic", "auto", False),
                ("dependencies", "auto", True)
            ] {
                cfg.native.walker_speculation = mode;
                cfg.native.walker_dependency_inspection = inspection;
                source = Path(tmp) / (name + ".jac");
                checked = code;
                if inspection {
                    checked = checked.replace(
                        "topology spawn changer;",
                        "before_change: int = __jac_spec_get_inspections(); topology spawn changer; "
                            + "after_change: int = __jac_spec_get_inspections(); "
                            + "assert 0 < after_change - before_change <= 6;"
                    );
                    checked = checked.replace(
                        "topology spawn creator;",
                        "before_create: int = __jac_spec_get_inspections(); topology spawn creator; "
                            + "after_create: int = __jac_spec_get_inspections(); "
                            + "assert after_create == before_create;"
                    );
                    checked += "\nimport from c { def __jac_spec_get_inspections -> int; }\n";
                }
                source.write_text(checked);
                binary = str(Path(tmp) / name);
                assert native_build(str(source), output=binary, memory="rc") == 0;
                ran = subprocess.run(
                    [binary], capture_output=True, text=True, timeout=30
                );
                assert ran.returncode == 0 , ran.stderr;
                outputs.append(ran.stdout);
            }
        }
    } finally {
        set_config(previous);
    }
    assert outputs
        == ["mutable targets, retained reports and topology fallback passed\n"] * 3;
}
