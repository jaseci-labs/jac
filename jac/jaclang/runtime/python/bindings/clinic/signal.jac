def:priv signal_default_int_handler_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_default_int_handler_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_alarm_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_pause_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_raise_signal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_signal_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_signal_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_getsignal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_strsignal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_siginterrupt_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_siginterrupt_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob:priv signal_set_wakeup_fd_signature = CallSignature(
         "set_wakeup_fd", ["fd", "warn_on_full_buffer"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv signal_set_wakeup_fd_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_set_wakeup_fd_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_setitimer_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_setitimer_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_getitimer_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_pthread_sigmask_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_pthread_sigmask_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_sigpending_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_sigwait_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_valid_signals_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_sigwaitinfo_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv signal_sigtimedwait_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_sigtimedwait_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_pthread_kill_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_pthread_kill_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv signal_pidfd_send_signal_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv signal_pidfd_send_signal_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob struct_siginfo__doc__: str = "struct_siginfo: Result from sigwaitinfo or sigtimedwait.\n\nThis object may be accessed either as a tuple of\n(si_signo, si_code, si_errno, si_pid, si_uid, si_status, si_band),\nor via the attributes si_signo, si_code, and so on.",
     module_doc: str = "This module provides mechanisms to use signal handlers in Python.\n\nFunctions:\n\nalarm() -- cause SIGALRM after a specified time [Unix only]\nsetitimer() -- cause a signal (described below) after a specified\n               float time and the timer may restart then [Unix only]\ngetitimer() -- get current value of timer [Unix only]\nsignal() -- set the action for a given signal\ngetsignal() -- get the signal action for a given signal\npause() -- wait until a signal arrives [Unix only]\ndefault_int_handler() -- default SIGINT handler\n\nsignal constants:\nSIG_DFL -- used to refer to the system default handler\nSIG_IGN -- used to ignore the signal\nNSIG -- number of defined signals\nSIGINT, SIGTERM, etc. -- signal numbers\n\nitimer constants:\nITIMER_REAL -- decrements in real time, and delivers SIGALRM upon\n               expiration\nITIMER_VIRTUAL -- decrements only when the process is executing,\n               and delivers SIGVTALRM upon expiration\nITIMER_PROF -- decrements both when the process is executing and\n               when the system is executing on behalf of the process.\n               Coupled with ITIMER_VIRTUAL, this timer is usually\n               used to profile the time spent by the application\n               in user and kernel space. SIGPROF is delivered upon\n               expiration.\n\n\n*** IMPORTANT NOTICE ***\nA signal handler function is called with two arguments:\nthe first is the signal number, the second is the interrupted stack frame.",
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "default_int_handler",
             MethodCallbacks(fast=signal_default_int_handler_call),
             "default_int_handler($module, signalnum, frame, /)\n--\n\nThe default handler for SIGINT installed by Python.\n\nIt raises KeyboardInterrupt.",
             128
         ),
         MethodDefinition(
             "alarm",
             MethodCallbacks(positional=signal_alarm_call),
             "alarm($module, seconds, /)\n--\n\nArrange for SIGALRM to arrive after the given number of seconds.",
             8
         ),
         MethodDefinition(
             "pause",
             MethodCallbacks(positional=signal_pause_call),
             "pause($module, /)\n--\n\nWait until a signal arrives.",
             4
         ),
         MethodDefinition(
             "raise_signal",
             MethodCallbacks(positional=signal_raise_signal_call),
             "raise_signal($module, signalnum, /)\n--\n\nSend a signal to the executing process.",
             8
         ),
         MethodDefinition(
             "signal",
             MethodCallbacks(fast=signal_signal_call),
             "signal($module, signalnum, handler, /)\n--\n\nSet the action for the given signal.\n\nThe action can be SIG_DFL, SIG_IGN, or a callable Python object.\nThe previous action is returned.  See getsignal() for possible return\nvalues.\n\n*** IMPORTANT NOTICE ***\nA signal handler function is called with two arguments: the first is\nthe signal number, the second is the interrupted stack frame.",
             128
         ),
         MethodDefinition(
             "getsignal",
             MethodCallbacks(positional=signal_getsignal_call),
             "getsignal($module, signalnum, /)\n--\n\nReturn the current action for the given signal.\n\nThe return value can be:\n  SIG_IGN -- if the signal is being ignored\n  SIG_DFL -- if the default action for the signal is in effect\n  None    -- if an unknown handler is in effect\n  anything else -- the callable Python object used as a handler",
             8
         ),
         MethodDefinition(
             "strsignal",
             MethodCallbacks(positional=signal_strsignal_call),
             "strsignal($module, signalnum, /)\n--\n\nReturn the system description of the given signal.\n\nReturns the description of signal *signalnum*, such as \"Interrupt\"\nfor :const:`SIGINT`. Returns :const:`None` if *signalnum* has no\ndescription. Raises :exc:`ValueError` if *signalnum* is invalid.",
             8
         ),
         MethodDefinition(
             "siginterrupt",
             MethodCallbacks(fast=signal_siginterrupt_call),
             "siginterrupt($module, signalnum, flag, /)\n--\n\nChange system call restart behaviour.\n\nIf flag is False, system calls will be restarted when interrupted by\nsignal sig, else system calls will be interrupted.",
             128
         ),
         MethodDefinition(
             "set_wakeup_fd",
             MethodCallbacks(fast_keywords=signal_set_wakeup_fd_call),
             "set_wakeup_fd($module, fd, /, *, warn_on_full_buffer=True)\n--\n\nSets the fd to be written to (with the signal number) when a signal comes in.\n\nA library can use this to wakeup select or poll.\nThe previous fd or -1 is returned.\n\nThe fd must be non-blocking.",
             130
         ),
         MethodDefinition(
             "setitimer",
             MethodCallbacks(fast=signal_setitimer_call),
             "setitimer($module, which, seconds, interval=0.0, /)\n--\n\nSets given itimer (one of ITIMER_REAL, ITIMER_VIRTUAL or ITIMER_PROF).\n\nThe timer will fire after value seconds and after that every interval\nseconds.  The itimer can be cleared by setting seconds to zero.\n\nReturns old values as a tuple: (delay, interval).",
             128
         ),
         MethodDefinition(
             "getitimer",
             MethodCallbacks(positional=signal_getitimer_call),
             "getitimer($module, which, /)\n--\n\nReturns current value of given itimer.",
             8
         ),
         MethodDefinition(
             "pthread_sigmask",
             MethodCallbacks(fast=signal_pthread_sigmask_call),
             "pthread_sigmask($module, how, mask, /)\n--\n\nFetch and/or change the signal mask of the calling thread.",
             128
         ),
         MethodDefinition(
             "sigpending",
             MethodCallbacks(positional=signal_sigpending_call),
             "sigpending($module, /)\n--\n\nExamine pending signals.\n\nReturns a set of signal numbers that are pending for delivery to\nthe calling thread.",
             4
         ),
         MethodDefinition(
             "sigwait",
             MethodCallbacks(positional=signal_sigwait_call),
             "sigwait($module, sigset, /)\n--\n\nWait for a signal.\n\nSuspend execution of the calling thread until the delivery of one of the\nsignals specified in the signal set sigset.  The function accepts the\nsignal and returns the signal number.",
             8
         ),
         MethodDefinition(
             "valid_signals",
             MethodCallbacks(positional=signal_valid_signals_call),
             "valid_signals($module, /)\n--\n\nReturn a set of valid signal numbers on this platform.\n\nThe signal numbers returned by this function can be safely passed to\nfunctions like `pthread_sigmask`.",
             4
         ),
         MethodDefinition(
             "sigwaitinfo",
             MethodCallbacks(positional=signal_sigwaitinfo_call),
             "sigwaitinfo($module, sigset, /)\n--\n\nWait synchronously until one of the signals in *sigset* is delivered.\n\nReturns a struct_siginfo containing information about the signal.",
             8
         ),
         MethodDefinition(
             "sigtimedwait",
             MethodCallbacks(fast=signal_sigtimedwait_call),
             "sigtimedwait($module, sigset, timeout, /)\n--\n\nLike sigwaitinfo(), but with a timeout.\n\nThe timeout is specified in seconds, with floating-point numbers allowed.",
             128
         ),
         MethodDefinition(
             "pthread_kill",
             MethodCallbacks(fast=signal_pthread_kill_call),
             "pthread_kill($module, thread_id, signalnum, /)\n--\n\nSend a signal to a thread.",
             128
         ),
         MethodDefinition(
             "pidfd_send_signal",
             MethodCallbacks(fast=signal_pidfd_send_signal_call),
             "pidfd_send_signal($module, pidfd, signalnum, siginfo=None, flags=0, /)\n--\n\nSend a signal to a process referred to by a pid file descriptor.",
             128
         ),

     ];

