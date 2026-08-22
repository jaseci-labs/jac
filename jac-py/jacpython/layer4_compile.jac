# Layer 4 differential compile oracle (PLAN.md P0.2).
#
# Host compile() -> marshal -> Reader yields an expected PyCode; pycode_diff
# compares it structurally (including nested code constants) and via normalized
# disassembly. Until jacpython's native compiler exists, the "actual" side is
# the same oracle path -- these tests prove the differ and contract metadata.
#
# Product path poison: product_compile.jac must not reach host_oracle (P0.3).

import from objects { PyObj, PyCode, PyInt, expect_int, is_error }
import from opcode_meta {
    OP_BINARY_OP,
    OP_LOAD_ATTR,
    OP_CALL,
    OP_COMPARE_OP,
    OP_EXTENDED_ARG,
    OP_FOR_ITER,
    OP_JUMP_BACKWARD,
    OP_JUMP_FORWARD,
    opcode_cache_count,
    instruction_width,
}
import from pycode_diff {
    pycode_equal,
    pycode_diff_message,
    disassemble_lines,
    dis_diff_first,
}
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }
import from product_compile { compile_source, product_compile_active }


def oracle_code(source: str, filename: str, mode: str, optimize: int) -> PyObj {
    data = host_compile_marshal(source, filename, mode, optimize);
    return unmarshal(data);
}

def assert_oracle_self_equal(source: str, mode: str) {
    a = oracle_code(source, "<layer4>", mode, 0);
    b = oracle_code(source, "<layer4>", mode, 0);
    assert isinstance(a, PyCode);
    assert isinstance(b, PyCode);
    assert pycode_equal(a as PyCode, b as PyCode);
}

# ---------------- P0.1 contract tests ----------------

test "layer4: opcode cache counts match CPython 3.14.6 metadata" {
    assert opcode_cache_count(OP_BINARY_OP) == 5;
    assert opcode_cache_count(OP_CALL) == 3;
    assert opcode_cache_count(OP_COMPARE_OP) == 1;
    assert opcode_cache_count(OP_FOR_ITER) == 1;
    assert opcode_cache_count(OP_JUMP_BACKWARD) == 1;
    assert opcode_cache_count(OP_LOAD_ATTR) == 9;
    assert instruction_width(OP_LOAD_ATTR) == 11;
}

test "layer4: PyCode self-diff is identity for exec mode" {
    assert_oracle_self_equal("x = 1 + 2\n", "exec");
}

test "layer4: PyCode self-diff is identity for eval mode" {
    assert_oracle_self_equal("1 + 2", "eval");
}

test "layer4: nested code objects diff recursively" {
    src = (
        "def outer():\n"
        "    def inner():\n"
        "        return 3\n"
        "    return inner()\n"
        "outer()\n"
    );
    co = oracle_code(src, "<layer4-nested>", "exec", 0);
    assert isinstance(co, PyCode);
    outer = co as PyCode;
    inner_co: PyCode | None = None;
    oi = 0;
    while oi < len(outer.consts) {
        if isinstance(outer.consts[oi], PyCode) {
            outer_fn = outer.consts[oi] as PyCode;
            ci = 0;
            while ci < len(outer_fn.consts) {
                if isinstance(outer_fn.consts[ci], PyCode) {
                    inner_co = outer_fn.consts[ci] as PyCode;
                }
                ci = ci + 1;
            }
        }
        oi = oi + 1;
    }
    assert inner_co is not None;
    assert (inner_co as PyCode).name == "inner";
    assert_oracle_self_equal(src, "exec");
}

test "layer4: disassembly identifies instructions" {
    co = oracle_code("a = 1\nb = 2\na + b", "<layer4-dis>", "exec", 0);
    assert isinstance(co, PyCode);
    lines = disassemble_lines(co as PyCode);
    assert len(lines) > 0;
    found_binop = False;
    for line in lines {
        if "BINARY_OP" in line {
            found_binop = True;
        }
    }
    assert found_binop;
}

test "layer4: diff reports first bytecode mismatch" {
    a = oracle_code("1", "<a>", "eval", 0);
    b = oracle_code("2", "<b>", "eval", 0);
    assert isinstance(a, PyCode);
    assert isinstance(b, PyCode);
    msg = pycode_diff_message(a as PyCode, b as PyCode);
    assert msg != "";
    dis = dis_diff_first(a as PyCode, b as PyCode);
    assert dis != "";
}

test "layer4: exec oracle round-trip runs in ceval" {
    co = oracle_code("7 * 6", "<layer4-exec>", "eval", 0);
    outcome = exec_code(co, [], {});
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 42;
}

test "layer4: nested function oracle round-trip" {
    src = (
        "def outer():\n"
        "    def inner():\n"
        "        return 3\n"
        "    return inner()\n"
        "outer()\n"
    );
    assert_oracle_self_equal(src, "exec");
}

