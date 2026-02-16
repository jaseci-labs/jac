"""Language integration tests – migrated from tests/language/test_language.py.

These tests run Jac fixture programs and verify their stdout output matches
expected values. Each test mirrors a specific test function from the original
Python test suite.
"""

import io;
import sys;
import os;
import json;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.runtime { JacRuntime }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     EXAMPLES = os.path.join(JAC_ROOT, "examples");

"""Import a .jac file as __main__ and return its captured stdout."""
def run_jac(filepath: str) -> str {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        base = str(Path(filepath).parent);
        name = Path(filepath).stem;
        JacRuntime.jac_import(target=name, base_path=base, override_name="__main__");
    } finally {
        sys.stdout = old_stdout;
    }
    return buf.getvalue();
}

"""Import a dotted module target and return captured stdout."""
def run_module(target: str, base_path: str, as_main: bool = False) -> str {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        if as_main {
            JacRuntime.jac_import(
                target=target, base_path=base_path, override_name="__main__"
            );
        } else {
            JacRuntime.jac_import(target=target, base_path=base_path);
        }
    } finally {
        sys.stdout = old_stdout;
    }
    return buf.getvalue();
}

# ── Fixture-based tests (fixture_path -> FIXTURES) ──────────────────────────
test "sub abilities" {
    output = run_jac(os.path.join(FIXTURES, "sub_abil_sep.jac"));
    assert output == "Hello, world!\nI'm a ninja Myca!\n";
}

test "sub abilities multi" {
    output = run_jac(os.path.join(FIXTURES, "sub_abil_sep_multilev.jac"));
    assert output == "Hello, world!\nI'm a ninja Myca!\n";
}

test "guess game" {
    output = run_jac(os.path.join(FIXTURES, "guess_game.jac"));
    assert output == "Too high!\nToo low!\nToo high!\nCongratulations! You guessed correctly.\n";
}

test "printgraph" {
    output = run_jac(os.path.join(FIXTURES, "builtin_printgraph_json.jac"));
    data = json.loads(output);
    nodes = data["nodes"];
    edges = data["edges"];
    assert len(nodes) == 5;
    assert len(edges) == 6;
    for nd in nodes {
        label = nd["label"];
        assert label in ["root", "N(val=0)", "N(val=1)"];
    }
    for edge in edges {
        label = edge["label"];
        assert label in ["E(val=1)", "E(val=0)"];
    }
}

test "printgraph mermaid" {
    output = run_jac(os.path.join(FIXTURES, "builtin_printgraph_mermaid.jac"));
    assert "flowchart LR" in output;
}

test "chandra bugs" {
    output = run_jac(os.path.join(FIXTURES, "chandra_bugs.jac"));
    assert output == "<link href='{'new_val': 3, 'where': 'from_foo'}' rel='stylesheet'>\nTrue\n";
}

test "chandra bugs2" {
    output = run_jac(os.path.join(FIXTURES, "chandra_bugs2.jac"));
    assert output == "{'apple': None, 'pineapple': None}\nThis is a long\n        line of code.\n{'a': 'apple', 'b': 'ball', 'c': 'cat', 'd': 'dog', 'e': 'elephant'}\n";
}

test "ignore" {
    output = run_jac(os.path.join(FIXTURES, "ignore_dup.jac"));
    assert output.split("\n")[0].count("here") == 10;
    assert output.split("\n")[1].count("here") == 5;
}

test "dataclass hasability" {
    output = run_jac(os.path.join(FIXTURES, "hashcheck_dup.jac"));
    assert output.count("check") == 2;
}

test "assign compr" {
    output = run_jac(os.path.join(FIXTURES, "assign_compr_dup.jac"));
    assert output == "[MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]\n";
}

test "raw bytestr" {
    output = run_jac(os.path.join(FIXTURES, "raw_byte_string.jac"));
    assert output.count(r"\\\\") == 2;
    assert output.count("<class 'bytes'>") == 3;
}

test "deep imports" {
    output = run_jac(os.path.join(FIXTURES, "deep_import.jac"));
    assert output.split("\n")[0] == "one level deeperslHello World!";
}

