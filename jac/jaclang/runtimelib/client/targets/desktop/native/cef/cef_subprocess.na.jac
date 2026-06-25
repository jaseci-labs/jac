# cef_subprocess -- imports + entry; cef_platform.na.jac is spliced in at # PLATFORM by desktop_build._splice_platform (the # ENTRY marker is dropped)
import sys;

# Import order is load-order sensitive: libcef.so MUST be NEEDED before
# libc.so.6. libcef.so's internal `close` wrapper resolves the real libc
# close via dlsym(RTLD_NEXT, "close"), which only finds libc's close when
# libc loads AFTER libcef. If libc is NEEDED first, RTLD_NEXT from libcef
# walks past it and finds nothing -> "close symbol missing" -> ImmediateCrash
# in every child process (zygote/renderer/utility/gpu). This matches the
# working libcef_dispatch.so NEEDED order (libcef.so before libc.so.6).
import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;  def cef_version_info(
        which: i32
    ) -> i32;  obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }  """cef_app_t - 80 bytes (CEF capi cef_app_t).

    MUST stay field-compatible with the copy in cef_dispatch.na.jac: same
    field order + 80-byte size. Handlers are typed int here because the
    subprocess only assigns cef_stub_* and passes the struct opaquely; the
    dispatch copy types them as Callable. Keep the two in sync by hand until
    nacompile can share a struct decl across the spliced modules."""
    obj cef_app_t {
        has size: int = 0,
            add_ref: int = 0,
            release: int = 0,
            has_one_ref: int = 0,
            has_at_least_one_ref: int = 0,
            on_before_command_line_processing: int = 0,
            on_register_custom_schemes: int = 0,
            get_resource_bundle_handler: int = 0,
            get_browser_process_handler: int = 0,
            get_render_process_handler: int = 0;
    }
}

import from "libc.so.6" {
    def setenv(name: str, value: str, overwrite: i32) -> i32;  def readlink(
        path: str, buf: int, bufsiz: int
    ) -> int;  def access(path: str, mode: i32) -> i32;  def strcpy(
        dst: int, src: str
    ) -> int;  def strcat(dst: int, src: str) -> int;  def strrchr(
        s: int, c: i32
    ) -> int;  def calloc(n: int, size: int) -> int;  def free(ptr: int) -> None;  def memset(
        s: int, c: i32, n: int
    ) -> int;  def memcpy(dst: int, src: int, n: int) -> int;  def open(
        path: str, flags: i32
    ) -> i32;  def read(fd: i32, buf: int, count: int) -> int;  def close(
        fd: i32
    ) -> i32;  def strlen(s: str) -> int;  def write(
        fd: i32, buf: int, count: int
    ) -> int;  def abort -> None;
}

# PLATFORM

# ENTRY
def _subprocess_bootstrap {
    # Match main-process bootstrap (nacompile cannot share setenv/getenv cross-module yet).
    setenv("NO_AT_BRIDGE", "1", 0);
    buf: int = calloc(1, 4096);
    n: int = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        free(buf);
        return;
    }
    memset(buf + n, 0, 1);
    slash: int = strrchr(buf, 47);
    if slash == 0 {
        free(buf);
        return;
    }
    memset(slash, 0, 1);
    fc_buf: int = calloc(1, 4096);
    strcpy(fc_buf, buf);
    strcat(fc_buf, "/minimal-fonts.conf");
    if access(fc_buf, 4) == 0 {
        setenv("FONTCONFIG_FILE", fc_buf, 0);  # no-op if already set (overwrite=0)
    }
    free(fc_buf);
    free(buf);
}

glob g_app: cef_app_t = cef_app_t(
         size=80,
         add_ref=cef_stub_add_ref,
         release=cef_stub_release,
         has_one_ref=cef_stub_has_one_ref,
         has_at_least_one_ref=cef_stub_has_at_least_one_ref,
     );

def _subprocess_main {
    _assert_cef_abi();
    _subprocess_bootstrap();
    args: int = cef_main_args_create();
    code: i32 = cef_execute_process(args, g_app, 0);
    if code >= 0 {
        sys.exit(code);
    }
}

with entry {
    _subprocess_main();
}
