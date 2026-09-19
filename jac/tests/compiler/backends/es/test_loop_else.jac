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

def slot_loop_else(items: list[int]) -> JsxElement {
    <ul>
        {for item in items {
            <li key={item}>SLOT_ITEM</li>
        } else {
            <li>SLOT_ELSE</li>
        }}
    </ul>
}

def nested_ability_break() -> int {
    total = 0;
    for x in [1, 2] {
        if x == 2 {
            break;
        }
        def inner(v: int) -> int {
            for w in [3, 4] {
                if w == 4 {
                    break;
                }
                return v + w;
            }
            return 0;
        }
        total += inner(x);
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

def else_break_stays_inner() -> int {
    total = 0;
    for i in [1, 2] {
        for j in [1] {
            total += j;
        } else {
            break;
        }
        total += 10;
    } else {
        total += 1000;
    }
    return total;
}

def switch_break_in_loop_else(items: list[int]) -> int {
    total = 0;
    for item in items {
        switch item {
            case 2:
                break;
            case 3:
                total += 30;
                break;
            default:
                total += 1;
        }
        total += 100;
    } else {
        total += 1000;
    }
    return total;
}

def match_break_in_loop_else(items: list[int]) -> int {
    total = 0;
    for item in items {
        match item {
            case 2:
                break;
            case 3:
                total += 30;
                break;
            case _:
                total += 1;
        }
        total += 100;
    } else {
        total += 1000;
    }
    return total;
}

def match_break_without_loop(v: int) -> int {
    total = 0;
    match v {
        case 1:
            break;
        case _:
            total = 5;
    }
    return total;
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
    return es_to_js(es_pass.module.gen.es_ast);
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

test "slot loop else stays inside the view IIFE" {
    js = compile_to_js();
    region: str = js[js.find("function Slot_loop_else"):js.find(
        "function nested_ability_break"
    )];
    iife_idx = region.find("(() => {");
    assert iife_idx != -1 , f"view IIFE missing: {region[:400]}";
    acc_idx = region.find("let __jac_view_kids");
    item_idx = region.find("SLOT_ITEM");
    else_idx = region.find("SLOT_ELSE");
    ret_idx = region.find("return __jac_view_kids");
    assert acc_idx != -1 and item_idx != -1 and else_idx != -1 and ret_idx != -1 , (
        f"slot pieces missing: acc={acc_idx} item={item_idx} else={else_idx} ret={ret_idx}"
    );
    assert iife_idx < acc_idx and acc_idx < item_idx and item_idx < else_idx , (
        f"slot pieces out of order: {region[iife_idx:ret_idx + 40]}"
    );
    assert else_idx < ret_idx , (
        f"else body escaped the view IIFE: {region[iife_idx:else_idx + 60]}"
    );
}

test "nested function body does not capture the outer loop label" {
    js = compile_to_js();
    region: str = js[js.find("nested_ability_break"):js.find("forever_in_for_else")];
    labeled = re.findall("break (__jac_loop_[0-9]+)", region);
    assert len(labeled) == 1 , (
        f"only the outer break may be labeled, got {labeled}: {region[:600]}"
    );
    labels = re.findall("(__jac_loop_[0-9]+):", region);
    for b in labeled {
        assert b in labels , (
            f"break {b} targets a label that is never emitted: {sorted(labels)}"
        );
    }
}

test "break in a nested loop else exits only the inner construct" {
    js = compile_to_js();
    region: str = js[js.find("function else_break_stays_inner"):];
    breaks = re.findall("break (__jac_loop_[0-9]+)", region);
    labels = re.findall("(__jac_loop_[0-9]+):", region);
    assert len(breaks) == 1 and len(labels) == 1 and breaks[0] == labels[0] , (
        "the inner else break must target the one emitted label: "
        f"{sorted(breaks)} vs {sorted(labels)}: {region[:600]}"
    );
    outer_for = region.find("for (const i of");
    inner_for = region.find("for (const j of");
    label_idx = region.find(labels[0] + ":");
    assert outer_for != -1 and inner_for != -1 , f"loops missing: {region[:600]}";
    assert outer_for < label_idx and label_idx < inner_for , (
        "the label must sit on the inner loop's own sequence, not the "
        f"outer construct: {region[:600]}"
    );
}

test "switch case break binds to the switch, not the loop" {
    js = compile_to_js();
    region: str = js[js.find("function switch_break_in_loop_else"):js.find(
        "function match_break_in_loop_else"
    )];
    assert "switch (" in region , f"switch not lowered to a JS switch: {region[:400]}";
    assert "__jac_loop_" not in region , (
        "a loop whose breaks all belong to its switch must not emit a loop "
        f"label: {region[:400]}"
    );
    assert "total += 1000;" in region , f"else body missing: {region[:400]}";
}

test "match case break exits the match via its labeled block" {
    js = compile_to_js();
    region: str = js[js.find("function match_break_in_loop_else"):js.find(
        "function match_break_without_loop"
    )];
    assert "break __jac_loop_" not in region , (
        f"match break was labeled to the loop: {region[:400]}"
    );
    assert "__jac_loop_" not in region , (
        "a loop whose breaks all belong to its match must not emit a loop "
        f"label: {region[:400]}"
    );
    breaks = re.findall("break (__jac_match_[0-9]+)", region);
    labels = re.findall("(__jac_match_[0-9]+):", region);
    assert breaks , f"no match-targeted break found: {region[:400]}";
    for b in breaks {
        assert b in labels , (
            f"break {b} targets a label that is never emitted: {sorted(labels)}"
        );
    }
    assert "total += 1000;" in region , f"else body missing: {region[:400]}";
}

test "match break without a loop targets the match, not a bare break" {
    js = compile_to_js();
    region: str = js[js.find("function match_break_without_loop"):];
    breaks = re.findall("break (__jac_match_[0-9]+)", region);
    labels = re.findall("(__jac_match_[0-9]+):", region);
    assert breaks , f"match break was not rewritten to a labeled break: {region[:400]}";
    for b in breaks {
        assert b in labels , (
            f"break {b} targets a label that is never emitted: {sorted(labels)}"
        );
    }
}