test "deep imports mods" {
    targets = [
        "deep",
        "deep.deeper",
        "deep.mycode",
        "deep.deeper.snd_lev",
        "deep.one_lev"
    ];
    for i in targets {
        if i in sys.modules {
            del sys.modules[i];
        }
    }
    output = run_jac(os.path.join(FIXTURES, "deep_import_mods.jac"));
    import from builtins { eval as pyeval }
    result = pyeval(output);
    for i in targets {
        assert i in result;
    }
}

test "deep outer imports one" {
    output = run_module("deep.deeper.deep_outer_import", FIXTURES);
    assert "one level deeperslHello World!" in output;
    assert (
        "module 'pyfunc' from " in output
        or "module 'jaclang.tests.fixtures.pyfunc' from " in output
    );
}

test "has lambda goodness" {
    output = run_jac(os.path.join(FIXTURES, "has_goodness.jac"));
    assert output.split("\n")[0] == "mylist:  [1, 2, 3]";
    assert output.split("\n")[1] == "mydict:  {'a': 2, 'b': 4}";
}

test "conn assign on edges" {
    output = run_jac(os.path.join(FIXTURES, "edge_ops.jac"));
    assert "[(3, 5), (14, 1), (5, 1)]" in output;
    assert "10\n" in output;
    assert "12\n" in output;
}

test "disconnect" {
    output = run_jac(os.path.join(FIXTURES, "disconn.jac"));
    lines = output.split("\n");
    assert "c(cc=0)" in lines[0];
    assert "c(cc=1)" in lines[0];
    assert "c(cc=2)" in lines[0];
    assert "True" in lines[2];
    assert "[]" in lines[3];
    assert "['GenericEdge', 'GenericEdge', 'GenericEdge']" in lines[5];
}

test "simple archs" {
    output = run_jac(os.path.join(FIXTURES, "simple_archs.jac"));
    assert output.split("\n")[0] == "1 2 0";
    assert output.split("\n")[1] == "0";
}

test "edge walk" {
    output = run_jac(os.path.join(FIXTURES, "edges_walk.jac"));
    assert "creator()\n" in output;
    assert "[node_a(val=12)]\n" in output;
    assert "node_a(val=1)" in output;
    assert "node_a(val=2)" in output;
    assert "[node_a(val=42), node_a(val=42)]\n" in output;
}

test "tuple of tuple assign" {
    output = run_jac(os.path.join(FIXTURES, "tuplytuples.jac"));
    assert "a apple b banana a apple b banana a apple b banana a apple b banana" in output;
}

test "deferred field" {
    output = run_jac(os.path.join(FIXTURES, "deferred_field.jac"));
    assert "5 15" in output;
}

test "gen dot builtin" {
    output = run_jac(os.path.join(FIXTURES, "builtin_printgraph.jac"));
    assert output.count("True") == 16;
}

test "with contexts" {
    output = run_jac(os.path.join(FIXTURES, "with_context.jac"));
    assert "im in" in output;
    assert "in the middle" in output;
    assert "im out" in output;
    assert "{'apple': [1, 2, 3], 'banana': [1, 2, 3], 'cherry': [1, 2, 3]}" in output;
}

test "edge node walk" {
    output = run_jac(os.path.join(FIXTURES, "edge_node_walk.jac"));
    assert "creator()\n" in output;
    assert "[node_a(val=12)]\n" in output;
    assert "node_a(val=1)" in output;
    assert "node_a(val=2)" in output;
    assert "[node_b(val=42), node_b(val=42)]\n" in output;
}

test "enum inside arch" {
    output = run_jac(os.path.join(FIXTURES, "enum_inside_archtype.jac"));
    assert "2 Accessing privileged Data" in output;
}

test "refs target" {
    output = run_jac(os.path.join(FIXTURES, "refs_target.jac"));
    assert "[c(val=0), c(val=1), c(val=2)]" in output;
    assert "[c(val=0)]" in output;
}

test "inherit check" {
    output = run_jac(os.path.join(FIXTURES, "inherit_check.jac"));
    assert output == "I am in b\nI am in b\nwww is also in b\n";
}

test "tuple unpack" {
    output = run_jac(os.path.join(FIXTURES, "tupleunpack.jac"));
    lines = output.split("\n");
    assert "1" in lines[0];
    assert "[2, 3, 4]" in lines[1];
}

