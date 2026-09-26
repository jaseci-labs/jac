"""A pinned stage-0 compiler builds the kernel, and the checkout accepts it.

`jac/bootstrap/stage0.json` names the compiler that builds the kernel: "self"
(the running compiler) or a commit whose `jac/jaclang` snapshot is provisioned
into the cache. A snapshot runs only when its kernel ABI matches this tree;
every refusal falls back to the self build unless JAC_STAGE0_STRICT forbids
it. A stage-0 kernel is accepted by the pin, the ABI and the units' sources,
never by the running compiler's digest.
"""
import hashlib;
import io;
import json;
import os;
import from tests.support { JAC_ROOT }
import shutil;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.compiler.backends.native.stage0_build as stage0_build;
import from jaclang.compiler.backends.native.kernel_resolve {
    KERNEL_DEV_LINK_MODE,
    KernelUnavailable,
    SEALED_LINK_MODE,
    _accept_in_tree,
    _derive_in_tree,
    _from_sealed_image,
    kernel_options,
    read_sidecar
}
import from jaclang.compiler.backends.native.stage0_pin {
    STAGE0_PIN_ENV,
    STAGE0_ROOT_ENV,
    STAGE0_STRICT_ENV,
    Stage0Pin,
    Stage0PinError,
    abi_contract_digest,
    read_stage0_pin,
    stage0_pin_path,
    write_stage0_pin
}
import from jaclang.compiler.backends.native.stage0_build {
    build_kernel_by_pin,
    file_guard_trips,
    pin_for_commit,
    restamp_stage0_sidecar,
    typeshed_pin_of
}
import from jaclang.compiler.driver.jir { running_compiler_digest, unit_source_digest }
import from jaclang.compiler.frontend.codeinfo {
    KERNEL_UNIT_REL,
    NATIVE_ABI_VERSION,
    jaclang_pkg_root,
    native_unit_identity
}
import from jaclang.compiler.native_scope { KERNEL_ABI_CONTRACT_REL }
import from jaclang.testing.requires { require_flag }

glob COMMIT: str = "a" * 40,
     TREE: str = "b" * 40,
     NATIVE: str = "c" * 40;

def _with_env(values: dict[str, (str | None)], fn: any) -> any {
    prev = {k: os.environ.get(k) for k in values};
    for (k, v) in values.items() {
        if v is None {
            os.environ.pop(k, None);
        } else {
            os.environ[k] = v;
        }
    }
    try {
        return fn();
    } finally {
        for (k, v) in prev.items() {
            if v is None {
                os.environ.pop(k, None);
            } else {
                os.environ[k] = v;
            }
        }
    }
}

def _commit_pin(digest: str = "7:digest") -> Stage0Pin {
    return Stage0Pin(
        commit=COMMIT,
        jaclang_tree=TREE,
        compiler_digest=digest,
        native_tree=NATIVE,
        typeshed_pin=typeshed_pin_of(jaclang_pkg_root())
    );
}

def _write_json(path: str, data: any) {
    Path(path).write_text(json.dumps(data));
}

test "the stage-0 pin reads self, a commit and a missing file, and refuses malformed pins" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        path = os.path.join(tmp, "stage0.json");
        assert read_stage0_pin(path).is_self() , "no pin file means self";
        _write_json(path, {"stage0": "self"});
        assert read_stage0_pin(path).is_self();
        pin = _commit_pin();
        write_stage0_pin(pin, path);
        back = read_stage0_pin(path);
        assert not back.is_self();
        assert back.to_dict() == pin.to_dict();
        good = pin.to_dict();
        malformed: list[any] = [
            "not json {",
            [1, 2],
            {"stage0": "HEAD"},
            {"stage0": "self", "commit": COMMIT},
            {** good, "format": 2},
            {** good, "commit": "abc123"},
            {** good, "native_tree": "B" * 40},
            {
                k: v
                for (k, v) in good.items()
                if k != "compiler_digest"
            },
            {** good, "typeshed_pin": ""}
        ];
        for bad in malformed {
            if isinstance(bad, str) {
                Path(path).write_text(bad);
            } else {
                _write_json(path, bad);
            }
            refused = False;
            try {
                read_stage0_pin(path);
            } except Stage0PinError {
                refused = True;
            }
            assert refused , f"{bad!r} is not a pin";
        }
        assert _with_env({STAGE0_PIN_ENV: path}, lambda() { stage0_pin_path(); })
            == path;
    }
}

