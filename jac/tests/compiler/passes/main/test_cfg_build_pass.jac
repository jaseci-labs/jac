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
        "digraph G {\n" + '  0 [label="BB0\\nx = 5 ;\\ny = 3 ;\\nif x > 3", shape=box];\n' + '  1 [label="BB1\\nz = x + y ;", shape=box];\n' + '  2 [label="BB2\\nelif x == 0", shape=box];\n' + '  3 [label="BB3\\nz = y ;", shape=box];\n' + '  4 [label="BB4\\nz = x - y ;", shape=box];\n' + '  5 [label="BB5\\nfor i in range ( 0 , 10 )", shape=box];\n' + '  6 [label="BB6\\nz = z + 1 ;", shape=box];\n' + '  7 [label="BB7\\nwhile z < 10\\nz = z + 2 ;", shape=box];\n' + '  8 [label="BB8\\nz = z + 2 ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  1 -> 5;\n" + "  2 -> 3;\n" + "  2 -> 4;\n" + "  3 -> 5;\n" + "  4 -> 5;\n" + "  5 -> 6;\n" + "  5 -> 7;\n" + "  6 -> 5;\n" + "  7 -> 7;\n" + "  8 -> 7;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg abilities and objects" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_ability_test.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nobj math_mod", shape=box];\n' + '  1 [label="BB1\\ncan divide( x : int , y : int ) -> int\\nif y == 0", shape=box];\n' + '  2 [label="BB2\\nreturn 0 ;", shape=box];\n' + '  3 [label="BB3\\nreturn x // y ;", shape=box];\n' + '  4 [label="BB4\\ncan multiply( x : int , y : int ) -> int\\nreturn x * y ;", shape=box];\n' + '  5 [label="BB5\\nx = 5 ;\\ny = 0 ;\\nmath = math_mod ( ) ;\\nz = math . divide ( x , y ) ;\\nprint ( z ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 4;\n" + "  1 -> 2;\n" + "  1 -> 3;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg ability with has" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_has_var.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\nobj Rock", shape=box];\n' + '  1 [label="BB1\\nhas pellets : list ;", shape=box];\n' + '  2 [label="BB2\\ncan count_pellets( ) -> int\\nreturn self . pellets . length ( ) ;", shape=box];\n' + '  3 [label="BB3\\nrock = Rock ( pellets = [ 1 , 2 , 3 ] ) ;\\nprint ( \\"Number of pellets: \\" + rock . count_pellets ( ) . to_string ( ) ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg if no else" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_if_no_else.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ncan test_if_without_else( x : int )\\nif ( x > 0 )", shape=box];\n' + '  1 [label="BB1\\nprint ( \\"Positive\\" ) ;", shape=box];\n' + '  2 [label="BB2\\nprint ( \\"Done\\" ) ;", shape=box];\n' + '  3 [label="BB3\\ntest_if_without_else ( 5 ) ;\\ntest_if_without_else ( - 3 ) ;", shape=box];\n' + "  0 -> 1;\n" + "  0 -> 2;\n" + "  1 -> 2;\n" + "}\n"
    );
    assert dot == expected_dot;
}

test "cfg return stmt" {
    dot = cfg_dot_from_file(file_name=os.path.join(FIXTURES, "cfg_return.jac"));
    expected_dot = (
        "digraph G {\n" + '  0 [label="BB0\\ncan test_return_direct( )\\nprint ( \\"Before return\\" ) ;\\nreturn ;\\nprint ( \\"After return\\" ) ;", shape=box];\n' + '  1 [label="BB1\\ntest_return_direct ( ) ;", shape=box];\n' + "}\n"
    );
    assert dot == expected_dot;
}
