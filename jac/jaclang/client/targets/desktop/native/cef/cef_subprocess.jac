import sys;

import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;  def cef_version_info(
        which: i32
    ) -> i32;  obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }  obj cef_app_t {
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

def _subprocess_bootstrap;

glob g_app: cef_app_t = cef_app_t(
         size=80,
         add_ref=cef_stub_add_ref,
         release=cef_stub_release,
         has_one_ref=cef_stub_has_one_ref,
         has_at_least_one_ref=cef_stub_has_at_least_one_ref,
     );

def _subprocess_main;

with entry {
    _subprocess_main();
}
