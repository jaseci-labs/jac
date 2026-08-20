"""Tests for `jac test` discovery of the configured `[test] directory`.

Regression guard for issue #7151: `jac test` must honor the contract that a
declared `[test] directory` runs the `test` blocks of *every* `.jac` file
beneath it -- not only files that follow the `test_*.jac` / `*.test.jac`
naming conventions.

The declared test root is the `[test] directory` from jac.toml or an explicit
`-d <dir>`. Every `.jac` file under that root is collected as a suite, while
`impl` annexes and `fixtures/` inputs stay excluded. Positional path targets
(`jac test some/dir`) keep the `test_*` / `*.test` naming rules, so unrelated
`.jac` files are never swept in.

The `test` command is invoked in-process, so these exercise the real collection
path end to end. `JAC_TEST_JOBS=0` keeps the inner run single-process, so no
workers are forked inside the outer run.
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
name follows *no* test-naming convention (`phase1_tests.jac`). Returns the
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


"""Run the `jac test` command inside *proj* single-process; return its
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
    # which holds only `math/` and no direct `.jac`) must import during
    # collection. Before the fix
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


"""Create a temp project whose suite lives inside a Python package tree and
reaches a sibling module by its package-absolute name. Returns the root."""
def make_packaged_project -> str {
    proj = tempfile.mkdtemp(prefix="jacpkg-");
    (Path(proj) / "jac.toml").write_text(
        '[project]\nname = "r"\n\n[test]\ndirectory = "mypkg"\n'
    );
    pkg = Path(proj) / "mypkg";
    (pkg / "sub").mkdir(parents=True);
    (pkg / "__init__.py").write_text("");
    (pkg / "sub" / "__init__.py").write_text("");
    (pkg / "support.jac").write_text("glob VALUE: int = 42;\n");
    (pkg / "sub" / "phase1_tests.jac").write_text(
        "import from mypkg.support { VALUE }\n\n"
        'test "packaged" {\n    assert VALUE == 42;\n}\n'
    );
    return proj;
}


test "a suite inside a package resolves package-absolute imports" {
    # The runner puts the package *basedir* on sys.path -- the first ancestor
    # without an `__init__`, matching pytest's prepend import mode -- so
    # `import from mypkg.support` resolves from a suite nested at
    # mypkg/sub/. This used to work only by accident: pytest imported
    # `jac/tests/conftest.py` as the `tests.conftest` module, which is what put
    # `jac/` on sys.path and made every `import from tests.support` in this
    # repo's suite resolve. With the conftest gone the runner has to establish
    # that itself, and a project with no conftest at all now works too.
    proj = make_packaged_project();
    try {
        rc = run_in(proj, []);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert rc == 0 , (
        f"packaged suite must import mypkg.support and pass; got exit {rc}"
    );
}


"""Create a temp project shaped like this repo: the package root sits one
level below the project root (`sub/gappkg`, the `jac/tests` analog), and the
suite is nested under a directory with *no* `__init__` (`gap/`, the
`tests/compiler/passes` analog). Returns the project root."""
def make_gapped_project -> str {
    proj = tempfile.mkdtemp(prefix="jacgap-");
    (Path(proj) / "jac.toml").write_text(
        '[project]\nname = "r"\n\n[test]\ndirectory = "sub/gappkg"\n'
    );
    pkg = Path(proj) / "sub" / "gappkg";
    (pkg / "gap").mkdir(parents=True);
    (pkg / "__init__.py").write_text("");
    (pkg / "support.jac").write_text("glob VALUE: int = 42;\n");
    (pkg / "gap" / "phase1_tests.jac").write_text(
        "import from gappkg.support { VALUE }\n\n"
        'test "gapped" {\n    assert VALUE == 42;\n}\n'
    );
    return proj;
}


test "a suite below a non-package directory still resolves its package root" {
    # `_package_basedir` walks up only while every ancestor carries an
    # `__init__`, so it stops dead at `gap/` and never reaches the dir that
    # makes `gappkg` importable. This repo's own suite is shaped exactly that
    # way -- `tests/` and `tests/compiler/` are packages, `tests/compiler/
    # passes/` is not -- and it resolved `import from tests.support` only
    # because a jac.toml happened to sit in `jac/`, putting the right dir on
    # sys.path as the "project root". Moving that jac.toml to the repo root
    # broke 192 suites at import. The runner now adds the parent of the
    # *outermost* package an ancestor belongs to, so the package root is found
    # on its own evidence rather than on where a config file happens to live.
    proj = make_gapped_project();
    try {
        rc = run_in(proj, []);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert rc == 0 , (
        f"gapped suite must import gappkg.support and pass; got exit {rc}"
    );
}
