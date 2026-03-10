"""CFG build pass tests – migrated from test_cfg_build_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.cfg_build_pass { cfg_dot_from_file }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "cfg branches and loops" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_gen.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nx = 5 ;\\ny = 3 ;\\nif x > 3", shape=box];\n' + '  1 [label="BB1\\nz = x + y ;", shape=box];\n' + '  2 [label="BB2\\nelif x == 0", shape=box];\n' + '  3 [label="BB3\\nz = y ;", shape=box];\n' + '  4 [label="BB4\\nz = x - y ;", shape=box];\n' + '  5 [label="BB5\\nfor i in range ( 0 , 10 )", shape=box];\n' + '  6 [label="BB6\\nz = z + 1 ;", shape=box];\n' + '  7 [label="BB7\\nwhile z < 10", shape=box];\n' + '  8 [label="BB8\\nz = z + 2 ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  1 -> 5;\n" + "  2 -> 3;\n" + "  2 -> 4;\n" + "  3 -> 5;\n" + "  4 -> 5;\n" + "  5 -> 6;\n" + "  5 -> 7;\n" + "  6 -> 5;\n" + "  7 -> 8;\n" + "  8 -> 7;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg abilities and objects" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_ability_test.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nobj math_mod", shape=box];\n' + '  1 [label="BB1\\ndef divide( x : int , y : int ) -> int\\nif y == 0", shape=box];\n' + '  2 [label="BB2\\nreturn 0 ;", shape=box];\n' + '  3 [label="BB3\\nreturn x // y ;", shape=box];\n' + '  4 [label="BB4\\ndef multiply( x : int , y : int ) -> int\\nreturn x * y ;", shape=box];\n' + '  5 [label="BB5\\nx = 5 ;\\ny = 0 ;\\nmath = math_mod ( ) ;\\nz = math . divide ( x , y ) ;\\nprint ( z ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 4;\n" + "  1 -> 2;\n" + "  1 -> 3;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg ability with has" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_has_var.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nobj Rock", shape=box];\n' + '  1 [label="BB1\\nhas pellets : list ;", shape=box];\n' + '  2 [label="BB2\\ndef count_pellets( ) -> int\\nreturn self . pellets . length ( ) ;", shape=box];\n' + '  3 [label="BB3\\nrock = Rock ( pellets = [ 1 , 2 , 3 ] ) ;\\nprint ( \\"Number of pellets: \\" + rock . count_pellets ( ) . to_string ( ) ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg if no else" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_if_no_else.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef test_if_without_else( x : int )\\nif ( x > 0 )", shape=box];\n' + '  1 [label="BB1\\nprint ( \\"Positive\\" ) ;", shape=box];\n' + '  2 [label="BB2\\nprint ( \\"Done\\" ) ;", shape=box];\n' + '  3 [label="BB3\\ntest_if_without_else ( 5 ) ;\\ntest_if_without_else ( - 3 ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  1 -> 2;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg return stmt" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_return.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef test_return_direct( )\\nprint ( \\"Before return\\" ) ;\\nreturn ;", shape=box];\n' + '  1 [label="BB1\\nprint ( \\"After return\\" ) ;", shape=box];\n' + '  2 [label="BB2\\ntest_return_direct ( ) ;", shape=box];\n' + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg while loop with break continue and else" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_while_stmt.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nx = 0 ;", shape=box];\n' + '  1 [label="BB1\\nwhile x < 5", shape=box];\n' + '  2 [label="BB2\\nx = x + 1 ;\\nif x == 2", shape=box];\n' + '  3 [label="BB3\\ncontinue ;", shape=box];\n' + '  4 [label="BB4\\nprint ( x ) ;\\nif x == 4", shape=box];\n' + '  5 [label="BB5\\nbreak ;", shape=box];\n' + '  6 [label="BB6\\nprint ( \\"done\\" ) ;", shape=box];\n' + "  0 -> 1;\n" + "  1 -> 2;\n" + "  1 -> 6;\n" + "  2 -> 3;\n" + "  2 -> 4;\n" + "  3 -> 1;\n" + "  4 -> 5;\n" + "  4 -> 1;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg for loop with break continue and else" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_for_stmt.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nfor i in range ( 0 , 5 )", shape=box];\n' + '  1 [label="BB1\\nif i == 1", shape=box];\n' + '  2 [label="BB2\\ncontinue ;", shape=box];\n' + '  3 [label="BB3\\nprint ( i ) ;\\nif i == 3", shape=box];\n' + '  4 [label="BB4\\nbreak ;", shape=box];\n' + '  5 [label="BB5\\nprint ( \\"done\\" ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 5;\n" + "  1 -> 2;\n" + "  1 -> 3;\n" + "  2 -> 0;\n" + "  3 -> 4;\n" + "  3 -> 0;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg try except finally" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_try_except.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef risky( x : int ) -> int\\ntry", shape=box];\n' + '  1 [label="BB1\\ny = 10 / x ;", shape=box];\n' + '  2 [label="BB2\\nexcept Exception\\ny = 0 ;", shape=box];\n' + '  3 [label="BB3\\nfinally\\nprint ( y ) ;", shape=box];\n' + '  4 [label="BB4\\nreturn y ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  0 -> 4;\n" + "  1 -> 3;\n" + "  2 -> 3;\n" + "  3 -> 4;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg match statement" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_match.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef classify( x : int ) -> str\\nmatch x", shape=box];\n' + '  1 [label="BB1\\ncase 0\\nreturn \\"zero\\" ;", shape=box];\n' + '  2 [label="BB2\\ncase 1\\nreturn \\"one\\" ;", shape=box];\n' + '  3 [label="BB3\\ncase _\\nreturn \\"other\\" ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  0 -> 3;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg nested if" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_nested_if.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef quadrant( x : int , y : int ) -> str\\nif x > 0", shape=box];\n' + '  1 [label="BB1\\nif y > 0", shape=box];\n' + '  2 [label="BB2\\nreturn \\"Q1\\" ;", shape=box];\n' + '  3 [label="BB3\\nreturn \\"Q4\\" ;", shape=box];\n' + '  4 [label="BB4\\nreturn \\"left\\" ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 4;\n" + "  1 -> 2;\n" + "  1 -> 3;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg nested loops" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_nested_loop.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nfor i in range ( 3 )", shape=box];\n' + '  1 [label="BB1\\nfor j in range ( 3 )", shape=box];\n' + '  2 [label="BB2\\nprint ( i , j ) ;", shape=box];\n' + "  0 -> 1;\n" + "  1 -> 2;\n" + "  1 -> 0;\n" + "  2 -> 1;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg for else" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_for_else.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef find( items : list , target : int ) -> bool", shape=box];\n' + '  1 [label="BB1\\nfor item in items", shape=box];\n' + '  2 [label="BB2\\nif item == target", shape=box];\n' + '  3 [label="BB3\\nreturn True ;", shape=box];\n' + '  4 [label="BB4\\nreturn False ;", shape=box];\n' + "  0 -> 1;\n" + "  1 -> 2;\n" + "  1 -> 4;\n" + "  2 -> 3;\n" + "  2 -> 1;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg raise terminal" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_raise.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ndef safe_sqrt( x : float ) -> float\\nif x < 0", shape=box];\n' + '  1 [label="BB1\\nraise ValueError ( \\"negative\\" ) ;", shape=box];\n' + '  2 [label="BB2\\nreturn x ** 0.5 ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg boolean short circuit" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_bool_expr.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nx = 5 ;\\nif\\n( x < 3 and x < 10 ) or ( x > 20 and x < 30 )", shape=box];\n' + '  1 [label="BB1\\nprint ( x ) ;\\nx = x + 1 ;", shape=box];\n' + "  0 -> 1;\n" + "}\n"
    );
    assert dot == expected_dot;
}
