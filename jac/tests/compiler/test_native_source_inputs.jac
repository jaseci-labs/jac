import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compilation_context { SourceStore }
import from jaclang.compiler.placement.placement_solver {
    _native_dep_scan,
    native_scan_memo_clear
}

test "native placement scans reject changed contents with identical file metadata" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        clean = 'glob value = 1;'.ljust(64) + '\n';
        server = '::py::value = 1::py::'.ljust(64) + '\n';
        path.write_text(clean);
        original = path.stat();
        native_scan_memo_clear();
        assert _native_dep_scan(str(path)) == ('', []);
        path.write_text(server);
        os.utime(path, ns=(original.st_atime_ns, original.st_mtime_ns));
        assert path.stat().st_size == original.st_size;
        assert path.stat().st_mtime_ns == original.st_mtime_ns;
        result = _native_dep_scan(str(path));
        assert result is not None and result[0] == 'contains PyInlineCode' , str(
            result
        );
    }
}

test "native placement scans include newly created unsaved annexes in their source capture" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'main.jac';
        annex = Path(directory) / 'main.impl.jac';
        path.write_text('glob value = 1;\n');
        store = SourceStore();
        native_scan_memo_clear();
        assert _native_dep_scan(str(path)) == ('', []);
        store.set_overrides({str(annex): '::py::value = 1::py::\n'});
        with store.capture() as inputs {
            result = _native_dep_scan(str(path));
            assert result is not None and result[0] == 'contains PyInlineCode' , str(
                result
            );
            assert inputs.annex_paths[str(path)] == [str(annex)];
            assert inputs.is_current(store);
            store.set_overrides({});
            assert not inputs.is_current(store);
        }
        assert not annex.exists();
        assert _native_dep_scan(str(path)) == ('', []);
    }
}
