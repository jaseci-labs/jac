"""Tests for the mobile target (React Native over Expo).

A `kind = "mobile"` app is the mobile target: there is no separate client
axis, so `jac build --platform android|ios|web <app>` and `jac run --dev
<app>` reach it through the kind alone. Source-level contract tests and
functional unit tests cover target registration, scaffold generation,
iOS/release/EAS wiring, config resolution, and the build/dev pipeline
surface. End-to-end device builds are gated behind
``JAC_PHASE3_DUAL_TARGET_GATE=1`` / ``JAC_RN_E2E=1`` and are not exercised
in default CI.
"""

import os;
import from pathlib { Path }

# Client target modules ship with core under jaclang/client/.
glob _client_dir = (
         Path(os.path.dirname(__file__)).parent.parent / "jaclang" / "client"
     ),
     _targets_dir = _client_dir / "targets";

def _register_client_targets {
    import from jaclang.client.targets.register { register_targets }
    import from jaclang.client.targets.registry { get_target_registry }

    registry = get_target_registry();
    registry.clear();
    register_targets();
}

test "mobile target files exist" {
    target_jac = _targets_dir / "mobile_target.jac";
    target_impl = _targets_dir / "impl" / "mobile_target.impl.jac";

    assert target_jac.exists() , f"mobile_target.jac not found at {target_jac}";
    assert target_impl.exists() , (
        f"mobile_target.impl.jac not found at {target_impl}"
    );
    # The Capacitor target that used to live under this name is gone for good.
    assert not (_targets_dir / "mobile").exists() , (
        "the Capacitor target dir (targets/mobile/) must not come back"
    );
    assert not (_targets_dir / "react_native_target.jac").exists() , (
        "react_native_target.jac was renamed to mobile_target.jac"
    );
    assert not (_client_dir / "mobile_setup_env.jac").exists();
    assert not (_client_dir / "mobile_dev_host.jac").exists();

    content = target_jac.read_text();
    assert "obj MobileTarget(ClientTarget)" in content , (
        "MobileTarget must extend ClientTarget directly (D3), not WebTarget"
    );
    # D3 belt-and-suspenders: no `WebTarget` in any import/inheritance position.
    # Docstrings explaining the decision are fine, so we don't ban the literal
    # token, only the import/extension forms.
    assert "import from jaclang.client.targets.web_target" not in content;
    assert "MobileTarget(WebTarget)" not in content;
    assert 'name: str = "mobile"' in content;
    assert "requires_setup: bool = True" in content;
    assert 'config_section: str = "react_native"' in content;
    assert "`default" not in content , "ClientTarget has no default flag any more";
}

test "the mobile kind resolves to the mobile target" {
    import from jaclang.client.targets.registry {
        KIND_TARGET,
        get_target_registry,
        target_for_kind
    }
    import from jaclang.project.kinds {
        KIND_SPECS,
        MOBILE_PLATFORMS,
        UI_MOBUI,
        kind_has_client,
        kind_is_mobui,
        kind_ui
    }

    # The kind is the whole story: no client axis, no alias table.
    assert KIND_TARGET["mobile"] == "mobile";
    assert UI_MOBUI == "mobui";
    assert kind_ui("mobile") == UI_MOBUI;
    assert kind_is_mobui("mobile") and kind_has_client("mobile");
    assert KIND_SPECS["mobile"].ui == "mobui";
    assert KIND_SPECS["mobile"].flags == {} , (
        "the mobile kind carries no client flag; the kind decides the target"
    );
    assert MOBILE_PLATFORMS == ["android", "ios", "web"];

    _register_client_targets();
    assert sorted(t.name for t in get_target_registry().get_all())
        == ["desktop", "mobile", "static", "web"] , (
        "exactly four targets register: web, static, desktop, mobile"
    );
    target = target_for_kind("mobile", Path.cwd());
    assert target.name == "mobile";
    assert target.requires_setup == True;
    assert not hasattr(target, "default") , "ClientTarget has no default flag";
    assert target.config_section == "react_native";
    assert target.project_dir == Path.cwd();
    # The documented target surface (D11): lifecycle methods present; RN
    # computes artifact paths per platform, so the static output_dir field
    # stays at the base default.
    assert hasattr(target, "setup");
    assert hasattr(target, "build");
    assert hasattr(target, "dev");
    assert hasattr(target, "start");
    assert target.output_dir is None;
    # Kinds without a client are a hard error, not a fallback to web.
    for kind in ["cli", "service", "py-package", "banana"] {
        raised = False;
        try {
            target_for_kind(kind, Path.cwd());
        } except ValueError as e {
            raised = True;
            assert kind in str(e) , str(e);
        }
        assert raised , f"target_for_kind({kind!r}) must raise";
    }
}

test "target_for_app reads the app's kind" {
    import from jaclang.client.targets.registry { target_for_app }
    import from jaclang.project.config { JacConfig }

    _register_client_targets();
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.phone]\nkind = "mobile"\npath = "phone"\n\n'
        '[apps.site]\nkind = "web-app"\npath = "site"\n\n'
        '[apps.page]\nkind = "web-static"\npath = "page"\n\n'
        '[apps.shell]\nkind = "desktop"\npath = "shell"\n\n'
        '[apps.api]\nkind = "service"\npath = "api"\n'
    );
    expected = {"phone": "mobile", "site": "web", "page": "static", "shell": "desktop"};
    for (name, target_name) in expected.items() {
        assert target_for_app(cfg.apps[name], Path.cwd()).name == target_name , (
            f"app {name} ({cfg.apps[name].kind}) must build with the "
            f"{target_name} target"
        );
    }
    raised = False;
    try {
        target_for_app(cfg.apps["api"], Path.cwd());
    } except ValueError as e {
        raised = True;
        assert "service" in str(e) , str(e);
    }
    assert raised , "a service app has no client target";
}

test "mobile build rejects platforms outside android, ios and web" {
    import tempfile;
    import from jaclang.client.targets.registry { target_for_kind }

    _register_client_targets();
    with tempfile.TemporaryDirectory() as tmp {
        target = target_for_kind("mobile", Path(tmp));
        for bad in ["windows", "macos", "linux", "all"] {
            raised = False;
            try {
                target.build(Path(tmp) / "main.jac", Path(tmp), platform=bad);
            } except ValueError as e {
                raised = True;
                assert str(e)
                    == (
                        f"Unsupported mobile platform '{bad}'. "
                        "Use --platform android, ios, or web."
                    ) , str(e);
            }
            assert raised , f"platform {bad!r} must be rejected before any build";
        }
    }
}

test "mobile dev fails fast when scaffold is missing" {
    # The Metro Fast Refresh loop is wired into dev, so `dev` no longer raises
    # NotImplementedError. Instead, calling it without a scaffold must
    # raise a RuntimeError pointing the user at `jac setup <app>`
    # — the contract is "explicit failure, never silent partial work".
    import tempfile;
    import from jaclang.client.targets.registry { target_for_kind }

    _register_client_targets();
    with tempfile.TemporaryDirectory() as tmp {
        target = target_for_kind("mobile", Path(tmp));
        try {
            target.dev(Path(tmp) / "main.jac", Path(tmp));
            assert False , "expected dev() to raise when scaffold is missing";
        } except NotImplementedError as e {
            assert False , (
                "dev() should no longer raise NotImplementedError now "
                f"that the new dev flow is in place; got: {e}"
            );
        } except RuntimeError as e {
            assert "jac setup <app>" in str(e) , (
                f"missing-scaffold error must point at setup command: {e}"
            );
            assert "--client" not in str(e) , (
                f"the --client flag is gone; the hint must not mention it: {e}"
            );
        }
    }
}

test "mobile build source includes iOS, web and release wiring" {
    # The iOS path now uses the real build flow instead of the old
    # NotImplementedError. Keep this as a source-level contract check so the
    # test suite stays deterministic (no Node/Xcode/EAS requirement).
    impl_path = _targets_dir / "impl" / "mobile_target.impl.jac";
    build_path = _targets_dir / "react_native" / "build.jac";
    cfg_path = _targets_dir / "react_native" / "config.jac";

    impl_content = impl_path.read_text();
    build_content = build_path.read_text();
    cfg_content = cfg_path.read_text();

    build_section = impl_content.split("impl MobileTarget.build")[1].split(
        "impl MobileTarget.dev"
    )[0];
    assert "NotImplementedError" not in build_section;
    # --platform web is the browser preview: it is the web target's bundle
    # (react-native-web), not a native build.
    assert 'if plat == "web"' in build_section;
    assert "WebTarget" in build_section;
    assert "Use --platform android, ios, or web." in build_section;
    # No user-facing hint names the retired --client flag.
    assert "--client" not in impl_content;
    assert "jac build --platform ios <app>" in build_section;
    assert "run_xcodebuild_ios" in build_section;
    assert "run_eas_local_build" in build_section;
    assert "_resolve_rn_release" in build_section;
    assert "_resolve_rn_ios_builder" in build_section;
    assert "_resolve_rn_android_builder" in build_section;
    assert "_resolve_rn_eas_update_enabled" in build_section;
    assert "iOS native build requested on non-macOS host" in build_section;
    assert "EAS Build cloud" in build_section;

    assert "def run_xcodebuild_ios" in build_content;
    assert "def run_eas_local_build" in build_content;
    assert "def run_eas_update_opt_in" in build_content;
    # xcodebuild path returns a .app bundle for simctl install, not an .ipa.
    assert "def _package_ios_app_as_ipa" not in build_content;
    assert ".app" in build_content;
    assert "expo prebuild" in build_content;

    assert "def _resolve_rn_release" in cfg_content;
    assert "def _resolve_rn_ios_builder" in cfg_content;
    assert "def _resolve_rn_android_builder" in cfg_content;
}