impl signal_default_int_handler_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        signalnum: i32 = convert_int(value);
        value = clinic_args[1];
        frame: ptr[PyObject] = value;
        return signal_default_int_handler_impl(receiver, signalnum, frame);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_default_int_handler_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("default_int_handler", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_default_int_handler_bound(receiver, args, nargs);
}

impl signal_alarm_call(receiver: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    try {
        seconds: i32 = convert_int(value);
        return return_long(signal_alarm_impl(receiver, seconds));
    } except boundary_failure {
        return NULL;
    }
}

impl signal_pause_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return signal_pause_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_raise_signal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        signalnum: i32 = convert_int(value);
        return signal_raise_signal_impl(receiver, signalnum);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_signal_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        signalnum: i32 = convert_int(value);
        value = clinic_args[1];
        handler: ptr[PyObject] = value;
        return signal_signal_impl(receiver, signalnum, handler);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_signal_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2) and not check_positional("signal", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_signal_bound(receiver, args, nargs);
}

impl signal_getsignal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        signalnum: i32 = convert_int(value);
        return signal_getsignal_impl(receiver, signalnum);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_strsignal_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        signalnum: i32 = convert_int(value);
        return signal_strsignal_impl(receiver, signalnum);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_siginterrupt_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        signalnum: i32 = convert_int(value);
        value = clinic_args[1];
        flag: i32 = convert_int(value);
        return signal_siginterrupt_impl(receiver, signalnum, flag);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_siginterrupt_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("siginterrupt", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_siginterrupt_bound(receiver, args, nargs);
}

