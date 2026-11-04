"""Cache entries the native kernel produces are keyed on that kernel's identity
and on the exact bytes that were compiled."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.backends.native { kernel_resolve }
import from jaclang.compiler.driver.jir {
    SEC_PRODUCER,
    begin_prepare_memo,
    compiled_content_reads,
    end_prepare_memo,
    get_module_cache_path,
    is_module_cache_valid,
    kernel_producer,
    module_cache_key,
    pin_content_reads,
    set_kernel_producer,
    write_module_cache
}
import from jaclang.compiler.frontend.kernel_analyze { AnalysisReport }
import from jaclang.project.compiler_host { _native_scan_path }
import from jaclang.project.kernel_check { _record_outcome, _replayed_outcome }
import from jaclang.project.textio { read_file_with_encoding }

glob JAC_TOML: str = "[project]\nname = \"probe\"\nversion = \"0.1.0\"\nentry-point = \"main\"\n",
     CLEAN: str = "with entry {\n    print(1);\n}\n",
     EDITED: str = "with entry {\n    print(2);\n}\n";

def make_project(workdir: str) -> str {
    Path(workdir, "jac.toml").write_text(JAC_TOML);
    source = os.path.join(workdir, "main.jac");
    Path(source).write_text(CLEAN);
    return source;
}

def as_kernel(ident: str) {
    setattr(kernel_resolve, "kernel_identity", lambda -> str { return ident; });
}

test "a kernel check record written under one kernel is not replayed under another" {
    original = kernel_resolve.kernel_identity;
    with TemporaryDirectory() as workdir {
        source = make_project(workdir);
        records = os.path.join(workdir, "records");
        os.makedirs(records);
        record = os.path.join(records, "main.check.json");
        try {
            as_kernel("kernel-A");
            _record_outcome(record, source, AnalysisReport(entry_path=source));
            assert os.path.isfile(record);
            assert _replayed_outcome(record, source) is not None;
            as_kernel("kernel-B");
            assert _replayed_outcome(record, source) is None;
        } finally {
            setattr(kernel_resolve, "kernel_identity", original);
        }
    }
}

test "a native scan record is stored per producing kernel" {
    original = kernel_resolve.kernel_identity;
    with TemporaryDirectory() as workdir {
        source = make_project(workdir);
        try {
            as_kernel("kernel-A");
            under_a = _native_scan_path(source, "digest");
            as_kernel("kernel-B");
            under_b = _native_scan_path(source, "digest");
            assert under_a != under_b;
        } finally {
            setattr(kernel_resolve, "kernel_identity", original);
        }
    }
}

test "a module a kernel compiled is not served under another kernel" {
    previous = kernel_producer();
    with TemporaryDirectory() as workdir {
        source = make_project(workdir);
        cache = get_module_cache_path(source);
        try {
            set_kernel_producer("kernel-A");
            assert write_module_cache(
                source, b"bytecode", extra_sections={SEC_PRODUCER: b"kernel-A"}
            );
            assert is_module_cache_valid(source, cache);
            set_kernel_producer("kernel-B");
            assert not is_module_cache_valid(source, cache);
            assert write_module_cache(source, b"bytecode-floor");
            assert is_module_cache_valid(source, cache);
            set_kernel_producer("kernel-A");
            assert is_module_cache_valid(source, cache);
        } finally {
            set_kernel_producer(previous);
        }
    }
}

test "an edit between the key read and the parse never keys the product as the clean source" {
    with TemporaryDirectory() as workdir {
        source = make_project(workdir);
        clean_key = module_cache_key(source);
        memo = begin_prepare_memo();
        try {
            pin_content_reads();
            assert module_cache_key(source) == clean_key;
            Path(source).write_text(EDITED);
            parsed = read_file_with_encoding(source, compiled_content_reads());
            assert parsed == EDITED;
            stored_key = module_cache_key(source);
        } finally {
            end_prepare_memo(memo);
        }
        assert stored_key != clean_key;
        Path(source).write_text(CLEAN);
        assert module_cache_key(source) == clean_key;
        assert module_cache_key(source) != stored_key;
    }
}
