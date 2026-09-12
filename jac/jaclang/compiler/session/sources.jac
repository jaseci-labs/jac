import from jaclang.compiler.ir.identity { MutationPermit }
import from jaclang.compiler.ir.identity { RevisionId, SourceId }
import copy;
import hashlib;
import from collections { OrderedDict }
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.pass_base { Alert }

obj SourceUnit {
    has syntax: Module,
        failed: bool,
        errors: list[Alert],
        warnings: list[Alert],
        revision: RevisionId = RevisionId(""),
        node_count: int = 0;
}

obj SourceCache {
    has limit: int = 100000,
        nodes: int = 0,
        units: OrderedDict[RevisionId, SourceUnit] = OrderedDict();

    def get(key: RevisionId) -> SourceUnit | None {
        unit = self.units.get(key);
        if unit is not None {
            self.units.move_to_end(key);
        }
        return unit;
    }

    def put(key: RevisionId, unit: SourceUnit) {
        if unit.node_count > self.limit {
            return;
        }
        previous = self.units.pop(key, None);
        if previous is not None {
            self.nodes -= previous.node_count;
        }
        while self.units and self.nodes + unit.node_count > self.limit {
            (_, removed) = self.units.popitem(last=False);
            self.nodes -= removed.node_count;
        }
        self.units[key] = unit;
        self.nodes += unit.node_count;
    }

    def clear {
        self.units.clear();
        self.nodes = 0;
    }
}

obj SourceStore {
    has units: dict[RevisionId, SourceUnit] = {},
        revisions: dict[SourceId, RevisionId] = {},
        shared: SourceCache | None = None,
        parses: int = 0,
        hits: int = 0;

    def unit(source: str, path: str, annexes: list[tuple[str, str]]) -> SourceUnit {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven }
        import from jaclang.compiler.session.session { JacProgram }
        import from jaclang.compiler.ir.syntax.cloning { freeze_source }
        key = RevisionId(
            hashlib.sha256(repr((path, source, annexes)).encode()).hexdigest()
        );
        unit = self.units.get(key);
        if unit is None and self.shared is not None {
            unit = self.shared.get(key);
        }
        if unit is None {
            diagnostics = JacProgram();
            (syntax, failed) = parse_woven(source, path, diagnostics, annexes);
            node_count = freeze_source(syntax, MutationPermit());
            unit = SourceUnit(
                syntax,
                failed,
                list(diagnostics.errors_had),
                list(diagnostics.warnings_had),
                revision=key,
                node_count=node_count
            );
            if self.shared is not None {
                self.shared.put(key, unit);
            }
            self.parses += 1;
        } else {
            self.hits += 1;
        }
        previous = self.revisions.get(SourceId(path));
        if previous is not None and previous != key {
            self.units.pop(previous, None);
        }
        self.revisions[SourceId(path)] = key;
        self.units[key] = unit;
        return unit;
    }

    def parse(
        source: str, path: str, program: JacProgram, annexes: list[tuple[str, str]]
    ) -> tuple[Module, bool] {
        unit = self.unit(source, path, annexes);
        syntax = copy.deepcopy(
            unit.syntax, {id(unit.syntax.mutation_permit): program.analysis.mutations}
        );
        assert isinstance(syntax, Module);

        program.errors_had.extend(copy.deepcopy(unit.errors));
        program.warnings_had.extend(copy.deepcopy(unit.warnings));
        return (syntax, unit.failed);
    }
}
