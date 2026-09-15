"""Segment maps must survive repeated identifier text inside one parent.

`build_segments` derives each node's generated offset by locating its emitted
text inside its parent's emitted text. Any node whose text repeats within its
parent -- `x + x`, `a.b.a`, `f(x, x)`, or an import clause where one specifier
is a substring of another (`default as mermaid, Mermaid`) -- is where a naive
search mislocates. These tests pin the exact generated column of every such
occurrence.
"""

import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.backends.es.es_unparse { es_to_js_with_map }

"""An es.Identifier carrying the Jac column it came from."""
def _ident(name: str, col: int, line: int = 1) -> any {
    return es.Identifier(
        name=name,
        loc=es.SourceLocation(
            start=es.Position(line=line, column=col),
            end=es.Position(line=line, column=col + len(name))
        )
    );
}

def _stmt(expr: any) -> any {
    return es.ExpressionStatement(expression=expr);
}

"""Map generated (line, column) -> (source line, source column, name)."""
def _segment_index(segments: list[any]) -> dict[tuple[int, int], tuple[int, int, str]] {
    out: dict[tuple[int, int], tuple[int, int, str]] = {};
    for seg in segments {
        out[(seg[0], seg[1])] = (seg[2], seg[3], seg[4]);
    }
    return out;
}

test "each occurrence of a repeated identifier maps to its own Jac column" {
    # x + x, where the two x's come from different Jac columns.
    program = es.Program(
        body=[
            _stmt(
                es.BinaryExpression(
                    left=_ident("x", 5), operator="+", right=_ident("x", 9)
                )
            )
        ]
    );
    (code, segments) = es_to_js_with_map(program);
    assert code == "(x + x);" , code;
    index = _segment_index(segments);
    assert index[(1, 1)] == (1, 5, "x") , index;
    assert index[(1, 5)] == (1, 9, "x") , index;
}

test "a member chain that repeats a name maps each link separately" {
    # a.b.a -- the trailing 'a' must not collapse onto the leading one.
    chain = es.MemberExpression(
        object=es.MemberExpression(
            object=_ident("a", 3), property=_ident("b", 5), computed=False
        ),
        property=_ident("a", 7),
        computed=False
    );
    (code, segments) = es_to_js_with_map(es.Program(body=[_stmt(chain)]));
    assert code == "a.b.a;" , code;
    index = _segment_index(segments);
    assert index[(1, 0)] == (1, 3, "a") , index;
    assert index[(1, 2)] == (1, 5, "b") , index;
    assert index[(1, 4)] == (1, 7, "a") , index;
}

test "two identical call arguments keep distinct generated columns" {
    call = es.CallExpression(
        callee=_ident("f", 1), arguments=[_ident("x", 3), _ident("x", 6)]
    );
    (code, segments) = es_to_js_with_map(es.Program(body=[_stmt(call)]));
    assert code == "f(x, x);" , code;
    index = _segment_index(segments);
    assert index[(1, 0)] == (1, 1, "f") , index;
    assert index[(1, 2)] == (1, 3, "x") , index;
    assert index[(1, 5)] == (1, 6, "x") , index;
}

test "an import specifier is not shadowed by a longer one it is a substring of" {
    # import mermaid, { Mermaid } from "mermaid";
    # 'mermaid' appears three times in the emitted line and 'Mermaid' shares
    # its tail; every one must map back to its own Jac column.
    decl = es.ImportDeclaration(
        specifiers=[
            es.ImportDefaultSpecifier(local=_ident("mermaid", 36)),
            es.ImportSpecifier(
                imported=_ident("Mermaid", 45), local=_ident("Mermaid", 45)
            )
        ],
        source=es.Literal(
            value="mermaid",
            loc=es.SourceLocation(
                start=es.Position(line=1, column=13), end=es.Position(line=1, column=22)
            )
        )
    );
    (code, segments) = es_to_js_with_map(es.Program(body=[decl]));
    assert code == 'import mermaid, { Mermaid } from "mermaid";' , code;
    index = _segment_index(segments);
    # the default binding, at its own Jac column
    assert index[(1, 7)] == (1, 36, "mermaid") , index;
    # the named specifier, at the Jac column of the item that imports it
    assert index[(1, 18)] == (1, 45, "Mermaid") , index;
    # the module string, at the Jac column of the quoted path
    assert index[(1, 33)][1] == 13 , index[(1, 33)];
    # nothing claims a generated column the emitter never wrote a node at
    for seg in segments {
        assert seg[1] < len(code) , seg;
    }
}

test "an unlocatable child is skipped rather than guessed onto a wrong column" {
    # gen_import_specifier collapses `imported as local` to one name when the
    # two match, so `local` shares `imported`'s text. It must map to that same
    # offset, never to some unrelated earlier occurrence of the text.
    decl = es.ImportDeclaration(
        specifiers=[
            es.ImportSpecifier(imported=_ident("v", 10), local=_ident("v", 10)),
            es.ImportSpecifier(imported=_ident("w", 13), local=_ident("w", 13))
        ],
        source=es.Literal(value="p")
    );
    (code, segments) = es_to_js_with_map(es.Program(body=[decl]));
    assert code == 'import { v, w } from "p";' , code;
    index = _segment_index(segments);
    assert index[(1, 9)] == (1, 10, "v") , index;
    assert index[(1, 12)] == (1, 13, "w") , index;
    # no segment may point at a generated column whose text is not the name
    for seg in segments {
        if seg[4] {
            assert code[seg[1]:seg[1] + len(seg[4])] == seg[4] , f"{seg} does not sit on its own text in {code!r}";
        }
    }
}