test "trailing comma" {
    output = run_jac(os.path.join(FIXTURES, "trailing_comma.jac"));
    assert "Code compiled and ran successfully!" in output;
}

test "try finally" {
    output = run_jac(os.path.join(FIXTURES, "try_finally.jac"));
    lines = output.split("\n");
    assert "try block" in lines[0];
    assert "finally block" in lines[1];
    assert "try block" in lines[2];
    assert "else block" in lines[3];
    assert "finally block" in lines[4];
}

test "arithmetic bug" {
    output = run_jac(os.path.join(FIXTURES, "arithmetic_bug.jac"));
    lines = output.split("\n");
    assert lines[0] == "0.0625";
    assert lines[1] == "1e-06";
    assert lines[2] == "1000.000001";
    assert lines[3] == "78";
    assert lines[4] == "12";
}

test "lambda expr" {
    output = run_jac(os.path.join(FIXTURES, "lambda.jac"));
    lines = output.split("\n");
    assert lines[0] == "9";
    assert lines[1] == "567";
}

test "override walker inherit" {
    output = run_jac(os.path.join(FIXTURES, "walker_override.jac"));
    assert output == "baz\nbar\n";
}

test "self with no sig" {
    output = run_jac(os.path.join(FIXTURES, "nosigself.jac"));
    assert output.count("5") == 2;
}

test "hash init check" {
    output = run_jac(os.path.join(FIXTURES, "hash_init_check.jac"));
    assert "Test Passed" in output;
}

test "edge expr not type" {
    output = run_jac(os.path.join(FIXTURES, "edgetypeissue.jac"));
    assert "[x()]" in output;
}

test "blank with entry" {
    output = run_jac(os.path.join(FIXTURES, "blankwithentry.jac"));
    assert "i work" in output;
}

test "need import" {
    output = run_jac(os.path.join(FIXTURES, "needs_import.jac"));
    assert "<module 'pyfunc' from" in output;
}

test "gen dot bubble" {
    output = run_jac(os.path.join(FIXTURES, "gendot_bubble_sort.jac"));
    assert '[label="inner_node(main=5, sub=2)"fillcolor="#FFDEAD"];' in output;
}

test "double import exec" {
    output = run_jac(os.path.join(FIXTURES, "dblhello.jac"));
    assert output.count("Hello World!") == 1;
    assert "im still here" in output;
}

test "cls method" {
    output = run_jac(os.path.join(FIXTURES, "cls_method.jac"));
    lines = output.split("\n");
    assert lines[0] == "MyClass";
    assert lines[1] == "Hello, World1! Hello, World2!";
    assert lines[2] == "Hello, World! Hello, World22!";
}

test "match multi ex" {
    output = run_jac(os.path.join(FIXTURES, "match_multi_ex.jac"));
    lines = output.split("\n");
    assert lines[0] == "Ten";
    assert lines[1] == "ten";
}

test "entry exit" {
    output = run_jac(os.path.join(FIXTURES, "entry_exit.jac"));
    lines = output.split("\n");
    assert "Entering at the beginning of walker:  Root()" in lines[0];
    assert "entry_count=1, exit_count=1" in lines[12];
    assert "Exiting at the end of walker:  test_node(value=" in lines[11];
}

test "visit order" {
    output = run_jac(os.path.join(FIXTURES, "visit_order.jac"));
    assert output == "[MyNode(Name='End'), MyNode(Name='Middle')]\n";
}

test "global multivar" {
    output = run_jac(os.path.join(FIXTURES, "glob_multivar_statement.jac"));
    lines = output.split("\n");
    assert "Hello World !" in lines[0];
    assert "Welcome to Jaseci!" in lines[1];
}

test "archetype def" {
    output = run_jac(os.path.join(FIXTURES, "archetype_def_bug.jac"));
    lines = output.split("\n");
    assert "MyWalker" in lines[0];
    assert "MyNode" in lines[1];
}