test "native runtime file ships parallel to the web runtime" {
    # D9: shared logic lives in client_react_core; native is platform adapters.
    runtime_core = _client_dir / "client_react_core.jac";
    runtime_core_impl = _client_dir / "impl" / "client_react_core.impl.jac";
    runtime_native = _client_dir / "client_runtime_native.jac";
    runtime_native_impl = _client_dir / "impl" / "client_runtime_native.impl.jac";

    assert runtime_core.exists() , (
        f"client_react_core.jac not found at {runtime_core}"
    );
    assert runtime_core_impl.exists();
    assert runtime_native.exists() , (
        f"client_runtime_native.jac not found at {runtime_native}"
    );
    assert runtime_native_impl.exists();
    assert "import from client_react_core" in runtime_native.read_text();

    core_content = runtime_core.read_text();
    cl_content = runtime_native.read_text();
    impl_content = runtime_native_impl.read_text();

    # Renderer dispatch lives in core (R3); native supplies __jacNativeCreate.
    assert "__jacJsx" in core_content;
    assert "__jacRegisterRenderer" in core_content;
    assert "__jacNativeCreate" in cl_content;
    assert "__jacNativeCreate" in impl_content;
    # Must import from react-native, not react-dom / react-router.
    assert "from 'react-native'" in cl_content;
    assert "@react-navigation/native" in cl_content;
    assert "@react-navigation/native-stack" in cl_content;
    assert "expo-secure-store" in cl_content;
    forbidden_imports = [
        "from 'react-dom",
        "from 'react-router-dom'",
        "from \"react-dom",
        "from \"react-router-dom\""
    ];
    for needle in forbidden_imports {
        assert needle not in cl_content , (
            f"native runtime leaked web import: {needle!r}"
        );
        assert needle not in impl_content , (
            f"native runtime impl leaked web import: {needle!r}"
        );
    }
    # Symbols only valid in DOM context must not appear as identifiers in
    # the impl (comments are fine — they document the contrast).
    forbidden_symbols = ["createRoot(", "BrowserRouter(", "document.getElementById"];
    for needle in forbidden_symbols {
        assert needle not in impl_content , (
            f"native runtime impl uses web-only symbol: {needle!r}"
        );
    }
    # Router surface is implemented via React Navigation; no
    # placeholder stubs should remain.
    assert "__nativeRouterStub" not in cl_content;
    assert "__nativeRouterStub" not in impl_content;
    # Q8 follow-up: img src -> RN Image source adaptation exists.
    assert "_adaptImageProps" in impl_content;
    assert 'uri.startswith("/")' in impl_content;
    assert "_RELATIVE_IMG_SRC_WARNED" in impl_content;
    assert "__JAC_RN_ASSET_MAP__" in impl_content;
    assert "__jac_rn_asset__:" in impl_content;
    assert "10.0.2.2" not in impl_content;
    assert "Missing API base URL" in impl_content;
    assert 'field_type == "select"' in impl_content;
    assert 'field_type == "radio"' in impl_content;
    assert "_getEnumOptions" in impl_content;
}

test "JacClientCompiler selects the native runtime with native=True" {
    # The compiler takes one boolean, `native`, in place of the old
    # target-name axis: native=True swaps in the React Native runtime and the
    # .native.jac variants, so the mobile target needs no bundler glue.
    # Source-level contract check.
    src_path = _client_dir / "jac_client_compiler.jac";
    impl_path = _client_dir / "impl" / "jac_client_compiler.impl.jac";
    src_content = src_path.read_text();
    impl_content = impl_path.read_text();

    assert 'NATIVE_RUNTIME_FILE = "client_runtime_native.jac"' in src_content , (
        "JacClientCompiler must name the single native runtime file"
    );
    assert "PLATFORM_RUNTIME_FILES" not in src_content , (
        "the per-target runtime map is gone: native is a boolean"
    );
    assert "native: bool = False" in src_content;
    assert "target_name" not in src_content , "compile() takes native=, not target_name=";
    assert "target_name" not in impl_content;
    assert "self.compile_runtime_utils(self.NATIVE_RUNTIME_FILE)" in impl_content;
    assert "COMPOUND_EXTENSIONS = ['.native.jac']" in src_content , (
        "COMPOUND_EXTENSIONS must strip .native.jac ahead of the plain .jac "
        "fallback so Header.native.jac maps to Header.js (not Header.native.js)."
    );
    assert "client_react_core.jac" in impl_content , (
        "compile_runtime_utils must bundle client_react_core (D9)"
    );
    assert "_bundle_runtime_js" in impl_content;
}

test "ViteCompiler wires jac_client_compiler on init" {
    impl_path = _client_dir / "impl" / "compiler.impl.jac";
    impl_content = impl_path.read_text();

    assert "self.jac_client_compiler = JacClientCompiler(" in impl_content , (
        "ViteCompiler.init must construct JacClientCompiler so react-native "
        "targets can reach the bundler-agnostic compile layer."
    );
    # Both compilers must share one compiled dir (the engine owns it).
    assert "compiled_dir = self.jac_client_compiler.compiled_dir" in impl_content;
    assert "self.compiled_dir = compiled_dir" in impl_content;
}

test "mobile target addresses the entry by project-relative module path" {
    impl_path = _targets_dir / "impl" / "mobile_target.impl.jac";
    impl_content = impl_path.read_text();

    assert "entry_file.stem" not in impl_content , (
        "the entry must be addressed by its project-relative module path; "
        "entry_file.stem drops the directory for a nested entry and only "
        "half-strips compound extensions like .jac"
    );
    assert impl_content.count(
        "entry_module: str = entry_module_for(entry_file, project_dir)"
    )
        == 2 , ("both build() and dev() must resolve the entry module the same way");
}

test "client compiler selects .native variants when native=True" {
    impl_path = _client_dir / "impl" / "jac_client_compiler.impl.jac";
    impl_content = impl_path.read_text();

    assert "if native {" in impl_content;
    assert "_native_variant" in impl_content;
    assert ".native.jac" in impl_content , (
        "the stem probe must cover the suffixed variant pair"
    );
    assert ".native.jac" in impl_content , (
        "the stem probe must cover the markerless variant pair"
    );
    assert "base_stem" in impl_content , (
        "variant resolution keys on the module stem, not the .jac extension"
    );
    assert "native=native" in impl_content;
    assert "_scan_and_compile_pages(" in impl_content;
    assert "native=native" in impl_content.split("_scan_and_compile_pages(")[1] , (
        "page modules must be compiled with the same native flag as the entry"
    );
}


test "target selection keeps web and native entry/runtime paths separate" {
    # Invariant: target flag controls runtime + entry strategy.
    # RN uses Expo registerRootComponent; web keeps its own entry wiring.
    rn_build_src = _targets_dir / "react_native" / "build.jac";
    rn_impl_src = _targets_dir / "impl" / "mobile_target.impl.jac";
    rn_dev_src = _targets_dir / "react_native" / "dev.jac";
    web_compiler_impl = _client_dir / "impl" / "compiler.impl.jac";
    web_target_impl = _targets_dir / "impl" / "web_target.impl.jac";

    rn_build_content = rn_build_src.read_text();
    rn_impl_content = rn_impl_src.read_text();
    rn_dev_content = rn_dev_src.read_text();
    web_content = web_compiler_impl.read_text();

    assert "registerRootComponent(App)" in rn_build_content;
    assert "native=True" in rn_impl_content;
    assert "native=True" in rn_dev_content;
    # Web compile path should not force native runtime.
    assert "native=True" not in web_content;
    assert "native=True" not in web_target_impl.read_text();
}

