"""Native consumers must invalidate when imported compile-time layouts change."""
import json;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }


def build_value(folder: Path, attempt: int) -> str {
    binary = folder / ("probe" + str(attempt));
    built = subprocess.run(
        jac_command("build", str(folder / "main.jac"), "--native", "-o", str(binary)),
        cwd=folder,
        capture_output=True,
        text=True,
        timeout=120
    );
    assert built.returncode == 0 , built.stdout + built.stderr;
    result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=10);
    assert result.returncode == 0 , result.stdout + result.stderr;
    return result.stdout.strip();
}


def check_layout_edit(kind: str, inherited: bool = False) {
    with tempfile.TemporaryDirectory(prefix="jac-layout-cache-") as directory {
        folder = Path(directory);
        provider = folder / "record.jac";
        name = "Base" if inherited else "Record";
        provider.write_text(f"{kind} {name} {{ has value: int = 42; }}\n");
        if inherited {
            (folder / "derived.jac").write_text(
                "import from .record { Base }\nobj Record(Base) {}\n"
            );
        }
        imported = "derived" if inherited else "record";
        (folder / "reader.jac").write_text(
            f"import from .{imported} {{ Record }}\n"
            "def read(record: Record) -> int { return record.value; }\n"
        );
        (folder / "main.jac").write_text(
            f"import from .{imported} {{ Record }}\n"
            "import from .reader { read }\n"
            "with entry { print(read(Record(value=42))); }\n"
        );
        assert build_value(folder, 0) == "42";
        entries = list(folder.rglob("reader.*.ir_meta"));
        assert len(entries) == 1;
        cached = entries[0];
        stamp = cached.stat().st_mtime_ns;
        assert build_value(folder, 1) == "42";
        assert cached.stat().st_mtime_ns == stamp , "Unchanged reader should reuse its IR";
        provider.write_text(
            f"{kind} {name} {{ has padding: int = 99, value: int = 42; }}\n"
        );
        assert build_value(folder, 2) == "42" , "Reader used the old field offset";
        metadata = json.loads(cached.read_text());
        assert str(provider.resolve()) in metadata["ct_deps"];
        stamp = cached.stat().st_mtime_ns;
        assert build_value(folder, 3) == "42";
        assert cached.stat().st_mtime_ns == stamp;
    }
}


test "warm native object readers invalidate after a provider layout edit" {
    check_layout_edit("obj");
}


test "warm native node readers invalidate after a provider layout edit" {
    check_layout_edit("node");
}


test "warm native readers track transitive inherited layouts" {
    check_layout_edit("obj", inherited=True);
}


test "warm native consumers observe ordinary imported body changes" {
    with tempfile.TemporaryDirectory(prefix="jac-body-cache-") as directory {
        folder = Path(directory);
        provider = folder / "provider.jac";
        provider.write_text("def value() -> int { return 1; }\n");
        (folder / "main.jac").write_text(
            "import from .provider { value }\nwith entry { print(value()); }\n"
        );
        assert build_value(folder, 0) == "1";
        assert build_value(folder, 1) == "1";
        provider.write_text("def value() -> int { return 2; }\n");
        assert build_value(folder, 2) == "2";
        assert build_value(folder, 3) == "2";
    }
}