impl signal_set_wakeup_fd_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        fd: ptr[PyObject] = value;
        warn_on_full_buffer: bool = True;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            warn_on_full_buffer = convert_bool(value);
        }
        return signal_set_wakeup_fd_impl(receiver, fd, warn_on_full_buffer);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_set_wakeup_fd_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return signal_set_wakeup_fd_bound(receiver, args, nargs);
    }
    values = unpack_stack(signal_set_wakeup_fd_signature, args, nargs, kwnames);
    if values {
        unpacked = signal_set_wakeup_fd_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        signal_set_wakeup_fd_signature,
        args,
        nargs,
        kwnames,
        signal_set_wakeup_fd_bound,
        receiver
    );
}

impl signal_setitimer_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        which: i32 = convert_int(value);
        value = clinic_args[1];
        seconds: ptr[PyObject] = value;
        interval: ptr[PyObject] = NULL;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            interval = value;
        }
        return signal_setitimer_impl(receiver, which, seconds, interval);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_setitimer_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 3)
        and not check_positional("setitimer", int(nargs), 2, 3) {
        return NULL;
    }
    return signal_setitimer_bound(receiver, args, nargs);
}

impl signal_getitimer_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        which: i32 = convert_int(value);
        return signal_getitimer_impl(receiver, which);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_pthread_sigmask_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        how: i32 = convert_int(value);
        value = clinic_args[1];
        mask = convert__Py_Sigset_Converter(
            value, "pthread_sigmask", argument_label("", 2)
        );
        return signal_pthread_sigmask_impl(receiver, how, mask);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_pthread_sigmask_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("pthread_sigmask", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_pthread_sigmask_bound(receiver, args, nargs);
}

impl signal_sigpending_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return signal_sigpending_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_sigwait_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        sigset = convert__Py_Sigset_Converter(value, "sigwait", "argument");
        return signal_sigwait_impl(receiver, sigset);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_valid_signals_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return signal_valid_signals_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_sigwaitinfo_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        sigset = convert__Py_Sigset_Converter(value, "sigwaitinfo", "argument");
        return signal_sigwaitinfo_impl(receiver, sigset);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_sigtimedwait_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        sigset = convert__Py_Sigset_Converter(
            value, "sigtimedwait", argument_label("", 1)
        );
        value = clinic_args[1];
        timeout: ptr[PyObject] = value;
        return signal_sigtimedwait_impl(receiver, sigset, timeout);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_sigtimedwait_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("sigtimedwait", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_sigtimedwait_bound(receiver, args, nargs);
}

impl signal_pthread_kill_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        thread_id: u64 = convert_unsigned_long(
            value, True, "pthread_kill", argument_label("", 1)
        );
        value = clinic_args[1];
        signalnum: i32 = convert_int(value);
        return signal_pthread_kill_impl(receiver, thread_id, signalnum);
    } except boundary_failure {
        return NULL;
    }
}

impl signal_pthread_kill_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("pthread_kill", int(nargs), 2, 2) {
        return NULL;
    }
    return signal_pthread_kill_bound(receiver, args, nargs);
}

impl signal_pidfd_send_signal_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        pidfd: i32 = convert_int(value);
        value = clinic_args[1];
        signalnum: i32 = convert_int(value);
        siginfo: ptr[PyObject] = borrowed_none();
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            siginfo = value;
        }
        flags: i32 = 0;
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            flags = convert_int(value);
        }
        return signal_pidfd_send_signal_impl(
            receiver, pidfd, signalnum, siginfo, flags
        );
    } except boundary_failure {
        return NULL;
    }
}

impl signal_pidfd_send_signal_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 4)
        and not check_positional("pidfd_send_signal", int(nargs), 2, 4) {
        return NULL;
    }
    return signal_pidfd_send_signal_bound(receiver, args, nargs);
}