test "react native scaffold writes Expo project files" {
    # Smoke-test the scaffold writer end to end: setup an empty project dir,
    # run write_expo_scaffold, assert the canonical files exist and that the
    # generated metro.config.js points @jac/runtime at the staged native runtime.
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        assert (rn_dir / "package.json").exists();
        assert (rn_dir / "app.json").exists();
        assert (rn_dir / "metro.config.js").exists();
        assert (rn_dir / "babel.config.js").exists();
        assert (rn_dir / "index.ts").exists();
        assert (rn_dir / "app" / "App.tsx").exists();
        metro_content = (rn_dir / "metro.config.js").read_text();
        pkg_content = (rn_dir / "package.json").read_text();
        app_content = (rn_dir / "app" / "App.tsx").read_text();
        index_content = (rn_dir / "index.ts").read_text();
        tsconfig_content = (rn_dir / "tsconfig.json").read_text();
        # Metro must alias @jac/runtime to the compiled runtime so the
        # bundle gets the native variant at resolution time.
        assert "@jac/runtime" in metro_content;
        assert "client_runtime.js" in metro_content;
        assert "jac-src" in metro_content;
        assert "const compiledDir" not in metro_content;
        assert "config.watchFolders" not in metro_content;
        assert "path.resolve(compiledDir, 'client_runtime.js')" not in metro_content;
        assert "@react-navigation/native" in pkg_content;
        assert "@react-navigation/native-stack" in pkg_content;
        assert "react-native-screens" in pkg_content;
        assert "expo-asset" in pkg_content;
        assert "react-native-gesture-handler" in pkg_content;
        assert "import 'react-native-gesture-handler';" in index_content;
        assert "registerRootComponent(App);" in index_content;
        assert "AppRegistry.registerComponent" not in index_content;
        assert "from '../jac-app'" in app_content;
        assert "SafeAreaProvider" in app_content;
        assert "react-native-safe-area-context" in app_content;
        assert "SafeAreaView, StatusBar } from 'react-native'" not in app_content;
        assert '"strict": false' in tsconfig_content;
        assert '"strict": true' not in tsconfig_content;
        app_json = (rn_dir / "app.json").read_text();
        # D8: New Architecture + Hermes from day one.
        assert "newArchEnabled" in app_json;
        assert "hermes" in app_json;
    }
}

test "scaffold merges [dependencies.npm.native] into package.json" {
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        (project_root / "jac.toml").write_text(
            "[project]\n"
            'name = "demo"\n\n'
            "[dependencies.npm]\n"
            'left-pad = "^1.3.0"\n\n'
            "[dependencies.npm.native]\n"
            'react-native-webview = "^13.15.0"\n'
            'react-native-svg = "^15.13.0"\n'
        );
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        pkg_content = (rn_dir / "package.json").read_text();
        assert "react-native-webview" in pkg_content;
        assert "^13.15.0" in pkg_content;
        assert "react-native-svg" in pkg_content;
        assert "left-pad" not in pkg_content;
        assert "react-native-gesture-handler" in pkg_content;
        assert "expo-asset" in pkg_content;
    }
}

test "scaffold tolerates a project with no jac.toml" {
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        assert (rn_dir / "package.json").exists();
        assert "expo" in (rn_dir / "package.json").read_text();
    }
}

"""Build a temp project whose client entry is nested below the project root and
imports a module that lives above it, then return (compiler, entry)."""
def _nested_entry_project(proj: Path) -> tuple[any, Path] {
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
    (proj / "shared").mkdir(parents=True, exist_ok=True);
    (proj / "shared" / "utils.jac").write_text(
        'def:pub format_date(d: str) -> str {\n    return "on " + d;\n}\n'
    );
    (proj / "apps" / "mobile").mkdir(parents=True, exist_ok=True);
    `entry = proj / "apps" / "mobile" / "main.jac";
    `entry.write_text(
        'import from ...shared.utils { format_date }\n\n'
        'def:pub app() -> any {\n'
        '    return <div>{format_date("fri")}</div>;\n'
        '}\n'
    );
    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler().jac_client_compiler;
    compiler.compiled_dir = proj / "out";
    compiler.project_dir = proj;
    return (compiler, `entry);
}

test "nested client entry stages deps at project-relative paths, not flat" {
    import tempfile;

    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(str(tmp)).resolve();
        (compiler, `entry) = _nested_entry_project(proj);
        compiler.compile(None, `entry);
        out = proj / "out";
        assert (out / "apps" / "mobile" / "main.js").exists() , (
            "nested entry must compile to its project-relative path"
        );
        assert (out / "shared" / "utils.js").exists() , (
            "a dep above the entry must keep its project-relative path"
        );
        assert not (out / "utils.js").exists() , (
            "dep was staged flat: the emitted import points at "
            "../../shared/utils.js and will not resolve"
        );
    }
}

test "entry outside the project dir stages relative to its own folder" {
    # Guards the fallback: source_root may only be the project dir when the
    # entry actually lives under it. Rooting at an unrelated project dir makes
    # every relative_to() raise, collapsing the whole tree to flat output.
    import tempfile;
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(str(tmp)).resolve();
        (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
        app = proj / "app";
        (app / "src").mkdir(parents=True, exist_ok=True);
        (app / "src" / "header.jac").write_text(
            'def:pub Header() -> any {\n    return <div>hi</div>;\n}\n'
        );
        `entry = app / "main.jac";
        `entry.write_text(
            'import from .src.header { Header }\n\n'
            'def:pub app() -> any {\n    return <div><Header/></div>;\n}\n'
        );
        builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
        compiler = builder._get_compiler().jac_client_compiler;
        compiler.compiled_dir = proj / "out";
        # project_dir deliberately does not contain the entry.
        compiler.project_dir = proj / "unrelated";
        compiler.compile(None, `entry);
        out = proj / "out";
        assert (out / "main.js").exists() , (
            "entry must still stage relative to its own folder"
        );
        assert (out / "src" / "header.js").exists() , (
            "a dep below the entry must keep its relative path; rooting at an "
            "unrelated project dir flattens it and breaks the emitted import"
        );
        assert not (out / "header.js").exists() , (
            "dep was staged flat instead of under src/"
        );
    }
}

test "entry_module_for matches the path the compiler actually writes" {
    import tempfile;
    import from jaclang.client.targets.react_native.build { entry_module_for }
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(str(tmp)).resolve();
        (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
        builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
        compiler = builder._get_compiler().jac_client_compiler;
        for rel in [
            "apps/mobile/main.jac",
            "apps/mobile/main.jac",
            "apps/mobile/main.native.jac",
            "apps/mobile/main.impl.jac",
            "shared/widgets.jac",
            "main.jac"
        ] {
            f = proj / rel;
            f.parent.mkdir(parents=True, exist_ok=True);
            f.write_text("");
            expected = compiler._jac_path_to_js(rel);
            got = entry_module_for(f, proj) + ".js";
            assert got == expected , (
                f"entry module for {rel} resolved to {got!r} but the compiler "
                f"writes it to {expected!r}"
            );
        }
    }
}

test "scaffold preserves user-edited files on re-run" {
    # Re-running setup must not stomp on user customizations. The scaffold
    # marker line opts a file into auto-refresh; removing it pins the file.
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        # Simulate user editing App.tsx and removing the scaffold marker.
        app_tsx = rn_dir / "app" / "App.tsx";
        custom = "// my own shell\nexport default function App() { return null; }\n";
        app_tsx.write_text(custom);
        # Re-run scaffold. App.tsx should be left alone; metro.config.js
        # (still marker-managed) should be refreshed.
        write_expo_scaffold(rn_dir, project_root);
        assert app_tsx.read_text() == custom , (
            "scaffold clobbered user-edited App.tsx"
        );
        # metro.config.js must still be present (refreshed)
        assert (rn_dir / "metro.config.js").exists();
    }
}

test "scaffold refreshes auto-generated index.ts on re-run" {
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        index_path = rn_dir / "index.ts";
        jac_app_path = rn_dir / "jac-app.js";
        # Files a previous `jac build <app>` wrote carry this banner; the
        # scaffold treats it as its own and refreshes them.
        index_path.write_text(
            "// Auto-generated by jac build <app> (mobile). Do not edit.\n"
            "import { registerRootComponent } from 'expo';\n"
            "const App = () => null;\n"
            "registerRootComponent(App);\n",
            encoding="utf-8"
        );
        jac_app_path.write_text(
            "// Auto-generated by jac build <app> (mobile). Do not edit.\n"
            "export { app } from './jac-src/main.js';\n",
            encoding="utf-8"
        );
        write_expo_scaffold(rn_dir, project_root);
        refreshed = index_path.read_text(encoding="utf-8");
        refreshed_app = jac_app_path.read_text(encoding="utf-8");
        assert "jac-client: scaffold-managed" in refreshed;
        assert "const App = () => null;" not in refreshed;
        assert "jac-client: scaffold-managed" in refreshed_app;
        assert "export { app } from './jac-src/main.js';" not in refreshed_app;
    }
}

test "lint_unmapped_tags flags HTML tags outside the documented map" {
    # The compile-time lint pass (D10) scans compiled JS for __jacJsx calls
    # using HTML tags outside the supported subset. Construct a fake
    # compiled dir with both supported and unsupported tags and assert
    # the lint result.
    import tempfile;
    import from jaclang.client.targets.react_native.build { lint_unmapped_tags }

    with tempfile.TemporaryDirectory() as tmp {
        compiled = Path(tmp);
        # `div` and `button` are supported; `marquee` and `details` aren't.
        (compiled / "user.js").write_text(
            '__jacJsx("div", {}, [__jacJsx("button", {}, ["click"])]);\n'
            '__jacJsx("marquee", {}, ["whee"]);\n'
            '__jacJsx("details", {}, []);\n'
        );
        # client_runtime.js should be ignored (it contains the tag-map
        # literals which would generate false positives).
        (compiled / "client_runtime.js").write_text(
            '__jacJsx("marquee", {}, []); // tag-map self-test\n'
        );
        unmapped = lint_unmapped_tags(compiled);
        assert "marquee" in unmapped;
        assert "details" in unmapped;
        assert "div" not in unmapped;
        assert "button" not in unmapped;
    }
}

