"""Integration tests for the mobile pipeline.

Covers:
  Scaffold (jac setup mobile):
  1. mobile/ directory structure is generated
  2. Placeholder icon files are created
  3. [mobile] section is appended to jac.toml
  4. Idempotency - running twice does not duplicate [mobile]
  5. all-in-one committed jac.toml has no pre-baked mobile config
  6. all-in-one .gitignore excludes mobile/

  Build pipeline helpers:
  7. _prepare_build_dir copies scaffold files to .jac/mobile/
  8. _copy_web_bundle_to_mobile copies index.html, client.js, styles.css
  9. Backend URL injection: JAC_MOBILE_API_URL overrides jac.toml
  10. Backend URL injection: falls back to [mobile.features].api_url in jac.toml
  11. Backend URL injection: empty URL does not crash the build

  MobileTarget API:
  12. MobileTarget declares build, dev, and start methods
"""

import json;
import os;
import pytest;
import shutil;
import subprocess;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.project.config { get_config }

import from test_helpers { get_jac_command }
import from jac_client.plugin.src.targets.mobile.bundle_helpers {
    _prepare_build_dir,
    _copy_web_bundle_to_mobile
}
import from jac_client.plugin.src.targets.mobile.dev_helpers { _write_build_config }

glob _tests_dir = Path(os.path.dirname(__file__)),
     _jac_client_root = _tests_dir.parent,
     _all_in_one_path = _jac_client_root / "examples" / "all-in-one",
     _MINIMAL_JAC_TOML = (
         "[project]\n"
         "name = \"test-mobile-app\"\n"
         "version = \"1.0.0\"\n"
         "description = \"Minimal jac project for mobile integration tests\"\n"
         "entry-point = \"main.jac\"\n"
     ),
     _MINIMAL_MAIN_JAC = (
         "walker test_walker {\n"
         "    can greet with `root entry {\n"
         "        print(\"hello\");\n"
         "    }\n"
         "}\n"
     );


test "jac setup mobile scaffolds mobile directory structure" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        jac_cmd = get_jac_command();
        result = subprocess.run(
            [*jac_cmd, "setup", "mobile"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=60
        );
        print(f"[DEBUG] stdout:\n{result.stdout}");
        print(f"[DEBUG] stderr:\n{result.stderr}");
        assert result.returncode == 0 , (
            f"jac setup mobile failed (rc={result.returncode}):\n{result.stderr}"
        );
        mobile_dir = project_dir / "mobile";
        assert mobile_dir.is_dir() , "mobile/ directory not created";
        for expected in [
            mobile_dir / "app.json",
            mobile_dir / "package.json",
            mobile_dir / "tsconfig.json",
            mobile_dir / "app" / "index.tsx",
            mobile_dir / "app" / "_layout.tsx",
            mobile_dir / "assets" / "jac-app" / "create-bundle.js",
            mobile_dir / ".gitignore",

        ] {
            assert expected.exists() , f"expected file missing: {expected.name}";
        }
    }
}


test "jac setup mobile generates placeholder icon files" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        jac_cmd = get_jac_command();
        result = subprocess.run(
            [*jac_cmd, "setup", "mobile"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=60
        );
        assert result.returncode == 0 , f"jac setup mobile failed:\n{result.stderr}";
        assets_dir = project_dir / "mobile" / "assets";
        for icon in ["icon.png", "splash.png", "adaptive-icon.png", "favicon.png"] {
            assert (assets_dir / icon).exists() , f"placeholder icon missing: {icon}";
            assert (assets_dir / icon).stat().st_size > 0 , f"icon is empty: {icon}";
        }
    }
}


test "jac setup mobile appends [mobile] section to jac.toml" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        toml_path = project_dir / "jac.toml";
        toml_path.write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        with open(str(toml_path), "rb") as f {
            before = tomllib.load(f);
        }
        assert "mobile" not in before , "[mobile] must not exist before setup";
        jac_cmd = get_jac_command();
        result = subprocess.run(
            [*jac_cmd, "setup", "mobile"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=60
        );
        assert result.returncode == 0 , f"jac setup mobile failed:\n{result.stderr}";
        with open(str(toml_path), "rb") as f {
            after = tomllib.load(f);
        }
        assert "mobile" in after , "[mobile] section not added to jac.toml";
        mobile = after["mobile"];
        assert "name" in mobile , "[mobile].name missing";
        assert "bundle_id" in mobile , "[mobile].bundle_id missing";
        assert "platforms" in mobile , "[mobile.platforms] missing";
        assert "features" in mobile , "[mobile.features] missing";
        assert "api_url" in mobile["features"] , "[mobile.features].api_url missing";
        assert "expo" in mobile , "[mobile.expo] missing";
    }
}