test "the checkout ships a stage-0 pin beside its jaclang package" {
    # The suite may run against a jaclang installed outside the checkout, where
    # no pin sits beside the package and stage 0 is the self build; the pin the
    # checkout ships is read from the checkout itself. The shipped pin may be
    # "self" or a pinned snapshot (the stage0-bump workflow moves it); a
    # malformed pin raises Stage0PinError, so parsing it is the assertion.
    shipped = os.path.join(JAC_ROOT, "bootstrap", "stage0.json");
    assert os.path.isfile(shipped);
    pin = read_stage0_pin(shipped);
    assert pin.is_self() or pin.commit;
    path = _with_env(
        {STAGE0_PIN_ENV: None, STAGE0_ROOT_ENV: None}, lambda() { stage0_pin_path(); }
    );
    assert path
        == os.path.join(
            os.path.dirname(os.path.realpath(jaclang_pkg_root())),
            "bootstrap",
            "stage0.json"
        );
}

test "JAC_STAGE0_ROOT names the source tree whose pin and history drive stage 0" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        src_dir = os.path.realpath(tmp);
        path = _with_env(
            {STAGE0_PIN_ENV: None, STAGE0_ROOT_ENV: src_dir},
            lambda() { stage0_pin_path(); }
        );
        assert path == os.path.join(src_dir, "bootstrap", "stage0.json");
        explicit = os.path.join(src_dir, "elsewhere.json");
        assert _with_env(
            {STAGE0_PIN_ENV: explicit, STAGE0_ROOT_ENV: src_dir},
            lambda() { stage0_pin_path(); }
        )
            == explicit;
    }
}

test "the kernel ABI contract covers every kernel unit and names files that exist" {
    assert set(KERNEL_UNIT_REL) <= set(KERNEL_ABI_CONTRACT_REL);
    for rel in KERNEL_ABI_CONTRACT_REL {
        assert os.path.isfile(os.path.join(jaclang_pkg_root(), rel)) , rel;
    }
}

def _contract_tree(dst: str) -> str {
    src = jaclang_pkg_root();
    rels = list(KERNEL_ABI_CONTRACT_REL)
        + ["compiler/frontend/codeinfo.jac", "vendor/typeshed/PIN"];
    for rel in rels {
        out = os.path.join(dst, rel);
        os.makedirs(os.path.dirname(out), exist_ok=True);
        shutil.copyfile(os.path.join(src, rel), out);
    }
    return dst;
}

