"""Cache publication is atomic and merges products under one persistent lock."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from concurrent.futures { ThreadPoolExecutor }
import from jaclang.jac0core.cache_paths { FileLock, atomic_write }
import from jaclang.compiler.driver.jir {
    get_module_cache_path,
    is_module_cache_valid,
    module_source_key,
    read_section_bytes,
    write_module_cache,
    SEC_BYTECODE,
    SEC_DEPS,
    SEC_DIAG,
    SEC_IFACE
}

test "publication rejects products from a displaced source revision" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "revision.jac";
        source.write_text("def answer() -> int { return 41; }\n");
        revision = module_source_key(str(source));
        assert write_module_cache(str(source), b"first", expected_source_key=revision);
        source.write_text("def answer() -> int { return 42; }\n");
        assert not write_module_cache(
            str(source), b"stale", expected_source_key=revision
        );
        cache = get_module_cache_path(str(source));
        assert not is_module_cache_valid(str(source), cache);
        revision = module_source_key(str(source));
        assert write_module_cache(
            str(source), b"current", expected_source_key=revision
        );
        assert read_section_bytes(cache.read_bytes(), SEC_BYTECODE) == b"current";
    }
}

test "changing dependency revisions cannot relabel older executable products" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "consumer.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        path = str(source);
        assert write_module_cache(
            path,
            b"old code",
            {SEC_DEPS: b"first dependencies", SEC_DIAG: b"old verdict"}
        );
        assert write_module_cache(
            path, None, {SEC_DEPS: b"new dependencies", SEC_IFACE: b"new interface"}
        );
        data = get_module_cache_path(path).read_bytes();
        assert read_section_bytes(data, SEC_BYTECODE) is None;
        assert read_section_bytes(data, SEC_DIAG) is None;
        assert read_section_bytes(data, SEC_IFACE) == b"new interface";
        assert write_module_cache(path, b"new code");
        assert read_section_bytes(get_module_cache_path(path).read_bytes(), SEC_IFACE)
            == b"new interface";
    }
}

test "concurrent product writers retain both complete products" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "example.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        path = str(source);
        with ThreadPoolExecutor(max_workers=2) as pool {
            bytecode = pool.submit(write_module_cache, path, b"bytecode");
            interface = pool.submit(
                write_module_cache, path, None, {SEC_IFACE: b"interface"}
            );
            assert bytecode.result(timeout=20);
            assert interface.result(timeout=20);
        }
        cache = get_module_cache_path(path);
        data = cache.read_bytes();
        assert read_section_bytes(data, SEC_BYTECODE) == b"bytecode";
        assert read_section_bytes(data, SEC_IFACE) == b"interface";
        assert is_module_cache_valid(path, cache);
        original = source.stat();
        source.write_text("def answer() -> int { return 43; }\n");
        os.utime(path, ns=(original.st_atime_ns, original.st_mtime_ns));
        assert not is_module_cache_valid(path, cache);
        assert write_module_cache(path, b"new bytecode");
        assert read_section_bytes(cache.read_bytes(), SEC_IFACE) is None;
        annex = Path(directory) / "example.impl.jac";
        annex.write_text("impl answer { return 44; }\n");
        assert write_module_cache(path, b"annex bytecode");
        assert is_module_cache_valid(path, cache);
        annex.unlink();
        assert not is_module_cache_valid(path, cache);
    }
}

test "atomic replacement preserves permissions and open reader contents" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / "artifact";
        atomic_write(path, b"old", mode=0o644);
        with path.open("rb") as reader {
            atomic_write(path, b"new");
            assert reader.read() == b"old";
            assert path.read_bytes() == b"new";
        }
        if os.name != "nt" {
            assert path.stat().st_mode & 0o777 == 0o644;
        }
        assert len(list(Path(directory).iterdir())) == 1;
    }
}

test "lock timeout releases its descriptor and the lock remains reusable" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / "artifact.lock";
        contender = FileLock(path, timeout=0.0);
        with FileLock(path) {
            failed = False;
            try {
                contender.acquire();
            } except TimeoutError {
                failed = True;
            }
            assert failed;
        }
        with contender {
            assert path.exists();
        }
        assert contender.handle == -1;
    }
}
