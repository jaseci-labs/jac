"""Metadata refreshes must not make obsolete executable sections look fresh."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.jir {
    SEC_BYTECODE,
    SEC_NATIVE_OBJ,
    SEC_LLVM_IR,
    SEC_INTEROP,
    SEC_CTDEPS,
    SEC_IFACE,
    ct_deps_section,
    ct_deps_fresh,
    write_module_cache,
    get_module_cache_path,
    read_section_bytes
}

obj CacheFixture {
    has source: Path,
        dep: Path;

    def seed {
        self.source.write_text("import from .dep { value }\n");
        self.dep.write_text("def value() -> int { return 1; }\n");
        write_module_cache(
            str(self.source),
            b"old bytecode",
            extra_sections={
                SEC_CTDEPS: self.metadata(),
                SEC_NATIVE_OBJ: b"old native bitcode",
                SEC_LLVM_IR: b"old LLVM",
                SEC_INTEROP: b"old interop",
                SEC_IFACE: b"valid interface"
            }
        );
    }

    def metadata -> bytes {
        return ct_deps_section([str(self.dep)], [str(self.dep)]);
    }

    def data -> bytes {
        return get_module_cache_path(str(self.source)).read_bytes();
    }
}

test "metadata refresh drops code and interop from stale dependencies" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        fixture.dep.write_text("def value() -> int { return 2; }\n");
        assert not ct_deps_fresh(fixture.data());
        write_module_cache(
            str(fixture.source), None, extra_sections={SEC_CTDEPS: fixture.metadata()}
        );
        assert ct_deps_fresh(fixture.data());
        for kind in [SEC_BYTECODE, SEC_NATIVE_OBJ, SEC_LLVM_IR, SEC_INTEROP] {
            assert read_section_bytes(fixture.data(), kind) is None;
        }
    }
}

test "unchanged dependency metadata preserves executable sections without rewriting" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        before = fixture.data();
        assert not write_module_cache(
            str(fixture.source), None, extra_sections={SEC_CTDEPS: fixture.metadata()}
        );
        assert fixture.data() == before;
    }
}

test "changed dependency provenance invalidates old code even when old inputs are fresh" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        assert ct_deps_fresh(fixture.data());
        write_module_cache(str(fixture.source), None, extra_sections={SEC_CTDEPS: b""});
        assert read_section_bytes(fixture.data(), SEC_NATIVE_OBJ) is None;
    }
}

test "a fresh compile can replace stale code and metadata together" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        fixture.dep.write_text("def value() -> int { return 2; }\n");
        write_module_cache(
            str(fixture.source),
            b"new bytecode",
            extra_sections={
                SEC_CTDEPS: fixture.metadata(),
                SEC_NATIVE_OBJ: b"new bitcode"
            }
        );
        assert ct_deps_fresh(fixture.data());
        assert read_section_bytes(fixture.data(), SEC_BYTECODE) == b"new bytecode";
        assert read_section_bytes(fixture.data(), SEC_NATIVE_OBJ) == b"new bitcode";
        assert read_section_bytes(fixture.data(), SEC_INTEROP) is None;
    }
}

test "metadata refresh cannot pair native code with a different library manifest" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        write_module_cache(
            str(fixture.source),
            None,
            extra_sections={
                SEC_CTDEPS: fixture.metadata(),
                SEC_INTEROP: b"empty interop"
            }
        );
        for kind in [SEC_BYTECODE, SEC_NATIVE_OBJ, SEC_LLVM_IR] {
            assert read_section_bytes(fixture.data(), kind) is None;
        }
        assert read_section_bytes(fixture.data(), SEC_INTEROP) == b"empty interop";
        assert read_section_bytes(fixture.data(), SEC_IFACE) == b"valid interface";
    }
}

test "unchanged library manifest preserves native code" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        before = fixture.data();
        assert not write_module_cache(
            str(fixture.source), None, extra_sections={SEC_INTEROP: b"old interop"}
        );
        assert fixture.data() == before;
    }
}

test "replacing native code drops the other cached representation" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        write_module_cache(
            str(fixture.source), None, extra_sections={SEC_LLVM_IR: b"new LLVM"}
        );
        assert read_section_bytes(fixture.data(), SEC_NATIVE_OBJ) is None;
        assert read_section_bytes(fixture.data(), SEC_LLVM_IR) == b"new LLVM";
        assert read_section_bytes(fixture.data(), SEC_INTEROP) == b"old interop";
        write_module_cache(
            str(fixture.source), None, extra_sections={SEC_NATIVE_OBJ: b"new bitcode"}
        );
        assert read_section_bytes(fixture.data(), SEC_LLVM_IR) is None;
        assert read_section_bytes(fixture.data(), SEC_NATIVE_OBJ) == b"new bitcode";
    }
}


test "a write with stale dependencies removes code even without new metadata" {
    with TemporaryDirectory() as directory {
        fixture = CacheFixture(
            source=Path(directory) / "main.jac", dep=Path(directory) / "dep.jac"
        );
        fixture.seed();
        fixture.dep.write_text("def value() -> int { return 2; }\n");
        assert write_module_cache(str(fixture.source), None);
        assert read_section_bytes(fixture.data(), SEC_NATIVE_OBJ) is None;
    }
}