test "jac setup mobile is idempotent: [mobile] not duplicated on second run" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        jac_cmd = get_jac_command();
        for _ in range(2) {
            result = subprocess.run(
                [*jac_cmd, "setup", "mobile"],
                cwd=str(project_dir),
                capture_output=True,
                text=True,
                timeout=60
            );
            assert result.returncode == 0 , (
                f"jac setup mobile failed on repeat run:\n{result.stderr}"
            );
        }
        content = (project_dir / "jac.toml").read_text();
        mobile_count = content.count("[mobile]");
        assert mobile_count == 1 , (
            f"[mobile] duplicated after second run ({mobile_count} occurrences)"
        );
    }
}


test "all-in-one jac.toml has no pre-committed [mobile] section" {
    toml_path = _all_in_one_path / "jac.toml";
    assert toml_path.exists() , "all-in-one jac.toml not found";

    with open(str(toml_path), "rb") as f {
        config = tomllib.load(f);
    }
    assert "mobile" not in config , (
        "all-in-one jac.toml must not pre-commit [mobile]; "
        "generated by `jac setup mobile`"
    );
    envs = config.get("environments", {});
    assert "mobile" not in envs , (
        "all-in-one jac.toml must not pre-commit [environments.mobile.*]"
    );
}


test "all-in-one .gitignore excludes mobile/" {
    gitignore_path = _all_in_one_path / ".gitignore";
    assert gitignore_path.exists() , "all-in-one .gitignore not found";

    lines = gitignore_path.read_text().splitlines();
    assert "mobile/" in lines , (
        "all-in-one .gitignore must contain 'mobile/'; "
        "scaffold is generated by `jac setup mobile` and must not be committed"
    );
}


# ── Build pipeline helpers ────────────────────────────────────────────────────
test "_prepare_build_dir copies scaffold files to .jac/mobile/" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        jac_cmd = get_jac_command();
        result = subprocess.run(
            [*jac_cmd, "setup", "mobile"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=60
        );
        assert result.returncode == 0 , f"jac setup mobile failed:\n{result.stderr}";
        mobile_src_dir = project_dir / "mobile";
        mobile_build_dir = project_dir / ".jac" / "mobile";
        mobile_build_dir.mkdir(parents=True, exist_ok=True);
        # Create stub node_modules so _prepare_build_dir skips yarn install
        (mobile_build_dir / "node_modules").mkdir();
        _prepare_build_dir(mobile_src_dir, mobile_build_dir);
        for expected in [
            mobile_build_dir / "app.json",
            mobile_build_dir / "package.json",
            mobile_build_dir / "app" / "index.tsx",
            mobile_build_dir / "app" / "_layout.tsx",
            mobile_build_dir / "assets" / "jac-app" / "create-bundle.js",

        ] {
            assert expected.exists() , f"missing in .jac/mobile/: {expected.name}";
        }
    }
}


test "_copy_web_bundle_to_mobile copies index.html, client.js, styles.css" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        # Fake web bundle dist dir
        dist_dir = project_dir / "dist";
        dist_dir.mkdir();
        (dist_dir / "index.html").write_text("<html></html>");
        (dist_dir / "main.js").write_text("console.log('app');");
        (dist_dir / "styles.css").write_text("body {}");
        # Target mobile build dir
        mobile_dir = project_dir / ".jac" / "mobile";
        assets_dir = mobile_dir / "assets" / "jac-app";
        assets_dir.mkdir(parents=True);
        _copy_web_bundle_to_mobile(dist_dir, mobile_dir);
        assert (assets_dir / "index.html").exists() , "index.html not copied";
        assert (assets_dir / "client.js").exists() , "client.js not copied";
        assert (assets_dir / "styles.css").exists() , "styles.css not copied";
        assert (assets_dir / "client.js").read_text() == "console.log('app');";
    }
}


# ── Backend URL injection ─────────────────────────────────────────────────────
test "backend URL injection: JAC_MOBILE_API_URL overrides jac.toml" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        mobile_build_dir = project_dir / ".jac" / "mobile";
        mobile_build_dir.mkdir(parents=True);
        prev = os.environ.pop("JAC_MOBILE_API_URL", None);
        try {
            os.environ["JAC_MOBILE_API_URL"] = "https://api.override.com";
            _write_build_config(mobile_build_dir, project_dir);
        } finally {
            if prev is None {
                os.environ.pop("JAC_MOBILE_API_URL", None);
            } else {
                os.environ["JAC_MOBILE_API_URL"] = prev;
            }
        }
        config = json.loads((mobile_build_dir / "dev-config.json").read_text());
        assert config["productionApiUrl"] == "https://api.override.com" , (
            f"expected override URL, got: {config['productionApiUrl']}"
        );
    }
}