test "a snapshot whose kernel ABI contract differs trips the guard" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        snap = _contract_tree(os.path.join(tmp, "snap"));
        target = _contract_tree(os.path.join(tmp, "target"));
        pin = _commit_pin();
        assert file_guard_trips(pin, snap, target) == [];
        tag = os.path.join(target, "runtime", "osp_tag.jac");
        Path(tag).write_text(Path(tag).read_text() + "\n");
        trips = file_guard_trips(pin, snap, target);
        assert len(trips) == 1 and "runtime/osp_tag.jac" in trips[0] , trips;
        shutil.copyfile(os.path.join(snap, "runtime", "osp_tag.jac"), tag);
        codeinfo = os.path.join(snap, "compiler", "frontend", "codeinfo.jac");
        Path(codeinfo).write_text(
            Path(codeinfo).read_text().replace(
                f"NATIVE_ABI_VERSION: int = {NATIVE_ABI_VERSION}",
                f"NATIVE_ABI_VERSION: int = {NATIVE_ABI_VERSION + 1}"
            )
        );
        trips = file_guard_trips(pin, snap, target);
        assert len(trips) == 1 and "native ABI" in trips[0] , trips;
        shutil.copyfile(
            os.path.join(jaclang_pkg_root(), "compiler", "frontend", "codeinfo.jac"),
            codeinfo
        );
        assert file_guard_trips(pin, snap, target) == [];
        stale = _commit_pin();
        stale.typeshed_pin = "0" * 40;
        trips = file_guard_trips(stale, snap, target);
        assert len(trips) == 1 and "typeshed" in trips[0] , trips;
        Path(os.path.join(snap, "vendor", "typeshed", "PIN")).write_text("0" * 40);
        trips = file_guard_trips(pin, snap, target);
        assert len(trips) == 1 and "typeshed" in trips[0] , trips;
    }
}

def _refused_build(
    dst: str, strict: bool, child_status: int = 0
) -> tuple[bool, str, bool] {
    err = io.StringIO();
    raised = False;
    result = False;
    with patch.object(stage0_build, "checkout_repo", return_value=("/repo", "jac/")), patch.object(
        stage0_build, "provision_stage0", return_value=jaclang_pkg_root()
    ), patch.object(stage0_build, "native_tree_trips", return_value=[]), patch.object(
        stage0_build,
        "file_guard_trips",
        return_value=(
            ["kernel ABI contract differs: runtime/osp_tag.jac"]
                if child_status == 0
                else []
        )
    ), patch.object(stage0_build, "run_stage0_child", return_value=child_status), patch.object(
        sys, "stderr", err
    ) {
        try {
            result = _with_env(
                {STAGE0_STRICT_ENV: "1" if strict else None},
                lambda() { build_kernel_by_pin(dst); }
            );
        } except KernelUnavailable {
            raised = True;
        }
    }
    return (result, err.getvalue(), raised);
}

test "a guard trip or an unknown target format falls back to the self build, unless strict" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        pin_path = os.path.join(tmp, "stage0.json");
        write_stage0_pin(_commit_pin(), pin_path);
        dst = os.path.join(tmp, "libjac_compiler.so");
        def run(strict: bool, status: int) -> tuple[bool, str, bool] {
            return _with_env(
                {STAGE0_PIN_ENV: pin_path},
                lambda() { _refused_build(dst, strict, status); }
            );
        }
        (built, notice, raised) = run(False, 0);
        assert not built and not raised;
        assert notice.count("stage-0 kernel build unavailable") == 1 , notice;
        assert "osp_tag.jac" in notice;
        (built, notice, raised) = run(True, 0);
        assert raised and not built , "strict mode refuses the self build";
        (built, notice, raised) = run(False, 3);
        assert not built and not raised;
        assert "target format" in notice , notice;
        (built, notice, raised) = run(True, 3);
        assert raised;
        assert not os.path.exists(dst + ".target.json") , "the target spec is removed";
        write_stage0_pin(Stage0Pin(), pin_path);
        err = io.StringIO();
        with patch.object(
            stage0_build,
            "provision_stage0",
            side_effect=AssertionError("pin self provisions nothing")
        ), patch.object(sys, "stderr", err) {
            assert _with_env(
                {STAGE0_PIN_ENV: pin_path, STAGE0_STRICT_ENV: "1"},
                lambda() { build_kernel_by_pin(dst); }
            )
                is False;
        }
        assert err.getvalue() == "" , "the self build under pin self is silent";
        Path(pin_path).write_text("{");
        (built, notice, raised) = run(False, 0);
        assert not built and "unreadable pin" in notice , notice;
    }
}

