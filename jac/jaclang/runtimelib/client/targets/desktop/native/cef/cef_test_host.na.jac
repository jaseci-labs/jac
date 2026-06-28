import sys;
import from cef {
    cef_execute_subprocess,
    cef_startup,
    cef_open_browser,
    cef_run_loop,
    cef_cleanup,
}

glob code: i32 = cef_execute_subprocess();

with entry {
    if code >= 0 {
        sys.exit(code);
    }
}

glob rc: i32 = cef_startup("", 1);

with entry {
    if rc == 1 {
        cef_open_browser("https://example.com", "CEF test", 1024, 768);
        cef_run_loop();
    }
    cef_cleanup();
}
