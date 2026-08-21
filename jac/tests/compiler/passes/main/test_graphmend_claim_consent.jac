"""Consent gates on .py import claiming: imported code is claimed only under
the [run] graphmend_claim_imports opt-in, an abandoned claim leaves a
diagnostic naming the file and reason, and the SourceFileLoader patch is
restored on teardown instead of outliving the claiming region."""
import os;
import tempfile;
import from importlib.machinery { SourceFileLoader }
import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.project.config { JacConfig }
import jaclang.project.config as config_mod;

"""Write `name` under `tmp` and return its absolute path."""
def _write(tmp: str, name: str, src: str) -> str {
    path = os.path.join(tmp, name);
    with open(path, "w") as fh {
        fh.write(src);
    }
    return path;
}

"""Drop any installed GraphMend loader patch; return what was there."""
def _unhook_loader -> any {
    prev = SourceFileLoader.__dict__.get("get_code");
    if prev is not None {
        delattr(SourceFileLoader, "get_code");
    }
    if "_jac_graphmend_hooked" in SourceFileLoader.__dict__ {
        delattr(SourceFileLoader, "_jac_graphmend_hooked");
    }
    return prev;
}

"""Put back a patch `_unhook_loader` removed."""
def _rehook_loader(prev: any) {
    if prev is not None {
        setattr(SourceFileLoader, "get_code", prev);
        setattr(SourceFileLoader, "_jac_graphmend_hooked", True);
    }
}

test "claiming an imported py needs its own explicit opt in" {
    # A registered claim covers this path, yet the import-time gate must
    # refuse it until [run] graphmend_claim_imports grants consent; the
    # graphmend default alone is not consent for recompiling imported code.
    import sys;
    import from jaclang.meta_importer { _graphmend_claims }
    prog = Jac.get_program();
    prev_claimed = set(prog.graphmend_claimed);
    old_config = config_mod._config;
    saved_torch = sys.modules.pop("torch", None);
    with tempfile.TemporaryDirectory() as tmp {
        path = _write(tmp, "thirdparty.py", "x = 1\n");
        real = os.path.realpath(path);
        try {
            prog.graphmend_claimed.clear();
            prog.graphmend_claimed.add(real);
            config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
            assert _graphmend_claims("thirdparty", path) is False , (
                "a registered claim must not be honored at import time "
                "without the claim-imports opt-in"
            );
            config_mod._config = JacConfig.from_toml_str(
                "[run]\ngraphmend_claim_imports = true\n"
            );
            assert _graphmend_claims("thirdparty", path) is True , (
                "the opt-in must let a registered claim through"
            );
            config_mod._config = JacConfig.from_toml_str(
                "[run]\ngraphmend = false\ngraphmend_claim_imports = true\n"
            );
            assert _graphmend_claims("thirdparty", path) is False , (
                "the graphmend off switch still beats the claim opt-in"
            );
        } finally {
            if saved_torch is not None {
                sys.modules["torch"] = saved_torch;
            }
            config_mod._config = old_config;
            cur = Jac.get_program();
            cur.graphmend_claimed.clear();
            cur.graphmend_claimed.update(prev_claimed);
        }
    }
}

test "an imported package under a registered claim stays stock by default" {
    # End to end: with nothing opted in, the meta importer must decline the
    # claimed submodule so the stock machinery serves it untouched.
    import importlib;
    import sys;
    import from jaclang.meta_importer { JacMetaImporter }
    prog = Jac.get_program();
    old_config = config_mod._config;
    prev_hook = _unhook_loader();
    saved_torch = sys.modules.pop("torch", None);
    with tempfile.TemporaryDirectory() as tmp {
        pkg = os.path.join(tmp, "consentpkg");
        os.mkdir(pkg);
        _write(pkg, "__init__.py", "");
        dep = _write(pkg, "dep.py", "VALUE = 2\n");
        real = os.path.realpath(dep);
        sys.path.insert(0, tmp);
        try {
            config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
            prog.graphmend_claimed.add(real);
            sys.modules.pop("consentpkg", None);
            sys.modules.pop("consentpkg.dep", None);
            mod = importlib.import_module("consentpkg.dep");
            assert not isinstance(mod.__spec__.loader, JacMetaImporter) , (
                "an imported claimed .py must stay with the stock loader "
                "unless claim imports is opted in"
            );
            assert mod.VALUE == 2;
        } finally {
            if saved_torch is not None {
                sys.modules["torch"] = saved_torch;
            }
            sys.path.remove(tmp);
            sys.modules.pop("consentpkg", None);
            sys.modules.pop("consentpkg.dep", None);
            prog.graphmend_claimed.discard(real);
            _unhook_loader();
            _rehook_loader(prev_hook);
            config_mod._config = old_config;
        }
    }
}

