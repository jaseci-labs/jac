"""Known edge endpoint violations are rejected before graph execution."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

def endpoint_diagnostics(body: str) -> list[tuple[str, str]] {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'endpoints.jac';
        path.write_text('node A {} node B {} edge Link: A --> B {}\n' + body);
        program = JacProgram();
        program.compile(
            str(path),
            options=CompileOptions(
                no_cgen=True, no_ir_cache=True, default_codespace='server'
            )
        );
        return [
            (alert.code.code, alert.msg)
            for alert in program.errors_had
            if alert.code is not None
        ];
    }
}

test "forward reverse and collection connections accept valid endpoints" {
    assert endpoint_diagnostics(
        'def connect_pair(a:A, b:B, many:list[A]) {'
        ' a +>:Link:+> b; b <+:Link:<+ a; many +>:Link:+> b; }'
    )
        == [];
}

test "known wrong endpoint types fail in either direction and in collections" {
    for (body, endpoint) in [
        ('def connect_pair(a:B,b:B) { a +>:Link:+> b; }', 'source'),
        ('def connect_pair(a:A,b:A) { a +>:Link:+> b; }', 'target'),
        ('def connect_pair(a:list[B],b:B) { a +>:Link:+> b; }', 'source'),
        ('def connect_pair(a:A,b:A) { a <+:Link:<+ b; }', 'target'),
        ('def connect_pair(a:A|B,b:B) { a +>:Link:+> b; }', 'source'),
        ('edge Child(Link) {} def connect_pair(a:A,b:A) { a +>:Child:+> b; }', 'target')
    ] {
        diagnostics = endpoint_diagnostics(body);
        assert len(diagnostics) == 1 , diagnostics;
        assert diagnostics[0][0] == 'E1135' , diagnostics;
        assert 'Invalid ' + endpoint in diagnostics[0][1] , diagnostics;
    }
}

test "bidirectional connections check both declared directions" {
    diagnostics = endpoint_diagnostics('def connect_pair(a:A,b:B) { a <+:Link:+> b; }');
    assert len(diagnostics) == 2 , diagnostics;
    assert all(code == 'E1135' for (code, message) in diagnostics) , diagnostics;
}