test "backend URL injection: falls back to [mobile.features].api_url in jac.toml" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        toml_with_mobile = (
            _MINIMAL_JAC_TOML + "\n[mobile]\nname = \"test\"\nbundle_id = \"com.test\"\n" + "version = \"1.0.0\"\ndisplay_name = \"Test\"\nslug = \"test\"\nscheme = \"test\"\n" + "\n[mobile.features]\nuse_sidecar = false\napi_url = \"https://toml.example.com\"\n"
        );
        (project_dir / "jac.toml").write_text(toml_with_mobile);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        mobile_build_dir = project_dir / ".jac" / "mobile";
        mobile_build_dir.mkdir(parents=True);
        # Prime the global JacConfig singleton to the temp dir so that
        # MobileConfig.load() reads our jac.toml instead of the repo root's.
        get_config(start_path=project_dir, force_discover=True);
        prev = os.environ.pop("JAC_MOBILE_API_URL", None);
        try {
            _write_build_config(mobile_build_dir, project_dir);
        } finally {
            if prev is not None {
                os.environ["JAC_MOBILE_API_URL"] = prev;
            }
        }
        config = json.loads((mobile_build_dir / "dev-config.json").read_text());
        assert config["productionApiUrl"] == "https://toml.example.com" , (
            f"expected toml fallback URL, got: {config['productionApiUrl']}"
        );
    }
}


test "backend URL injection: empty URL does not crash the build" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        (project_dir / "jac.toml").write_text(_MINIMAL_JAC_TOML);
        (project_dir / "main.jac").write_text(_MINIMAL_MAIN_JAC);
        mobile_build_dir = project_dir / ".jac" / "mobile";
        mobile_build_dir.mkdir(parents=True);
        # Reset the singleton to our temp dir (no [mobile] section) so the
        # empty-URL fallback path is tested against a clean config.
        get_config(start_path=project_dir, force_discover=True);
        prev = os.environ.pop("JAC_MOBILE_API_URL", None);
        try {
            _write_build_config(mobile_build_dir, project_dir);
        } finally {
            if prev is not None {
                os.environ["JAC_MOBILE_API_URL"] = prev;
            }
        }
        config = json.loads((mobile_build_dir / "dev-config.json").read_text());
        assert "productionApiUrl" in config , "dev-config.json must have productionApiUrl key";
        assert config["productionApiUrl"] == "" , (
            "empty URL should be written as empty string, not crash"
        );
    }
}


# ── MobileTarget API ──────────────────────────────────────────────────────────
test "MobileTarget declares build, dev, and start methods" {
    plugin_dir = _jac_client_root / "plugin";
    impl_path = plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac";
    assert impl_path.exists() , f"impl file missing: {impl_path}";
    content = impl_path.read_text();
    assert "impl MobileTarget.build(" in content , "MobileTarget.build not implemented";
    assert "impl MobileTarget.dev(" in content , "MobileTarget.dev not implemented";
    assert "impl MobileTarget.start(" in content , "MobileTarget.start not implemented";
}