def _spec_link_mode(link_mode: str) -> str {
    import from jaclang.compiler.kernel_target { read_kernel_target }
    seen: list[str] = [];
    def child(snapshot: str, spec_path: str, dst: str) -> int {
        spec = read_kernel_target(spec_path);
        seen.append(spec.link_mode if spec is not None else "unreadable");
        return 0;
    }
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        pin_path = os.path.join(tmp, "stage0.json");
        write_stage0_pin(_commit_pin(), pin_path);
        dst = os.path.join(tmp, "libjac_compiler.so");
        with patch.object(
            stage0_build, "checkout_repo", return_value=("/repo", "jac/")
        ), patch.object(
            stage0_build, "provision_stage0", return_value=jaclang_pkg_root()
        ), patch.object(stage0_build, "native_tree_trips", return_value=[]), patch.object(
            stage0_build, "file_guard_trips", return_value=[]
        ), patch.object(stage0_build, "run_stage0_child", side_effect=child), patch.object(
            stage0_build, "restamp_stage0_sidecar", return_value={}
        ) {
            built = _with_env(
                {STAGE0_PIN_ENV: pin_path},
                lambda() { build_kernel_by_pin(dst, link_mode=link_mode)
                    if link_mode
                    else build_kernel_by_pin(dst); }
            );
        }
        assert built is True;
    }
    assert len(seen) == 1;
    return seen[0];
}

test "stage 0 links a dev kernel from unit objects and a sealed kernel as one optimized program" {
    assert KERNEL_DEV_LINK_MODE == "objects" and SEALED_LINK_MODE == "bitcode";
    assert kernel_options().native_link_mode == KERNEL_DEV_LINK_MODE;
    assert _spec_link_mode("") == KERNEL_DEV_LINK_MODE;
    assert _spec_link_mode(SEALED_LINK_MODE) == SEALED_LINK_MODE;
    import from jaclang.compiler.kernel_target {
        kernel_target_from_dict,
        with_link_mode
    }
    import from jaclang.compiler.backends.native.kernel_stage0 { running_kernel_target }
    spec = running_kernel_target();
    assert spec.link_mode == "";
    sealed = with_link_mode(spec, SEALED_LINK_MODE);
    back = kernel_target_from_dict(sealed.to_dict());
    assert back is not None and back.to_dict() == sealed.to_dict();
    legacy = spec.to_dict();
    legacy.pop("link_mode");
    old = kernel_target_from_dict(legacy);
    assert old is not None and old.link_mode == "" , "an older spec leaves the mode to the builder";
}

def _seal_with(pin: Stage0Pin, sidecar: (dict[str, any] | None), tmp: str) -> any {
    import from jaclang.dist.precompile_bytecode { seal_stage0_kernel }
    pin_path = os.path.join(tmp, "stage0.json");
    write_stage0_pin(pin, pin_path);
    lib = Path(tmp, "compiler", "libjac_compiler.so");
    lib.parent.mkdir(parents=True, exist_ok=True);
    def child(snapshot: str, spec_path: str, dst: str) -> int {
        Path(dst).write_bytes(b"a stage-0 kernel");
        _write_json(dst + ".layout.json", sidecar);
        return 0;
    }
    provision = patch.object(
        stage0_build,
        "provision_stage0",
        side_effect=AssertionError("pin self provisions nothing")
    )
        if pin.is_self()
        else patch.object(
            stage0_build, "provision_stage0", return_value=jaclang_pkg_root()
        );
    with patch.object(stage0_build, "checkout_repo", return_value=("/repo", "jac/")), provision, patch.object(
        stage0_build, "native_tree_trips", return_value=[]
    ), patch.object(stage0_build, "file_guard_trips", return_value=[]), patch.object(
        stage0_build, "run_stage0_child", side_effect=child
    ), patch.object(stage0_build, "restamp_stage0_sidecar", return_value={}) {
        return _with_env(
            {STAGE0_PIN_ENV: pin_path, STAGE0_STRICT_ENV: "1"},
            lambda() { seal_stage0_kernel(
                Path(jaclang_pkg_root()), lib, "compiler/libjac_compiler.so"
            ); }
        );
    }
}

