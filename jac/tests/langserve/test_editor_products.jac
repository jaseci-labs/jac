"""Editor products have no ownership of compiler graphs."""
import gc;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.lsp.server.engine { JacLangServer }

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