test "visit sequence" {
    output = run_jac(os.path.join(FIXTURES, "visit_sequence.jac"));
    expected = "walker entry\nwalker enter to root\na-1\na-2\na-3\nb-1\nb-2\nb-3\nc-1\nc-2\nc-3\nc-4\nc-5\nc-6\nb-4\nb-5\nb-6\na-4\na-5\na-6\nwalker exit\n";
    assert output == expected;
}

test "connect traverse syntax" {
    output = run_jac(os.path.join(FIXTURES, "connect_traverse_syntax.jac"));
    lines = output.split("\n");
    assert "A(val=5), A(val=10)" in lines[0];
    assert "[Root(), A(val=20)]" in lines[1];
    assert "A(val=5), A(val=10)" in lines[2];
    assert "[Root(), A(val=20)]" in lines[3];
}

test "node del" {
    output = run_jac(os.path.join(FIXTURES, "node_del.jac"));
    lines = output.split("\n");
    assert "0 : [2, 3, 4, 5, 6, 7, 8, 9, 10]" in lines[0];
    assert "7, 8 : [2, 3, 4, 5, 6, 7, 9]" in lines[1];
    assert "before delete : Inner(c=[1, 2, 3], d=4)" in lines[2];
    assert "after delete : Inner(c=[1, 3], d=4)" in lines[3];
}

test "async walker" {
    output = run_jac(os.path.join(FIXTURES, "async_walker.jac"));
    lines = output.split("\n");
    assert "Let's start the task" in lines[0];
    assert "It is Coroutine task True" in lines[1];
    assert "Coroutine task is completed" in lines[6];
}

test "async function" {
    output = run_jac(os.path.join(FIXTURES, "async_function.jac"));
    lines = output.split("\n");
    assert "Hello" in lines[0];
    assert "Hello" in lines[1];
    assert "World!" in lines[2];
}

test "concurrency" {
    output = run_jac(os.path.join(FIXTURES, "concurrency.jac"));
    assert "Started" in output;
    assert "B(name='Hi')" in output;
    assert "All are started" in output;
    assert "All are done" in output;
    assert "11" in output;
    assert "13" in output;
}

test "async ability" {
    output = run_jac(os.path.join(FIXTURES, "async_ability.jac"));
    lines = output.split("\n");
    assert "Let's start the task" in lines[0];
    assert "It is Coroutine task True" in lines[1];
    assert "I am here man MyNode(val=5)" in lines[2];
    assert "Async function" in lines[3];
    assert "foo3" in lines[4];
    assert "foo1" in lines[5];
    assert "foo2" in lines[6];
    assert "Coroutine task is completed" in lines[17];
}

test "iter for continue" {
    output = run_jac(os.path.join(FIXTURES, "iter_for_continue.jac"));
    lines = output.split("\n");
    assert "0" in lines[0];
    assert "1" in lines[1];
    assert "2" in lines[2];
    assert "Skipping 3" in lines[3];
    assert "4" in lines[4];
}

test "unicode string literals" {
    output = run_jac(os.path.join(FIXTURES, "unicode_strings.jac"));
    lines = output.split("\n");
    assert "1. ✓ 1st (due: True)" in lines[0];
    assert "🌟 Star" in lines[2];
    assert "Multi-line with ✓ unicode and ○ symbols" in lines[3];
    assert "Raw string with ✓ and ○" in lines[4];
    assert "Tab ✓" in lines[5];
    assert "Newline ○" in lines[6];
}

test "spawn loc list" {
    output = run_jac(os.path.join(FIXTURES, "spawn_loc_list.jac"));
    lines = output.split("\n");
    assert "I am here MyNode(val=5)" in lines[0];
    assert "I am here MyNode(val=15)" in lines[2];
    assert "I am here MyNode(val=30)" in lines[3];
    assert "I am here MyEdge(val=100)" in lines[4];
    assert "I am here MyNode(val=20)" in lines[6];
}

test "while else" {
    output = run_jac(os.path.join(FIXTURES, "while_else.jac"));
    lines = output.split("\n");
    assert "Num:  4" in lines[0];
    assert "Num:  3" in lines[1];
    assert "Completed" in lines[2];
}

test "funccall genexpr" {
    output = run_jac(os.path.join(FIXTURES, "funccall_genexpr.jac"));
    assert "Result: 30" in output.split("\n")[0];
}

