import gc;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.lsp.protocol.server { Workspace, Request }
import from jaclang.lsp.protocol.types { TextDocumentItem }
import from jaclang.lsp.server.engine { JacLangServer }
import from jaclang.lsp.server.scheduler { WorkQueue, WorkItem, WorkKind }

test "workspace indexing discovers unopened consumers and restores references without compiler trees" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        library = base / 'lib.jac';
        consumer = base / 'main.jac';
        library.write_text('def answer -> int { return 42; }\n');
        consumer.write_text(
            'import from .lib { answer }\ndef run -> int { return answer(); }\n'
        );
        excluded = base / 'node_modules';
        excluded.mkdir();
        (excluded / 'broken.jac').write_text('invalid source');
        server = JacLangServer();
        server.work.stop();
        server.worker.join();
        server.work = WorkQueue();
        server._workspace = Workspace(root_uri=base.as_uri());
        try {
            server.module_manager.budget.max_nodes = 0;
            server.start_indexing();
            visited: list[str] = [];
            while server.work.pending {
                item = server.work.take();
                assert isinstance(item, WorkItem);
                if item.kind == WorkKind.SCAN {
                    server._scan_workspace(item.uri);
                } else {
                    assert item.kind == WorkKind.INDEX;
                    visited.append(item.uri);
                    server._index_file(item);
                }
                server.module_manager.trim();
                server.work.finish(item);
            }
            assert set(visited) == {library.as_uri(), consumer.as_uri()};
            assert server.work.peak_pending <= 2;
            assert not server.diagnostics and not server.sem_managers;
            assert not server.module_manager.products;
            assert server.get_workspace_symbols('answer')[0].location.uri
                == library.as_uri();
            assert server.program.transitive_dependents(str(library))
                == {str(consumer)};
            gc.collect();
            assert server.program.analysis_cache_usage() == (0, 0);

            restored = JacLangServer();
            restored.work.stop();
            restored.worker.join();
            restored._workspace = Workspace(root_uri=base.as_uri());
            try {
                with patch.object(
                    restored.program,
                    'compile',
                    side_effect=AssertionError('cached index compiled source')
                ) {
                    assert restored.module_manager.indexer.load(str(library));
                    assert restored.module_manager.indexer.load(str(consumer));
                }
                assert restored.program.analysis_cache_usage() == (0, 0);
                assert restored.program.transitive_dependents(str(library))
                    == {str(consumer)};
                index = restored.module_manager.index;
                key = next(
                    key for shard in index.shards.values()
                    for (key, info) in shard.definitions.items()
                    if info.name == 'answer'
                );
                refs = index.references_for(key, restored.program.source_store);
                assert {ref.file for ref in refs} == {str(library), str(consumer)};
                library.write_text('def answer -> str { return "changed"; }\n');
                assert not restored.module_manager.indexer.load(str(consumer));
                assert not index.references_for(key, restored.program.source_store);
            } finally {
                restored.shutdown();
            }
        } finally {
            server.shutdown();
        }
    }
}

test "workspace indexing yields to checks and remains interruptible after a request burst" {
    work = WorkQueue(debounce=0.0);
    work.schedule('file:///workspace', WorkKind.SCAN);
    work.schedule('file:///main.jac');
    work.schedule('file:///main.jac', WorkKind.INDEX);
    checked = work.take();
    assert isinstance(checked, WorkItem) and checked.kind == WorkKind.CHECK;
    work.finish(checked);
    work.request_streak = work.request_burst;
    request = Request(1, 'textDocument/hover', {}, 0);
    assert work.submit(request);
    assert work.take() is request;
    work.finish(request);
    indexed = work.take();
    assert isinstance(indexed, WorkItem) and indexed.kind == WorkKind.SCAN;
    assert work.submit(Request(2, 'textDocument/hover', {}, 0));
    assert indexed.cancel_token.is_set();
    work.stop();
}

test "workspace indexing completes before rename while other requests stay responsive" {
    work = WorkQueue(debounce=0.0, request_limit=2);
    work.schedule('file:///lib.jac', WorkKind.INDEX);
    work.schedule('file:///edited.jac', WorkKind.CHECK);
    rename = Request(1, 'textDocument/rename', {}, 0);
    hover = Request(2, 'textDocument/hover', {}, 0);
    assert work.submit(rename, after_workspace=True);
    assert work.submit(hover);
    assert not work.submit(Request(3, 'textDocument/hover', {}, 0));
    assert work.take() is hover;
    work.finish(hover);
    checked = work.take();
    assert isinstance(checked, WorkItem) and checked.kind == WorkKind.CHECK;
    work.finish(checked);
    indexed = work.take();
    assert isinstance(indexed, WorkItem) and indexed.kind == WorkKind.INDEX;
    assert not indexed.cancel_token.is_set();
    work.finish(indexed);
    assert work.take() is rename;
    work.finish(rename);
    work.stop();
}

test "an open implementation annex schedules its compilation unit as editor work" {
    with TemporaryDirectory() as directory {
        base = Path(directory) / 'main.jac';
        annex = Path(directory) / 'main.impl.jac';
        base.write_text('def answer -> int;\n');
        annex.write_text('impl answer -> int { return 42; }\n');
        server = JacLangServer();
        server.work.stop();
        server.worker.join();
        server.work = WorkQueue();
        try {
            server.workspace.put_text_document(
                TextDocumentItem(uri=annex.as_uri(), text=annex.read_text(), version=1)
            );
            server._sync_sources(server.workspace.snapshot());
            assert server.work.pending[base.as_uri()].kind == WorkKind.CHECK;
            assert annex.as_uri() not in server.work.pending;
        } finally {
            server.shutdown();
        }
    }
}
