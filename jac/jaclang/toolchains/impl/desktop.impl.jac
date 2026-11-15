impl module_files(module: Path) -> list[Path] {
    return [module] + [Path(p) for p in discover_annex_files(str(module), ".impl.jac")];
}

impl stage_module(module: Path, dst_dir: Path) -> None {
    home = module.resolve().parent;
    for part in module_files(module) {
        target = dst_dir / part.resolve().relative_to(home);
        target.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(part, target);
    }
}

impl source_workspace(source: Path, name: str) -> Path {
    digest = hashlib.sha256();
    digest.update(file_digest(Path(sys.executable)).encode());
    real_source = source.resolve();
    files: list[Path] = [];
    for p in sorted(source.iterdir()) {
        if p.is_file() and p.name == "cef_sums.lock" {
            files.append(p);
        } elif p.is_file()
            and p.suffix == ".jac"
            and not p.name.endswith(".impl.jac") {
            files.extend(module_files(p));
        }
    }
    rels = sorted({str(p.resolve().relative_to(real_source)) for p in files});
    for rel in rels {
        digest.update(rel.encode());
        digest.update((real_source / rel).read_bytes());
    }
    destination = build_slot(name, host_platform(), digest.hexdigest()[:20]);
    with FileLock(destination.with_suffix(".lock")) {
        if not slot_ready(destination) {
            destination.parent.mkdir(parents=True, exist_ok=True);
            with tempfile.TemporaryDirectory(
                prefix=f".tmp.{os.getpid()}.", dir=destination.parent
            ) as tmp {
                staged = Path(tmp) / "source";
                staged.mkdir();
                for rel in rels {
                    (staged / rel).parent.mkdir(parents=True, exist_ok=True);
                    shutil.copy2(real_source / rel, staged / rel);
                }
                publish_build_slot(staged, destination);
            }
        }
    }
    return destination;
}

impl webview_library_name -> str {
    return shared_library_name("webview");
}

impl WebviewBuild.command(source: Path, output: Path) -> list[str] {
    return self.compile_args + [str(source), "-o", str(output)] + self.link_args;
}

impl linux_webview_build(module: str, version: str, flags: list[str]) -> WebviewBuild {
    return WebviewBuild(
        label="Building native WebKitGTK wrapper",
        library="libwebview.so",
        identity=WEBVIEW_HEADER.digest + "-" + module + "-" + version,
        compile_args=[
            "g++",
            "-std=c++17",
            "-DWEBVIEW_BUILD_SHARED",
            "-fPIC",
            "-O2",
            "-shared",
            "-Wl,-soname,libwebview.so"
        ],
        link_args=flags,
        webkit_module=module
    );
}

impl mac_webview_build(macos_version: str, machine: str) -> WebviewBuild {
    return WebviewBuild(
        label="Building native WKWebView wrapper",
        library="libwebview.dylib",
        identity=WEBVIEW_HEADER.digest
            + "-wkwebview-"
            + MACOS_DESKTOP_MIN_VERSION
            + "-"
            + macos_version
            + "-"
            + machine,
        compile_args=[
            "clang++",
            "-std=c++17",
            "-DWEBVIEW_BUILD_SHARED",
            "-fPIC",
            "-O2",
            "-w",
            "-shared",
            "-mmacosx-version-min=" + MACOS_DESKTOP_MIN_VERSION,
            "-install_name",
            "@loader_path/libwebview.dylib"
        ],
        link_args=["-framework", "WebKit"]
    );
}

impl _webview_build_for_host(host: str) -> WebviewBuild {
    if host.startswith("mac-") {
        return mac_webview_build(platform.mac_ver()[0], platform.machine());
    }
    module = webkit_module();
    version = subprocess.run(
        ["pkg-config", "--modversion", module],
        capture_output=True,
        text=True,
        check=True
    ).stdout.strip();
    flags = subprocess.run(
        ["pkg-config", "--cflags", "--libs", "gtk+-3.0", module],
        capture_output=True,
        text=True,
        check=True
    ).stdout;
    return linux_webview_build(module, version, shlex.split(flags));
}

impl ensure_webview(directory: Path) -> Path {
    host = ensure_desktop_host();
    return build_webview(directory, _webview_build_for_host(host));
}

impl build_webview(directory: Path, build: WebviewBuild) -> Path {
    output = directory / build.library;
    stamp = directory / ".webview-build";
    with FileLock(directory / ".build.lock") {
        if output.is_file()
            and stamp.is_file()
            and stamp.read_text() == build.identity {
            return output;
        }
        header = fetch(WEBVIEW_HEADER);
        with tempfile.TemporaryDirectory(dir=directory) as tmp {
            staging = Path(tmp);
            shutil.copy2(header, staging / "webview.h");
            source = staging / "webview.cc";
            source.write_text('#include "webview.h"\n');
            library = staging / build.library;
            run_step(
                build.label, build.command(source, library), staging, dict(os.environ)
            );
            library.replace(output);
        }
        if build.webkit_module {
            (directory / ".webkit_module").write_text(build.webkit_module);
        }
        stamp.write_text(build.identity);
    }
    return output;
}
