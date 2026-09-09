import from jaclang.toolchains.host { use_system_tools }
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.toolchains.host { host_platform, run_step }
import from jaclang.toolchains.store { cache_root, InstallLock, offline }

def ensure_apple -> dict[str, str] {
    if not host_platform().startswith("mac-") {
        raise RuntimeError(
            "iOS builds require a macOS build host with Xcode. Use a Mac or a hosted macOS builder."
        );
    }
    xcode = shutil.which("xcodebuild");
    if not xcode
        or subprocess.run([xcode, "-version"], capture_output=True).returncode != 0 {
        raise RuntimeError(
            "Install Xcode from the Mac App Store, select it with sudo xcode-select --switch /Applications/Xcode.app, and finish its first-launch setup. Apple requires this setup before iOS builds."
        );
    }
    env = dict(os.environ);
    if shutil.which("pod") and use_system_tools() {
        return env;
    }
    import from jaclang.toolchains.pins { RUBY_ARTIFACTS, RUBY_VERSION }
    import from jaclang.toolchains.store { install }
    ruby_dir = install(
        RUBY_ARTIFACTS[host_platform()], f"portable-ruby/{RUBY_VERSION}/bin/ruby"
    )
        / "portable-ruby"
        / RUBY_VERSION;
    ruby = str(ruby_dir / "bin" / "ruby");
    gem = str(ruby_dir / "bin" / "gem");
    home = cache_root() / "cocoapods" / host_platform() / RUBY_VERSION / "1.16.2";
    env["PATH"] = str(ruby_dir / "bin") + os.pathsep + env.get("PATH", "");
    env["GEM_HOME"] = str(home);
    env["GEM_PATH"] = str(home);
    env["PATH"] = str(home / "bin") + os.pathsep + env.get("PATH", "");
    with InstallLock(home.with_suffix(".lock")) {
        if not (home / "bin" / "pod").is_file() {
            if offline() {
                raise RuntimeError(
                    "CocoaPods is missing from the offline cache. Run setup online first."
                );
            }
            home.mkdir(parents=True, exist_ok=True);
            run_step(
                "Installing CocoaPods 1.16.2 into the Jac toolchain cache",
                [
                    ruby,
                    gem,
                    "install",
                    "cocoapods",
                    "--version",
                    "1.16.2",
                    "--no-document"
                ],
                home,
                env
            );
        }
    }
    run_step("Checking CocoaPods", [str(home / "bin" / "pod"), "--version"], home, env);
    return env;
}
