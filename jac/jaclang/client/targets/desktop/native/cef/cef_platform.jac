glob g_cmdline_buf: int = 0,
     g_argv_arr: int = 0;

glob CEF_ABI_MAJOR: int = 119,
     CEF_ABI_MINOR: int = 4,
     CEF_ABI_PATCH: int = 7;
glob g_abi_checked: int = 0;

def _eprint(msg: str);

def _write_uint(n: int);

def _assert_cef_abi;

def cef_stub_add_ref(self: int);
def cef_stub_release(self: int) -> int;

def cef_stub_has_one_ref(self: int) -> int;

def cef_stub_has_at_least_one_ref(self: int) -> int;

def cef_main_args_create -> int;