test "the seal selects the kernel's builder by the pin: self seals as before, stage 0 records itself" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        assert _seal_with(Stage0Pin(), None, tmp) is None , "pin self leaves the seal to this compiler";
        assert not os.path.exists(os.path.join(tmp, "compiler", "libjac_compiler.so"));
        pin = _commit_pin();
        sidecar = {
            "classes": {},
            "plan_digest": "p" * 64,
            "layout_digest": "l" * 64,
            "triple": kernel_options().effective_triple(),
            "link_mode": SEALED_LINK_MODE,
            "builder": "stage0",
            "stage0": {"commit": pin.commit, "digest": pin.compiler_digest}
        };
        record = _seal_with(pin, sidecar, tmp);
        assert record is not None;
        assert record["units"] == {} , "stage 0's units are not this compiler's sealed twins";
        artifact = record["artifact"];
        assert artifact["builder"] == "stage0";
        assert artifact["stage0"] == sidecar["stage0"];
        assert artifact["mode"] == SEALED_LINK_MODE;
        assert artifact["plan_digest"] == sidecar["plan_digest"];
        assert artifact["sha256"] == hashlib.sha256(b"a stage-0 kernel").hexdigest();
        refused = False;
        try {
            _seal_with(pin, {** sidecar, "link_mode": KERNEL_DEV_LINK_MODE}, tmp);
        } except RuntimeError {
            refused = True;
        }
        assert refused , "an objects-mode kernel is never sealed";
    }
}

test "a sealed image whose kernel is not a whole-program link is refused" {
    import jaclang.jac0core.sealed as sealed_mod;
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        lib = Path(tmp, "compiler", "libjac_compiler.so");
        lib.parent.mkdir(parents=True);
        lib.write_bytes(b"kernel");
        sidecar = {"classes": {}, "plan_digest": "p", "link_mode": SEALED_LINK_MODE};
        _write_json(str(lib) + ".layout.json", sidecar);
        record = {
            "path": "compiler/libjac_compiler.so",
            "sha256": hashlib.sha256(b"kernel").hexdigest(),
            "plan_digest": "p",
            "mode": SEALED_LINK_MODE
        };
        obj FakeImage {
            has pkg_dir: Path,
                record: dict[str, any];

            def native_artifact -> dict[str, any] {
                return self.record;
            }
        }
        def resolve(rec: dict[str, any]) -> tuple[bool, bool] {
            image = FakeImage(pkg_dir=Path(tmp), record=rec);
            with patch.object(sealed_mod, "_jaclang_image", return_value=image) {
                try {
                    return (_from_sealed_image() is not None, False);
                } except KernelUnavailable {
                    return (False, True);
                }
            }
        }
        assert resolve(record) == (True, False);
        assert resolve({** record, "mode": KERNEL_DEV_LINK_MODE}) == (False, True);
        _write_json(
            str(lib) + ".layout.json", {** sidecar, "link_mode": KERNEL_DEV_LINK_MODE}
        );
        assert resolve(record) == (False, True);
    }
}

def _stage0_sidecar(lib: str, unit: str, pin: Stage0Pin) -> dict[str, any] {
    ident = native_unit_identity(unit);
    options = kernel_options();
    return {
        "classes": {},
        "artifact_sha256": hashlib.sha256(Path(lib).read_bytes()).hexdigest(),
        "plan_digest": "p",
        "layout_digest": "l",
        "units": [unit],
        "unit_ids": [ident],
        "source_key": "folded by stage 0",
        "compiler_digest": "the stage-0 compiler, not this one",
        "codegen_identity": "stage 0 spells its codegen identity its own way",
        "triple": options.effective_triple(),
        "python": f"{sys.version_info.major}.{sys.version_info.minor}",
        "unit_sources": {ident: unit_source_digest(unit)},
        "unit_policy": {ident: int(options.native_required_for(unit))},
        "builder": "stage0",
        "stage0": {"commit": pin.commit, "digest": pin.compiler_digest},
        "abi": NATIVE_ABI_VERSION,
        "abi_contract": abi_contract_digest(jaclang_pkg_root())
    };
}