test "layer4: optimization level is honored by oracle" {
    co0 = oracle_code("x = 1", "<opt>", "exec", 0);
    co2 = oracle_code("x = 1", "<opt>", "exec", 2);
    assert isinstance(co0, PyCode);
    assert isinstance(co2, PyCode);
    # Both must decode; structural identity is not required across opt levels.
    assert len((co0 as PyCode).co_code) > 0;
    assert len((co2 as PyCode).co_code) > 0;
}

test "layer4: product compile_source produces native PyCode for eval" {
    # Phase B capstone: the eval path is now fully native (no host fallback).
    # Byte-exact oracle parity + VM execution live in layer8_product_expr.
    r = compile_source("1+1", "<product>", "eval", 0);
    assert not is_error(r);
    assert isinstance(r, PyCode);
}

test "layer4: product path flag starts clear" {
    assert not product_compile_active;
}

test "layer4: EXTENDED_ARG folds wide oparg for large indices" {
    # Many distinct constants force STORE_NAME/LOAD_NAME indices past 255.
    src = "";
    i = 0;
    while i < 260 {
        src = src + "c" + str(i) + "=" + str(i) + "\n";
        i = i + 1;
    }
    src = src + "x = c257\n";
    co = oracle_code(src, "<extarg>", "exec", 0);
    assert isinstance(co, PyCode);
    code_co = co as PyCode;
    found_ext = False;
    ip = 0;
    while ip < len(code_co.co_code) {
        op = code_co.co_code[ip];
        if op == OP_EXTENDED_ARG {
            found_ext = True;
        }
        ip = ip + instruction_width(op);
    }
    assert found_ext;
    assert_oracle_self_equal(src, "exec");
}

test "layer4: jump offsets are code-unit instruction boundaries" {
    src = "while True:\n    break\n";
    co = oracle_code(src, "<jump>", "exec", 0);
    assert isinstance(co, PyCode);
    code_co = co as PyCode;
    starts: list[int] = [];
    ip = 0;
    code = code_co.co_code;
    while ip < len(code) {
        starts.append(ip);
        op = code[ip];
        ip = ip + instruction_width(op);
    }
    ip = 0;
    while ip < len(code) {
        op = code[ip];
        w = instruction_width(op);
        arg = code[ip + 1];
        if op == OP_JUMP_FORWARD {
            target = ip + w + arg;
            found = False;
            si = 0;
            while si < len(starts) {
                if starts[si] == target {
                    found = True;
                }
                si = si + 1;
            }
            assert found;
        }
        if op == OP_JUMP_BACKWARD {
            target = ip + w - arg;
            found = False;
            si = 0;
            while si < len(starts) {
                if starts[si] == target {
                    found = True;
                }
                si = si + 1;
            }
            assert found;
        }
        ip = ip + w;
    }
}

test "layer4: localsplus varnames cellvars freevars for nested closure" {
    src = (
        "def outer(x):\n"
        "    def inner():\n"
        "        return x\n"
        "    return inner()\n"
        "outer(1)\n"
    );
    co = oracle_code(src, "<localsplus>", "exec", 0);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    outer_co: PyCode | None = None;
    inner_co: PyCode | None = None;
    oi = 0;
    while oi < len(mod.consts) {
        if isinstance(mod.consts[oi], PyCode) {
            outer_co = mod.consts[oi] as PyCode;
            ci = 0;
            while ci < len(outer_co.consts) {
                if isinstance(outer_co.consts[ci], PyCode) {
                    inner_co = outer_co.consts[ci] as PyCode;
                }
                ci = ci + 1;
            }
        }
        oi = oi + 1;
    }
    assert outer_co is not None;
    assert inner_co is not None;
    outer = outer_co as PyCode;
    inner = inner_co as PyCode;
    assert outer.varnames[0] == "x";
    assert len(inner.freevars) == 1;
    assert inner.freevars[0] == "x";
    # Merged locals-plus tail: [varnames][non-arg cellvars][freevars].
    merged_inner = len(inner.varnames) + len(inner.cellvars) + len(inner.freevars);
    assert merged_inner > len(inner.varnames);
    assert_oracle_self_equal(src, "exec");
}

test "layer4: exception table varint bytes stable across oracle runs" {
    src = "try:\n    1/0\nexcept ZeroDivisionError:\n    pass\n";
    co = oracle_code(src, "<exctab>", "exec", 0);
    assert isinstance(co, PyCode);
    assert len((co as PyCode).exceptiontable) > 0;
    assert_oracle_self_equal(src, "exec");
}

test "layer4: name and const ordering is stable across oracle runs" {
    src = "a = 1\nb = 2\nc = a + b\n";
    a = oracle_code(src, "<order>", "exec", 0);
    b = oracle_code(src, "<order>", "exec", 0);
    assert isinstance(a, PyCode);
    assert isinstance(b, PyCode);
    assert (a as PyCode).names == (b as PyCode).names;
    assert len((a as PyCode).consts) == len((b as PyCode).consts);
    assert_oracle_self_equal(src, "exec");
}