test "attr pattern case" {
    output = run_jac(os.path.join(FIXTURES, "attr_pattern_case.jac"));
    assert "Matched a.b.c Hello Jaseci!" in output.split("\n")[0];
}

test "switch case" {
    output = run_jac(os.path.join(FIXTURES, "switch_case.jac"));
    lines = output.split("\n");
    assert "Matched case for value: apple" in lines[0];
    assert "Matched case for value: banana, orange" in lines[1];
    assert "Matched case for value: grape" in lines[2];
    assert "Matched case for value: kiwi" in lines[3];
    assert "Matched case for value: Berry or Cherry" in lines[4];
    assert "No match found for value: banana" in lines[5];
    assert "No match found for value: mango" in lines[6];
}

test "safe call operator" {
    output = run_jac(os.path.join(FIXTURES, "safe_call_operator.jac"));
    lines = output.split("\n");
    assert "None" in lines[0];
    assert "Alice" in lines[1];
    assert "None" in lines[2];
    assert "None" in lines[3];
    assert "3" in lines[4];
    assert "None" in lines[5];
    assert "3" in lines[6];
    assert "None" in lines[7];
    assert "[2, 3]" in lines[8];
    assert "[]" in lines[9];
    assert "None" in lines[10];
    assert "None" in lines[11];
}

test "anonymous ability execution" {
    output = run_jac(os.path.join(FIXTURES, "anonymous_ability_test.jac"));
    assert "Walker root entry executed" in output;
    assert "Walker root exit executed" in output;
    assert "Node entry executed: TestNode" in output;
    assert "Walker visiting node" in output;
}

test "escaped quote strings" {
    output = run_jac(os.path.join(FIXTURES, "escaped_quote_strings.jac"));
    assert 'He said "Hello World"' in output;
    assert "It's a \"great\" day" in output;
    assert "Line 1\nLine 2\tTabbed" in output;
    assert "Path: C:\\Users\\Documents\\file.txt" in output;
}

test "here visitor usage" {
    output = run_jac(os.path.join(FIXTURES, "here_visitor_usage.jac"));
    lines = output.split("\n");
    assert "Here value is  10" in lines[0];
    assert "Visitor name is  Walker 1" in lines[1];
}

# ── Param tests (fixture_path("./params")) ──────────────────────────────────
test "kwonly params" {
    output = run_jac(os.path.join(FIXTURES, "params", "test_kwonly_params.jac"));
    lines = output.split("\n");
    assert lines[0] == "KW_SIMPLE: 42";
    assert lines[1] == "KW_DEF: 10-def 20-def";
    assert lines[2] == "REG_KW: 10|test";
    assert lines[3] == "MIXED_KW: 1-def-2.5-True 2-custom-3.5-False";
    assert lines[4] == "ALL_KW: 100:test:1.0 200:hi:9.9";
}

test "complex params" {
    output = run_jac(os.path.join(FIXTURES, "params", "test_complex_params.jac"));
    lines = output.split("\n");
    assert lines[0] == "ULTIMATE_MIN: 1|def|2.5|0|test|100|0";
    assert lines[1] == "ULTIMATE_FULL: 1|custom|3.14|3|req|200|1";
    assert lines[2] == "SEPARATORS: 42";
    assert lines[3] == "EDGE_MIX: 1-test-2-True-1";
    assert lines[4] == "RECURSIVE: 7 11";
    assert lines[5] == "VALIDATION: x:1,y:2.5,z:10,args:1,w:True,kwargs:1";
}

test "param failing" {
    params_path = os.path.join(FIXTURES, "params");
    combined = "";
    for i in ["test_failing_posonly", "test_failing_kwonly", "test_failing_varargs"] {
        combined += run_jac(os.path.join(params_path, i + ".jac"));
    }
    assert "FAILED" not in combined;
}

# ── Tests using execution.run() pattern ──────────────────────────────────────
test "dynamic spawn archetype" {
    output = run_jac(os.path.join(FIXTURES, "dynamic_archetype.jac")).strip();
    lines = output.split("\n");
    assert any("Spawned Node:" in line for line in lines);
    assert any("Spawned Walker:" in line for line in lines);
    assert any("Spawned External node:" in line for line in lines);
    for val in ["Value: 0", "Value: 1", "Value: 2", "Value: 3"] {
        occurrences = [
            line
            for line in lines
            if line.strip() == val
        ];
        assert len(occurrences) == 2;
    }
}

