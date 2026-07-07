"""Tests for `jac test` discovery of the configured `[test] directory`.

Regression guard for issue #7151: the pytest-based `jac test` path must honor
the native runner's contract that a declared `[test] directory` runs the
`test` blocks of *every* `.jac` file beneath it -- not only files that follow
the `test_*.jac` / `*.test.jac` naming conventions.

`jac test` signals the contract to the pytest plugin by passing
`--jac-test-dir <dir>` for the *declared* test root -- the `[test] directory`
from jac.toml or an explicit `-d <dir>`. The plugin then collects any `.jac`
file under that root as a suite, while still excluding `impl` annexes and
`fixtures/` inputs. Positional path targets (`jac test some/dir`) keep pytest
naming rules, so unrelated `.jac` files are never swept in.

The `test` command is invoked in-process (it drives `pytest.main` itself), so
these exercise the real collection path end to end. `JAC_TEST_JOBS=0` keeps the
inner run single-process (no xdist workers nested inside the outer run).
"""

import os;
import tempfile;
import shutil;
import from pathlib { Path }

import from jaclang.cli.commands { analysis as analysis_cmds }


"""Reset the config singleton so each run rediscovers jac.toml from cwd."""
def reset_config {
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
}


"""Create a temp project whose `[test] directory` holds a suite whose file
name follows *no* pytest/Jac convention (`phase1_tests.jac`). Returns the
project root."""
def make_project(with_fixture_trap: bool = False) -> str {
    proj = tempfile.mkdtemp(prefix="jac7151-");
    (Path(proj) / "jac.toml").write_text(
        '[project]\nname = "r"\n\n[test]\ndirectory = "tests"\n'
    );
    tests_dir = Path(proj) / "tests";
    tests_dir.mkdir();
    (tests_dir / "phase1_tests.jac").write_text(
        'test "adds" {\n    assert 1 + 1 == 2;\n}\n'
        'test "truth" {\n    assert True;\n}\n'
    );
    if with_fixture_trap {
        # A `.jac` under fixtures/ is a test *input*, never a suite. Its
        # always-failing `test` block turns a wrong collection into a red run.
        fixtures_dir = tests_dir / "fixtures";
        fixtures_dir.mkdir();
        (fixtures_dir / "input_data.jac").write_text(
            'test "must not be collected" {\n    assert False;\n}\n'
        );
    }
    return proj;
}


"""Create a temp project whose suite reaches a module via a project-root-absolute
import that descends through an *intermediate namespace package*: `engine/` holds
only the `math/` subpackage, so `engine` itself has no direct `.jac` file (and no
`__init__`). Returns the project root."""
def make_namespace_import_project -> str {
    proj = tempfile.mkdtemp(prefix="jac7211-");
    (Path(proj) / "jac.toml").write_text(
        '[project]\nname = "r"\n\n[test]\ndirectory = "tests"\n'
    );
    math_dir = Path(proj) / "engine" / "math";
    math_dir.mkdir(parents=True);
    (math_dir / "vec3.jac").write_text(
        'obj Vec3 {\n    has x: float = 0.0;\n    has z: float = 0.0;\n}\n\n'
        'def forward(v: Vec3) -> Vec3 {\n    return Vec3(v.x, v.z + 1.0);\n}\n'
    );
    tests_dir = Path(proj) / "tests";
    tests_dir.mkdir();
    (tests_dir / "phase1_tests.jac").write_text(
        'import from engine.math.vec3 { Vec3, forward }\n\n'
        'test "vec3_default" {\n    assert Vec3().x == 0.0;\n}\n'
        'test "vec3_forward" {\n    assert forward(Vec3(1.0, 3.0)).z == 4.0;\n}\n'
    );
    return proj;
}


"""Run the `jac test` command inside *proj* with xdist disabled; return its
exit code. `test` is a keyword, so it is reached as a module attribute. With
both *paths* and *directory* empty, config drives discovery from jac.toml."""
def run_in(proj: str, paths: list[str], directory: str = "") -> int {
    jac_test = getattr(analysis_cmds, "test");
    old = os.getcwd();
    had_jobs = os.environ.get("JAC_TEST_JOBS");
    os.environ["JAC_TEST_JOBS"] = "0";
    os.chdir(proj);
    reset_config();
    try {
        return int(jac_test(paths, directory=directory));
    } finally {
        os.chdir(old);
        reset_config();
        if had_jobs is None {
            os.environ.pop("JAC_TEST_JOBS", None);
        } else {
            os.environ["JAC_TEST_JOBS"] = had_jobs;
        }
    }
}


test "non-conventional .jac in [test] directory is discovered" {
    proj = make_project();
    try {
        rc = run_in(proj, []);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    # rc == 0 requires at least one suite collected AND passing; a regression
    # (naming rules only) collects nothing and exits 5.
    assert rc == 0 , "phase1_tests.jac under [test] directory must be discovered and pass "
    f"(exit 0); got exit {rc}";
}


test "`-d` test root collects all .jac and skips fixtures/" {
    proj = make_project(with_fixture_trap=True);
    try {
        rc = run_in(proj, [], directory="tests");
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    # The real suite is collected (so not exit 5) while the always-failing
    # fixtures/ input is excluded (so not exit 1) -- both hold iff exit 0.
    assert rc == 0 , "`jac test -d tests` must collect phase1_tests.jac and skip the "
    f"fixtures/ input; got exit {rc}";
}


test "project-root-absolute import through a namespace package is collected" {
    # Regression guard for issue #7211: a suite whose project-root-absolute
    # import descends through an intermediate namespace package (`engine/`,
    # which holds only `math/` and no direct `.jac`) must import during pytest
    # collection, exactly as the native runner resolves it. Before the fix
    # `JacMetaImporter.find_spec` only treated a directory as a Jac namespace
    # package when it held `.jac` files *directly*, so `import engine.math.vec3`
    # raised `ModuleNotFoundError("No module named 'engine'")`, the suite
    # collected 0 items, and `jac test` exited 5 (a silent green in directory
    # mode where the import error is swallowed during collection).
    proj = make_namespace_import_project();
    try {
        rc = run_in(proj, []);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert rc == 0 , "suite importing engine.math.vec3 through a namespace "
    f"package must be collected and pass (exit 0); got exit {rc}";
}