test "a stage-0 kernel is accepted by its pin, ABI and unit sources, not by this compiler's digest" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        unit = os.path.join(tmp, "unit.jac");
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        lib = os.path.join(tmp, "libjac_compiler.so");
        Path(lib).write_bytes(b"not a real kernel");
        pin_path = os.path.join(tmp, "stage0.json");
        pin = _commit_pin();
        write_stage0_pin(pin, pin_path);
        sidecar = _stage0_sidecar(lib, unit, pin);
        ident = native_unit_identity(unit);
        def write(record: dict[str, any]) {
            _write_json(lib + ".layout.json", record);
        }
        def accepted -> bool {
            return _with_env(
                {STAGE0_PIN_ENV: pin_path}, lambda() { _accept_in_tree(lib); }
            )
                is not None;
        }
        write(sidecar);
        assert sidecar["compiler_digest"] != running_compiler_digest();
        assert accepted() , "the pin vouches for the stage-0 compiler";
        for (field, value) in [
            ("stage0", {"commit": pin.commit, "digest": "another stage 0"}),
            ("stage0", {"commit": "d" * 40, "digest": pin.compiler_digest}),
            ("abi", NATIVE_ABI_VERSION + 1),
            ("abi_contract", "another contract"),
            ("triple", "wasm32-unknown-unknown"),
            ("python", "2.7"),
            ("unit_policy", {ident: 1}),
            ("unit_sources", {ident: "an older unit"})
        ] {
            write({** sidecar, field: value});
            assert not accepted() , f"a different {field} is another kernel";
        }
        write(
            {
                k: v
                for (k, v) in sidecar.items()
                if k != "builder"
            }
        );
        assert not accepted() , "without the builder stamp this compiler's digest decides";
        write(sidecar);
        assert accepted();
        write_stage0_pin(_commit_pin("8:another digest"), pin_path);
        assert not accepted() , "a pin bump retires the kernel";
        write_stage0_pin(Stage0Pin(), pin_path);
        assert not accepted() , "pin self retires every stage-0 kernel";
        write_stage0_pin(pin, pin_path);
        Path(unit).write_text("def one -> int {\n    return 2;\n}\n");
        assert not accepted() , "an edited unit needs a rebuild";
    }
}

test "the checkout re-stamps a stage-0 sidecar with its own unit digests" {
    with tempfile.TemporaryDirectory(prefix="jac-stage0-") as tmp {
        unit = os.path.join(tmp, "unit.jac");
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        lib = os.path.join(tmp, "libjac_compiler.so");
        Path(lib).write_bytes(b"not a real kernel");
        pin_path = os.path.join(tmp, "stage0.json");
        pin = _commit_pin();
        write_stage0_pin(pin, pin_path);
        ident = native_unit_identity(unit);
        child = _stage0_sidecar(lib, unit, pin);
        for field in ("builder", "stage0", "abi", "abi_contract") {
            child.pop(field);
        }
        child["unit_sources"] = {ident: "digested by stage 0's own rules"};
        _write_json(lib + ".layout.json", child);
        before = {os.path.realpath(unit): unit_source_digest(unit)};
        stamped = restamp_stage0_sidecar(lib, pin, jaclang_pkg_root(), before);
        assert stamped["builder"] == "stage0";
        assert stamped["stage0"]
            == {"commit": pin.commit, "digest": pin.compiler_digest};
        assert stamped["abi"] == NATIVE_ABI_VERSION;
        assert stamped["unit_sources"] == {ident: unit_source_digest(unit)};
        assert read_sidecar(lib) == stamped;
        assert _with_env({STAGE0_PIN_ENV: pin_path}, lambda() { _accept_in_tree(lib); })
            is not None;
        _write_json(lib + ".layout.json", child);
        raced = False;
        try {
            restamp_stage0_sidecar(
                lib, pin, jaclang_pkg_root(), {os.path.realpath(unit): "before"}
            );
        } except RuntimeError {
            raced = True;
        }
        assert raced , "a unit edited during the build is never stamped";
    }
}

