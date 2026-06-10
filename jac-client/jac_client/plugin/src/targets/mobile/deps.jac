"""Mobile target: toolchain dependency checks (Node, Android, iOS)."""
import os;
import shutil;
import platform as platform_mod;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }
import from jac_client.plugin.src.targets.mobile.common {
    SUBPROCESS_TIMEOUT_SHORT,
    _check_command_available,
    _get_java_runtime_details,
    _get_jdk_compiler_details,
    _normalize_mobile_platform
}

"""Check and report on Android build prerequisites."""
def _check_android_dependencies {
    # Java / JDK (Capacitor Android Gradle modules target Java 21+)
    (java_ok, java_line, java_major) = _get_java_runtime_details();
    (javac_ok, javac_line, javac_major) = _get_jdk_compiler_details();
    java_exe = shutil.which("java");
    java_home = os.environ.get("JAVA_HOME", "");
    if java_ok {
        console.print(f"  ✔ Java runtime: {java_line}", style="success");
        if java_exe {
            console.print(f"    java binary: {java_exe}", style="muted");
        }
        if java_home {
            console.print(f"    JAVA_HOME: {java_home}", style="muted");
        } else {
            console.print(
                "    JAVA_HOME: (not set — using java on PATH)", style="muted"
            );
        }
        if java_major is not None {
            if java_major < 21 {
                console.print(
                    f"  Java {java_major} is below 21. Capacitor Android / Gradle "
                    "needs JDK 21+ to compile.",
                    style="warning"
                );
                console.print(
                    "    Set JAVA_HOME to a JDK 21 install, e.g. "
                    "/usr/lib/jvm/java-21-openjdk (Linux).",
                    style="muted"
                );
            }
        } else {
            console.print(
                "    (Could not parse Java version — ensure JDK 21+ for native Android builds)",
                style="muted"
            );
        }
    } else {
        console.warning("  ✖ Java runtime not found on PATH");
        console.print(
            "    Install JDK 21+ (e.g. OpenJDK 21): https://adoptium.net or your package manager",
            style="muted"
        );
    }
    # The JDK compiler (javac) is what Gradle actually invokes. Many distros
    # split JRE/JDK packages, so probe it separately — a JRE-only install
    # certifies green here today and then fails inside Gradle with an opaque
    # "Toolchain ... does not provide [JAVA_COMPILER]" message.
    if javac_ok {
        console.print(f"  ✔ JDK compiler: {javac_line}", style="success");
        if (
            java_major is not None
            and javac_major is not None
            and java_major != javac_major
        ) {
            console.print(
                f"  java ({java_major}) and javac ({javac_major}) major versions "
                "differ. Gradle uses javac — align them via JAVA_HOME.",
                style="warning"
            );
        }
    } else {
        console.warning(
            "  ✖ JDK compiler (javac) not found — Gradle cannot build without it"
        );
        console.print(
            "    A JRE alone is not enough. Install a JDK (e.g. OpenJDK 21):\n"
            "    Ubuntu/Debian: sudo apt install openjdk-21-jdk\n"
            "    macOS:         brew install openjdk@21\n"
            "    or download from https://adoptium.net",
            style="muted"
        );
    }

    # Android SDK (ANDROID_HOME or ANDROID_SDK_ROOT)
    android_home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT");
    if android_home and Path(android_home).is_dir() {
        console.print(f"  ✔ Android SDK found: {android_home}", style="success");
    } else {
        console.warning(
            "  ✖ Android SDK not found (ANDROID_HOME / ANDROID_SDK_ROOT not set)"
        );
        console.print(
            "    Install Android Studio or the command-line tools:\n"
            "    https://developer.android.com/studio",
            style="muted"
        );
    }

    # ADB (optional, needed for on-device deployment)
    (adb_ok, adb_ver) = _check_command_available(["adb", "--version"]);
    if adb_ok {
        first_line = (adb_ver or "").split("\n")[0];
        console.print(f"  ✔ ADB found: {first_line}", style="success");
    } else {
        console.print(
            "  ⚠ ADB not found (needed for on-device deployment)", style="warning"
        );
        console.print("    ADB ships with Android SDK platform-tools", style="muted");
    }

    # Gradle (optional, gradlew in android/ is preferred)
    (gradle_ok, gradle_ver) = _check_command_available(["gradle", "--version"]);
    if gradle_ok {
        first_line = (gradle_ver or "").split("\n")[0];
        console.print(f"  ✔ Gradle found: {first_line}", style="success");
    }
}

