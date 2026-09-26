"""Compile-time operators use Jac semantics through one binary dispatcher."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.types.ct_eval { CtEvaluator, CtError }
import from jaclang.compiler.types.ct_value {
    CtRaise,
    CtValue,
    ct_eq,
    dict_set,
    mk_dict,
    mk_float,
    mk_int,
    mk_list,
    mk_str
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }

def ints(*vals: int) -> list[CtValue] {
    return [mk_int(v) for v in vals];
}

test "compile-time comparison and membership preserve operand order" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    keyed = mk_dict();
    dict_set(keyed, mk_str("key"), mk_int(7));
    assert evaluator._cmp(Tok.LT.value, mk_int(-2), mk_int(3));
    assert evaluator._cmp(Tok.LTE.value, mk_int(3), mk_int(3));
    assert evaluator._cmp(Tok.GT.value, mk_str("b"), mk_str("a"));
    assert evaluator._cmp(Tok.GTE.value, mk_str("a"), mk_str("a"));
    assert evaluator._cmp(Tok.KW_IN.value, mk_str("key"), keyed);
    assert not evaluator._cmp(Tok.KW_IN.value, mk_int(7), keyed);
    assert evaluator._cmp(
        Tok.KW_NIN.value, mk_str("missing"), mk_list([mk_str("key")])
    );
    assert evaluator._cmp(Tok.KW_IN.value, mk_str("bc"), mk_str("abcd"));
}

test "shared compile-time binary operators preserve values and errors" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    assert ct_eq(
        evaluator._binop_by_name(Tok.PLUS.value, mk_list(ints(1)), mk_list(ints(2))),
        mk_list(ints(1, 2))
    );
    assert ct_eq(
        evaluator._binop_by_name(Tok.STAR_MUL.value, mk_str("ab"), mk_int(2)),
        mk_str("abab")
    );
    assert ct_eq(
        evaluator._binop_by_name(Tok.FLOOR_DIV.value, mk_int(-7), mk_int(3)), mk_int(-3)
    );
    assert ct_eq(
        evaluator._binop_by_name(Tok.MOD.value, mk_int(-7), mk_int(3)), mk_int(2)
    );
    assert ct_eq(
        evaluator._binop_by_name(Tok.DIV.value, mk_int(7), mk_int(2)), mk_float(3.5)
    );
    assert ct_eq(
        evaluator._binop_by_name(Tok.RSHIFT.value, mk_int(16), mk_int(2)), mk_int(4)
    );
    with testraises(CtRaise) {
        evaluator._binop_by_name(Tok.DIV.value, mk_int(1), mk_int(0));
    }
    with testraises(CtError) {
        evaluator._binop_by_name("unsupported", mk_int(16), mk_int(2));
    }
}
