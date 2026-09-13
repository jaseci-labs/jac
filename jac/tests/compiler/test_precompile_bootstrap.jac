"""Seed sealing extends the importer cache and preserves complete warm products."""

import marshal;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.dist.precompile_bootstrap as bootstrap;
import from jaclang.dist.precompile_bytecode {
    precompile_worker_init,
    precompile_worker_exit
}
import from jaclang.compiler.driver.jir {
    FLAG_BOOTSTRAP,
    SEC_BYTECODE,
    SEC_IFACE,
    compute_precompile_module_key,
    read_section_bytes,
    write_precompiled_jir
}

test "bootstrap sealing reuses complete products and extends bytecode-only artifacts" {
    with TemporaryDirectory() as directory {
        package_path = Path(directory) / "jaclang";
        package_path.mkdir();
        source = package_path / "example.jac";
        source.write_text("def answer() -> int;\n");
        annex = package_path / "example.impl.jac";
        annex.write_text("impl answer { return 42; }\n");
        output_dir = package_path
            / "_precompiled"
            / f"cpython-{sys.version_info.major}{sys.version_info.minor}";
        output = output_dir / "example.jir";
        with patch.object(bootstrap, "bootstrap_sources", return_value=[source]) {
            precompile_worker_init();
            try {
                cold: dict[str, int] = {};
                assert bootstrap.seal_bootstrap(package_path, output_dir, False, cold)
                    == 0;
                assert cold["compiled"] == 1;
                original = output.read_bytes();
                assert read_section_bytes(original, SEC_IFACE) is not None;
            } finally {
                precompile_worker_exit();
            }
            precompile_worker_init();
            try {
                warm: dict[str, int] = {};
                assert bootstrap.seal_bootstrap(package_path, output_dir, False, warm)
                    == 0;
                assert warm["reused"] == 1;
                assert warm["compiled"] == 0;
                assert output.read_bytes() == original;
                output.write_bytes(
                    write_precompiled_jir(
                        read_section_bytes(original, SEC_BYTECODE),
                        compute_precompile_module_key(str(source)),
                        FLAG_BOOTSTRAP
                    )
                );
                partial: dict[str, int] = {};
                assert bootstrap.seal_bootstrap(
                    package_path, output_dir, False, partial
                )
                    == 0;
                assert partial["bytecode_reused"] == 1;
                assert partial["compiled"] == 1;
                assert read_section_bytes(output.read_bytes(), SEC_IFACE) is not None;
                annex.write_text("impl answer { return 43; }\n");
                edited: dict[str, int] = {};
                assert bootstrap.seal_bootstrap(package_path, output_dir, True, edited)
                    == 0;
                assert edited["compiled"] == 1;
                assert edited["bytecode_reused"] == 0;
                code = marshal.loads(
                    read_section_bytes(output.read_bytes(), SEC_BYTECODE)
                );
                namespace: dict[str, any] = {};
                exec(code, namespace);
                assert namespace["answer"]() == 43;
            } finally {
                precompile_worker_exit();
            }
        }
    }
}