def _stage_copy(dst: str) -> str {
    src = jaclang_pkg_root();
    target = os.path.join(dst, "jaclang");
    shutil.copytree(
        src,
        target,
        ignore=shutil.ignore_patterns(
            "__pycache__", "_precompiled", "*.so", "*.so.*", "vendor", ".jac"
        )
    );
    os.symlink(os.path.join(src, "vendor"), os.path.join(target, "vendor"));
    return target;
}

def _e2e_log(msg: str) {
    stream = sys.__stderr__;
    if stream is not None {
        stream.write(msg + "\n");
        stream.flush();
    }
    log_path = os.environ.get("JAC_STAGE0_E2E_LOG", "");
    if log_path {
        with open(log_path, "a", encoding="utf-8") as f {
            f.write(msg + "\n");
        }
    }
}

test "stage 0 pinned to HEAD builds this tree's kernel and the checkout accepts it" {
    require_flag("JAC_STAGE0_E2E", "it builds a kernel through stage 0");
    import from jaclang.compiler.kernel_target {
        active_kernel_target,
        set_kernel_target
    }
    import from jaclang.compiler.backends.native.kernel_stage0 { running_kernel_target }
    tmp = tempfile.mkdtemp(prefix="jac-stage0-e2e-");
    prev_target = active_kernel_target();
    try {
        started = time.perf_counter();
        pin = pin_for_commit("HEAD");
        pin_path = os.path.join(tmp, "stage0.json");
        write_stage0_pin(pin, pin_path);
        _e2e_log(
            f"STAGE0 pin {pin.commit} digest {pin.compiler_digest} in "
            f"{time.perf_counter() - started:.1f}s"
        );
        copy = _stage_copy(os.path.join(tmp, "pr"));
        set_kernel_target(running_kernel_target(copy));
        lib = os.path.join(tmp, "lib", "libjac_compiler.so");
        os.makedirs(os.path.dirname(lib));
        def derive -> any {
            return _with_env(
                {STAGE0_PIN_ENV: pin_path, STAGE0_STRICT_ENV: "1"},
                lambda() { _derive_in_tree(lib); }
            );
        }
        def accepted -> bool {
            return _with_env(
                {STAGE0_PIN_ENV: pin_path}, lambda() { _accept_in_tree(lib); }
            )
                is not None;
        }
        started = time.perf_counter();
        found = derive();
        _e2e_log(f"STAGE0 cold build {time.perf_counter() - started:.1f}s");
        assert found is not None;
        sidecar = read_sidecar(lib);
        assert sidecar is not None and sidecar["builder"] == "stage0";
        assert sidecar["stage0"]["commit"] == pin.commit;
        assert sidecar["link_mode"] == KERNEL_DEV_LINK_MODE , "an in-tree kernel links unit objects";
        assert accepted() , "the checkout accepts the kernel stage 0 built";
        edited = os.path.join(copy, "runtime", "na_stdlib", "keyword.jac");
        Path(edited).write_text(Path(edited).read_text() + "\n");
        assert not accepted() , "an edited kernel unit retires the kernel";
        started = time.perf_counter();
        found = derive();
        _e2e_log(f"STAGE0 one-edit build {time.perf_counter() - started:.1f}s");
        assert found is not None;
        sidecar = read_sidecar(lib);
        assert sidecar is not None and sidecar["builder"] == "stage0";
        assert accepted();
    } finally {
        set_kernel_target(prev_target);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
