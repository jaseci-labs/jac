glob:priv METH_FASTCALL: i64 = 128;

obj:priv CallbackAsker(HostAsker) {
    has callback: ptr[PyObject];

    def ask(method: str, key: str) -> dict[str, any];
}

def:priv request_of(
    args: ptr[ptr[PyObject]], count: i64, function: str
) -> KernelRequest;

def:priv asker_of(args: ptr[ptr[PyObject]], count: i64) -> (HostAsker | None);

def:priv compile_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv check_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "jac_kernel",
         "The Jac compiler kernel.",
         [
             MethodDefinition(
                 "compile",
                 MethodCallbacks(fast=compile_call),
                 "compile(request, asker=None) -> dict\n\nCompile a KernelRequest given as plain data and return its CompileReport as plain data.",
                 flags=METH_FASTCALL
             ),
             MethodDefinition(
                 "check",
                 MethodCallbacks(fast=check_call),
                 "check(request, asker=None) -> dict\n\nAnalyse a KernelRequest given as plain data and return its AnalysisReport as plain data.",
                 flags=METH_FASTCALL
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_jac_kernel -> ptr[PyObject];
