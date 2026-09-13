import hashlib;
import json;
import os;
import shutil;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.types.stubcat.locate { catalog_key }
import jaclang.compiler.types.stubcat.build as builder;

test "catalog identity covers parser logic and actual stubs across package roots" {
    with TemporaryDirectory() as directory {
        first = Path(directory) / "first";
        parser = first / "compiler/frontend/parser/example.jac";
        parser.parent.mkdir(parents=True);
        parser.write_text("parser one");
        stub = first / "vendor/typeshed/stdlib/example.pyi";
        stub.parent.mkdir(parents=True);
        stub.write_text("def value() -> int: ...\n");
        original = catalog_key(str(first));
        second = Path(directory) / "second";
        shutil.copytree(first, second);
        assert catalog_key(str(second)) == original;
        parser.write_text("parser two");
        assert catalog_key(str(first)) != original;
        assert catalog_key(str(second)) == original;
        before = stub.stat();
        stub.write_text("def value() -> str: ...\n");
        os.utime(stub, ns=(before.st_atime_ns, before.st_mtime_ns));
        parser.write_text("parser one");
        assert catalog_key(str(first)) != original;
        stub.unlink();
        assert catalog_key(str(first)) != original;
    }
}

test "only complete validated catalogs satisfy the requested module selection" {
    with TemporaryDirectory() as directory {
        output = Path(directory) / "catalog.bin";
        calls: list[list[str] | None] = [];
        def produce(*args: any) -> dict[str, any] {
            only = args[2];
            key = args[6];
            calls.append(only);
            data = b"catalog bytes";
            output.write_bytes(data);
            manifest = {
                "key": key,
                "selection": sorted(only) if only is not None else None,
                "sha256": hashlib.sha256(data).hexdigest(),
                "reused": False
            };
            Path(str(output) + ".json").write_text(json.dumps(manifest));
            return manifest;
        }
        with patch.object(builder, "_build_catalog_inner", side_effect=produce) {
            assert not builder.build_catalog(
                str(output), only=["math"], pkg_dir=directory
            )["reused"];
            assert builder.build_catalog(str(output), only=["math"], pkg_dir=directory)[
                "reused"
            ];
            assert len(calls) == 1;
            assert not builder.build_catalog(str(output), pkg_dir=directory)["reused"];
            assert len(calls) == 2;
            output.write_bytes(b"damaged catalog");
            assert not builder.build_catalog(str(output), pkg_dir=directory)["reused"];
            assert len(calls) == 3;
        }
    }
}
