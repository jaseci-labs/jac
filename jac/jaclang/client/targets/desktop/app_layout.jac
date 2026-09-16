"""Where a built desktop app's pieces live, per host.

Linux ships a flat directory: the executable, libwebview, the sealed image and
the client bundle side by side. macOS ships an application bundle: the
executable and libwebview under Contents/MacOS, the image and the client bundle
under Contents/Resources, Info.plist under Contents. The build lays the app out
with `for_host`; the running host recovers the same layout from its own path
with `from_executable`, so build and runtime agree by construction."""
import from pathlib { Path }

obj AppLayout {
    has directory: Path,
        executable: Path,
        resources: Path,
        bundle: Path | None = None;

    static def for_host(directory: Path, app_name: str, host: str) -> AppLayout {
        if host.startswith("mac-") {
            bundle = directory / (app_name + ".app");
            contents = bundle / "Contents";
            return AppLayout(
                directory=directory,
                executable=contents / "MacOS" / app_name,
                resources=contents / "Resources",
                bundle=bundle
            );
        }
        return AppLayout(
            directory=directory, executable=directory / app_name, resources=directory
        );
    }

    static def from_executable(executable: Path) -> AppLayout {
        exe_dir = executable.parent;
        contents = exe_dir.parent;
        if (
            exe_dir.name == "MacOS"
            and contents.name == "Contents"
            and contents.parent.suffix == ".app"
        ) {
            return AppLayout(
                directory=contents.parent.parent,
                executable=executable,
                resources=contents / "Resources",
                bundle=contents.parent
            );
        }
        return AppLayout(directory=exe_dir, executable=executable, resources=exe_dir);
    }

    """The directory the executable loads its shared libraries from."""
    def library_dir -> Path {
        return self.executable.parent;
    }

    """The shell launcher beside the app that wires in the project venv."""
    def launcher -> Path {
        return self.directory / (self.executable.name + "-launch.sh");
    }

    """The executable as the launcher reaches it from its own directory."""
    def launch_target -> str {
        return "./" + str(self.executable.relative_to(self.directory));
    }
}
