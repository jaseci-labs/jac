"""Stage 0 and the kernel the host boots on (#10471 step 16).

`jac native build kernel` runs on the pinned previous release; every other
process boots on the published kernel, which must match the sources its record
names. These tests cover the pure-Python half: which command line is a
bootstrap, how a published kernel's record goes stale, and what the pin
refuses.
"""
import hashlib;
import json;
import os;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.jac0core.stage0 as stage0;

def _publish(root: Path, slot: Path, sources: list[Path]) {
    built = slot.parent / f".built.{slot.name}";
    built.parent.mkdir(parents=True, exist_ok=True);
    built.write_bytes(b"kernel bytes");
    stage0.write_build(
        str(built),
        hashlib.sha256(b"kernel bytes").hexdigest(),
        "x86_64-unknown-linux-gnu",
        [str(path) for path in sources]
    );
    stage0.publish(built, slot, "a test", root);
}

test "only the host kernel's plain build is a bootstrap" {
    assert stage0.requested_bootstrap(["jac", "native", "build", "kernel"]) is False;
    assert stage0.requested_bootstrap(["jac", "native", "build", "kernel", "--force"])
        is True;
    assert stage0.requested_bootstrap(
        ["jac", "native", "build", "kernel", "--target-spec", "s", "--output", "o"]
    )
        is None;
    assert stage0.requested_bootstrap(["jac", "native", "build", "kernel@linux-aarch64"])
        is None;
    assert stage0.requested_bootstrap(["jac", "run", "main.jac"]) is None;
}

test "a published kernel is current until a source it read changes" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        root = Path(tmp) / "jaclang";
        source = root / "compiler" / "unit.jac";
        source.parent.mkdir(parents=True);
        source.write_text("glob x: int = 1;\n");
        slot = stage0.slot_path(pkg=root);
        assert stage0.kernel_drift(slot, root) == [stage0.NOT_BUILT];
        _publish(root, slot, [source]);
        assert stage0.kernel_drift(slot, root) == [];
        record = stage0.read_record(slot);
        assert record is not None;
        assert list(record["inputs"]) == ["jaclang/compiler/unit.jac"];
        source.write_text("glob x: int = 2;\n");
        assert stage0.kernel_drift(slot, root) == ["jaclang/compiler/unit.jac changed"];
        source.unlink();
        assert stage0.kernel_drift(slot, root) == ["jaclang/compiler/unit.jac is gone"];
    }
}

test "a kernel that does not match its record's sha256 is not current" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        root = Path(tmp) / "jaclang";
        source = root / "compiler" / "unit.jac";
        source.parent.mkdir(parents=True);
        source.write_text("glob x: int = 1;\n");
        slot = stage0.slot_path(pkg=root);
        _publish(root, slot, [source]);
        slot.write_bytes(b"something else");
        assert stage0.kernel_drift(slot, root)
            == ["the kernel does not match the sha256 its record carries"];
    }
}

test "a checkout without a kernel stops the boot and names the command" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        slot = Path(tmp) / "compiler" / "_kernel" / "jac_kernel.so";
        with patch.object(stage0.sealed, "_jaclang_image", return_value=None),
            patch.object(stage0, "slot_path", return_value=slot),
            patch.dict(stage0.sys.modules, {}, clear=False) {
            stage0.sys.modules.pop(stage0.KERNEL_MODULE, None);
            try {
                stage0.boot_kernel();
                raised = "";
            } except stage0.KernelUnavailable as err {
                raised = str(err);
            }
        }
        assert "has no compiler kernel" in raised , raised;
        assert "jac native build kernel" in raised , raised;
    }
}

test "a stage-0 pin without a digest for this host refuses to run" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        pins = Path(tmp) / "pins.json";
        pins.write_text(
            json.dumps(
                {
                    "stage0": {
                        "version": "9.9.9",
                        "release_base": "https://example.invalid",
                        "assets": {stage0.host_osarch(): {"sha256": ""}}
                    }
                }
            )
        );
        with patch.object(stage0, "pins_file", return_value=pins) {
            try {
                stage0.stage0_pin();
                told = "";
            } except stage0.Stage0Error as err {
                told = str(err);
            }
        }
        assert "no pinned sha256" in told , told;
    }
}

test "the checked-in roster is the stage-1 kernel target" {
    import from jaclang.compiler.backends.native.kernel_stage0 { running_kernel_target }
    import from jaclang.compiler.kernel_target { roster_of }
    spec = stage0.target_spec(stage0.package_root());
    running = running_kernel_target(str(stage0.package_root()));
    assert {name: spec[name] for name in stage0.ROSTER_FIELDS} == roster_of(running) , (
        "compiler/kernel_roster.json is stale: `jac native build kernel` rewrites it"
    );
}
