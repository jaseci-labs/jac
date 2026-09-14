import tempfile;
import shutil;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from bootstrap.compiler {
    compile_module,
    complete_image,
    exclude_native_python_sources,
    native_python_sources,
    module_cache_identity,
    image_codec,
    snapshot_sources
}

test "image completion accepts an empty build output and preserves occupied outputs" {
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        source = workspace / "source";
        package = source / "jaclang";
        package.mkdir(parents=True);
        shutil.copyfile(Path(JAC_ROOT) / "jaclang/image.py", package / "image.py");
        codec = image_codec(str(package));
        precompiled = package / "_precompiled";
        precompiled.mkdir();
        codec.write_compiler_manifest(
            precompiled,
            {
                "package": "jaclang",
                "python_tag": codec.python_tag(),
                "modules": {},
                "payloads": {},
                "producer_digest": "test-producer"
            }
        );
        catalog = workspace / "stubcat.bin";
        catalog.write_bytes(b"test-catalog");
        output = workspace / "output";
        output.mkdir();
        complete_image(source, catalog, output);
        assert (output / "jaclang/_precompiled/stubcat.bin").read_bytes()
            == b"test-catalog";
        completed = codec.load_image(output / "jaclang/_precompiled");
        assert completed is not None;
        completed.verify();
        with testraises(OSError) {
            complete_image(source, catalog, output);
        }
        assert (output / "jaclang/_precompiled/stubcat.bin").is_file();
    }
}

test "native build outputs do not invalidate compiler source artifacts" {
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        package = workspace / "source" / "jaclang";
        package.mkdir(parents=True);
        shutil.copyfile(Path(JAC_ROOT) / "jaclang/image.py", package / "image.py");
        (package.parent / "jac.toml").write_text(
            '[project]\nname = "jaclang"\nversion = "0.1.0"\n'
                + '[placement]\ndefault = "server"\n'
        );
        (package / "probe.jac").write_text("def answer -> int { return 42; }\n");
        (package / "config.json").write_text('{"mode": "first"}');
        cache = workspace / "cache";
        identities: list[str] = [];
        (package / "compiler").mkdir();
        for revision in range(2) {
            for extension in ("so", "dylib") {
                library = package / "compiler" / ("libjac_compiler." + extension);
                library.write_bytes(bytes([revision]));
                Path(str(library) + ".layout.json").write_text(
                    '{"revision": ' + str(revision) + '}'
                );
            }
            snapshot = workspace / str(revision) / "jaclang";
            snapshot_sources(package, snapshot);
            assert not list(snapshot.rglob("libjac_compiler.*"));
            identity = module_cache_identity(snapshot, "same-producer");
            identities.append(identity);
            result = compile_module(
                snapshot / "probe.jac",
                snapshot,
                workspace / (str(revision) + ".jir"),
                cache,
                identity
            );
            assert bool(result.get("cached")) == bool(revision);
        }
        assert identities[0] == identities[1];
        assert module_cache_identity(snapshot, "different-producer") != identity;
        (snapshot / "config.json").write_text('{"mode": "second"}');
        assert module_cache_identity(snapshot, "same-producer") != identity;
    }
}

test "compiler module cache follows dependency and source changes" {
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        package = workspace / "site" / "jaclang";
        snapshot_sources(Path(JAC_ROOT) / "jaclang", package);
        source = package / "probe.jac";
        dependency = package / "dependency.jac";
        dependency.write_text("def value -> int { return 7; }\n");
        source.write_text(
            "import from .dependency { value }\ndef answer -> int { return value(); }\n"
        );
        cache = workspace / "cache";
        output = workspace / "probe.jir";
        first = compile_module(source, package, output, cache, "test-producer");
        assert not first.get("cached", False);
        codec = image_codec(str(package));
        assert codec.read_section_bytes(output.read_bytes(), codec.SEC_IFACE) is None;
        assert codec.read_section_bytes(output.read_bytes(), codec.SEC_DIAG) is None;
        assert codec.read_section_bytes(output.read_bytes(), codec.SEC_CTDEPS)
            is not None;
        assert codec.read_section_bytes(output.read_bytes(), codec.SEC_BYTECODE)
            is not None;
        assert compile_module(source, package, output, cache, "test-producer").get(
            "cached"
        );
        dependency.write_text("def value -> int { return 8; }\n");
        assert not compile_module(source, package, output, cache, "test-producer").get(
            "cached", False
        );
        source.write_text("def answer -> int { return 9; }\n");
        assert not compile_module(source, package, output, cache, "test-producer").get(
            "cached", False
        );
        assert not compile_module(source, package, output, cache, "new-producer").get(
            "cached", False
        );
        (cache / "probe.jir").write_bytes(b"corrupt");
        assert not compile_module(source, package, output, cache, "new-producer").get(
            "cached", False
        );
    }
}

test "compiler bytecode does not depend on its staging directory" {
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        package = workspace / "first" / "jaclang";
        snapshot_sources(Path(JAC_ROOT) / "jaclang", package);
        source = package / "probe.jac";
        source.write_text("obj Record { def answer -> int; }\n");
        (package / "probe.impl.jac").write_text(
            "impl Record.answer -> int { return 42; }\n"
        );
        first = workspace / "first.jir";
        compile_module(source, package, first, identity="same-producer");
        relocated = workspace / "second" / "jaclang";
        shutil.copytree(package.parent, relocated.parent);
        second = workspace / "second.jir";
        compile_module(
            relocated / "probe.jac", relocated, second, identity="same-producer"
        );
        codec = image_codec(str(package));
        assert codec.read_section_bytes(first.read_bytes(), codec.SEC_BYTECODE)
            == codec.read_section_bytes(second.read_bytes(), codec.SEC_BYTECODE);
    }
}


test "the compiler image excludes native Python implementation sources and preserves its license" {
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        package = workspace / "source";
        snapshot = workspace / "image";
        for relative in native_python_sources() {
            (package / relative).mkdir(parents=True);
            (package / relative / "sample.jac").write_text(
                "def sample -> int { return 42; }\n"
            );
        }
        license_file = Path("runtime/python/LICENSE.cpython");
        (package / license_file).write_text("Python license");
        shutil.copytree(package, snapshot);
        exclude_native_python_sources(package, snapshot);
        assert (snapshot / license_file).read_text() == "Python license";
        assert not list(snapshot.rglob("*.jac"));
        assert list(package.rglob("*.jac"));
    }
}