test "dynamic archetype creation" {
    output = run_jac(os.path.join(FIXTURES, "create_dynamic_archetype.jac")).strip();
    assert "Dynamic Node Value: 99" in output;
}

test "dynamic archetype creation rel import" {
    lines = run_jac(os.path.join(FIXTURES, "arch_rel_import_creation.jac")).strip().splitlines();
    for val in ["DynamicWalker Started", "UtilityNode Data: 42"] {
        assert val in lines;
    }
}

test "object ref interface" {
    output = run_jac(os.path.join(FIXTURES, "objref.jac"));
    lines = output.split("\n");
    assert len(lines[0]) == 32;
    assert lines[1] == "MyNode(value=0)";
    assert lines[2] == "valid: True";
}

test "edge ability" {
    output = run_jac(os.path.join(FIXTURES, "edge_ability.jac"));
    lines = output.split("\n");
    assert "MyEdge from walker MyEdge(path=1)" in lines[0];
    assert "MyWalker from edge MyWalker()" in lines[1];
    assert "MyWalker from node MyWalker()" in lines[3];
    assert "MyEdge from walker MyEdge(path=2)" in lines[4];
}

test "backward edge visit" {
    output = run_jac(os.path.join(FIXTURES, "backward_edge_visit.jac"));
    lines = output.split("\n");
    assert "MyWalker() from node MyNode(val=0)" in lines[0];
    assert "MyWalker() from edge MyEdge(path=0)" in lines[1];
    assert "MyWalker() from edge MyEdge(path=3)" in lines[6];
    assert "MyWalker() from node MyNode(val=40)" in lines[9];
}

test "visit traversal" {
    output = run_jac(os.path.join(FIXTURES, "visit_traversal.jac"));
    lines = output.split("\n");
    assert "MyWalker() from node MyNode(val=0)" in lines[0];
    assert "MyWalker() from node MyNode(val=20)" in lines[2];
    assert "MyWalker() from node MyNode(val=60)" in lines[4];
    assert "MyWalker() from node MyNode(val=40)" in lines[6];
    assert "MyWalker() from node MyNode(val=90)" in lines[7];
    assert "MyWalker() from node MyNode(val=70)" in lines[9];
}

# ── Tests using examples_path ────────────────────────────────────────────────
test "simple jac red" {
    output = run_module("micro.simple_walk", EXAMPLES, as_main=True);
    assert output == "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n";
}

test "simple walk by edge" {
    output = run_module("micro.simple_walk_by_edge", EXAMPLES);
    assert output == "Visited 1\nVisited 2\n";
}

test "typed filter compr" {
    output = run_module("micro.typed_filter_compr", EXAMPLES);
    assert "[MyObj(a=0), MyObj2(a=2), MyObj(a=1), MyObj2(a=3), MyObj(a=2), MyObj(a=3)]\n" in output;
    assert "[MyObj(a=0), MyObj(a=1), MyObj(a=2)]\n" in output;
}

# ── Tests using compiler fixture paths ───────────────────────────────────────
test "fstring multiple quotation" {
    output = run_module(
        "compiler/passes/main/fixtures/fstrings", os.path.join(JAC_ROOT, "tests")
    );
    lines = output.split("\n");
    assert lines[0] == "11 13 12 12 11 12 12";
    assert lines[1] == '12 12 """hello"""  18 18';
    assert lines[2] == "11 12 11 12 11 18 23";
    assert lines[3] == 'hello klkl"""';
}

test "fstring escape sequences" {
    output = run_module(
        "compiler/passes/main/fixtures/fstring_escape_sequences",
        os.path.join(JAC_ROOT, "tests")
    );
    lines = output.strip().split("\n");
    assert lines[0] == "'hello\\nworld'";
    assert lines[1] == "'tab\\there'";
    assert lines[2] == "'line1\\nline2\\nline3'";
    assert lines[3] == "'world\\tworld\\tworld'";
}
