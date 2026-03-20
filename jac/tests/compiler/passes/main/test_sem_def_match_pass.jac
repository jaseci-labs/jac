"""Semantic definition match pass tests – migrated from test_sem_def_match_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "sem def match" {
    out = JacProgram();
    out.compile(os.path.join(FIXTURES, "sem_def_match.jac"));
    assert not out.errors_had;
    mod = out.mod.hub[os.path.join(FIXTURES, "sem_def_match.jac")];

    sym_e = mod.lookup("E");
    assert sym_e is not None;
    assert sym_e.decl is not None;
    assert sym_e.decl.name_of is not None;
    assert sym_e.decl.name_of.semstr == "An enum representing some values.";
    assert sym_e.symbol_table is not None;
    sym_a = sym_e.symbol_table.lookup("A");
    assert sym_a is not None;
    assert sym_a.decl is not None;
    assert sym_a.decl.name_of is not None;
    assert sym_a.decl.name_of.semstr == "The first value of the enum E.";
    sym_b = sym_e.symbol_table.lookup("B");
    assert sym_b is not None;
    assert sym_b.decl is not None;
    assert sym_b.decl.name_of is not None;
    assert sym_b.decl.name_of.semstr == "The second value of the enum E.";

    sym_person = mod.lookup("Person");
    assert sym_person is not None;
    assert sym_person.decl is not None;
    assert sym_person.decl.name_of is not None;
    assert sym_person.decl.name_of.semstr == "A class representing a person.";

    person_scope = sym_person.symbol_table;
    assert person_scope is not None;
    sym_name = person_scope.lookup("name");
    assert sym_name is not None;
    assert sym_name.decl is not None;
    assert sym_name.decl.name_of is not None;
    assert sym_name.decl.name_of.semstr == "The name of the person.";
    sym_yob = person_scope.lookup("yob");
    assert sym_yob is not None;
    assert sym_yob.decl is not None;
    assert sym_yob.decl.name_of is not None;
    assert sym_yob.decl.name_of.semstr == "The year of birth of the person.";

    sym_calc_age = person_scope.lookup("calc_age");
    assert sym_calc_age is not None;
    assert sym_calc_age.decl is not None;
    assert sym_calc_age.decl.name_of is not None;
    assert sym_calc_age.decl.name_of.semstr == "Calculate the age of the person.";

    calc_age_scope = sym_calc_age.symbol_table;
    assert calc_age_scope is not None;
    sym_year = calc_age_scope.lookup("year");
    assert sym_year is not None;
    assert sym_year.decl is not None;
    assert sym_year.decl.name_of is not None;
    assert sym_year.decl.name_of.semstr == "The year to calculate the age against.";

    sym_outer = mod.lookup("OuterClass");
    assert sym_outer is not None;
    assert sym_outer.decl is not None;
    assert sym_outer.decl.name_of is not None;
    assert sym_outer.decl.name_of.semstr == "A class containing an inner class.";
    outer_scope = sym_outer.symbol_table;
    assert outer_scope is not None;
    sym_inner = outer_scope.lookup("InnerClass");
    assert sym_inner is not None;
    assert sym_inner.decl is not None;
    assert sym_inner.decl.name_of is not None;
    assert sym_inner.decl.name_of.semstr == "An inner class within OuterClass.";
    inner_scope = sym_inner.symbol_table;
    assert inner_scope is not None;
    sym_inner_value = inner_scope.lookup("inner_value");
    assert sym_inner_value is not None;
    assert sym_inner_value.decl is not None;
    assert sym_inner_value.decl.name_of is not None;
    assert sym_inner_value.decl.name_of.semstr == "A value specific to the inner class.";
}

test "sem def match for s e m prefixed functions" {
    # Regression test for issue #5233: lstrip('sem.') strips individual characters
    # {s, e, m, .} instead of the prefix "sem.", corrupting function names that
    # start with those letters and silently dropping their sem strings.
    out = JacProgram();
    out.compile(os.path.join(FIXTURES, "sem_def_match.jac"));
    assert not out.errors_had;
    mod = out.mod.hub[os.path.join(FIXTURES, "sem_def_match.jac")];

    sym_summarize = mod.lookup("summarize_text");
    assert sym_summarize is not None;
    assert sym_summarize.decl.name_of.semstr == "Summarize the given text into a concise summary." , (
        f"s-prefix: expected sem string, got '{sym_summarize.decl.name_of.semstr}'"
    );

    sym_evaluate = mod.lookup("evaluate_score");
    assert sym_evaluate is not None;
    assert sym_evaluate.decl.name_of.semstr == "Evaluate and return a numeric score for the text." , (
        f"e-prefix: expected sem string, got '{sym_evaluate.decl.name_of.semstr}'"
    );

    sym_merge = mod.lookup("merge_results");
    assert sym_merge is not None;
    assert sym_merge.decl.name_of.semstr == "Merge multiple results into a single combined output." , (
        f"m-prefix: expected sem string, got '{sym_merge.decl.name_of.semstr}'"
    );

    sym_fetch = mod.lookup("fetch_data");
    assert sym_fetch is not None;
    assert sym_fetch.decl.name_of.semstr == "Fetch data from the remote source." , (
        f"f-prefix: expected sem string, got '{sym_fetch.decl.name_of.semstr}'"
    );
}
