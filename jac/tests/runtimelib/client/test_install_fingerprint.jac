"""Tests for npm install fingerprinting and the runtime import preflight.

install_packages stamps node_modules with a hash of the generated
configs/package.json (+ .npmrc) after a successful install and skips the
install only when the stamp still matches, so dependency-set changes always
reinstall. _preflight_runtime_imports fails a build with a named, actionable
error when the compiled client runtime imports an npm package that is not
present under node_modules, instead of the cryptic Rollup resolve trace.
"""

import json;
import os;
import tempfile;
import unittest.mock;
import from pathlib { Path }

"""Create a client build dir with a configs/package.json and return it."""
def _make_build_dir(temp_dir: str, deps: dict) -> Path {
    build_dir = Path(temp_dir) / ".jac" / "client";
    configs = build_dir / "configs";
    configs.mkdir(parents=True);
    (configs / "package.json").write_text(json.dumps({"dependencies": deps}));
    return build_dir;
}

"""Fake an installed node_modules with a vite binary so clean_stale passes."""
def _fake_node_modules(build_dir: Path) -> Path {
    vite_bin = build_dir / "node_modules" / ".bin";
    vite_bin.mkdir(parents=True);
    (vite_bin / "vite").write_text("");
    return build_dir / "node_modules";
}

test "install packages fingerprint gates reinstalls" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        build_dir = _make_build_dir(temp_dir, {"react": "^18.2.0"});
        node_modules = _fake_node_modules(build_dir);
        bundler = ViteBundler(Path(temp_dir));
        ok_result = type("Result", (), {"returncode": 0});
        with unittest.mock.patch(
            "jaclang.runtimelib.client.bun_installer.get_bun", return_value="bun"
        ) {
            with unittest.mock.patch(
                "subprocess.run", return_value=ok_result()
            ) as mock_run {
                # Pre-fingerprint node_modules has no stamp: must reinstall.
                bundler.install_packages(install_dir=build_dir, clean_stale=True);
                assert mock_run.call_count == 1 , (
                    "missing stamp must trigger an install"
                );
                stamp = node_modules / ".jac-package-hash";
                assert stamp.exists() , (
                    "successful install must write the fingerprint stamp"
                );
                # Unchanged package.json: short-circuit.
                bundler.install_packages(install_dir=build_dir, clean_stale=True);
                assert mock_run.call_count == 1 , (
                    "matching stamp must skip the install"
                );
                # Changed package.json: fingerprint mismatch, reinstall.
                (build_dir / "configs" / "package.json").write_text(
                    json.dumps({"dependencies": {"react": "^18.2.0", "zod": "^4.3.6"}})
                );
                bundler.install_packages(install_dir=build_dir, clean_stale=True);
                assert mock_run.call_count == 2 , (
                    "a changed package.json must trigger a reinstall"
                );
            }
        }
    }
}

test "preflight names missing runtime import packages" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client_bundle { ClientBundleError }

    with tempfile.TemporaryDirectory() as temp_dir {
        build_dir = _make_build_dir(temp_dir, {});
        compiled = build_dir / "compiled";
        compiled.mkdir(parents=True);
        (compiled / "client_runtime.js").write_text(
            'import { useForm } from "@tanstack/react-form";\n'
            'import { z } from "zod";\n'
            'import * as React from "react";\n'
            'import { helper } from "./client_runtime_core.js";\n'
        );
        (build_dir / "node_modules" / "react").mkdir(parents=True);
        (build_dir / "node_modules" / "zod").mkdir(parents=True);
        bundler = ViteBundler(Path(temp_dir));
        message = "";
        try {
            bundler._preflight_runtime_imports(build_dir);
        } except ClientBundleError as e {
            message = str(e);
        }
        assert "@tanstack/react-form" in message , (
            "the missing package must be named in the error"
        );
        assert "jac add --npm" in message , ("the error must carry the remedy");
        assert "zod" not in message , ("installed packages must not be flagged");
        # Installing the package clears the preflight.
        (build_dir / "node_modules" / "@tanstack" / "react-form").mkdir(parents=True);
        bundler._preflight_runtime_imports(build_dir);
    }
}

test "preflight raises actionable error when node modules missing" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client_bundle { ClientBundleError }

    with tempfile.TemporaryDirectory() as temp_dir {
        build_dir = _make_build_dir(temp_dir, {});
        compiled = build_dir / "compiled";
        compiled.mkdir(parents=True);
        (compiled / "client_runtime.js").write_text('import { z } from "zod";\n');
        bundler = ViteBundler(Path(temp_dir));
        message = "";
        try {
            bundler._preflight_runtime_imports(build_dir);
        } except ClientBundleError as e {
            message = str(e);
        }
        assert "jac install" in message , ("the error must point at jac install");
        with unittest.mock.patch.dict(
            os.environ, {"JAC_CLIENT_SKIP_NPM_INSTALL": "1"}
        ) {
            skip_message = "";
            try {
                bundler._preflight_runtime_imports(build_dir);
            } except ClientBundleError as e {
                skip_message = str(e);
            }
            assert "JAC_CLIENT_SKIP_NPM_INSTALL" in skip_message , (
                "the error must call out the skip-install env var"
            );
        }
    }
}
