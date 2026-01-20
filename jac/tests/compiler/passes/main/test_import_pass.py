"""Test pass module."""

import io
import re
from collections.abc import Callable
from contextlib import AbstractContextManager

import pytest

import jaclang.pycore.unitree as uni
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from jaclang.pycore.program import JacProgram


def test_pygen_jac_cli(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (out := JacProgram()).compile(fixture_path("base.jac"))
    assert not out.errors_had
    mod = out.mod.hub[fixture_path("impl/imps.jac")]
    assert "56" in str(mod.to_dict())


def test_import_auto_impl(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (prog := JacProgram()).compile(fixture_path("autoimpl.jac"))
    num_modules = len(list(prog.mod.hub.values())[0].impl_mod)
    mod_names = [i.name for i in list(prog.mod.hub.values())[0].impl_mod]
    assert num_modules == 5
    assert "getme.impl" in mod_names
    assert "autoimpl.impl" in mod_names
    assert "autoimpl.something.else.impl" in mod_names
    assert "autoimpl.shared.impl" in mod_names  # shared folder impl


def test_import_include_auto_impl(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (prog := JacProgram()).compile(fixture_path("incautoimpl.jac"))
    num_modules = len(list(prog.mod.hub.values())[1].impl_mod) + 1
    mod_names = [i.name for i in list(prog.mod.hub.values())[1].impl_mod]
    assert num_modules == 6
    assert list(prog.mod.hub.values())[0].name == "incautoimpl"
    assert list(prog.mod.hub.values())[1].name == "autoimpl"
    assert "getme.impl" in mod_names
    assert "autoimpl.impl" in mod_names
    assert "autoimpl.something.else.impl" in mod_names
    assert "autoimpl.shared.impl" in mod_names  # shared folder impl


def test_annexalbe_by_discovery(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (prog := JacProgram()).compile(fixture_path("incautoimpl.jac"))
    count = 0
    all_mods = prog.mod.hub.values()
    # Annex modules (.impl.jac and .test.jac files only, .cl.jac are standalone)
    # ["incautoimpl", "autoimpl", "autoimpl.something.else.impl",
    #  "autoimpl.impl", "autoimpl.empty.impl", "getme.impl", "autoimpl.shared.impl"]
    assert len(all_mods) == 7
    for main_mod in all_mods:
        for i in main_mod.impl_mod:
            if i.name not in ["autoimpl", "incautoimpl"]:
                count += 1
                assert i.annexable_by == fixture_path("autoimpl.jac")
    assert count == 5


def test_annexable_by_shared_folder(fixture_path: Callable[[str], str]) -> None:
    """Test annexable_by correctly discovers base file from shared impl/ folder."""
    (prog := JacProgram()).compile(fixture_path("autoimpl.jac"))
    main_mod = list(prog.mod.hub.values())[0]

    # Find the shared folder impl module
    shared_impl = next(
        (m for m in main_mod.impl_mod if m.name == "autoimpl.shared.impl"), None
    )
    assert shared_impl is not None, "Expected shared folder impl to be loaded"
    assert shared_impl.annexable_by == fixture_path("autoimpl.jac")


@pytest.mark.skip(reason="TODO: Fix when we have the type checker")
def test_py_raise_map(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (build := JacProgram()).compile(fixture_path("py_imp_test.jac"))
    p = {
        "math": r"jaclang/vendor/mypy/typeshed/stdlib/math.pyi$",
        "pygame_mock": r"pygame_mock/__init__.pyi$",
        "pygame_mock.color": r"pygame_mock/color.py$",
        "pygame_mock.constants": r"pygame_mock/constants.py$",
        "argparse": r"jaclang/vendor/mypy/typeshed/stdlib/argparse.pyi$",
        "builtins": r"jaclang/vendor/mypy/typeshed/stdlib/builtins.pyi$",
        "pygame_mock.display": r"pygame_mock/display.py$",
        "os": r"jaclang/vendor/mypy/typeshed/stdlib/os/__init__.pyi$",
        "genericpath": r"jaclang/vendor/mypy/typeshed/stdlib/genericpath.pyi$",
    }
    for i in p:
        assert i in build.py_raise_map
        assert re.match(
            p[i],
            re.sub(r".*fixtures/", "", build.py_raise_map[i]).replace("\\", "/"),
        )


@pytest.mark.skip(reason="TODO: Fix when we have the type checker")
def test_py_raised_mods(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (prog := JacProgram()).compile(fixture_path("py_imp_test.jac"))
    for i in list(
        filter(
            lambda x: x.is_raised_from_py,
            prog.mod.hub.values(),
        )
    ):
        print(uni.Module.get_href_path(i))

    module_count = len(
        list(
            filter(
                lambda x: x.is_raised_from_py,
                prog.mod.hub.values(),
            )
        )
    )

    assert module_count == 8


def test_double_empty_anx(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("autoimpl.jac"))
        execution.run(fixture_path("autoimpl.jac"))
    stdout_value = captured_output.getvalue()
    assert "foo" in stdout_value
    assert "bar" in stdout_value
    assert "baz" in stdout_value


def test_circular_import(fixture_path: Callable[[str], str]) -> None:
    """Test circular import."""
    (state := JacProgram()).compile(fixture_path("circular_import.jac"))
    assert not state.errors_had
    assert len(state.errors_had) == 0


def test_ts_module_import(fixture_path: Callable[[str], str]) -> None:
    """Test importing TypeScript modules in cl imports."""
    (prog := JacProgram()).compile(fixture_path("ts_imports/main.jac"), type_check=True)
    # Verify TS/JS modules are loaded into the module hub
    assert len(prog.errors_had) == 0


def test_ts_module_compilation_no_cgen(fixture_path: Callable[[str], str]) -> None:
    """Test TypeScript modules compile with no_cgen=True."""
    (prog := JacProgram()).compile(fixture_path("ts_imports/utils.ts"), no_cgen=True)
    assert not prog.errors_had
    ts_mod = list(prog.mod.hub.values())[0]
    assert ts_mod.name == "utils"
    assert not ts_mod.has_syntax_errors


def test_js_module_compilation_no_cgen(fixture_path: Callable[[str], str]) -> None:
    """Test JavaScript modules compile with no_cgen=True."""
    (prog := JacProgram()).compile(
        fixture_path("ts_imports/component.js"), no_cgen=True
    )
    assert not prog.errors_had
    js_mod = list(prog.mod.hub.values())[0]
    assert js_mod.name == "component"
    assert not js_mod.has_syntax_errors