test "html tag map is shared between build lint and native runtime" {
    import from jaclang.client.targets.react_native.html_tag_map {
        RN_HTML_VIEW_TAGS,
        RN_HTML_TEXT_TAGS,
        RN_HTML_SPECIAL_TAGS,
        supported_rn_html_tags
    }

    runtime_native = _client_dir / "client_runtime_native.jac";
    runtime_text = runtime_native.read_text();
    assert "html_tag_map" in runtime_text;
    assert "RN_HTML_VIEW_TAGS as _VIEW_TAGS" in runtime_text;
    assert "RN_HTML_TEXT_TAGS as _TEXT_TAGS" in runtime_text;

    expected = supported_rn_html_tags();
    assert "div" in expected;
    assert "button" in expected;
    assert "marquee" not in expected;
    assert len(expected)
        == (
            len(RN_HTML_VIEW_TAGS) + len(RN_HTML_TEXT_TAGS) + len(RN_HTML_SPECIAL_TAGS)
        );
}

test "lint_native_incompatible_usage flags css imports and web globals" {
    import tempfile;
    import from jaclang.client.targets.react_native.build {
        lint_native_incompatible_usage
    }

    with tempfile.TemporaryDirectory() as tmp {
        compiled = Path(tmp);
        (compiled / "feature.js").write_text(
            'import "./styles.css";\n'
            'const w = window.location.href;\n'
            'document.title = "x";\n'
            'localStorage.setItem("a", "b");\n'
            '__jacJsx("img", {src: "./avatar.png"}, []);\n'
            '__jacJsx("img", {src: "/static/assets/logo.png"}, []);\n'
        );
        # Runtime file is excluded from lint scanning by design.
        (compiled / "client_runtime.js").write_text(
            'import "./ignored.css";\nconst x = window;\n'
        );
        result = lint_native_incompatible_usage(compiled);
        assert "./styles.css" in result["css_imports"];
        assert "window" in result["web_globals"];
        assert "document" in result["web_globals"];
        assert "localStorage" in result["web_globals"];
        assert "ignored.css" not in result["css_imports"];
        assert "./avatar.png" in result["relative_img_srcs"];
        assert "./avatar.png" in result["unresolved_relative_img_srcs"];
        assert "/static/assets/logo.png" not in result["relative_img_srcs"];
    }
}

