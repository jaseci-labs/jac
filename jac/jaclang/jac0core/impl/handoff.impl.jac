impl handoff -> dict[str, object] {
    raw = os.environ.get(HANDOFF_ENV, "");
    if not raw {
        return {};
    }
    try {
        record = json.loads(raw);
    } except ValueError {
        return {};
    }
    if isinstance(record, dict) {
        return record;
    }
    return {};
}

impl update_handoff(**fields: object) {
    record = handoff();
    for (key, value) in fields.items() {
        if value is None {
            record.pop(key, None);
        } else {
            record[key] = value;
        }
    }
    if record {
        os.environ[HANDOFF_ENV] = json.dumps(record, sort_keys=True);
    } else {
        os.environ.pop(HANDOFF_ENV, None);
    }
}

impl process_executable -> str {
    try {
        if sys.platform.startswith("linux") {
            return os.path.realpath("/proc/self/exe");
        }
        import ctypes;
        if sys.platform == "darwin" {
            size = ctypes.c_uint32(0);
            libc = ctypes.CDLL(None);
            libc._NSGetExecutablePath(None, ctypes.byref(size));
            buf = ctypes.create_string_buffer(size.value);
            if libc._NSGetExecutablePath(buf, ctypes.byref(size)) == 0 {
                return os.path.realpath(buf.value.decode());
            }
        } elif sys.platform == "win32" {
            wide = ctypes.create_unicode_buffer(32768);
            if getattr(ctypes.windll.kernel32, "GetModuleFileNameW")(
                None, wide, 32768
            ) {
                return wide.value;
            }
        }
    } except (OSError, AttributeError, ValueError) {}
    return os.path.realpath(sys.executable);
}
