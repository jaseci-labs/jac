"""Editor products have no ownership of compiler graphs."""
import gc;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.lsp.server.engine { JacLangServer }
import from jaclang.lsp.protocol.server { Request }
import from io { BytesIO }
import jaclang.lsp.protocol.types as lspt;

test "cached outlines and tokens survive compiler graph release" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        path.write_text('def answer -> int { return 42; }\n');
        server = JacLangServer();
        try {
            assert server.type_check_file(path.as_uri());
            outline = server.get_outline(path.as_uri());
            tokens = server.get_semantic_tokens(path.as_uri()).data;
            assert outline and tokens;
            module = server.sem_managers[str(path)].ir;
            reference = weakref.ref(module);
            del module;
            server.sem_managers.clear();
            server.program.release_compile_closure();
            gc.collect();
            assert reference() is None , 'editor products retained a compiler tree';
            assert server.get_outline(path.as_uri()) == outline;
            assert server.get_semantic_tokens(path.as_uri()).data == tokens;
        } finally {
            server.shutdown();
        }
    }
}

test "invalidating a compilation unit drops all annex products" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        annex = Path(directory) / 'main.impl.jac';
        path.write_text('def answer -> int;\n');
        annex.write_text('impl answer -> int { return 42; }\n');
        server = JacLangServer();
        try {
            assert server.type_check_file(path.as_uri());
            assert set(server.module_manager.products) == {str(path), str(annex)};
            server.module_manager.invalidate(str(path));
            assert not server.module_manager.products and not server.sem_managers;
        } finally {
            server.shutdown();
        }
    }
}

test "a disk dependency changed during analysis cannot publish a result" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        library = Path(directory) / 'lib.jac';
        library.write_text('obj Foo { has x: int; }\n');
        path.write_text('import from .lib { Foo }\nwith entry { f = Foo(x=1); }\n');
        server = JacLangServer();
        server.work.stop();
        original = server.program.compile;
        def concurrent_change(*args: any, **kwargs: any) -> any {
            result = original(*args, **kwargs);
            library.write_text('obj Foo { has y: str; }\n');
            return result;
        }
        try {
            before = server.workspace.revision;
            with patch.object(
                server.program, 'compile', side_effect=concurrent_change
            ) {
                assert not server.type_check_file(path.as_uri());
            }
            assert not server.diagnostics and not server.module_manager.products;
            assert server.program.find_module(str(path)) is None;
            assert server.workspace.revision > before;
            assert server.program.source_store.snapshot is None;
            assert server.type_check_file(path.as_uri());
            assert server.diagnostics[path.as_uri()];
        } finally {
            server.shutdown();
        }
    }
}

test "lazy queries validate cached compiler inputs before publishing" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        library = Path(directory) / 'lib.jac';
        library.write_text('obj Foo { has x: int; }\n');
        path.write_text('import from .lib { Foo }\nwith entry { f = Foo(x=1); }\n');
        server = JacLangServer();
        server.work.stop();
        server.worker.join();
        try {
            assert server.type_check_file(path.as_uri());
            output = BytesIO();
            server._transport_writer = output;
            def change_during_query(ls: any, params: any) -> any {
                library.write_text('obj Foo { has y: str; }\n');
                return {'value': 42};
            }
            server._features['probe'] = change_during_query;
            request = Request(
                1,
                'probe',
                {'textDocument': {'uri': path.as_uri()}},
                server.workspace.revision
            );
            server._requests[1] = request;
            server._run_query(request);
            response = server._read_message(BytesIO(output.getvalue()));
            assert response is not None and response['error']['code'] == -32801;
            assert server.program.find_module(str(path)) is None;
            assert server.program.source_store.snapshot is None;
            assert request.inputs_current is None;
        } finally {
            server.shutdown();
        }
    }
}

test "evicted compiler contexts keep navigation products and rebuild only for semantic queries" {
    with TemporaryDirectory() as directory {
        library = Path(directory) / 'lib.jac';
        consumer = Path(directory) / 'main.jac';
        library.write_text('def answer -> int { return 42; }\n');
        consumer.write_text(
            'import from .lib { answer }\ndef run -> int { return answer(); }\n'
        );
        server = JacLangServer();
        server.work.stop();
        server.worker.join();
        try {
            server.module_manager.budget.max_contexts = 1;
            assert server.type_check_file(library.as_uri());
            module = server.sem_managers[str(library)].ir;
            reference = weakref.ref(module);
            del module;
            assert server.type_check_file(consumer.as_uri());
            server.module_manager.trim();
            gc.collect();
            assert reference() is None;
            assert str(library) not in server.sem_managers;
            assert server.get_outline(library.as_uri());
            assert server.get_semantic_tokens(library.as_uri()).data;
            request = Request(
                1,
                lspt.TEXT_DOCUMENT_DOCUMENT_SYMBOL,
                {'textDocument': {'uri': library.as_uri()}},
                server.workspace.revision
            );
            with patch.object(
                server,
                'type_check_file',
                side_effect=AssertionError('outline recompiled an evicted tree')
            ) {
                server._ensure_query(request);
            }
            refs = server.get_references(consumer.as_uri(), lspt.Position(1, 27));
            assert {ref.uri for ref in refs} == {library.as_uri(), consumer.as_uri()} , str(
                refs
            );
            uses = server.get_references(
                consumer.as_uri(), lspt.Position(1, 27), False
            );
            assert uses and all(ref.uri == consumer.as_uri() for ref in uses) , str(
                uses
            );
            request = Request(
                2,
                lspt.TEXT_DOCUMENT_HOVER,
                {'textDocument': {'uri': library.as_uri()}},
                server.workspace.revision
            );
            with patch.object(server, 'log_error') as errors {
                server._ensure_query(request);
                assert not errors.called , str(errors.call_args_list);
            }
            assert str(library) in server.sem_managers , (
                f'{request.method} {request.params}, query revision {request.revision}, workspace {server.workspace.revision}, '
                f'cancelled {request.cancel_token.is_set()}, responded {request.responded}'
            );
        } finally {
            server.shutdown();
        }
    }
}