# ── End-to-end: scaffold through release APK generation ──────────────────────
test "end-to-end: scaffold through release APK generation" {
    # Requires Android build tools. Returns early (passes trivially) when they
    # are not present; runs the full pipeline in Android CI environments.
    for tool in ["node", "yarn", "java", "keytool"] {
        if not shutil.which(tool) {
            print(
                f"[SKIP] missing required tool '{tool}': "
                "skipping full APK build test"
            );
            return;
        }
    }
    android_home = os.environ.get(
        "ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "")
    );
    if not android_home or not Path(android_home).exists() {
        print("[SKIP] ANDROID_HOME not set: skipping full APK build test");
        return;
    }

    jac_cmd = get_jac_command();

    with tempfile.TemporaryDirectory() as tmp {
        # Copy all-in-one into a temp dir so the test is fully isolated.
        project_dir = Path(tmp) / "app";
        shutil.copytree(
            str(_all_in_one_path),
            str(project_dir),
            ignore=shutil.ignore_patterns(".jac", "node_modules", "__pycache__")
        );
        # ── Step 1: scaffold ───────────────────────────────────────────────────
        result = subprocess.run(
            [*jac_cmd, "setup", "mobile"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=120
        );
        print(f"[step 1 stdout]\n{result.stdout}");
        print(f"[step 1 stderr]\n{result.stderr}");
        assert result.returncode == 0 , f"jac setup mobile failed:\n{result.stderr}";
        assert (project_dir / "mobile").is_dir() , "mobile/ not created by scaffold";
        # ── Step 2: build web bundle and prepare .jac/mobile/ ─────────────────
        build_env = os.environ.copy();
        build_env["JAC_MOBILE_API_URL"] = "https://api.example.com";
        result = subprocess.run(
            [*jac_cmd, "build", "--client", "mobile", "-p", "android"],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=600,
            env=build_env
        );
        print(f"[step 2 stdout]\n{result.stdout}");
        print(f"[step 2 stderr]\n{result.stderr}");
        assert result.returncode == 0 , (
            f"jac build --client mobile -p android failed:\n{result.stderr}"
        );
        mobile_build_dir = project_dir / ".jac" / "mobile";
        for artifact in ["app.json", "package.json"] {
            assert (mobile_build_dir / artifact).exists() , (
                f"Missing build artifact: {artifact}"
            );
        }
        assert (mobile_build_dir / "node_modules").is_dir() , (
            "node_modules missing - yarn install did not run"
        );
        assert (mobile_build_dir / "assets" / "jac-app" / "bundle.ts").exists() , (
            "Missing bundle.ts in build dir"
        );
        dev_config = json.loads((mobile_build_dir / "dev-config.json").read_text());
        assert dev_config.get("productionApiUrl") == "https://api.example.com" , (
            f"Expected baked API URL in dev-config.json, got: "
            f"{dev_config.get('productionApiUrl')}"
        );
        # ── Step 3: expo prebuild -> native Android project ────────────────────
        result = subprocess.run(
            [
                "npx",
                "expo",
                "prebuild",
                "--platform",
                "android",
                "--clean",
                "--no-install"
            ],
            cwd=str(mobile_build_dir),
            capture_output=True,
            text=True,
            timeout=300
        );
        print(f"[step 3 stdout]\n{result.stdout}");
        print(f"[step 3 stderr]\n{result.stderr}");
        assert result.returncode == 0 , f"expo prebuild failed:\n{result.stderr}";
        android_dir = mobile_build_dir / "android";
        assert android_dir.is_dir() , "android/ not generated by expo prebuild";
        assert (android_dir / "app" / "build.gradle").exists() , (
            "Missing app/build.gradle after expo prebuild"
        );
        # ── Step 4: generate throwaway release keystore ────────────────────────
        keystore_path = android_dir / "app" / "release.keystore";
        result = subprocess.run(
            [
                "keytool",
                "-genkeypair",
                "-v",
                "-keystore",
                str(keystore_path),
                "-storepass",
                "ciinstall",
                "-keypass",
                "ciinstall",
                "-alias",
                "ciinstallkey",
                "-keyalg",
                "RSA",
                "-keysize",
                "2048",
                "-validity",
                "10000",
                "-dname",
                "CN=Jac Test, OU=CI, O=Jaseci Labs, C=US"
            ],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert result.returncode == 0 , f"keytool failed:\n{result.stderr}";
        assert keystore_path.exists() , "release.keystore not created by keytool";
        # ── Step 5: configure release signing ──────────────────────────────────
        with open(str(android_dir / "gradle.properties"), "a") as gp {
            gp.write(
                "\nMYAPP_RELEASE_STORE_FILE=release.keystore\n"
                "MYAPP_RELEASE_STORE_PASSWORD=ciinstall\n"
                "MYAPP_RELEASE_KEY_ALIAS=ciinstallkey\n"
                "MYAPP_RELEASE_KEY_PASSWORD=ciinstall\n"
            );
        }
        with open(str(android_dir / "app" / "build.gradle"), "a") as bg {
            bg.write(
                "\n// CI release signing (appended by integration test)\n"
                "android {\n"
                "    signingConfigs {\n"
                "        ciRelease {\n"
                "            storeFile file(MYAPP_RELEASE_STORE_FILE)\n"
                "            storePassword MYAPP_RELEASE_STORE_PASSWORD\n"
                "            keyAlias MYAPP_RELEASE_KEY_ALIAS\n"
                "            keyPassword MYAPP_RELEASE_KEY_PASSWORD\n"
                "        }\n"
                "    }\n"
                "    buildTypes {\n"
                "        release { signingConfig signingConfigs.ciRelease }\n"
                "    }\n"
                "}\n"
            );
        }
        # ── Step 6: build release APK ──────────────────────────────────────────
        gradlew = android_dir / "gradlew";
        gradlew.chmod(0o755);
        result = subprocess.run(
            ["./gradlew", "assembleRelease"],
            cwd=str(android_dir),
            capture_output=True,
            text=True,
            timeout=1800
        );
        if result.returncode != 0 {
            print(f"[step 6 stderr (last 3000 chars)]\n{result.stderr[-3000:]}");
        }
        assert result.returncode == 0 , "Gradle assembleRelease failed (see stderr above)";
        # ── Step 7: verify APK ─────────────────────────────────────────────────
        apk_dir = android_dir / "app" / "build" / "outputs" / "apk" / "release";
        apks = list(apk_dir.glob("*.apk"));
        assert len(apks) > 0 , f"No APK found under {apk_dir}";
        apk = apks[0];
        assert apk.stat().st_size > 0 , f"APK is empty: {apk.name}";
        print(f"[OK] APK: {apk.name} ({apk.stat().st_size:,} bytes)");
    }
}
