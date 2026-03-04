"""Tests for match case type narrowing in the type checker.

These tests validate that the type checker narrows types inside match cases
based on the pattern being matched, similar to how isinstance narrowing works.
"""

obj StringVal {
    has value: str;
}

obj IntVal {
    has value: int;
}

obj FloatVal {
    has value: float;
}

obj BoolVal {
    has value: bool;
}

# 1. Basic match case narrowing with class pattern
#    Inside case StringVal(), the matched value is narrowed to StringVal.
def test_match_class_pattern(
    val: StringVal | IntVal
) -> str {
    match val {
        case StringVal():
            s: StringVal = val;  # <-- Ok after narrowing (StringVal)
            return s.value;

        case IntVal():
            i: IntVal = val;  # <-- Ok after narrowing (IntVal)
            return str(i.value);

    }
}

# 2. Match case with union pattern (|)
#    case A() | B() narrows to A | B.
def test_match_or_pattern(
    val: StringVal | IntVal | FloatVal
) -> str {
    match val {
        case StringVal() | IntVal():
            # val is narrowed to StringVal | IntVal
            return str(val.value);  # <-- Ok, both have 'value'


        case FloatVal():
            f: FloatVal = val;  # <-- Ok after narrowing (FloatVal)
            return str(f.value);

    }
}

# 3. Match case with three-way union pattern
def test_match_triple_or(
    val: StringVal | IntVal | FloatVal | BoolVal
) -> str {
    match val {
        case StringVal() | IntVal() | FloatVal():
            # val is narrowed to StringVal | IntVal | FloatVal
            return str(val.value);

        case BoolVal():
            b: BoolVal = val;  # <-- Ok after narrowing (BoolVal)
            return str(b.value);

    }
}

# 4. Match with explicit type access inside case
def test_match_access_member(
    val: StringVal | IntVal
) -> str {
    match val {
        case StringVal():
            return val.value;  # <-- Ok, StringVal has 'value: str'


        case IntVal():
            return str(val.value);  # <-- Ok, IntVal has 'value: int'


    }
}

# E1. Error: Wrong type assignment inside narrowed case
def test_error_wrong_type_in_case(
    val: StringVal | IntVal
) -> str {
    match val {
        case StringVal():
            i: IntVal = val;  # <-- Error: StringVal cannot assign to IntVal
            return str(i.value);

        case IntVal():
            return str(val.value);

    }
}

# E2. Error: Union pattern still can't assign to single type
def test_error_or_pattern_single(
    val: StringVal | IntVal | FloatVal
) -> str {
    match val {
        case StringVal() | IntVal():
            s: StringVal = val;  # <-- Error: StringVal | IntVal cannot assign to StringVal
            return s.value;

        case FloatVal():
            return str(val.value);

    }
}
