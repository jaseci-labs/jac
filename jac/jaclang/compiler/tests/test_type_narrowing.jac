"""Type narrowing tests for the Jac type checker.

Tests the CFG-based type narrowing system including:
- None checks (is None, is not None, == None, != None)
- isinstance checks (basic, tuple, negated, nested)
- Boolean AND/OR narrowing
- if-elif-else chain narrowing
- Attribute-based narrowing (c.field is not None, isinstance(c.field, T))
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob TYPE_NARROWING_FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent),
         "compiler",
         "tests",
         "fixtures",
         "type_narrowing"
     );

"""Test None check narrowing patterns.

Covers:
- x is None / x is not None
- x == None / x != None
- Early return narrowing pattern
- Nested None checks
"""
test "none_check_narrowing" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPE_NARROWING_FIXTURES, "none_check_basic.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # All None check patterns should pass without type errors
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test isinstance narrowing patterns.

Covers:
- Basic isinstance(x, T)
- isinstance with else branch
- isinstance with tuple of types
- Negated isinstance (not isinstance)
- Nested isinstance checks
- isinstance with None type
- isinstance preserving generic type args
"""
test "isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPE_NARROWING_FIXTURES, "isinstance_basic.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # All isinstance patterns should pass without type errors
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test boolean AND/OR narrowing patterns.

Covers:
- Basic AND narrowing (a and b -> both non-None)
- Chained AND with isinstance
- Truthiness narrowing (if x: -> x is non-None)
- AND short-circuit in expressions

Note: Some advanced patterns (OR else branch, De Morgan) are marked as TODO.
"""
test "bool_and_or_narrowing" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPE_NARROWING_FIXTURES, "bool_and_or.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # All supported patterns should pass without type errors
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test if-elif-else chain narrowing.

Covers:
- Progressive isinstance narrowing through elif
- elif with union type exhaustion
- elif with None checks
- Nested if inside elif
- Long elif chains
- Early return in if-elif

Note: Compound elif conditions are partially supported (marked as TODO).
"""
test "if_elif_else_narrowing" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPE_NARROWING_FIXTURES, "if_elif_else.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # All supported patterns should pass without type errors
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}
