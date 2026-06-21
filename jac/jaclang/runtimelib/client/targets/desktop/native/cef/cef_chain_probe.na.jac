"""Full handler-chain probe: subprocess → startup → browser → render bootstrap.

Set these before running:
  JAC_CEF_SINGLE_PROCESS=1   (render callbacks fire in main process)
  JAC_CEF_HEADLESS=1          (no display needed)
  JAC_CEF_USER_DATA_DIR=/tmp/cef_probe_XXX

Logs to watch on stderr:
  [cef] startup: cef_initialize ok
  [cef] context initialized
  [cef] context initialized: browser created
  [cef] render: bootstrap injected    ← proves render handler chain
  [cef] browser before-close
"""

import sys;
import from "libcef.so" {
    def cef_run_message_loop -> None;  def cef_shutdown -> None;
}
import from "libcef_dispatch.so" {
    def cef_dispatch_execute_process -> i32;  def cef_dispatch_startup(
        cache_path: str, no_sandbox: int
    ) -> i32;  def cef_dispatch_set_pending_browser(
        url: str, title: str, width: int, height: int
    ) -> None;
}

glob sub_code: i32 = cef_dispatch_execute_process();

with entry {
    if sub_code >= 0 {
        sys.exit(sub_code);
    }
    cef_dispatch_set_pending_browser("about:blank", "chain-probe", 800, 600);
}

glob rc: i32 = cef_dispatch_startup("", 1);

with entry {
    if rc == 1 {
        cef_run_message_loop();
    }
    cef_shutdown();
}
