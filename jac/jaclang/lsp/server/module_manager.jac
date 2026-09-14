import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compilation_context {
    AnalysisCacheBudget,
    InputManifest
}
import from jaclang.compiler.tools.symbol_index { SymbolIndex }
import from jaclang.compiler.tools.workspace_index { WorkspaceIndexer }
import from .sem_manager { SemTokManager }
import from .source_view { SourceView }
import jaclang.lsp.protocol.types as lspt;

obj DocumentProducts {
    has unit_path: str,
        inputs: InputManifest | None,
        semantic_tokens: list[int],
        outline: list[lspt.DocumentSymbol] | None = None;
}

obj ModuleManager {
    has program: JacProgram,
        sem_managers: dict[str, SemTokManager],
        source_views: dict[str, SourceView] = {},
        products: dict[str, DocumentProducts] = {},
        completions: dict[int, list[lspt.CompletionItem]] = {},
        index: SymbolIndex = SymbolIndex(),
        indexer: WorkspaceIndexer postinit,
        budget: AnalysisCacheBudget = AnalysisCacheBudget();

    def postinit {
        self.indexer = WorkspaceIndexer(self.program, self.index);
    }

    def trim -> None;
    def invalidate(path: str) {
        self.program.invalidate_module(path);
        self.program.drop_module_alerts(path);
        self.completions.clear();
        affected = [
            file
            for (file, manager) in self.sem_managers.items()
            if file == path or manager.ir.loc.mod_path == path
        ];
        for file in affected {
            self.sem_managers.pop(file, None);
            self.products.pop(file, None);
        }
        self.products.pop(path, None);
        for file in list(self.products) {
            if self.products[file].unit_path == path {
                self.products.pop(file);
            }
        }
    }

    def forget(path: str) {
        self.invalidate(path);
        self.source_views.pop(path, None);
    }

    def source_view(path: str, source: str) -> SourceView {
        previous = self.source_views.get(path);
        if previous is None or previous.source != source {
            previous = SourceView(source, path);
            self.source_views[path] = previous;
        }
        return previous;
    }

    def update(
        file_path: str,
        build: uni.Module,
        update_annexed: bool = True,
        files: (list[str] | None) = None
    ) -> None;

    def clear_alerts_for_file(file_path_fs: str) -> None;
}