test "stage_native_image_assets rewrites relative img src to Metro token map" {
    import tempfile;
    import from jaclang.client.targets.react_native.build { stage_native_image_assets }

    with tempfile.TemporaryDirectory() as tmp {
        tmp_path = Path(tmp);
        compiled = tmp_path / "compiled";
        rn_dir = tmp_path / "mobile-rn";
        compiled.mkdir(parents=True);
        rn_dir.mkdir(parents=True);
        (compiled / "avatar.png").write_bytes(b"pngbytes");
        (compiled / "feature.js").write_text(
            '__jacJsx("img", {src: "./avatar.png"}, []);\n'
        );
        result = stage_native_image_assets(compiled, rn_dir);
        rewritten = (compiled / "feature.js").read_text();
        registry = (rn_dir / "jac-asset-registry.js").read_text();
        assert result["bundled_count"] == 1;
        assert result["unresolved_relative_img_srcs"] == [];
        assert "__jac_rn_asset__:" in rewritten;
        assert "require('./jac-assets/" in registry;
        assert (rn_dir / "jac-assets").exists();
        staged_assets = list((rn_dir / "jac-assets").`glob("*"));
        assert len(staged_assets) == 1;
    }
}

test "stage_compiled_entry injects asset registry import" {
    import tempfile;
    import from jaclang.client.targets.react_native.build {
        stage_compiled_entry,
        stage_native_image_assets
    }

    with tempfile.TemporaryDirectory() as tmp {
        tmp_path = Path(tmp);
        compiled = tmp_path / "compiled";
        rn_dir = tmp_path / "mobile-rn";
        compiled.mkdir(parents=True);
        rn_dir.mkdir(parents=True);
        (compiled / "main.js").write_text("export const app = () => null;\n");
        stage_compiled_entry(compiled, rn_dir, "main");
        stage_native_image_assets(rn_dir / "jac-src", rn_dir);
        staged = (rn_dir / "jac-app.js").read_text();
        assert "Auto-generated by jac build <app> (mobile)" in staged;
        assert "--client" not in staged;
        assert "import './jac-asset-registry';" in staged;
    }
}

test "stage_native_image_assets leaves canonical compiled dir unchanged" {
    import tempfile;
    import from jaclang.client.targets.react_native.build {
        stage_compiled_entry,
        stage_native_image_assets
    }

    with tempfile.TemporaryDirectory() as tmp {
        tmp_path = Path(tmp);
        compiled = tmp_path / "compiled";
        rn_dir = tmp_path / "mobile-rn";
        compiled.mkdir(parents=True);
        rn_dir.mkdir(parents=True);
        original_src = '__jacJsx("img", {src: "./avatar.png"}, []);\n';
        (compiled / "avatar.png").write_bytes(b"pngbytes");
        (compiled / "feature.js").write_text(original_src);
        stage_compiled_entry(compiled, rn_dir, "feature");
        stage_native_image_assets(rn_dir / "jac-src", rn_dir);
        assert (compiled / "feature.js").read_text() == original_src;
        staged_js = (rn_dir / "jac-src" / "feature.js").read_text();
        assert "__jac_rn_asset__:" in staged_js;
        assert "./avatar.png" not in staged_js;
    }
}


test "dev helpers exist and are importable" {
    # The dev module is the entry point for `jac run --dev <app>` on a
    # mobile app. Importing it must succeed and expose the helper surface the
    # target impl depends on; the impl uses each by name, so a missing
    # export would be a build-time failure for users.
    import from jaclang.client.targets.react_native.dev {
        DEFAULT_METRO_PORT,
        JAC_RN_DEV_HOST_ENV,
        JAC_RN_METRO_PORT_ENV,
        build_expo_start_argv,
        inject_dev_api_base_url,
        resolve_metro_port,
        restore_app_json,
        rn_hmr_on_jac_changed,
        run_expo_start,
        setup_android_port_reverse
    }

    assert DEFAULT_METRO_PORT == 8081 , (
        "Metro's documented default is 8081; changing it without a "
        "corresponding scaffold update would break adb-reverse + Expo CLI."
    );
    assert JAC_RN_METRO_PORT_ENV == "JAC_RN_METRO_PORT";
    assert JAC_RN_DEV_HOST_ENV == "JAC_RN_DEV_HOST";
}

test "resolve_metro_port honors env override over cli value" {
    import os;
    import from jaclang.client.targets.react_native.dev {
        JAC_RN_METRO_PORT_ENV,
        resolve_metro_port
    }

    prev = os.environ.get(JAC_RN_METRO_PORT_ENV, None);
    try {
        os.environ[JAC_RN_METRO_PORT_ENV] = "19999";
        assert resolve_metro_port(8081) == 19999;
        os.environ[JAC_RN_METRO_PORT_ENV] = "";
        assert resolve_metro_port(8081) == 8081;
    } finally {
        if prev is None {
            if JAC_RN_METRO_PORT_ENV in os.environ {
                del os.environ[JAC_RN_METRO_PORT_ENV];
            }
        } else {
            os.environ[JAC_RN_METRO_PORT_ENV] = prev;
        }
    }
}

test "resolve_rn_port_or_next_available bumps away from a busy port" {
    import socket;
    import from jaclang.client.targets.client_dev_common {
        resolve_port_or_next_available
    }

    try {
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    } except PermissionError {
        return;
    }
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0);
    s.bind(("127.0.0.1", 0));
    busy_port = s.getsockname()[1];
    s.listen(1);
    try {
        chosen = resolve_port_or_next_available(busy_port, "API");
        assert chosen > busy_port , (
            f"Expected auto-port fallback to move past busy port {busy_port}, got {chosen}"
        );
    } finally {
        s.close();
    }
}

test "resolve_rn_port_or_next_available skips reserved ports" {
    import socket;
    import from jaclang.client.targets.client_dev_common {
        resolve_port_or_next_available
    }

    # Pick a currently free base port, then mark it reserved so resolver
    # must move upward even though bind would succeed.
    try {
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    } except PermissionError {
        return;
    }
    s.bind(("127.0.0.1", 0));
    base_port: int = s.getsockname()[1];
    s.close();

    chosen = resolve_port_or_next_available(
        base_port, "API", reserved=[base_port], max_scan=50
    );
    assert chosen > base_port , (
        f"Reserved base port {base_port} must not be selected; got {chosen}"
    );
}

test "build_expo_start_argv emits expected metro flags" {
    # Pure helper — easy to assert and the surface most likely to drift
    # if someone tweaks the dev loop without rerunning the smoke test.
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.react_native.dev { build_expo_start_argv }

    def _fake_get_bun -> str {
        return "/opt/jac/_bun/bun";
    }

    with tempfile.TemporaryDirectory() as tmp {
        rn_dir = Path(tmp);
        `entry = _stub_node_tool(rn_dir, "expo", "expo");
        with unittest.mock.patch(
            "jaclang.client.targets.node_tooling_common.get_bun",
            side_effect=_fake_get_bun
        ) {
            argv = build_expo_start_argv(rn_dir, 8081, clear_cache=True);
            argv2 = build_expo_start_argv(rn_dir, 9090, clear_cache=False);
        }
        # Expo's own JS entry is the argument bun runs; `bun x expo` would
        # dispatch on the `.bin` shim's node shebang instead.
        assert argv[:2] == ["/opt/jac/_bun/bun", str(`entry.resolve())];
    }
    assert "start" in argv;
    assert "--port" in argv;
    assert "8081" in argv;
    assert "--clear" in argv;
    assert "x" not in argv;

    assert "9090" in argv2;
    assert "--clear" not in argv2;
}

test "inject_dev_api_base_url rewrites app.json and roundtrips" {
    # Verifies the round-trip invariant: inject returns the original raw
    # bytes; restore puts them back verbatim. This is what guarantees the
    # user's pre-dev app.json (often hand-edited extra fields) survives a
    # `jac run --dev` session unscathed.
    import json;
    import tempfile;
    import from jaclang.client.targets.react_native.dev {
        inject_dev_api_base_url,
        restore_app_json
    }

    with tempfile.TemporaryDirectory() as tmp {
        rn_dir = Path(tmp);
        original_cfg = {
            "expo": {
                "name": "main",
                "extra": {"apiBaseUrl": "http://baked.example", "feature": True}
            }
        };
        app_json = rn_dir / "app.json";
        original_text = json.dumps(original_cfg, indent=2) + "\n";
        app_json.write_text(original_text, encoding="utf-8");
        returned = inject_dev_api_base_url(rn_dir, "http://10.0.0.5:8000");
        assert returned == original_text;
        after = json.loads(app_json.read_text(encoding="utf-8"));
        assert after["expo"]["extra"]["apiBaseUrl"] == "http://10.0.0.5:8000";
        # Other fields preserved (we only touch apiBaseUrl).
        assert after["expo"]["extra"]["feature"] == True;
        assert after["expo"]["name"] == "main";
        restore_app_json(rn_dir, returned);
        assert app_json.read_text(encoding="utf-8") == original_text;
    }
}

test "inject_dev_api_base_url no-ops gracefully on missing app.json" {
    import tempfile;
    import from jaclang.client.targets.react_native.dev {
        inject_dev_api_base_url,
        restore_app_json
    }

    with tempfile.TemporaryDirectory() as tmp {
        rn_dir = Path(tmp);
        # No app.json written. inject must return None so the caller's
        # `finally restore_app_json(...)` is a no-op rather than writing
        # garbage to a file that should stay absent.
        result = inject_dev_api_base_url(rn_dir, "http://localhost:8000");
        assert result is None;
        # restore must also no-op cleanly given None.
        restore_app_json(rn_dir, None);
        assert not (rn_dir / "app.json").exists();
    }
}

test "_RNHmrHandler obj is declared and wired in target module" {
    # Source-level check that the dev loop's watcher binding exists; a
    # missing handler would silently disable Fast Refresh recompiles.
    target_jac = _targets_dir / "mobile_target.jac";
    impl_jac = _targets_dir / "impl" / "mobile_target.impl.jac";
    target_content = target_jac.read_text();
    impl_content = impl_jac.read_text();

    assert "obj _RNHmrHandler" in target_content;
    assert "rn_dir: Path" in target_content;
    assert "entry_module: str" in target_content;
    assert "impl _RNHmrHandler.on_event" in impl_content;
    assert "rn_hmr_on_jac_changed" in impl_content;
    # Dev impl must invoke the real flow, not the old NotImplementedError.
    assert "raise NotImplementedError"
        not in impl_content.split("impl MobileTarget.dev")[1].split(
            "impl MobileTarget.start"
        )[0];
    assert "run_expo_start" in impl_content;
    assert "JacFileWatcher" in impl_content;
}

test "native index entry omits web-only imports" {
    # The whole point of the per-target entry (R2) is to keep DOM and
    # react-router out of the native bundle. Regress-guard those against
    # the production entry source that ``jac build`` writes.
    import from jaclang.client.targets.react_native.build {
        build_native_index_entry_source
    }
    script = build_native_index_entry_source();

    assert "registerRootComponent" in script;
    assert "import App from './app/App'" in script;
    forbidden = [
        "react-dom",
        "createRoot",
        "document.getElementById",
        "react-router",
        "BrowserRouter"
    ];
    for needle in forbidden {
        assert needle not in script , (
            f"native entry leaked web-only symbol: {needle!r}"
        );
    }
}

test "client config scopes npm deps by the kind's target: [dependencies.npm.mobile]" {
    import tempfile;
    import from jaclang.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        jac_toml = (
            "[project]\n"
            "name = \"rn-target-deps\"\n"
            "version = \"1.0.0\"\n"
            "entry-point = \"main.jac\"\n"
            "kind = \"mobile\"\n\n"
            "[dependencies.npm]\n"
            "react = \"^19.2.0\"\n\n"
            "[dependencies.npm.mobile]\n"
            "react-native = \"0.76.6\"\n"
            "\"expo-secure-store\" = \"~14.0.1\"\n\n"
            "[dependencies.npm.react_native]\n"
            "left-pad = \"^1.3.0\"\n"
        );
        (project_dir / "jac.toml").write_text(jac_toml, encoding="utf-8");
        cfg = JacClientConfig(project_dir=project_dir).load();
        deps = cfg["package"]["dependencies"];
        assert "react" in deps;
        assert deps["react-native"] == "0.76.6";
        assert deps["expo-secure-store"] == "~14.0.1";
        # The scope tables themselves must never leak into package.json as
        # dict-valued dependencies (invalid npm manifest).
        assert "mobile" not in deps;
        assert "react_native" not in deps;
        assert all(isinstance(v, str) for v in deps.values());
        # The old [dependencies.npm.react_native] table is no longer a scope:
        # the key is the kind's target name (KIND_TARGET["mobile"] == "mobile").
        assert "left-pad" not in deps , (
            "[dependencies.npm.react_native] is not read any more; the mobile "
            "scope is [dependencies.npm.mobile]"
        );
    }
}

test "a web-app does not pick up the mobile npm scope" {
    import tempfile;
    import from jaclang.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(
            "[project]\n"
            "name = \"web-deps\"\n"
            "version = \"1.0.0\"\n"
            "entry-point = \"main.jac\"\n"
            "kind = \"web-app\"\n\n"
            "[dependencies.npm]\n"
            "react = \"^19.2.0\"\n\n"
            "[dependencies.npm.mobile]\n"
            "react-native = \"0.76.6\"\n\n"
            "[dependencies.npm.web]\n"
            "left-pad = \"^1.3.0\"\n",
            encoding="utf-8"
        );
        deps = JacClientConfig(project_dir=project_dir).load()["package"][
            "dependencies"
        ];
        assert "react-native" not in deps , "the mobile scope is mobile-only";
        assert deps["left-pad"] == "^1.3.0" , "a web-app reads the web scope";
        assert "mobile" not in deps and "web" not in deps;
    }
}

test "react native common owns detect_lan_ipv4 and imports no Capacitor helpers" {
    import from jaclang.client.targets.react_native.common { detect_lan_ipv4 }

    common_path = _targets_dir / "react_native" / "common.jac";
    content = common_path.read_text();
    assert "node_tooling_common" in content;
    # The Capacitor target and its helper modules are gone; nothing may
    # reach for them.
    assert "jaclang.client.targets.mobile.common" not in content;
    assert "mobile_dev_host" not in content;
    assert "mobile_setup_env" not in content;
    assert "_mobile_check_command_available" not in content;
    assert "_mobile_resolve_npx" not in content;
    assert "_mobile_run_install_cmd" not in content;
    assert "run_manifest_install as _run_manifest_install" not in content;
    # detect_lan_ipv4 moved here from the deleted mobile_dev_host module.
    assert "def detect_lan_ipv4" in content;
    lan = detect_lan_ipv4();
    assert lan is None or isinstance(lan, str);
}

test "client config exposes the react_native table and no Capacitor table" {
    import tempfile;
    import from jaclang.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        jac_toml = (
            "[project]\n"
            "name = \"cfg-getters\"\n"
            "version = \"1.0.0\"\n"
            "entry-point = \"main.jac\"\n\n"
            "[client.react_native]\n"
            "project_dir = \"mobile-rn-alt\"\n"
            "default_platform = \"ios\"\n"
        );
        (project_dir / "jac.toml").write_text(jac_toml, encoding="utf-8");
        cfg = JacClientConfig(project_dir=project_dir);
        cfg.load();
        rn_cfg = cfg.get_react_native_config();
        assert rn_cfg["project_dir"] == "mobile-rn-alt";
        assert rn_cfg["default_platform"] == "ios";
        # The Capacitor [client.mobile] getter went with the Capacitor target.
        assert not hasattr(cfg, "get_mobile_config") , (
            "get_mobile_config() (Capacitor [client.mobile]) must not come back"
        );
    }
}

test "mobile start honors JAC_MOBILE_PLATFORM over the configured default" {
    # `jac run --platform ios <app>` reaches MobileTarget.start through the
    # JAC_MOBILE_PLATFORM env var (run_client_start sets it); the toml
    # default_platform is the fallback, and android the last resort.
    import os;
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.registry { target_for_kind }

    _register_client_targets();
    seen: list[str] = [];

    def _fake_build(entry_file: Path, project_dir: Path, platform: any = None) -> Path {
        seen.append(str(platform));
        raise RuntimeError("stop after platform resolution");
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(
            "[project]\nname = \"t\"\nversion = \"1.0\"\nkind = \"mobile\"\n"
            "entry-point = \"main.jac\"\n\n"
            "[client.react_native]\ndefault_platform = \"ios\"\n",
            encoding="utf-8"
        );
        target = target_for_kind("mobile", project_dir);
        prev = os.environ.pop("JAC_MOBILE_PLATFORM", None);
        try {
            with unittest.mock.patch.object(target, "build", _fake_build) {
                for (env_value, expected) in [
                    ("", "ios"),
                    ("android", "android"),
                    ("IOS", "ios")
                ] {
                    if env_value {
                        os.environ["JAC_MOBILE_PLATFORM"] = env_value;
                    } else {
                        os.environ.pop("JAC_MOBILE_PLATFORM", None);
                    }
                    try {
                        target.start(project_dir / "main.jac", project_dir);
                    } except RuntimeError as e {
                        assert "stop after" in str(e) , str(e);
                    }
                    assert seen[-1] == expected , (
                        f"JAC_MOBILE_PLATFORM={env_value!r}: expected {expected}, "
                        f"got {seen[-1]}"
                    );
                }
            }
        } finally {
            if prev is None {
                os.environ.pop("JAC_MOBILE_PLATFORM", None);
            } else {
                os.environ["JAC_MOBILE_PLATFORM"] = prev;
            }
        }
    }
}

"""Lay out a tool the way `bun install` does: the package's real JS entry
plus the `node_modules/.bin` symlink, which is what carries the
`#!/usr/bin/env node` shebang."""
def _stub_node_tool(project_dir: Path, package: str, tool: str) -> Path {
    bin_dir = project_dir / "node_modules" / package / "bin";
    bin_dir.mkdir(parents=True, exist_ok=True);
    `entry = bin_dir / f"{tool}.js";
    `entry.write_text("#!/usr/bin/env node\n");
    `entry.chmod(0o755);
    shim_dir = project_dir / "node_modules" / ".bin";
    shim_dir.mkdir(parents=True, exist_ok=True);
    (shim_dir / tool).symlink_to(`entry);
    return `entry;
}

test "node tooling runs installs and tools on the bundled bun only" {
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.node_tooling_common {
        resolve_node_tool,
        run_manifest_install
    }

    calls: list[list[str]] = [];

    def _fake_run(cmd: list[str], **kwargs: dict) -> object {
        class _Res {
            has returncode: int = 0,
                stdout: str = "",
                stderr: str = "";
        }
        calls.append(cmd);
        return _Res();
    }

    def _fake_get_bun -> str {
        return "/opt/jac/_bun/bun";
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        `entry = _stub_node_tool(project_dir, "expo", "expo");
        with unittest.mock.patch("subprocess.run", side_effect=_fake_run) {
            with unittest.mock.patch(
                "jaclang.client.targets.node_tooling_common.get_bun",
                side_effect=_fake_get_bun
            ) {
                run_manifest_install(project_dir);
                runner = resolve_node_tool(project_dir, "expo");
            }
        }
        # The tool's own JS entry is named, never the `.bin` shim and never
        # `bun x`: both of those dispatch on the node shebang.
        assert runner == ["/opt/jac/_bun/bun", str(`entry.resolve())];
    }
    # No system tooling is ever probed or used -- bundled bun only.
    assert ["/opt/jac/_bun/bun", "install"] in calls;
    assert "x" not in runner;
    for cmd in calls {
        assert cmd[0] != "npm" and cmd[0] != "npx" and cmd[0] != "bunx" , (
            f"system JS tooling must never be invoked, got: {cmd}"
        );
    }
}

test "node tooling refuses to run a tool that is not installed locally" {
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.node_tooling_common { resolve_node_tool }

    def _fake_get_bun -> str {
        return "/opt/jac/_bun/bun";
    }

    # A clean break: with no local install there is nothing bun can run, and
    # falling back to `bun x` would silently reintroduce the node dependency.
    with tempfile.TemporaryDirectory() as tmp {
        with unittest.mock.patch(
            "jaclang.client.targets.node_tooling_common.get_bun",
            side_effect=_fake_get_bun
        ) {
            try {
                resolve_node_tool(Path(tmp), "expo");
                assert False , "expected RuntimeError when the tool is absent";
            } except RuntimeError as e {
                assert "expo" in str(e);
                assert "node_modules" in str(e);
            }
        }
    }
}

test "node tooling raises actionably when the bundled bun is missing" {
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.node_tooling_common { resolve_node_tool }

    def _no_bun -> None {
        return None;
    }

    with tempfile.TemporaryDirectory() as tmp {
        with unittest.mock.patch(
            "jaclang.client.targets.node_tooling_common.get_bun", side_effect=_no_bun
        ) {
            try {
                resolve_node_tool(Path(tmp), "expo");
                assert False , "expected RuntimeError when bundled bun is absent";
            } except RuntimeError as e {
                assert "fetch-bun" in str(e);
                assert "JAC_BUN" in str(e);
            }
        }
    }
}

test "expo prebuild runs even when native tree and prebuild state exist" {
    # Adding an Expo config plugin to app.json must re-run prebuild so
    # native autolinking picks it up. The old guard skipped prebuild when
    # android/ and .expo/prebuild-state.json were present.
    import json;
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.react_native.build { run_expo_prebuild }

    calls: list[list[str]] = [];

    def _fake_run(cmd: list[str], **kwargs: dict) -> object {
        class _Res {
            has returncode: int = 0,
                stdout: str = "",
                stderr: str = "";
        }
        calls.append(cmd);
        return _Res();
    }

    with tempfile.TemporaryDirectory() as tmp {
        rn_dir = Path(tmp) / "mobile-rn";
        rn_dir.mkdir();
        (rn_dir / "android").mkdir();
        expo_dir = rn_dir / ".expo";
        expo_dir.mkdir();
        (expo_dir / "prebuild-state.json").write_text(
            json.dumps({"version": 1}), encoding="utf-8"
        );
        (rn_dir / "app.json").write_text(
            json.dumps({"expo": {"plugins": ["expo-camera"]}}), encoding="utf-8"
        );
        with unittest.mock.patch(
            "jaclang.client.targets.react_native.build.resolve_node_tool",
            return_value=["/opt/jac/_bun/bun", "/expo/bin/cli.js"]
        ), unittest.mock.patch("subprocess.run", side_effect=_fake_run) {
            run_expo_prebuild(rn_dir, "android");
        }
    }

    assert [
        "/opt/jac/_bun/bun",
        "/expo/bin/cli.js",
        "prebuild",
        "--platform",
        "android",
        "--no-install"
    ]
        in calls;
}

test "dual-target gate can run e2e builds when explicitly enabled" {
    import shutil;
    import subprocess;
    import tempfile;
    try {
        import from test_helpers { get_env_with_npm, get_jac_command }
    } except ModuleNotFoundError {
        return;
    }

    if os.environ.get("JAC_PHASE3_DUAL_TARGET_GATE", "0") != "1" {
        testskip(
            "Set JAC_PHASE3_DUAL_TARGET_GATE=1 to run emulator-grade dual-target gate."
        );
    }

    fixture_src = Path(__file__).parent / "fixtures" / "react_native_multiscreen";
    if not fixture_src.exists() {
        testskip("react_native_multiscreen fixture not found");
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp) / "react_native_multiscreen";
        shutil.copytree(fixture_src, project_dir);
        env = get_env_with_npm();
        jac_cmd = get_jac_command();
        # The mobile app's browser bundle: --platform web on the mobile kind.
        web_cmd = jac_cmd + ["build", "--platform", "web", "main.jac"];
        web_result = subprocess.run(
            web_cmd,
            cwd=project_dir,
            env=env,
            capture_output=True,
            text=True,
            timeout=1200
        );
        assert web_result.returncode == 0 , (
            f"web build failed\nSTDOUT:\n{web_result.stdout}\nSTDERR:\n{web_result.stderr}"
        );
        rn_cmd = jac_cmd + ["build", "--platform", "android", "main.jac"];
        rn_result = subprocess.run(
            rn_cmd,
            cwd=project_dir,
            env=env,
            capture_output=True,
            text=True,
            timeout=3600
        );
        assert rn_result.returncode == 0 , (
            "mobile android build failed\n"
            f"STDOUT:\n{rn_result.stdout}\nSTDERR:\n{rn_result.stderr}"
        );
    }
}

test "strip_css_imports removes CSS import lines and deletes CSS files" {
    import tempfile;
    import from jaclang.client.targets.react_native.build { strip_css_imports }

    with tempfile.TemporaryDirectory() as tmp {
        compiled = Path(tmp);
        # User JS with CSS imports. Covers every form a bundler emits:
        # side-effect (``import "./x.css"``), default (``import s from``),
        # and named (``import { a } from``). All three must be stripped or
        # Metro chokes on the unresolvable .css module; the bare side-effect
        # form alone is not representative of real CSS-module usage.
        (compiled / "app.js").write_text(
            'import "./styles.css";\n'
            'import "./theme.scss";\n'
            'import buttons from "./buttons.css";\n'
            'import { card } from "./card.sass";\n'
            'import wide\n'
            '  from "./wide.css";\n'
            'import {\n'
            '  panel,\n'
            '  row\n'
            '} from "./panel.less";\n'
            'import { useState } from "react";\n'
            'import "./other.js";\n'
            'console.log("hello");\n',
            encoding="utf-8"
        );
        # A CSS file that should be deleted.
        (compiled / "styles.css").write_text(".foo { color: red; }", encoding="utf-8");
        (compiled / "theme.scss").write_text("$bg: blue;", encoding="utf-8");
        (compiled / "buttons.css").write_text(
            ".btn { padding: 4px; }", encoding="utf-8"
        );
        (compiled / "card.sass").write_text(".card\n  margin: 0", encoding="utf-8");
        # A non-CSS file that should survive.
        (compiled / "other.js").write_text("export const x = 1;", encoding="utf-8");
        # Runtime file should be ignored.
        (compiled / "client_runtime.js").write_text(
            'import "./ignored.css";\n', encoding="utf-8"
        );
        count = strip_css_imports(compiled);
        assert count >= 4 , f"Expected at least 4 stripped lines, got {count}";
        app_js = (compiled / "app.js").read_text(encoding="utf-8");
        assert "styles.css" not in app_js;
        assert "theme.scss" not in app_js;
        # Named/default CSS imports must be stripped too, not just side-effect
        # ones — these were previously linted but left in the bundle.
        assert "buttons.css" not in app_js;
        assert "card.sass" not in app_js;
        # Multiline forms: a default binding split before `from`, and a
        # braced list spanning lines. The lint path catches these, so the
        # strip path must too or Metro fails on the unresolvable module.
        assert "wide.css" not in app_js;
        assert "panel.less" not in app_js;
        # Non-CSS imports must be preserved.
        assert "from \"react\"" in app_js;
        assert "other.js" in app_js;
        # CSS files deleted.
        assert not (compiled / "styles.css").exists();
        assert not (compiled / "theme.scss").exists();
        assert not (compiled / "buttons.css").exists();
        assert not (compiled / "card.sass").exists();
        # Non-CSS files survive.
        assert (compiled / "other.js").exists();
        # Runtime file untouched.
        assert (compiled / "client_runtime.js").exists();
        runtime_text = (compiled / "client_runtime.js").read_text(encoding="utf-8");
        assert "ignored.css" in runtime_text;
    }
}


test "compiler resolves .native.jac when native=True" {
    # Functional test: create a temp project with both .jac and
    # .native.jac, compile with native=True, and verify the native variant
    # was chosen.
    import tempfile;
    import from jaclang.client.config_loader { JacClientConfig }

    fixture_dir = Path(__file__).parent / "fixtures" / "react_native_dual_platform";

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp) / "dual_platform";
        import shutil;
        shutil.copytree(fixture_dir, project_dir);
        entry_file = project_dir / "main.jac";
        # Compile with native=True.
        import from jaclang.runtime.runtime { JacRuntime as Jac }
        builder: any = Jac.get_client_bundle_builder();
        vite_compiler = builder._get_compiler();
        jac_compiler = vite_compiler.jac_client_compiler;
        compiled_dir = jac_compiler.compiled_dir;
        compiled_dir.mkdir(parents=True, exist_ok=True);
        artifact = jac_compiler.jac_compiler.compile_module(entry_file);
        if artifact.js {
            jac_compiler.compile(None, entry_file, native=True);

            # The native variant should have been picked. Verify by checking
            # the compiled header.js for native-only content.
            header_js = compiled_dir / "src" / "header.js";
            if header_js.exists() {
                header_content = header_js.read_text(encoding="utf-8");
                # Native variant has "native" badge text, web has "web".
                assert "native" in header_content , (
                    "Expected native variant of header to be compiled "
                    f"but got content without 'native' marker: {header_content[:200]}"
                );
                assert "className" not in header_content , (
                    "Native variant should not contain className but does: "
                    f"{header_content[:200]}"
                );
            }

            # Now compile for web and verify the web variant is picked.
            # Clean compiled dir first.
            import shutil as shutil2;
            if compiled_dir.exists() {
                shutil2.rmtree(compiled_dir);
            }
            compiled_dir.mkdir(parents=True, exist_ok=True);

            artifact2 = jac_compiler.jac_compiler.compile_module(entry_file);
            if artifact2.js {
                jac_compiler.compile(None, entry_file);

                header_js_web = compiled_dir / "src" / "header.js";
                if header_js_web.exists() {
                    web_content = header_js_web.read_text(encoding="utf-8");
                    # Web variant has "web" badge text.
                    assert "className" in web_content , (
                        "Expected web variant of header with className "
                        f"but got: {web_content[:200]}"
                    );
                }
            }
        }
    }
}


test "mobile build pipeline calls lint, strip, and stage in correct order" {
    # Verify the build pipeline calls these functions in the right sequence:
    # lint -> strip -> copy jac-src -> rewrite images in jac-src only.
    impl_path = _targets_dir / "impl" / "mobile_target.impl.jac";
    impl_content = impl_path.read_text();

    build_section = impl_content.split("impl MobileTarget.build")[1].split(
        "impl MobileTarget.dev"
    )[0];

    lint_pos = build_section.find("lint_unmapped_tags");
    strip_pos = build_section.find("strip_css_imports");
    copy_pos = build_section.find("stage_compiled_entry");
    asset_pos = build_section.find("stage_native_image_assets");

    assert lint_pos > 0 , "build must call lint_unmapped_tags";
    assert strip_pos > 0 , "build must call strip_css_imports";
    assert copy_pos > 0 , "build must call stage_compiled_entry";
    assert asset_pos > 0 , "build must call stage_native_image_assets";
    assert lint_pos < strip_pos , (
        "lint must run before strip so warnings are visible"
    );
    assert strip_pos < copy_pos , (
        "strip must run before jac-src copy so staged modules omit CSS imports"
    );
    assert copy_pos < asset_pos , ("jac-src copy must run before image token rewrite");
    assert 'stage_native_image_assets(rn_dir / "jac-src", rn_dir)' in build_section , (
        "image staging must rewrite mobile-rn/jac-src, not .jac/client/compiled"
    );
}

# ---------------------------------------------------------------------------
# iOS, release builds, EAS, project_dir config
# ---------------------------------------------------------------------------
test "react native scaffold writes eas.json with build and update profiles" {
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }
    import from jaclang.client.targets.react_native.common {
        EAS_CLI_VERSION,
        EXPO_SDK_VERSION
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        eas_path = rn_dir / "eas.json";
        assert eas_path.exists() , f"eas.json not written by scaffold";
        import json;
        eas = json.loads(eas_path.read_text(encoding="utf-8"));
        assert "build" in eas , "eas.json must have a 'build' section";
        assert "production" in eas["build"] , (
            "eas.json must include a 'production' build profile"
        );
        assert "preview" in eas["build"] , (
            "eas.json must include a 'preview' build profile"
        );
        assert eas["build"]["preview"]["distribution"] == "internal" , (
            "preview profile must use internal distribution for testing"
        );
        assert "android" in eas["build"]["preview"] , (
            "preview profile must include android config"
        );
        assert "ios" in eas["build"]["preview"] , (
            "preview profile must include ios config"
        );
        assert eas["build"]["preview"]["ios"]["simulator"] == True , (
            "preview ios profile must enable simulator builds"
        );
        assert "submit" in eas , "eas.json must have a 'submit' section";
        # cli.version constrains the EAS CLI, which is versioned
        # independently of the Expo SDK. Guard against the regression of
        # deriving it from EXPO_SDK_VERSION (which produced an impossible
        # constraint like ">=54.0.0" that no EAS CLI could satisfy).
        assert "cli" in eas and "version" in eas["cli"] , (
            "eas.json must declare a cli.version constraint"
        );
        cli_version = eas["cli"]["version"];
        assert f">={EAS_CLI_VERSION}.0.0" == cli_version , (
            f"cli.version must track EAS_CLI_VERSION (>= {EAS_CLI_VERSION}.0.0), "
            f"got '{cli_version}'"
        );
        assert str(EXPO_SDK_VERSION) not in cli_version , (
            f"cli.version must not derive from EXPO_SDK_VERSION (got '{cli_version}'); "
            "EAS CLI is versioned independently of the Expo SDK"
        );
    }
}

test "eas.json is scaffold-managed and refreshed on re-run" {
    import tempfile;
    import from jaclang.client.targets.react_native.scaffold { write_expo_scaffold }

    with tempfile.TemporaryDirectory() as tmp {
        project_root = Path(tmp);
        rn_dir = project_root / "mobile-rn";
        write_expo_scaffold(rn_dir, project_root);
        eas_path = rn_dir / "eas.json";
        sidecar = rn_dir / ".eas-managed";
        original = eas_path.read_text(encoding="utf-8");
        assert sidecar.exists() , "scaffold sidecar marker must be written";
        # Re-run scaffold; eas.json should be refreshed while sidecar exists.
        write_expo_scaffold(rn_dir, project_root);
        assert eas_path.read_text(encoding="utf-8") == original;
        # Remove the sidecar to simulate user ownership — re-run must preserve.
        sidecar.unlink();
        custom = original + "\n";
        eas_path.write_text(custom, encoding="utf-8");
        write_expo_scaffold(rn_dir, project_root);
        assert eas_path.read_text(encoding="utf-8") == custom , (
            "scaffold must not overwrite user-edited eas.json"
        );
    }
}

test "resolve_rn_project_dir honors project_dir config override" {
    import tempfile;
    import from jaclang.client.targets.react_native.common { resolve_rn_project_dir }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        # Default: no config → .jac/mobile-rn/ (centralized build root)
        default_dir = resolve_rn_project_dir(project_dir);
        assert default_dir == project_dir / ".jac" / "mobile-rn" , (
            f"Expected .jac/mobile-rn, got {default_dir}"
        );
        # Custom relative path.
        toml_content = (
            "[project]\nname = \"test\"\nversion = \"1.0\"\n"
            "entry-point = \"main.jac\"\n\n"
            "[client.react_native]\n"
            'project_dir = "native-app"\n'
        );
        (project_dir / "jac.toml").write_text(toml_content, encoding="utf-8");
        custom_dir = resolve_rn_project_dir(project_dir);
        assert custom_dir == project_dir / "native-app" , (
            f"Expected native-app, got {custom_dir}"
        );
        # Absolute path.
        abs_path = Path(tmp) / "abs-native";
        toml_abs = (
            "[project]\nname = \"test\"\nversion = \"1.0\"\n"
            "entry-point = \"main.jac\"\n\n"
            "[client.react_native]\n"
            f'project_dir = "{abs_path}"\n'
        );
        (project_dir / "jac.toml").write_text(toml_abs, encoding="utf-8");
        abs_dir = resolve_rn_project_dir(project_dir);
        assert abs_dir == abs_path , f"Expected {abs_path}, got {abs_dir}";
    }
}

test "normalize_rn_platform validates platform strings" {
    import from jaclang.client.targets.react_native.common { normalize_rn_platform }

    assert normalize_rn_platform(None) == "android";
    assert normalize_rn_platform("") == "android";
    assert normalize_rn_platform("android") == "android";
    assert normalize_rn_platform("iOS") == "ios";
    assert normalize_rn_platform("IOS") == "ios";

    try {
        normalize_rn_platform("windows");
        assert False , "Expected ValueError for unsupported platform";
    } except ValueError as e {
        assert "Unsupported" in str(e);
    }
}

test "build source includes iOS start helper" {
    impl_path = _targets_dir / "impl" / "mobile_target.impl.jac";
    impl_content = impl_path.read_text();

    # start method must handle both iOS and Android.
    start_section = impl_content.split("impl MobileTarget.start")[1].split(
        "impl _RNHmrHandler.on_event"
    )[0];
    assert "_start_ios" in start_section;
    assert "_start_android" in start_section;
    assert "normalize_rn_platform" in start_section;
    # `jac run --platform <p> <app>` arrives through the env var, ahead of
    # [client.react_native] default_platform.
    assert "JAC_MOBILE_PLATFORM" in start_section;
    assert start_section.index("JAC_MOBILE_PLATFORM")
        < start_section.index("default_platform");

    # iOS start helper must exist in the file.
    assert "def _start_ios" in impl_content;
    assert "xcrun simctl" in impl_content;
    assert "simctl install" in impl_content;
    # addmedia is for the photo library, NOT app install — must be gone.
    assert "simctl addmedia" not in impl_content;
    assert "bundleIdentifier" in impl_content;

    # Android start helper must still work.
    assert "def _start_android" in impl_content;
    assert "adb install" in impl_content;
}

test "config helpers support ios_builder and release" {
    import tempfile;
    import from jaclang.client.config_loader { JacClientConfig }
    import from jaclang.client.targets.react_native.config {
        _resolve_rn_ios_builder,
        _resolve_rn_android_builder,
        _resolve_rn_release,
        _resolve_rn_eas_profile,
        _resolve_rn_eas_update_enabled,
        _resolve_rn_eas_update_branch,
        _resolve_rn_eas_update_message
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        # Defaults: no config → xcodebuild for iOS, gradle for Android, debug.
        cfg = JacClientConfig(project_dir).get_react_native_config();
        assert _resolve_rn_ios_builder(cfg) == "xcodebuild";
        assert _resolve_rn_android_builder(cfg) == "gradle";
        assert _resolve_rn_release(cfg) == False;
        assert _resolve_rn_eas_profile(cfg, True) == "production";
        assert _resolve_rn_eas_profile(cfg, False) == "preview";
        assert _resolve_rn_eas_update_enabled(cfg) == False;
        assert _resolve_rn_eas_update_branch(cfg, True) == "production";
        assert _resolve_rn_eas_update_branch(cfg, False) == "preview";
        assert _resolve_rn_eas_update_message(cfg) == "";
        # With config overrides.
        toml_content = (
            "[project]\nname = \"test\"\nversion = \"1.0\"\n"
            "entry-point = \"main.jac\"\n\n"
            "[client.react_native]\n"
            "release = true\n"
            'ios_builder = "eas"\n'
            'android_builder = "eas"\n'
            'eas_profile = "staging"\n'
            'eas_update = true\n'
            'eas_update_branch = "main"\n'
            'eas_update_message = "RN release"\n'
        );
        (project_dir / "jac.toml").write_text(toml_content, encoding="utf-8");
        cfg2 = JacClientConfig(project_dir).get_react_native_config();
        assert _resolve_rn_ios_builder(cfg2) == "eas";
        assert _resolve_rn_android_builder(cfg2) == "eas";
        assert _resolve_rn_release(cfg2) == True;
        assert _resolve_rn_eas_profile(cfg2, True) == "staging";
        assert _resolve_rn_eas_update_enabled(cfg2) == True;
        assert _resolve_rn_eas_update_branch(cfg2, True) == "main";
        assert _resolve_rn_eas_update_message(cfg2) == "RN release";
    }
}


test "react native scaffold includes EAS docs pointer in setup output" {
    # Verify the setup method prints EAS Build and EAS Update next-step hints.
    impl_path = _targets_dir / "impl" / "mobile_target.impl.jac";
    impl_content = impl_path.read_text();
    setup_section = impl_content.split("impl MobileTarget.setup")[1].split(
        "impl MobileTarget.build"
    )[0];
    assert "eas build" in setup_section.lower();
    assert "eas update" in setup_section.lower();
    assert "--platform ios" in setup_section;
    # The next-step hints use the kind-only CLI surface.
    assert "jac build --platform android <app>" in setup_section;
    assert "jac build --platform web <app>" in setup_section;
    assert "jac run --dev <app>" in setup_section;
    assert "jac setup react-native" not in impl_content;
    assert "--client" not in setup_section;
}

# ---------------------------------------------------------------------------
# E2E: full React Native Android build (gated behind JAC_RN_E2E=1)
# ---------------------------------------------------------------------------
"""End-to-end test: scaffold → compile → expo prebuild → Gradle assembleDebug.

Requires Android SDK + Java JDK on PATH. Skipped unless JAC_RN_E2E=1 is set.
Validates that the pinned RN 0.81.x stack produces a working Gradle build
with a real APK artifact.
"""
test "e2e: mobile android build produces APK" {
    import shutil;
    import subprocess;
    import tempfile;
    try {
        import from test_helpers { get_env_with_npm, get_jac_command }
    } except ModuleNotFoundError {
        return;
    }

    if os.environ.get("JAC_RN_E2E", "0") != "1" {
        testskip(
            "Set JAC_RN_E2E=1 to run the full React Native Android build "
            "(requires Android SDK + JDK)."
        );
    }

    fixture_src = Path(__file__).parent / "fixtures" / "react_native_multiscreen";
    if not fixture_src.exists() {
        testskip("react_native_multiscreen fixture not found");
    }

    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp) / "rn_e2e";
        shutil.copytree(fixture_src, project_dir);
        env = get_env_with_npm();
        jac_cmd = get_jac_command();
        # Step 1: jac build --platform android main.jac (kind = "mobile")
        rn_cmd = jac_cmd + ["build", "--platform", "android", "main.jac"];
        result = subprocess.run(
            rn_cmd,
            cwd=project_dir,
            env=env,
            capture_output=True,
            text=True,
            timeout=3600
        );
        assert result.returncode == 0 , (
            "jac build --platform android main.jac failed\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        );
        # Step 2: verify the APK artifact was produced.
        rn_project = project_dir / ".jac" / "mobile-rn";
        apk_outputs = rn_project
            / "android"
            / "app"
            / "build"
            / "outputs"
            / "apk"
            / "debug";
        assert apk_outputs.exists() , (f"Expected Gradle output dir at {apk_outputs}");
        apks = list(apk_outputs.`glob("*.apk"));
        assert len(apks) > 0 , (
            "Gradle assembleDebug succeeded but no APK found under "
            f"{apk_outputs}. Full stdout:\n{result.stdout}"
        );
    }
}
