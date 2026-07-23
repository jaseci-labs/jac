"""Regression fixture for the CommentInjectionPass memoization (#7495):
comment-dense, adjacent JSX test blocks that exercise the shared IfBreak
DocIR DAG. On the buggy memoized _process, standalone comments were
duplicated/misattributed across blocks and formatting was non-idempotent."""

test "JSX slot statement bodies round-trip through the formatter" {
    # `{...}` slots with statement-form bodies (control flow yielding JSX,
    # `return` guards) get lowered by ViewLowerPass into an accumulator
    # IIFE; the formatter pipeline doesn't run that pass, so it must see
    # and preserve the original slot syntax verbatim.
    source = (
        'def:pub Greeting(name: str) -> JsxElement {\n'
        '    return <div>\n'
        '        {if name == "" {\n'
        '            <p>anon</p>\n'
        '        } else {\n'
        '            <h1>Hello, {name}</h1>\n'
        '        }}\n'
        '    </div>;\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac or "";

    # The slot keyword `if` must survive verbatim -- never expanded into
    # a comprehension or ternary.
    assert "{if name" in formatted , (
        "the statement-form `if` slot must survive formatting:\n" + str(formatted)
    );
    assert "} else {" in formatted , (
        "the `else` branch must survive formatting:\n" + str(formatted)
    );
    # The lowering must never leak into formatted source.
    assert "__jac_view_kids" not in formatted , (
        "formatter must not expose the lowering accumulator:\n" + str(formatted)
    );

    # Idempotency: formatting the formatted output must be a no-op.
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert not prog2.errors_had;
    assert formatted == prog2.mod.main.gen.jac , ("slot formatting is not idempotent");
}

test "dynamic JSX tags round-trip through the formatter" {
    # `<@expr ...>` syntax must survive formatting verbatim - the `@`-led
    # dynamic-tag form is parsed into the JSX kid list and the structural
    # formatter must emit it back in the same shape.
    source = (
        'def:pub Box(as_: str, children: any = None) -> JsxElement {\n'
        '    return <@as_ class="box">{children}</@as_>;\n'
        '}\n'
        '\n'
        'def:pub Icon(glyph: type) -> JsxElement {\n'
        '    return <@{glyph} class="icon"/>;\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac or "";

    assert "<@as_" in formatted , (
        "identifier-form dynamic open tag must survive formatting:\n" + str(formatted)
    );
    assert "</@as_>" in formatted , (
        "identifier-form dynamic close tag must survive formatting:\n" + str(formatted)
    );
    assert "<@{glyph}" in formatted , (
        "brace-wrapped dynamic tag must survive formatting:\n" + str(formatted)
    );

    # Idempotency: formatting the formatted output must be a no-op.
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert not prog2.errors_had;
    assert formatted == prog2.mod.main.gen.jac , (
        "dynamic-tag formatting is not idempotent"
    );
}
