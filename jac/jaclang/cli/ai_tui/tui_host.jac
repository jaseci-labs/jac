import from jaclang.cli.ai_tui.tui_shared { _ensure_na_artifact }


obj TuiHost {
    has lib: any = None;

    def load(lib_path: str) {
        import ctypes;
        import os;

        abs_path = os.path.abspath(lib_path);
        self.lib = ctypes.CDLL(abs_path);

        self.lib.tui_init.restype = ctypes.c_int64;
        self.lib.tui_init.argtypes = [
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_char_p
        ];
        self.lib.tui_apply_frame.restype = ctypes.c_int64;
        self.lib.tui_apply_frame.argtypes = [ctypes.c_char_p];
        self.lib.tui_wait_key.restype = ctypes.c_int64;
        self.lib.tui_wait_key.argtypes = [ctypes.c_int64];
        self.lib.tui_handle_key.restype = ctypes.c_int64;
        self.lib.tui_handle_key.argtypes = [];
        self.lib.tui_next_command.restype = ctypes.c_char_p;
        self.lib.tui_next_command.argtypes = [];
        self.lib.tui_quit_requested.restype = ctypes.c_int64;
        self.lib.tui_quit_requested.argtypes = [];
        self.lib.tui_render.restype = ctypes.c_int64;
        self.lib.tui_render.argtypes = [];
        self.lib.tui_shutdown.restype = ctypes.c_int64;
        self.lib.tui_shutdown.argtypes = [];
    }

    def start(project: str, files_env: str, presets_env: str, tty_dev: str) -> int {
        return int(
            self.lib.tui_init(
                project.encode("utf-8"),
                files_env.encode("utf-8"),
                presets_env.encode("utf-8"),
                tty_dev.encode("utf-8")
            )
        );
    }

    def apply_frame(blob: str) -> int {
        return int(self.lib.tui_apply_frame(blob.encode("utf-8")));
    }

    def wait_key(timeout_ms: int) -> int {
        return int(self.lib.tui_wait_key(int(timeout_ms)));
    }

    def handle_key -> int {
        return int(self.lib.tui_handle_key());
    }

    def next_command -> str {
        raw = self.lib.tui_next_command();
        if raw is None {
            return "";
        }
        return raw.decode("utf-8", "replace");
    }

    def quit_requested -> int {
        return int(self.lib.tui_quit_requested());
    }

    def render -> int {
        return int(self.lib.tui_render());
    }

    def shutdown -> int {
        return int(self.lib.tui_shutdown());
    }
}


def _tui_lib_path(pkg_root: any) -> str {
    import sys;
    name: str = "libtui.so";
    if sys.platform == "darwin" {
        name = "libtui.dylib";
    }
    return str(pkg_root / "ai_tui_na" / "bin" / name);
}


def _ensure_tui_lib(pkg_root: any) -> dict {
    import os;
    lib_path = _tui_lib_path(pkg_root);
    return _ensure_na_artifact(
        pkg_root,
        lib_path,
        str(pkg_root / "ai_tui_na" / "host.na.jac"),
        os.path.basename(lib_path),
    );
}
