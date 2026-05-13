"""Mobile target: native Android / iOS bundle builds (Gradle, xcodebuild)."""
import os;
import stat;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jac_client.plugin.src.targets.mobile.common { SUBPROCESS_TIMEOUT_BUILD }

# ==============================================================================
# Android Build Helpers
# ==============================================================================
"""Find newest Android APK or AAB artifact."""
def _find_android_artifact(project_dir: Path) -> Path {
    outputs_root = project_dir / "android" / "app" / "build" / "outputs";
    if not outputs_root.exists() {
        return outputs_root;
    }
    artifacts: list[Path] = [];
    for ext in [".apk", ".aab"] {
        artifacts.extend(
            [
                f
                for f in outputs_root.rglob(f"*{ext}")
                if f.is_file()
            ]
        );
    }
    if artifacts {
        def _artifact_mtime(artifact: Path) -> float {
            return float(artifact.stat().st_mtime);
        }
        artifacts.sort(key=_artifact_mtime, reverse=True);
        return artifacts[0];
    }
    return outputs_root;
}

"""Resolve gradlew path and ensure it is executable."""
def _resolve_gradlew(project_dir: Path) -> str {
    gradlew = project_dir / "android" / "gradlew";
    if gradlew.exists() {
        st = os.stat(gradlew);
        os.chmod(str(gradlew), int(st.st_mode) | int(stat.S_IEXEC));
        return str(gradlew);
    }
    return "gradle";
}

"""Determine the Gradle task based on build mode.

Returns the Gradle task name: assembleDebug, assembleRelease, or bundleRelease.
"""
def _get_gradle_task(release: bool = False, bundle: bool = False) -> str {
    if bundle {
        return "bundleRelease";
    }
    if release {
        return "assembleRelease";
    }
    return "assembleDebug";
}

"""Build Android APK/AAB via Gradle."""
def _build_android(project_dir: Path, mobile_cfg: dict) -> Path {
    release = mobile_cfg.get("release", False);
    bundle_aab = mobile_cfg.get("bundle", False);
    gradle_task = _get_gradle_task(release=release, bundle=bundle_aab);

    console.print(f"  Step 3: Running {gradle_task}...", style="muted");
    gradlew = _resolve_gradlew(project_dir);
    android_dir = project_dir / "android";
    subprocess.run(
        [gradlew, gradle_task],
        cwd=android_dir,
        check=True,
        capture_output=False,
        timeout=SUBPROCESS_TIMEOUT_BUILD
    );

    artifact = _find_android_artifact(project_dir);
    return artifact;
}

# ==============================================================================
# iOS Build Helpers
# ==============================================================================
"""Find the Xcode workspace path in ios/App/."""
def _find_xcode_workspace(project_dir: Path) -> Path | None {
    ios_app = project_dir / "ios" / "App";
    if not ios_app.exists() {
        return None;
    }
    workspaces = list(ios_app.glob("*.xcworkspace"));
    if workspaces {
        return workspaces[0];
    }
    projects = list(ios_app.glob("*.xcodeproj"));
    if projects {
        return projects[0];
    }
    return None;
}

"""Build iOS app via xcodebuild.

Produces a debug build for the iOS Simulator by default.
For device builds or release archives, the user should open Xcode:
  npx cap open ios
"""
def _build_ios(project_dir: Path, mobile_cfg: dict) -> Path {
    release = mobile_cfg.get("release", False);
    ios_dir = project_dir / "ios" / "App";

    workspace = _find_xcode_workspace(project_dir);
    if workspace is None {
        raise RuntimeError(
            "Xcode workspace not found in ios/App/. Run 'jac setup mobile' first."
        );
    }

    # Determine build configuration and destination
    configuration = "Release" if release else "Debug";
    # Default to simulator; device builds require provisioning and are best done via Xcode
    sdk = mobile_cfg.get("ios_sdk", "iphonesimulator");
    destination = mobile_cfg.get(
        "ios_destination", "platform=iOS Simulator,name=iPhone 16,OS=latest"
    );

    console.print(f"  Step 3: Building iOS ({configuration}, {sdk})...", style="muted");

    build_cmd = [
        "xcodebuild",
        "-workspace",
        str(workspace),
        "-scheme",
        "App",
        "-configuration",
        configuration,
        "-sdk",
        sdk,
        "-destination",
        destination,
        "build"
    ];

    console.print(f"  Running: {' '.join(build_cmd)}", style="muted");
    result = subprocess.run(
        build_cmd,
        cwd=ios_dir,
        check=False,
        capture_output=False,
        timeout=SUBPROCESS_TIMEOUT_BUILD
    );

    if result.returncode != 0 {
        console.warning(
            "  xcodebuild failed. For device builds or provisioning issues, "
            "open the project in Xcode:"
        );
        console.print("    npx cap open ios", style="muted");
        raise RuntimeError("xcodebuild failed — see output above");
    }

    # Return the DerivedData or build products path
    build_output = project_dir / "ios" / "App" / "build";
    console.print(f"  ✔ iOS build complete ({configuration})", style="success");
    return build_output;
}
