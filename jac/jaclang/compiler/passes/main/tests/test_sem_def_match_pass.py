"""Test pass module."""

from collections.abc import Callable

from jaclang.compiler.program import JacProgram


def test_sem_def_match(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (out := JacProgram()).compile(fixture_path("sem_def_match.jac"))
    assert not out.errors_had
    mod = out.mod.hub[fixture_path("sem_def_match.jac")]

    assert mod.lookup("E").decl.name_of.semstr == "An enum representing some values."  # type: ignore
    assert (
        mod.lookup("E").symbol_table.lookup("A").decl.name_of.semstr
        == "The first value of the enum E."
    )  # type: ignore
    assert (
        mod.lookup("E").symbol_table.lookup("B").decl.name_of.semstr
        == "The second value of the enum E."
    )  # type: ignore

    assert mod.lookup("Person").decl.name_of.semstr == "A class representing a person."  # type: ignore

    person_scope = mod.lookup("Person").symbol_table  # type: ignore
    assert person_scope.lookup("name").decl.name_of.semstr == "The name of the person."  # type: ignore
    assert (
        person_scope.lookup("yob").decl.name_of.semstr
        == "The year of birth of the person."
    )  # type: ignore

    sym_calc_age = person_scope.lookup("calc_age")  # type: ignore
    assert sym_calc_age.decl.name_of.semstr == "Calculate the age of the person."  # type: ignore

    calc_age_scope = sym_calc_age.symbol_table  # type: ignore
    assert (
        calc_age_scope.lookup("year").decl.name_of.semstr
        == "The year to calculate the age against."
    )  # type: ignore

    assert (
        mod.lookup("OuterClass").decl.name_of.semstr
        == "A class containing an inner class."
    )  # type: ignore
    outer_scope = mod.lookup("OuterClass").symbol_table  # type: ignore
    assert (
        outer_scope.lookup("InnerClass").decl.name_of.semstr
        == "An inner class within OuterClass."
    )  # type: ignore
    inner_scope = outer_scope.lookup("InnerClass").symbol_table  # type: ignore
    assert (
        inner_scope.lookup("inner_value").decl.name_of.semstr
        == "A value specific to the inner class."
    )  # type: ignore
