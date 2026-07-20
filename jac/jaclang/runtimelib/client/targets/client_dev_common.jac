import os;
import shutil;
import socket;
import subprocess;
import from pathlib { Path }
import from typing { Any, Optional, cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.build_common { SUBPROCESS_TIMEOUT_SHORT }
import from jaclang.runtimelib.sv_client { headless_start_args }
import from jaclang.runtimelib.watcher { FileChangeEvent }

def port_bind_error(port: int) -> Optional[str] {
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    try {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(("0.0.0.0", port));
        return None;
    } except OSError as e {
        return str(e);
    } finally {
        s.close();
    }
}

def assert_port_available(port: int, role: str, failure_hint: str) -> None {
    err = port_bind_error(port);
    if err is None {
        return;
    }
    raise RuntimeError(f"{role} port {port} is already in use ({err}). {failure_hint}");
}

def resolve_port_or_next_available(
    start_port: int,
    role: str,
    reserved: Optional[list[int]] = None,
    max_scan: int = 200
) -> int {
    reserved_set: set[int] = set(reserved or []);
    candidate = start_port;
    first_err: Optional[str] = None;
    scans = 0;

    while scans <= max_scan {
        if candidate in reserved_set {
            candidate += 1;
            scans += 1;
            continue;
        }
        err = port_bind_error(candidate);
        if err is None {
            if candidate != start_port {
                if first_err is None {
                    console.warning(
                        f"  {role} port {start_port} is reserved; using {candidate}."
                    );
                } else {
                    console.warning(
                        f"  {role} port {start_port} is in use ({first_err}); "
                        f"using {candidate}."
                    );
                }
            }
            return candidate;
        }
        if first_err is None {
            first_err = err;
        }
        candidate += 1;
        scans += 1;
    }

    raise RuntimeError(
        f"Unable to find a free {role} port starting at {start_port} "
        f"(scanned {max_scan + 1} ports)."
    );
}

def setup_android_port_reverse_common(ports: list[int], timeout: int = 5) -> None {
    if not shutil.which("adb") {
        return;
    }
    seen: set[int] = set();
    for port in ports {
        if port <= 0 or port in seen {
            continue;
        }
        seen.add(port);
        cmd = ["adb", "reverse", f"tcp:{port}", f"tcp:{port}"];
        try {
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout, check=False
            );
            if result.returncode == 0 {
                console.print(
                    f"  ✔ adb reverse tcp:{port} tcp:{port}", style="success"
                );
            } else {
                err = (result.stderr or "").strip() or "unknown adb error";
                console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({err})");
            }
        } except Exception as e {
            console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({e})");
        }
    }
}

def ensure_watchdog_common(target_name: str) -> bool {
    try {
        import watchdog;
        return True;
    } except ImportError {
        console.warning(
            f"  watchdog not installed — saving .jac files will not refresh {target_name}. "
            "Install with: pip install 'watchdog>=3.0.0' (or add to [dev-dependencies]).",
            style="muted"
        );
        return False;
    }
}

def start_backend_server_common(entry_file: Path, project_dir: Path, port: int) -> any {
    import sys;
    return subprocess.Popen(
        [sys.executable, "-m", "jaclang"] + headless_start_args(str(entry_file), port),
        cwd=str(project_dir),
        stdout=None,
        stderr=None
    );
}

def prepare_vite_dev_compilation(project_dir: Path, entry_file: Path) -> tuple {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client.vite_client_bundle {
        make_client_bundle_builder
    }

    console.print("  Preparing compilation for Vite dev…", style="muted");
    bundler = ViteBundler(project_dir=project_dir);
    package_json_path = bundler._get_client_dir() / "configs" / "package.json";
    if not package_json_path.exists() {
        bundler.create_package_json();
    }
    builder = make_client_bundle_builder(project_dir);
    if not builder.vite_package_json or not builder.vite_package_json.exists() {
        builder.vite_package_json = package_json_path;
    }
    compiler = builder._get_compiler();
    compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
    (_, mod, _) = compiler.jac_compiler.compile_module(entry_file);
    if not mod {
        raise RuntimeError(f"Failed to compile client entry module: {entry_file}");
    }
    compiler.compile(mod, entry_file);
    console.print("  ✔ Client modules compiled for dev mode", style="success");
    return (bundler, compiler);
}

obj _ClientHmrHandler {
    has compiler: any,
        entry_file: Path,
        project_dir: Path;

    def on_event(evt: FileChangeEvent) -> None {
        try {
            pth = evt.path or "";
            if not pth or not pth.endswith(".jac") {
                return;
            }
            try {
                Path(pth).resolve().relative_to(self.project_dir.resolve());
            } except ValueError {
                return;
            }
            invalidate_runtime_module_cache([pth, str(self.entry_file)]);
            compile_out = cast(
                Any, self.compiler.jac_compiler.compile_module(self.entry_file)
            );
            mod2 = compile_out[1];
            if not mod2 {
                return;
            }
            self.compiler.compile(mod2, self.entry_file);
            console.print("  ✔ Client recompiled after save", style="success");
        } except Exception as e {
            console.error(f"  HMR recompile failed: {e}");
        }
    }
}

def invalidate_runtime_module_cache(paths: list[str]) -> None {
    try {
        import from jaclang { JacRuntime as Jac }
        program = Jac.program;
        if not program or not program.mod or not program.mod.hub {
            return;
        }
        hub = program.mod.hub;
        norm_targets: set[str] = set();
        for p in paths {
            if not p {
                continue;
            }
            try {
                norm_targets.add(os.path.normcase(str(Path(p).resolve())));
            } except Exception {
                norm_targets.add(os.path.normcase(str(p)));
            }
        }
        if not norm_targets {
            return;
        }
        to_delete: list[str] = [];
        for k in list(hub.keys()) {
            if os.path.normcase(str(k)) in norm_targets {
                to_delete.append(k);
            }
        }
        for k in to_delete {
            del hub[k];
        }
    } except Exception {
        return;
    }
}

def stop_dev_watcher(watcher: any) {
    if watcher {
        try {
            watcher.stop();
        } except Exception { }
    }
}

def terminate_dev_processes(
    processes: list[any], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) {
    for p in processes {
        if not p {
            continue;
        }
        try {
            p.terminate();
            p.wait(timeout=timeout);
        } except Exception {
            try {
                p.kill();
            } except Exception { }
        }
    }
}

def install_dev_signal_handlers {
    import signal;
    import sys;
    import from typing { cast }
    def on_signal(signum: int, frame: any) {
        sys.exit(0);
    }
    signal.signal(cast(int, signal.SIGINT), on_signal);
    signal.signal(cast(int, signal.SIGTERM), on_signal);
}
