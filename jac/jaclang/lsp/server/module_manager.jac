import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compilation_context {
    AnalysisCacheBudget,
    InputManifest,
    SourceStore
}
import from jaclang.compiler.tools.symbol_index { IndexShard, SymbolIndex }
import from jaclang.compiler.tools.workspace_index { WorkspaceIndexer }
import from .sem_manager { SemTokManager }
import from .source_view { SourceView }
import jaclang.lsp.protocol.types as lspt;

obj DocumentProducts {
    has unit_path: str,
        inputs: InputManifest | None,
        semantic_tokens: list[int],
        outline: list[lspt.DocumentSymbol] | None = None,
        index_shards: tuple[IndexShard, ...] = ();

    def is_current(store: SourceStore) -> bool {
        if self.index_shards {
            return all(shard.inputs.is_current(store) for shard in self.index_shards);
        }
        return self.inputs is not None and self.inputs.is_current(store);
    }
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
    def has_current_analysis(path: str) -> bool {
        products = self.products.get(path);
        return products is not None and bool(products.index_shards)
            and products.is_current(self.program.source_store);
    }

    def invalidate(path: str, retain_products: bool = False) {
        if retain_products {
            import from jaclang.lsp.server.utils { get_symbols_for_outline }
            for (file, manager) in self.sem_managers.items() {
                products = self.products.get(file);
                if products is not None and products.unit_path == path
                    and products.outline is None {
                    products.outline = get_symbols_for_outline(manager.ir.sym_tab, file);
                }
            }
        }
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
