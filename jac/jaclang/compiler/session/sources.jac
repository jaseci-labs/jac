import from jaclang.compiler.ir.identity { MutationPermit }
import from jaclang.compiler.ir.identity { RevisionId, SourceId }
import copy;
import hashlib;
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.pass_base { Alert }

obj SourceUnit {
    has syntax: Module,
        failed: bool,
        errors: list[Alert],
        warnings: list[Alert],
        revision: RevisionId = RevisionId("");
}

obj SourceStore {
    has units: dict[RevisionId, SourceUnit] = {},
        revisions: dict[SourceId, RevisionId] = {},
        parses: int = 0,
        hits: int = 0;

    def unit(source: str, path: str, annexes: list[tuple[str, str]]) -> SourceUnit {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven }
        import from jaclang.compiler.session.session { JacProgram }
        key = RevisionId(
            hashlib.sha256(repr((path, source, annexes)).encode()).hexdigest()
        );
        unit = self.units.get(key);
        if unit is None {
            diagnostics = JacProgram();
            (syntax, failed) = parse_woven(source, path, diagnostics, annexes);
            syntax.freeze_structure();
            syntax.attach_permit(MutationPermit());
            unit = SourceUnit(
                syntax,
                failed,
                list(diagnostics.errors_had),
                list(diagnostics.warnings_had),
                revision=key
            );
            previous = self.revisions.get(SourceId(path));
            if previous is not None {
                self.units.pop(previous, None);
            }
            self.revisions[SourceId(path)] = key;
            self.units[key] = unit;
            self.parses += 1;
        } else {
            self.hits += 1;
        }
        return unit;
    }

    def parse(
        source: str, path: str, program: JacProgram, annexes: list[tuple[str, str]]
    ) -> tuple[Module, bool] {
        unit = self.unit(source, path, annexes);
        syntax = copy.deepcopy(unit.syntax);
        assert isinstance(syntax, Module);
        syntax.thaw_structure();
        program.errors_had.extend(unit.errors);
        program.warnings_had.extend(unit.warnings);
        return (syntax, unit.failed);
    }
}
