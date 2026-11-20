impl AndroidEnvironment.env -> dict[str, str] {
    result: dict[str, str] = dict(os.environ);
    result["JAVA_HOME"] = str(self.java_home);
    result["ANDROID_HOME"] = str(self.sdk_home);
    result["ANDROID_SDK_ROOT"] = str(self.sdk_home);
    result["GRADLE_USER_HOME"] = os.environ.get(
        "GRADLE_USER_HOME", str(bucket("toolchains-gradle").path())
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

impl ensure_jdk -> Path {
    return tool_path("jdk");
}

impl ensure_android -> AndroidEnvironment {
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
        else bucket("toolchains-android-sdk").path() / host;
    sdk.mkdir(parents=True, exist_ok=True);
    environment = AndroidEnvironment(java, sdk);
    manager_name = "sdkmanager.bat" if os.name == "nt" else "sdkmanager";
    with FileLock(sdk / ".jac-sdk.lock") {
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