"""Check and report on iOS build prerequisites."""
def _check_ios_dependencies -> None {
    if platform_mod.system() != "Darwin" {
        console.warning("  ⚠ iOS builds require macOS — current OS is not macOS");
        console.print(
            "    You can still scaffold the project, but building requires a Mac.",
            style="muted"
        );
        return;
    }

    # Xcode Command Line Tools
    (xcode_ok, xcode_ver) = _check_command_available(["xcode-select", "-p"]);
    if xcode_ok {
        console.print(f"  ✔ Xcode CLI tools found: {xcode_ver}", style="success");
    } else {
        console.warning("  ✖ Xcode Command Line Tools not found");
        console.print("    Install with: xcode-select --install", style="muted");
    }

    # xcodebuild
    (xcbuild_ok, xcbuild_ver) = _check_command_available(["xcodebuild", "-version"]);
    if xcbuild_ok {
        first_line = (xcbuild_ver or "").split("\n")[0];
        console.print(f"  ✔ Xcode build: {first_line}", style="success");
    } else {
        console.warning("  ✖ xcodebuild not found");
        console.print(
            "    Install Xcode from the App Store: https://apps.apple.com/app/xcode/id497799835",
            style="muted"
        );
    }

    # CocoaPods (used by Capacitor iOS)
    (pod_ok, pod_ver) = _check_command_available(["pod", "--version"]);
    if pod_ok {
        console.print(f"  ✔ CocoaPods found: {pod_ver}", style="success");
    } else {
        console.warning("  ✖ CocoaPods not found (required by Capacitor iOS)");
        console.print("    Install with: sudo gem install cocoapods", style="muted");
    }

    # ios-deploy (optional, for on-device deployment)
    (iosdep_ok, _) = _check_command_available(["ios-deploy", "--version"]);
    if iosdep_ok {
        console.print("  ✔ ios-deploy found", style="success");
    } else {
        console.print(
            "  ⚠ ios-deploy not found (needed for on-device deployment)",
            style="warning"
        );
        console.print("    Install with: brew install ios-deploy", style="muted");
    }

    # iOS Simulator CLI (xcrun simctl) — for simulator dev/build
    (simctl_ok, _) = _check_command_available(
        ["xcrun", "simctl", "help"], timeout=SUBPROCESS_TIMEOUT_SHORT
    );
    if simctl_ok {
        console.print(
            "  ✔ iOS Simulator tools (xcrun simctl) available", style="success"
        );
    } else {
        console.print(
            "  ⚠ xcrun simctl not available (install full Xcode, not only CLT, "
            "for the iOS Simulator)",
            style="warning"
        );
    }
}

"""Check and report on all mobile build prerequisites for a given platform."""
def _check_and_report_dependencies(plat: str = "android") {
    console.print("\n📦 Checking mobile build dependencies...", style="bold");

    # Common: Node.js / Bun (required for Capacitor CLI)
    (node_ok, node_ver) = _check_command_available(["node", "--version"]);
    if node_ok {
        console.print(f"  ✔ Node.js found: {node_ver}", style="success");
    } else {
        # Resolve via get_bun so the project-local .jac/bin copy counts too
        # (auto-installs if neither node nor bun is present anywhere).
        bun = get_bun();
        if bun {
            (bun_ok, bun_ver) = _check_command_available([bun, "--version"]);
        } else {
            (bun_ok, bun_ver) = (False, None);
        }
        if bun_ok {
            console.print(f"  ✔ Bun found: {bun_ver}", style="success");
        } else {
            console.warning("  ✖ Node.js or Bun not found");
            console.print(
                "    Install Node.js (https://nodejs.org) or Bun (https://bun.sh)",
                style="muted"
            );
        }
    }

    # Platform-specific checks
    if plat == "android" {
        _check_android_dependencies();
    } elif plat == "ios" {
        _check_ios_dependencies();
    }
}

"""Run platform dependency check; log and continue on internal errors."""
def _try_check_mobile_dependencies(plat: str) {
    try {
        _check_and_report_dependencies(plat);
    } except Exception as e {
        console.warning(f"  Dependency check encountered an issue: {e}");
    }
}

"""iOS native workflows need macOS; fail fast on other hosts."""
def _require_macos_for_ios(plat: str) -> None {
    if _normalize_mobile_platform(plat) != "ios" {
        return;
    }
    if platform_mod.system() == "Darwin" {
        return;
    }
    raise RuntimeError(
        "iOS native builds and `cap run ios` require macOS with Xcode. "
        "Use a Mac or a macOS CI runner for the iOS target."
    );
}
