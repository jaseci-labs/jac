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

    def library_dir -> Path {
        return self.executable.parent;
    }

    def launcher -> Path {
        return self.directory / (self.executable.name + "-launch.sh");
    }

    def launch_target -> str {
        return "./" + str(self.executable.relative_to(self.directory));
    }
}
