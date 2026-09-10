"""`resolve_kernel()` is the one kernel lookup (#8943).

Its precedence is fixed: the explicit switch, the sealed image, the source
tree by source key, then the store parser when there is no toolchain. A
source tree with no kernel derives one on the first parse, in a child
process; a kernel whose sidecar source key disagrees with the sources now
is rebuilt; nothing raises about a missing kernel a build could make.
"""

import json;
import hashlib;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.kernel_resolve {
    KERNEL_LIB_ENV,
    KernelUnavailable,
    _accept_in_tree,
    kernel_options,
    read_sidecar,
    resolve_kernel,
    source_tree_kernel_path
}
import from jaclang.compiler.backends.native.link_plan { units_source_key }
import from jaclang.compiler.native_compiler { ensure_loaded, reset_loaded }

def _with_env(name: str, value: (str | None), fn: any) -> any {
    prev = os.environ.get(name);
    if value is None {
        os.environ.pop(name, None);
    } else {
        os.environ[name] = value;
    }
    try {
        return fn();
    } finally {
        if prev is None {
            os.environ.pop(name, None);
        } else {
            os.environ[name] = prev;
        }
    }
}

test "the off switch selects the store parser" {
    reset_loaded();
    try {
        assert _with_env(KERNEL_LIB_ENV, "off", lambda() { resolve_kernel(); }) is None;
        assert _with_env(KERNEL_LIB_ENV, "off", lambda() { ensure_loaded(); }) is None;
    } finally {
        reset_loaded();
    }
}

test "the catalog build never loads a kernel" {
    reset_loaded();
    try {
        assert _with_env("JAC_STUBCAT_BUILDING", "1", lambda() { resolve_kernel(); })
            is None;
    } finally {
        reset_loaded();
    }
}

test "an explicit path must carry its sidecar" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        bogus = os.path.join(tmp, "libjac_compiler.so");
        Path(bogus).write_bytes(b"not a library");
        raised = False;
        try {
            _with_env(KERNEL_LIB_ENV, bogus, lambda() { resolve_kernel(); });
        } except KernelUnavailable {
            raised = True;
        }
        assert raised , "a kernel path without its .layout.json sidecar is refused";
    }
}

test "the sidecar reader wants a classes map" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.so");
        Path(lib + ".layout.json").write_text(json.dumps({"plan_digest": "x"}));
        assert read_sidecar(lib) is None;
        Path(lib + ".layout.json").write_text(
            json.dumps({"classes": {}, "plan_digest": "x", "layout_digest": "y"})
        );
        found = read_sidecar(lib);
        assert found is not None and found["plan_digest"] == "x";
    }
}

test "the source-tree kernel lives beside the loader" {
    path = source_tree_kernel_path();
    assert os.path.basename(os.path.dirname(path)) == "compiler";
    assert "jac_compiler" in os.path.basename(path);
}

test "an in-tree kernel is accepted by source key, without a plan" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        unit = os.path.join(tmp, "unit.jac");
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        lib = os.path.join(tmp, "libjac_compiler.dylib");
        Path(lib).write_bytes(b"not a real kernel");
        key = units_source_key([unit], kernel_options());
        sidecar = {
            "classes": {},
            "artifact_sha256": hashlib.sha256(Path(lib).read_bytes()).hexdigest(),
            "plan_digest": "p",
            "layout_digest": "l",
            "units": [unit],
            "source_key": key
        };
        Path(lib + ".layout.json").write_text(json.dumps(sidecar));
        found = _accept_in_tree(lib);
        assert found is not None , "a matching source key accepts the kernel";
        assert found.source == "tree" and found.plan_digest == "p";
        Path(unit).write_text("def one -> int {\n    return 2;\n}\n");
        assert _accept_in_tree(lib) is None , "an edited unit moves the source key";
        stale = dict(sidecar);
        stale.pop("source_key");
        Path(lib + ".layout.json").write_text(json.dumps(stale));
        assert _accept_in_tree(lib) is None , "a sidecar without a source key is never accepted";
    }
}


test "a kernel built elsewhere is accepted by its units' package identity" {
    import from jaclang.compiler.backends.native.link_plan { sidecar_unit_paths }
    import from jaclang.compiler.frontend.codeinfo {
        jaclang_pkg_root,
        native_unit_identity
    }
    unit = os.path.join(jaclang_pkg_root(), "compiler", "driver", "jir.jac");
    ident = native_unit_identity(unit);
    assert ident.startswith("jaclang/") , ident;
    elsewhere = os.path.join(
        "/build", "stage", "site", "jaclang", "compiler", "driver", "jir.jac"
    );
    resolved = sidecar_unit_paths({"units": [elsewhere], "unit_ids": [ident]});
    assert resolved == [unit] , (
        "a unit recorded at the build's path is found where this jaclang lives"
    );
    key_here = units_source_key([unit], kernel_options());
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.dylib");
        Path(lib).write_bytes(b"not a real kernel");
        sidecar = {
            "classes": {},
            "artifact_sha256": hashlib.sha256(Path(lib).read_bytes()).hexdigest(),
            "plan_digest": "p",
            "layout_digest": "l",
            "units": [elsewhere],
            "unit_ids": [ident],
            "source_key": key_here
        };
        Path(lib + ".layout.json").write_text(json.dumps(sidecar));
        found = _accept_in_tree(lib);
        assert found is not None , (
            "the source key is keyed on package identity, not on the build's paths"
        );
    }
}

test "application configuration does not change the compiler kernel" {
    import from unittest.mock { patch }
    import from jaclang.project.config { JacConfig }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    before = kernel_options().codegen_identity();
    cfg = JacConfig();
    cfg.memory.profile = "nogc";
    cfg.memory.enforce = ["*"];
    cfg.native.debug = True;
    cfg.native.opt = 0;
    cfg.native.target = "aarch64-unknown-linux-gnu";
    prev = push_native_target(cfg.native.target);
    try {
        with patch(
            "jaclang.compiler.driver.compile_options._project_config", return_value=cfg
        ) {
            assert CompileOptions().codegen_identity() != before;
            opts = kernel_options();
            assert opts.codegen_identity() == before;
            assert opts.memory_profile == "managed";
            assert not opts.nogc_enforce_all;
            assert opts.dump_ir_path == "";
        }
    } finally {
        pop_native_target(prev);
    }
}


test "kernel publication never accepts mismatched library and sidecar images" {
    import from unittest.mock { patch }
    import jaclang.compiler.backends.native.kernel_resolve as resolver;
    import from jaclang.jac0core.cache_paths { atomic_write }
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "new.so";
        target = Path(directory) / "kernel.so";
        source.write_bytes(b"new kernel");
        target.write_bytes(b"old kernel");
        for path in [source, target] {
            Path(str(path) + ".layout.json").write_text(
                json.dumps(
                    {
                        "classes": {},
                        "artifact_sha256": hashlib.sha256(path.read_bytes()).hexdigest()
                    }
                )
            );
        }
        observed: list[bool] = [];
        def publish(path: str, data: bytes, mode: (int | None) = None) {
            atomic_write(path, data, mode);
            observed.append(_accept_in_tree(str(target)) is not None);
        }
        with patch.object(resolver, "_sidecar_matches_sources", return_value=True) {
            assert _accept_in_tree(str(target)) is not None;
            with patch.object(resolver, "atomic_write", side_effect=publish) {
                resolver._publish_kernel(str(source), str(target));
            }
        }
        assert observed == [False, True];
    }
}
