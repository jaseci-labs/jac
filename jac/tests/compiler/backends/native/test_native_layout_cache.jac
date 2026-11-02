"""Native consumers must invalidate when imported compile-time layouts change."""
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }


def build_value(folder: Path, attempt: int, reused: bool = False) -> str {
    binary = folder / ("probe" + str(attempt));
    built = subprocess.run(
        jac_command("build", str(folder / "main.jac"), "--native", "-o", str(binary)),
        cwd=folder,
        capture_output=True,
        text=True,
        timeout=120
    );
    assert built.returncode == 0 , built.stdout + built.stderr;
    if reused {
        assert "Recompiled 0 unit(s)" in built.stdout + built.stderr , (
            "Unchanged builds should reuse every native unit: "
            + built.stdout
            + built.stderr
        );
    }
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
        assert build_value(folder, 1, reused=True) == "42";
        provider.write_text(
            f"{kind} {name} {{ has padding: int = 99, value: int = 42; }}\n"
        );
        assert build_value(folder, 2) == "42" , "Reader used the old field offset";
        assert build_value(folder, 3, reused=True) == "42";
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
        assert build_value(folder, 1, reused=True) == "1";
        provider.write_text("def value() -> int { return 2; }\n");
        assert build_value(folder, 2) == "2";
        assert build_value(folder, 3, reused=True) == "2";
    }
}
