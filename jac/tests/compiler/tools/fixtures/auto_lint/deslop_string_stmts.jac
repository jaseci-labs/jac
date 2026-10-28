def first_stmt(n: int) -> int {
    """FIRST_STMT_DOC""";
    return n;
}

def mid_body(n: int) -> int {
    m = n + 1;
    """MID_BODY_DOC""";
    "SINGLE_QUOTED_NOTE";
    "MULTI_" "STRING_NOTE";
    f"KEPT_FSTRING {m}";
    "KEPT_SUPPRESSED";  # jac:ignore[W3051]
    if m > 2 {
        "NESTED_NOTE";
    }
    match m {
        case 1:
            "KEPT_LONE_CASE";
        case _:
            m = 3;
            "CASE_NOTE";
    }
    return m;
}

def lambdas -> list[str] {
    kept = lambda { "KEPT_LAMBDA_RETURN"; };
    noted = lambda {
        "LAMBDA_NOTE";
        return "LAMBDA_VALUE";
    };
    shielded = lambda {
        "KEPT_BEFORE_LONE_EXPR";
        len("abc");
    };
    return [kept(), noted(), str(shielded())];
}

def:pub slot_view(show: bool) -> JsxElement {
    return
        <div>
            {if show {
                "KEPT_SLOT_CONTENT";
            }}
        </div>;
}
