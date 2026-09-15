import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.inputs { SourceStore }
import from jaclang.compiler.driver.analysis_service { AnalysisRecord }
import from .sem_manager { SemTokManager }
import from .source_view { SourceView }
import jaclang.lsp.protocol.types as lspt;

obj DocumentProducts {
    has unit_path: str,
        analysis: AnalysisRecord,
        semantic_tokens: list[int],
        outline: list[lspt.DocumentSymbol];

    def is_current(store: SourceStore) -> bool {
        return self.analysis.is_current(store);
    }
}

obj EditorCacheBudget {
    has max_source_views: int = 64,
        max_source_chars: int = 4000000,
        max_completion_items: int = 20000;
}

obj ModuleManager {
    has program: JacProgram,
        sem_managers: dict[str, SemTokManager],
        source_views: dict[str, SourceView] = {},
        products: dict[str, DocumentProducts] = {},
        completions: dict[int, list[lspt.CompletionItem]] = {},
        editor_budget: EditorCacheBudget = EditorCacheBudget();

    def trim -> None;
    def trim_editor_caches {
        chars = sum(len(view.source) for view in self.source_views.values());
        while self.source_views
            and (
                len(self.source_views) > self.editor_budget.max_source_views
                or chars > self.editor_budget.max_source_chars
            ) {
            oldest_source = next(iter(self.source_views));
            chars -= len(self.source_views.pop(oldest_source).source);
        }
        count = sum(len(items) for items in self.completions.values());
        while self.completions and count > self.editor_budget.max_completion_items {
            oldest_completion = next(iter(self.completions));
            count -= len(self.completions.pop(oldest_completion));
        }
    }

    def has_current_analysis(path: str) -> bool {
        document_products = self.products.get(path);
        return document_products is not None
            and bool(document_products.analysis.shards)
            and document_products.is_current(self.program.source_store);
    }

    def changed_inputs(path: str) -> set[str] {
        document_products = self.products.get(path);
        if document_products is None {
            return set();
        }
        return document_products.analysis.changed_inputs(self.program.source_store);
    }

    def invalidate(path: str, retain_products: bool = False) {
        self.completions.clear();
        affected = [
            file
            for (file, manager) in self.sem_managers.items()
            if file == path or manager.ir.loc.mod_path == path
        ];
        for file in affected {
            self.sem_managers.pop(file, None);
            if not retain_products {
                self.products.pop(file, None);
            }
        }
        if retain_products {
            return;
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
        previous = self.source_views.pop(path, None);
        if previous is None or previous.source != source {
            previous = SourceView(source, path);
        }
        self.source_views[path] = previous;
        self.trim_editor_caches();
        return previous;
    }

    def update(
        file_path: str,
        build: uni.Module,
        analysis: AnalysisRecord,
        files: (list[str] | None) = None
    ) -> None;
}
