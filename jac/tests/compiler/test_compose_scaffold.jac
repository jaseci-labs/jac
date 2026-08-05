"""Tests for the Compose Android Gradle scaffold — locks in the HMR module split.

The 2-module dev layout (base :app host + :hot app code) is what makes
DexClassLoader hot-swap possible, so the file routing it produces is a
regression-sensitive contract. These tests assert it without touching Gradle,
the SDK, or a device.
"""
import from jaclang.compiler.passes.compose.gradle_scaffold { build_gradle_scaffold }

test "dev scaffold splits host into :app and app code into :hot" {
    files = build_gradle_scaffold(
        "dev.jac.myapp", "My App", "http://10.0.2.2:8000", ["/"], dev=True
    );

    # Two modules are declared.
    assert ":hot" in files["settings.gradle.kts"];
    assert "hot/build.gradle.kts" in files;
    assert "hot/src/main/AndroidManifest.xml" in files;

    # The polling host lives in the BASE (:app) and is its launcher.
    assert "app/src/main/java/dev/jac/myapp/JacDevHostActivity.kt" in files;
    manifest = files["app/src/main/AndroidManifest.xml"];
    assert "JacDevHostActivity" in manifest;
    # Dev builds must expose exactly one launcher — the HMR host, not MainActivity.
    assert manifest.count("android.intent.category.LAUNCHER") == 1;
    assert "JacDevHostActivity" in manifest.split("LAUNCHER")[0];

    # All app code — infra, the mount entry — lives in :hot so a hot dex can
    # carry ONLY app classes (Compose stays in the parent/base).
    assert "hot/src/main/java/dev/jac/myapp/JacDevEntry.kt" in files;
    assert "hot/src/main/java/dev/jac/myapp/JacRouting.kt" in files;
    assert "hot/src/main/java/dev/jac/myapp/JacTheme.kt" in files;
}

test "release scaffold is single-module with no :hot" {
    files = build_gradle_scaffold("dev.jac.myapp", "A", "", ["/"], dev=False);

    # No second module.
    assert ":hot" not in files["settings.gradle.kts"];
    has_hot = False;
    for k in files {
        if k.startswith("hot/") {
            has_hot = True;
        }
    }
    assert not has_hot;

    # Infra returns to the single :app source set; the dev host is absent.
    assert "app/src/main/java/dev/jac/myapp/MainActivity.kt" in files;
    assert "app/src/main/java/dev/jac/myapp/JacRouting.kt" in files;
    assert "JacDevHostActivity" not in files["app/src/main/AndroidManifest.xml"];
}

test "dev host manifest has the jacDevServer intent surface" {
    # The host reads the dev-server URL from the `jacDevServer` extra at launch;
    # the scaffolded Kotlin (JacDevHostActivity.resolveEndpoint) depends on this
    # contract, so pin the extra name here.
    files = build_gradle_scaffold("dev.jac.myapp", "A", "", ["/"], dev=True);
    host_kt = files["app/src/main/java/dev/jac/myapp/JacDevHostActivity.kt"];
    assert "jacDevServer" in host_kt;
    assert "DexClassLoader" in host_kt;
    assert "/_jac/dev/modules/manifest.json" in host_kt;
}
