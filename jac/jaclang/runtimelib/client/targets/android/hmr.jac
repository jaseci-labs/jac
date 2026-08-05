import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.android.dev_server { publish_hot_module }
import from jaclang.runtimelib.watcher { FileChangeEvent, ChangeType }

obj AndroidHotReloadHandler {
    has target: any,
        entry_file: Path,
        project_dir: Path,
        android_dir: Path,
        package_name: str,
        state: dict,
        _busy: bool = False;

    def _is_watched_jac(path: str) -> bool {
        if not path or not path.endswith(".jac") {
            return False;
        }
        if "node_modules" in path or "/.git/" in path or "apps/android" in path {
            return False;
        }
        try {
            Path(path).resolve().relative_to(self.project_dir.resolve());
        } except ValueError {
            return False;
        }
        return True;
    }

    def on_event(evt: FileChangeEvent) {
        if self._busy or not self._is_watched_jac(evt.path or "") {
            return;
        }
        self._busy = True;
        try {
            console.print(
                f"  ⚡ client .jac changed — rebuilding hot module...", style="muted"
            );
            (model, _mod) = self.target._compile_compose_modules(
                self.entry_file, self.project_dir
            );
            if model is not None {
                import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
                model.intent.package_name = self.package_name;
                emitter = ComposeEmit(model=model, out_dir=self.android_dir, dev=True);
                emitter.write();
            }
            (version, dex_path) = self.target._build_hot_dex(
                self.android_dir, self.package_name
            );
            publish_hot_module(self.state, version, str(dex_path));
            console.success(f"  ⚡ Hot module swapped → v{version}");
        } except Exception as e {
            console.warning(f"  hot rebuild failed: {e}");
        } finally {
            self._busy = False;
        }
    }
}

def watch_android_hot_reload(
    target: any,
    entry_file: Path,
    project_dir: Path,
    android_dir: Path,
    package_name: str,
    state: dict
) {
    import from time { sleep }
    import from jaclang.runtimelib.client.targets.client_dev_common {
        ensure_watchdog_common,
        install_dev_signal_handlers
    }
    import from jaclang.runtimelib.watcher { JacFileWatcher }

    install_dev_signal_handlers();
    if not ensure_watchdog_common("the Android hot module") {
        _watch_android_hot_reload_poll(
            target, entry_file, project_dir, android_dir, package_name, state
        );
        return;
    }

    handler = AndroidHotReloadHandler(
        target=target,
        entry_file=entry_file,
        project_dir=project_dir,
        android_dir=android_dir,
        package_name=package_name,
        state=state
    );
    watcher = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
    watcher.add_callback(handler.on_event);
    watcher.start();
    console.print("  Watching client .jac files for hot reload.", style="muted");
    try {
        while True {
            sleep(1);
        }
    } except KeyboardInterrupt {
        watcher.stop();
        console.print("  dev server stopped.", style="muted");
    }
}

def _watch_android_hot_reload_poll(
    target: any,
    entry_file: Path,
    project_dir: Path,
    android_dir: Path,
    package_name: str,
    state: dict
) {
    import from time { sleep }

    sources = target._collect_jac_sources(project_dir);
    mtimes: dict = {};
    for s in sources {
        try {
            mtimes[s] = s.stat().st_mtime;
        } except Exception { }
    }
    try {
        while True {
            sleep(0.5);
            changed: list = [];
            for s in target._collect_jac_sources(project_dir) {
                try {
                    m = s.stat().st_mtime;
                } except Exception {
                    continue;
                }
                if m != mtimes.get(s) {
                    mtimes[s] = m;
                    changed.append(s);
                }
            }
            if changed {
                handler = AndroidHotReloadHandler(
                    target=target,
                    entry_file=entry_file,
                    project_dir=project_dir,
                    android_dir=android_dir,
                    package_name=package_name,
                    state=state
                );
                handler.on_event(
                    FileChangeEvent(
                        path=str(changed[0]),
                        change_type=ChangeType.MODIFIED,
                        timestamp=0.0
                    )
                );
            }
        }
    } except KeyboardInterrupt {
        console.print("  dev server stopped.", style="muted");
    }
}
