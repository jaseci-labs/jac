import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.progstate { DiagLedger }
import from jaclang.project.span { Span }
import from jaclang.compiler.passes.transform { Alert, Transform }

def diagnostic(path: Path, message: str) -> Alert {
    return Alert(message, Span.make(str(path), '', (1, 1), (1, 1), (0, 0)), Transform);
}

test "batched diagnostic ownership preserves module and annex ordering" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        foo = str(base / 'foo.jac');
        bar = str(base / 'bar.jac');
        ledger = DiagLedger();
        annex = diagnostic(base / 'foo.impl' / 'nested.jac', 'nested');
        shared = diagnostic(base / 'impl' / 'foo.extra.impl.jac', 'shared');
        dotted = diagnostic(base / 'foo.extra.test.jac', 'dotted');
        unrelated = diagnostic(base / 'foo.extra.jac', 'independent');
        other = diagnostic(base / 'bar.jac', 'other');
        ledger.extend([annex, other, unrelated], [shared, dotted, other]);
        (errors, warnings) = ledger.owned_by([bar, foo, foo]);
        assert errors == [other, annex];
        assert warnings == [other, shared, dotted];
        assert errors == ledger.owned_errors(bar) + ledger.owned_errors(foo);
        assert warnings == ledger.owned_warnings(bar) + ledger.owned_warnings(foo);
        assert ledger.owned_by([]) == ([], []);
    }
}

test "diagnostic owner lookups scale with owners rather than warning count" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        paths = [str(base / f'module{i}.jac') for i in range(20)];
        ledger = DiagLedger();
        ledger.extend(
            [diagnostic(base / 'module0.impl.jac', 'error')],
            [diagnostic(base / 'module0.impl.jac', f'warning{i}') for i in range(100)]
        );
        with patch.object(ledger, '_owned', wraps=ledger._owned) as probe {
            (errors, warnings) = ledger.owned_by(paths);
            assert len(errors) == 1 and len(warnings) == 100;
            assert probe.call_count <= len(paths);
        }
    }
}

test "batched ownership observes ledger edits without stale indexes" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        foo = str(base / 'foo.jac');
        bar = str(base / 'bar.jac');
        alert = diagnostic(base / 'foo.jac', 'changed');
        ledger = DiagLedger(warnings=[alert]);
        assert ledger.owned_by([foo])[1] == [alert];
        alert.owner = bar;
        assert ledger.owned_by([foo]) == ([], []);
        assert ledger.owned_by([bar])[1] == [alert];
        ledger.drop_module(bar);
        assert ledger.owned_by([bar]) == ([], []);
        ledger.warnings.append(alert);
        assert ledger.owned_by([bar])[1] == [alert];
        ledger.clear();
        assert ledger.owned_by([bar]) == ([], []);
    }
}
