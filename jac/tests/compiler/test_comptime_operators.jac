"""Compile-time operators use Jac semantics through one binary dispatcher."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.types.ct_eval { CtEvaluator, CtError }
import from jaclang.compiler.frontend.constant { Tokens as Tok }

test "compile-time comparison and membership preserve operand order" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    assert evaluator._cmp(Tok.LT.value, -2, 3);
    assert evaluator._cmp(Tok.LTE.value, 3, 3);
    assert evaluator._cmp(Tok.GT.value, "b", "a");
    assert evaluator._cmp(Tok.GTE.value, "a", "a");
    assert evaluator._cmp(Tok.KW_IN.value, "key", {"key": 7});
    assert not evaluator._cmp(Tok.KW_IN.value, 7, {"key": 7});
    assert evaluator._cmp(Tok.KW_NIN.value, "missing", ["key"]);
    assert evaluator._cmp(Tok.KW_IN.value, "bc", "abcd");
}

test "shared compile-time binary operators preserve values and errors" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    assert evaluator._binop_by_name(Tok.PLUS.value, [1], [2]) == [1, 2];
    assert evaluator._binop_by_name(Tok.STAR_MUL.value, "ab", 2) == "abab";
    assert evaluator._binop_by_name(Tok.FLOOR_DIV.value, -7, 3) == -3;
    assert evaluator._binop_by_name(Tok.MOD.value, -7, 3) == 2;
    assert evaluator._binop_by_name(Tok.DIV.value, 7, 2) == 3.5;
    assert evaluator._binop_by_name(Tok.RSHIFT.value, 16, 2) == 4;
    with testraises(ZeroDivisionError) {
        evaluator._binop_by_name(Tok.DIV.value, 1, 0);
    }
    with testraises(CtError) {
        evaluator._binop_by_name("unsupported", 16, 2);
    }
}
