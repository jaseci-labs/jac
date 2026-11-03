glob:priv METH_FASTCALL: i64 = 128,
     _SESSIONS: dict[int, KernelSession] = {},
     _NEXT_SESSION: list[int] = [1];

def:priv arguments(
    args: ptr[ptr[PyObject]], count: i64, function: str, wanted: int
) -> list[any];

def:priv record_of(value: any, function: str) -> dict[str, any];

def:priv answer(value: any) -> ptr[PyObject];

def:priv compile_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv check_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv open_session_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_query_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv close_session_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_of(handle: any) -> KernelSession;

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "jac_kernel",
         "The Jac compiler kernel.",
         [
             MethodDefinition(
                 "compile",
                 MethodCallbacks(fast=compile_call),
                 "compile(request) -> dict\n\nCompile a CompileRequest given as plain data.",
                 flags=METH_FASTCALL
             ),
             MethodDefinition(
                 "check",
                 MethodCallbacks(fast=check_call),
                 "check(request) -> dict\n\nCheck a CheckRequest given as plain data.",
                 flags=METH_FASTCALL
             ),
             MethodDefinition(
                 "open_session",
                 MethodCallbacks(fast=open_session_call),
                 "open_session(project_root, search_paths, package_root) -> int\n\nOpen a session and return its handle.",
                 flags=METH_FASTCALL
             ),
             MethodDefinition(
                 "session_query",
                 MethodCallbacks(fast=session_query_call),
                 "session_query(handle, method, args) -> object\n\nAnswer one session query as plain data.",
                 flags=METH_FASTCALL
             ),
             MethodDefinition(
                 "close_session",
                 MethodCallbacks(fast=close_session_call),
                 "close_session(handle) -> None\n\nDrop a session.",
                 flags=METH_FASTCALL
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_jac_kernel -> ptr[PyObject];
