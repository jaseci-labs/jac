"""Loop `else` clause lowering in the ES backend (#8629).

JS loops have no else clause, so the backend must synthesize the
semantics: the loop and its else block are wrapped in a labeled block,
exhaustion falls through into the else statements, and every `break`
belonging to the loop is rewritten to a labeled break that skips them.
"""

import os;
import tempfile;
import re;
import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob FIXTURE_SOURCE = '''
def loop_while_exhausts() -> int {
    x = 0;
    while x < 3 {
        x += 1;
    } else {
        x = 99;
    }
    return x;
}

def loop_while_break_skips() -> int {
    x = 0;
    while x < 9 {
        if x == 2 {
            break;
        }
        x += 1;
    } else {
        x = 99;
    }
    return x;
}

def loop_for_exhausts(items: list[int]) -> int {
    total = 0;
    for item in items {
        total += item;
    } else {
        total += 1000;
    }
    return total;
}

def loop_for_break_skips(items: list[int]) -> int {
    total = 0;
    for item in items {
        if item == 20 {
            break;
        }
        total += item;
    } else {
        total += 1000;
    }
    return total;
}

def forever_in_for_else() -> str {
    out = "";
    for x in [1, 2] {
        if x == 2 {
            break;
        }
        forever {
            out += "f";
            break;
        }
    } else {
        out += "e";
    }
    return out;
}
''',
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_loop_else_");

with entry {
    with open(os.path.join(_test_tmp_dir, "jac.toml"), "w") as _pins {
        _pins.write('[placement.pins]\n"*" = "client"\n');
    }
    with open(os.path.join(_test_tmp_dir, "loop_else.jac"), "w") as _fixture {
        _fixture.write(FIXTURE_SOURCE);
    }
}

"""Compile the loop-else fixture to JavaScript source."""
def compile_to_js -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(_test_tmp_dir, "loop_else.jac"), no_cgen=True
    );
    assert not prog.errors_had , (
        f"Compilation errors: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = run_pass(EsastGenPass, ir, prog);
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

test "while else lowers to labeled blocks with labeled breaks" {
    js = compile_to_js();
    # The exhaustion-only while needs no label; its else is plain sequence.
    exhaust_start = js.find("loop_while_exhausts");
    exhaust_end = js.find("loop_while_break_skips");
    exhaust_body = js[exhaust_start:exhaust_end];
    assert "while ((x < 3))" in exhaust_body , f"while missing: {exhaust_body}";
    assert "x = 99;" in exhaust_body , f"else body misplaced: {exhaust_body}";
    assert "__jac_loop_" not in exhaust_body , (
        f"a break-free while must not emit a label: {exhaust_body}"
    );
    # The breaking while gets a label; its break targets it.
    break_body = js[exhaust_end:];
    assert "__jac_loop_1:" in break_body or "__jac_loop_2:" in break_body , (
        f"missing loop label: {break_body}"
    );
    assert "break __jac_loop_" in break_body , f"break not rewritten: {break_body}";
    assert "x = 99;" in break_body , f"else body missing: {break_body}";
}

test "for-of exhaustion sequences the else body without a label" {
    js = compile_to_js();
    start = js.find("loop_for_exhausts");
    end = js.find("loop_for_break_skips");
    body = js[start:end];
    assert "for (const item of" in body , f"for-of loop missing: {body}";
    assert "total += 1000;" in body , f"else body not sequenced after loop: {body}";
    assert "__jac_loop_" not in body , (
        f"a break-free loop must not emit a label: {body}"
    );
}

test "for-of break rewrites to its own label and skips the else" {
    js = compile_to_js();
    body = js[js.find("loop_for_break_skips"):];
    assert "__jac_loop_" in body , f"no label around breaking for-of: {body[:400]}";
    assert "break __jac_loop_" in body , f"break not labeled: {body[:400]}";
}

test "forever inside for-else leaves no dangling labeled break" {
    js = compile_to_js();
    body = js[js.find("forever_in_for_else"):];
    assert "break __jac_loop_" in body , (
        f"outer break was not rewritten to a labeled break: {body[:400]}"
    );
    breaks = re.findall("break (__jac_loop_[0-9]+)", body);
    labels = re.findall("(__jac_loop_[0-9]+):", body);
    for b in breaks {
        assert b in labels , (
            f"break {b} targets a label that is never emitted: {sorted(labels)}"
        );
    }
}