test "the claim imports gate is off by default at every layer" {
    import from jaclang.jac0core.compile_options {
        CompileOptions,
        resolved_graphmend_claim_imports_setting
    }
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
        assert config_mod._config.run.graphmend_claim_imports is False;
        assert resolved_graphmend_claim_imports_setting() is False;
        assert CompileOptions().graphmend_claim_imports is False;
        config_mod._config = JacConfig.from_toml_str(
            "[run]\ngraphmend_claim_imports = true\n"
        );
        assert resolved_graphmend_claim_imports_setting() is True;
        assert CompileOptions().graphmend_claim_imports is True;
    } finally {
        config_mod._config = old_config;
    }
}

test "an abandoned claim reports the file and the reason" {
    # A granted claim the Jac front end cannot serve must fall back to the
    # stock loader AND leave a diagnostic on the program; today the failure
    # is swallowed whole and the downgrade is invisible.
    import sys;
    import from jaclang.meta_importer { install_graphmend_loader_hook }
    prog = Jac.get_program();
    compiler = Jac.get_compiler();
    prev_claimed = set(prog.graphmend_claimed);
    prev_warnings = list(prog.warnings_had);
    old_config = config_mod._config;
    prev_hook = _unhook_loader();
    saved_torch = sys.modules.pop("torch", None);
    def _refuse_bytecode(full_target: str, target_program: any) -> any {
        raise RuntimeError(
            f"front end declined ({bool(full_target)}, {bool(target_program)})"
        );
    }
    with tempfile.TemporaryDirectory() as tmp {
        path = _write(tmp, "abandoned_claim_mod.py", "VALUE = 41 + 1\n");
        real = os.path.realpath(path);
        try {
            config_mod._config = JacConfig.from_toml_str(
                "[run]\ngraphmend_claim_imports = true\n"
            );
            prog.graphmend_claimed.add(real);
            install_graphmend_loader_hook();
            setattr(compiler, "get_bytecode", _refuse_bytecode);
            loader = SourceFileLoader("abandoned_claim_mod", path);
            code = loader.get_code("abandoned_claim_mod");
            assert code is not None , "the stock loader must still serve the file";
            ns: dict = {};
            exec(code, ns);
            assert ns["VALUE"] == 42 , "the fallback must run the original source";
            hits = [
                w
                for w in prog.warnings_had
                if path in str(w)
            ];
            assert hits , (
                "abandoning a claim must leave a diagnostic naming the file"
            );
            assert "front end declined" in str(hits[0]) , (
                f"the diagnostic must carry the reason: {hits[0]}"
            );
            assert hits[0].code is not None , (
                "the abandoned-claim diagnostic must carry a registered code"
            );
            assert hits[0].code.code == "W1107";
        } finally {
            if saved_torch is not None {
                sys.modules["torch"] = saved_torch;
            }
            if "get_bytecode" in compiler.__dict__ {
                delattr(compiler, "get_bytecode");
            }
            _unhook_loader();
            _rehook_loader(prev_hook);
            config_mod._config = old_config;
            cur = Jac.get_program();
            cur.graphmend_claimed.clear();
            cur.graphmend_claimed.update(prev_claimed);
            cur.warnings_had.clear();
            cur.warnings_had.extend(prev_warnings);
        }
    }
}

test "teardown restores the stock loader get_code" {
    # The patch may not outlive the claiming region: uninstall must give the
    # stdlib class back its inherited get_code, be idempotent, and leave the
    # hook reinstallable; install must arm the process-teardown restore.
    import jaclang.meta_importer as mi;
    prev_hook = _unhook_loader();
    try {
        assert SourceFileLoader.__dict__.get("get_code") is None , (
            "precondition: the stdlib class starts unpatched"
        );
        mi.install_graphmend_loader_hook();
        assert SourceFileLoader.__dict__.get("get_code") is not None;
        assert SourceFileLoader.__dict__.get("_jac_graphmend_hooked") is True;
        mi.uninstall_graphmend_loader_hook();
        assert SourceFileLoader.__dict__.get("get_code") is None , (
            "uninstall must restore the inherited get_code"
        );
        assert "_jac_graphmend_hooked" not in SourceFileLoader.__dict__ , (
            "uninstall must drop the hook marker"
        );
        mi.uninstall_graphmend_loader_hook();
        assert SourceFileLoader.__dict__.get("get_code") is None , (
            "a second uninstall must be a no-op"
        );
        mi.install_graphmend_loader_hook();
        assert SourceFileLoader.__dict__.get("get_code") is not None , (
            "the hook must be reinstallable after a teardown"
        );
        mi.uninstall_graphmend_loader_hook();
        assert mi._graphmend_hook_state.get("atexit") is True , (
            "install must arm the process-teardown restore"
        );
    } finally {
        _unhook_loader();
        _rehook_loader(prev_hook);
    }
}
