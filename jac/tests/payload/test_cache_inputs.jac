"""Build cache identities describe committed inputs, never restored outputs."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import subprocess;

glob CACHE_KEYS = Path(__file__).resolve().parents[3]
         / "scripts/build_cache_keys.sh";

def _git(directory: Path, args: list[str]) {
    subprocess.run(
        [
            "git",
            "-c",
            "user.name=Cache test",
            "-c",
            "user.email=cache@example.invalid",
            "-c",
            "core.hooksPath=/dev/null"
        ]
            + args,
        cwd=str(directory),
        check=True,
        capture_output=True
    );
}

def _keys(directory: Path) -> dict[str, str] {
    result = subprocess.run(
        ["bash", str(CACHE_KEYS)],
        cwd=str(directory),
        check=True,
        capture_output=True,
        text=True
    );
    return dict(line.split("=", 1) for line in result.stdout.splitlines());
}

test "restored artifacts and dirty generated files cannot change checkout keys" {
    with TemporaryDirectory() as directory {
        checkout = Path(directory);
        compiler = checkout / "jac/jaclang/compiler";
        compiler.mkdir(parents=True);
        source = compiler / "example.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        _git(checkout, ["init", "--quiet"]);
        _git(checkout, ["add", "."]);
        _git(checkout, ["commit", "--quiet", "-m", "source"]);
        before = _keys(checkout);
        assert len(before) == 5;
        (compiler / "libjac_compiler.so").write_bytes(b"restored kernel");
        (compiler / "generated.py").write_text("restored = True\n");
        source.write_text("generated overwrite\n");
        assert _keys(checkout) == before;
        _git(checkout, ["checkout", "--", str(source)]);
        assert _keys(checkout) == before;
        source.write_text("def answer() -> int { return 43; }\n");
        _git(checkout, ["add", str(source)]);
        _git(checkout, ["commit", "--quiet", "-m", "compiler change"]);
        changed = _keys(checkout);
        for name in ("binary", "package", "python", "compiler") {
            assert changed[name] != before[name] , name;
        }
        assert changed["layers"] == before["layers"];
        _git(checkout, ["mv", str(source), str(compiler / "renamed.jac")]);
        _git(checkout, ["commit", "--quiet", "-m", "rename"]);
        assert _keys(checkout)["compiler"] != changed["compiler"];
        project = checkout / "jac/jaclang/project/source.jac";
        project.parent.mkdir();
        project.write_text("def read_source() -> str { return 'first'; }\n");
        _git(checkout, ["add", str(project)]);
        _git(checkout, ["commit", "--quiet", "-m", "project source services"]);
        before_project = _keys(checkout);
        project.write_text("def read_source() -> str { return 'changed'; }\n");
        _git(checkout, ["add", str(project)]);
        _git(checkout, ["commit", "--quiet", "-m", "source reader change"]);
        assert _keys(checkout)["compiler"] != before_project["compiler"];
    }
}

test "payload producer changes invalidate dependency snapshots" {
    with TemporaryDirectory() as directory {
        checkout = Path(directory);
        source = checkout / "jac/jaclang/dist/precompile_bytecode.jac";
        source.parent.mkdir(parents=True);
        source.write_text("with entry {}\n");
        producer = source.parent / "payload/assemble.jac";
        producer.parent.mkdir();
        producer.write_text("with entry {}\n");
        _git(checkout, ["init", "--quiet"]);
        _git(checkout, ["add", "."]);
        _git(checkout, ["commit", "--quiet", "-m", "source"]);
        before = _keys(checkout);
        producer.write_text("with entry { print(1); }\n");
        _git(checkout, ["add", str(producer)]);
        _git(checkout, ["commit", "--quiet", "-m", "producer change"]);
        after = _keys(checkout);
        assert after["layers"] != before["layers"];
        assert after["binary"] != before["binary"];
        assert after["compiler"] == before["compiler"];
    }
}
