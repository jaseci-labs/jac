import from jaclang.toolchains.host { use_system_tools }
import os;
import re;
import shutil;
import subprocess;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.toolchains.host { host_platform, executable, run_step }
import from jaclang.toolchains.pins { JDK_ARTIFACTS, JDK_VERSION, ANDROID_ARTIFACTS }
import from jaclang.toolchains.store { cache_root, install, InstallLock, offline }

obj AndroidEnvironment {
    has java_home: Path,
        sdk_home: Path;

    def env -> dict[str, str] {
        result = dict(os.environ);
        result["JAVA_HOME"] = str(self.java_home);
        result["ANDROID_HOME"] = str(self.sdk_home);
        result["ANDROID_SDK_ROOT"] = str(self.sdk_home);
        result["GRADLE_USER_HOME"] = os.environ.get(
            "GRADLE_USER_HOME", str(cache_root() / "gradle")
        );
        result["PATH"] = os.pathsep.join(
            [
                str(self.java_home / "bin"),
                str(self.sdk_home / "platform-tools"),
                result.get("PATH", "")
            ]
        );
        return result;
    }
}

def compatible_jdk(home: Path) -> bool {
    javac = home / "bin" / executable("javac");
    if not javac.is_file() {
        return False;
    }
    try {
        result = subprocess.run(
            [str(javac), "-version"], capture_output=True, text=True, timeout=15
        );
        return result.returncode == 0
            and bool(re.search(r"javac 21[.\s]", result.stdout + result.stderr));
    } except (OSError, subprocess.TimeoutExpired) {
        return False;
    }
}

def ensure_jdk -> Path {
    requested = os.environ.get("JAVA_HOME", "");
    if requested and use_system_tools() {
        home = Path(requested).expanduser();
        if compatible_jdk(home) {
            console.print(f"Using JDK 21 at {home}", style="muted");
            return home;
        }
        console.print(
            "JAVA_HOME does not contain a compatible JDK 21; provisioning a managed JDK.",
            style="muted"
        );
    }
    found = shutil.which(executable("javac"));
    if found and use_system_tools() {
        home = Path(found).resolve().parent.parent;
        if compatible_jdk(home) {
            return home;
        }
    }
    host = host_platform();
    artifact = JDK_ARTIFACTS.get(host);
    if artifact is None {
        raise RuntimeError(f"No managed JDK for {host}");
    }
    relative = f"jdk-{JDK_VERSION}";
    if host.startswith("mac-") {
        relative += "/Contents/Home";
    }
    installed = install(artifact, relative + "/bin/" + executable("javac"));
    home = installed / relative;
    if not compatible_jdk(home) {
        raise RuntimeError(f"Managed JDK could not execute at {home}");
    }
    return home;
}

def ensure_android -> AndroidEnvironment {
    host = host_platform();
    artifact = ANDROID_ARTIFACTS.get(host);
    if artifact is None {
        raise RuntimeError(
            f"Android native builds are not supported on {host}; use a supported build host."
        );
    }
    java = ensure_jdk();
    custom = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT");
    sdk = Path(custom).expanduser().resolve()
        if custom
        else cache_root() / "android-sdk" / host;
    sdk.mkdir(parents=True, exist_ok=True);
    environment = AndroidEnvironment(java, sdk);
    manager_name = "sdkmanager.bat" if os.name == "nt" else "sdkmanager";
    with InstallLock(sdk / ".jac-sdk.lock") {
        manager = sdk / "cmdline-tools" / "latest" / "bin" / manager_name;
        if not manager.is_file() {
            tools = install(artifact, "cmdline-tools/bin/" + manager_name);

            manager = tools / "cmdline-tools" / "bin" / manager_name;
        }
        licenses = sdk / "licenses";
        accepted = (licenses / "android-sdk-license").is_file();
        if not accepted {
            if offline() {
                raise RuntimeError(
                    "Android SDK licenses are missing; run jac setup --toolchain android online first."
                );
            }
            consent = os.environ.get("JAC_ACCEPT_ANDROID_LICENSES", "").lower()
                in ["1", "true", "yes"];
            if not consent and not os.isatty(0) {
                raise RuntimeError(
                    "Android SDK license acceptance is required. Run jac setup --toolchain android interactively, or set JAC_ACCEPT_ANDROID_LICENSES=1 after reviewing https://developer.android.com/studio/terms."
                );
            }
            run_step(
                "Reviewing Android SDK licenses",
                [str(manager), f"--sdk_root={sdk}", "--licenses"],
                sdk,
                environment.env(),
                "y\n" * 100 if consent else None
            );
            if not (licenses / "android-sdk-license").is_file() {
                raise RuntimeError("Android SDK licenses were not accepted.");
            }
        }
        if not (sdk / "platform-tools" / executable("adb")).is_file() {
            if offline() {
                raise RuntimeError(
                    "Android platform-tools are not cached; run setup online first."
                );
            }
            run_step(
                "Installing Android platform-tools (SDK Manager reports progress)",
                [str(manager), f"--sdk_root={sdk}", "platform-tools"],
                sdk,
                environment.env()
            );
        }
    }
    console.print(f"Android toolchain ready: {sdk}", style="success");
    return environment;
}
