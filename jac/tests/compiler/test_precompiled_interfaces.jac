import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.jir { SEC_IFACE, read_section_bytes }
import from jaclang.dist.precompile_bytecode { precompile_unit }

test "precompiled modules carry their type interface on cold and cached builds" {
    with TemporaryDirectory() as directory {
        package = Path(directory) / "library";
        package.mkdir();
        (package / "__init__.jac").write_text("");
        source = package / "api.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        for _attempt in range(2) {
            data = precompile_unit(str(source), str(package), collect=False);
            assert data is not None , "precompilation produced no artifact";
            assert read_section_bytes(data, SEC_IFACE) is not None , (
                "precompilation discarded the dependency's type interface"
            );
        }
    }
}
