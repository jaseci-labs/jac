"""The Argument Clinic signatures of _signal.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/signal.jac from them. Taken from
CPython 3.14.6 Modules/signalmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_signal",
         version="3.14.6",
         sources=["Modules/signalmodule.c"],
         functions=[
             Function(
                 name="default_int_handler",
                 full_name="signal.default_int_handler",
                 c_basename="signal_default_int_handler",
                 docstring="default_int_handler($module, signalnum, frame, /)\n"
                 "--\n"
                 "\n"
                 "The default handler for SIGINT installed by Python.\n"
                 "\n"
                 "It raises KeyboardInterrupt.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="frame", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="alarm",
                 full_name="signal.alarm",
                 c_basename="signal_alarm",
                 docstring="alarm($module, seconds, /)\n"
                 "--\n"
                 "\n"
                 "Arrange for SIGALRM to arrive after the given number of seconds.",
                 condition="defined(HAVE_ALARM)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="seconds",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pause",
                 full_name="signal.pause",
                 c_basename="signal_pause",
                 docstring="pause($module, /)\n"
                 "--\n"
                 "\n"
                 "Wait until a signal arrives.",
                 condition="defined(HAVE_PAUSE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="raise_signal",
                 full_name="signal.raise_signal",
                 c_basename="signal_raise_signal",
                 docstring="raise_signal($module, signalnum, /)\n"
                 "--\n"
                 "\n"
                 "Send a signal to the executing process.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="signal",
                 full_name="signal.signal",
                 c_basename="signal_signal",
                 docstring="signal($module, signalnum, handler, /)\n"
                 "--\n"
                 "\n"
                 "Set the action for the given signal.\n"
                 "\n"
                 "The action can be SIG_DFL, SIG_IGN, or a callable Python object.\n"
                 "The previous action is returned.  See getsignal() for possible return\n"
                 "values.\n"
                 "\n"
                 "*** IMPORTANT NOTICE ***\n"
                 "A signal handler function is called with two arguments: the first is\n"
                 "the signal number, the second is the interrupted stack frame.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="handler", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getsignal",
                 full_name="signal.getsignal",
                 c_basename="signal_getsignal",
                 docstring="getsignal($module, signalnum, /)\n"
                 "--\n"
                 "\n"
                 "Return the current action for the given signal.\n"
                 "\n"
                 "The return value can be:\n"
                 "  SIG_IGN -- if the signal is being ignored\n"
                 "  SIG_DFL -- if the default action for the signal is in effect\n"
                 "  None    -- if an unknown handler is in effect\n"
                 "  anything else -- the callable Python object used as a handler",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="strsignal",
                 full_name="signal.strsignal",
                 c_basename="signal_strsignal",
                 docstring="strsignal($module, signalnum, /)\n"
                 "--\n"
                 "\n"
                 "Return the system description of the given signal.\n"
                 "\n"
                 "Returns the description of signal *signalnum*, such as \"Interrupt\"\n"
                 "for :const:`SIGINT`. Returns :const:`None` if *signalnum* has no\n"
                 "description. Raises :exc:`ValueError` if *signalnum* is invalid.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="siginterrupt",
                 full_name="signal.siginterrupt",
                 c_basename="signal_siginterrupt",
                 docstring="siginterrupt($module, signalnum, flag, /)\n"
                 "--\n"
                 "\n"
                 "Change system call restart behaviour.\n"
                 "\n"
                 "If flag is False, system calls will be restarted when interrupted by\n"
                 "signal sig, else system calls will be interrupted.",
                 condition="defined(HAVE_SIGINTERRUPT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="flag",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="set_wakeup_fd",
                 full_name="signal.set_wakeup_fd",
                 c_basename="signal_set_wakeup_fd",
                 docstring="set_wakeup_fd($module, fd, /, *, warn_on_full_buffer=True)\n"
                 "--\n"
                 "\n"
                 "Sets the fd to be written to (with the signal number) when a signal comes in.\n"
                 "\n"
                 "A library can use this to wakeup select or poll.\n"
                 "The previous fd or -1 is returned.\n"
                 "\n"
                 "The fd must be non-blocking.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="warn_on_full_buffer",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setitimer",
                 full_name="signal.setitimer",
                 c_basename="signal_setitimer",
                 docstring="setitimer($module, which, seconds, interval=0.0, /)\n"
                 "--\n"
                 "\n"
                 "Sets given itimer (one of ITIMER_REAL, ITIMER_VIRTUAL or ITIMER_PROF).\n"
                 "\n"
                 "The timer will fire after value seconds and after that every interval\n"
                 "seconds.  The itimer can be cleared by setting seconds to zero.\n"
                 "\n"
                 "Returns old values as a tuple: (delay, interval).",
                 condition="defined(HAVE_SETITIMER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="which",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="seconds", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="interval",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0.0,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="getitimer",
                 full_name="signal.getitimer",
                 c_basename="signal_getitimer",
                 docstring="getitimer($module, which, /)\n"
                 "--\n"
                 "\n"
                 "Returns current value of given itimer.",
                 condition="defined(HAVE_GETITIMER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="which",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pthread_sigmask",
                 full_name="signal.pthread_sigmask",
                 c_basename="signal_pthread_sigmask",
                 docstring="pthread_sigmask($module, how, mask, /)\n"
                 "--\n"
                 "\n"
                 "Fetch and/or change the signal mask of the calling thread.",
                 condition="defined(HAVE_SIGSET_T) && defined(PYPTHREAD_SIGMASK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="how",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="mask",
                         kind="POSITIONAL_ONLY",
                         converter="sigset_t",
                         type="sigset_t",
                         format_unit="O&",
                         convert_with="_Py_Sigset_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sigpending",
                 full_name="signal.sigpending",
                 c_basename="signal_sigpending",
                 docstring="sigpending($module, /)\n"
                 "--\n"
                 "\n"
                 "Examine pending signals.\n"
                 "\n"
                 "Returns a set of signal numbers that are pending for delivery to\n"
                 "the calling thread.",
                 condition="defined(HAVE_SIGSET_T) && defined(HAVE_SIGPENDING)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="sigwait",
                 full_name="signal.sigwait",
                 c_basename="signal_sigwait",
                 docstring="sigwait($module, sigset, /)\n"
                 "--\n"
                 "\n"
                 "Wait for a signal.\n"
                 "\n"
                 "Suspend execution of the calling thread until the delivery of one of the\n"
                 "signals specified in the signal set sigset.  The function accepts the\n"
                 "signal and returns the signal number.",
                 condition="defined(HAVE_SIGSET_T) && defined(HAVE_SIGWAIT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="sigset",
                         kind="POSITIONAL_ONLY",
                         converter="sigset_t",
                         type="sigset_t",
                         format_unit="O&",
                         convert_with="_Py_Sigset_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="valid_signals",
                 full_name="signal.valid_signals",
                 c_basename="signal_valid_signals",
                 docstring="valid_signals($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a set of valid signal numbers on this platform.\n"
                 "\n"
                 "The signal numbers returned by this function can be safely passed to\n"
                 "functions like `pthread_sigmask`.",
                 condition="((defined(HAVE_SIGFILLSET) && defined(HAVE_SIGSET_T)) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="sigwaitinfo",
                 full_name="signal.sigwaitinfo",
                 c_basename="signal_sigwaitinfo",
                 docstring="sigwaitinfo($module, sigset, /)\n"
                 "--\n"
                 "\n"
                 "Wait synchronously until one of the signals in *sigset* is delivered.\n"
                 "\n"
                 "Returns a struct_siginfo containing information about the signal.",
                 condition="defined(HAVE_SIGSET_T) && defined(HAVE_SIGWAITINFO)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="sigset",
                         kind="POSITIONAL_ONLY",
                         converter="sigset_t",
                         type="sigset_t",
                         format_unit="O&",
                         convert_with="_Py_Sigset_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sigtimedwait",
                 full_name="signal.sigtimedwait",
                 c_basename="signal_sigtimedwait",
                 docstring="sigtimedwait($module, sigset, timeout, /)\n"
                 "--\n"
                 "\n"
                 "Like sigwaitinfo(), but with a timeout.\n"
                 "\n"
                 "The timeout is specified in seconds, with floating-point numbers allowed.",
                 condition="defined(HAVE_SIGSET_T) && defined(HAVE_SIGTIMEDWAIT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="sigset",
                         kind="POSITIONAL_ONLY",
                         converter="sigset_t",
                         type="sigset_t",
                         format_unit="O&",
                         convert_with="_Py_Sigset_Converter"
                     ),
                     Parameter(name="timeout", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pthread_kill",
                 full_name="signal.pthread_kill",
                 c_basename="signal_pthread_kill",
                 docstring="pthread_kill($module, thread_id, signalnum, /)\n"
                 "--\n"
                 "\n"
                 "Send a signal to a thread.",
                 condition="defined(HAVE_PTHREAD_KILL)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="thread_id",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="k"
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pidfd_send_signal",
                 full_name="signal.pidfd_send_signal",
                 c_basename="signal_pidfd_send_signal",
                 docstring="pidfd_send_signal($module, pidfd, signalnum, siginfo=None, flags=0, /)\n"
                 "--\n"
                 "\n"
                 "Send a signal to a process referred to by a pid file descriptor.",
                 condition="(defined(__linux__) && defined(__NR_pidfd_send_signal) && !(defined(__ANDROID__) && __ANDROID_API__ < 31))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pidfd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="signalnum",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="siginfo",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="flags",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=4,
                 pos_only=4
             )
         ],
         docs={
             "struct_siginfo__doc__": "struct_siginfo: Result from sigwaitinfo or sigtimedwait.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "(si_signo, si_code, si_errno, si_pid, si_uid, si_status, si_band),\n"
             "or via the attributes si_signo, si_code, and so on.",
             "module_doc": "This module provides mechanisms to use signal handlers in Python.\n"
             "\n"
             "Functions:\n"
             "\n"
             "alarm() -- cause SIGALRM after a specified time [Unix only]\n"
             "setitimer() -- cause a signal (described below) after a specified\n"
             "               float time and the timer may restart then [Unix only]\n"
             "getitimer() -- get current value of timer [Unix only]\n"
             "signal() -- set the action for a given signal\n"
             "getsignal() -- get the signal action for a given signal\n"
             "pause() -- wait until a signal arrives [Unix only]\n"
             "default_int_handler() -- default SIGINT handler\n"
             "\n"
             "signal constants:\n"
             "SIG_DFL -- used to refer to the system default handler\n"
             "SIG_IGN -- used to ignore the signal\n"
             "NSIG -- number of defined signals\n"
             "SIGINT, SIGTERM, etc. -- signal numbers\n"
             "\n"
             "itimer constants:\n"
             "ITIMER_REAL -- decrements in real time, and delivers SIGALRM upon\n"
             "               expiration\n"
             "ITIMER_VIRTUAL -- decrements only when the process is executing,\n"
             "               and delivers SIGVTALRM upon expiration\n"
             "ITIMER_PROF -- decrements both when the process is executing and\n"
             "               when the system is executing on behalf of the process.\n"
             "               Coupled with ITIMER_VIRTUAL, this timer is usually\n"
             "               used to profile the time spent by the application\n"
             "               in user and kernel space. SIGPROF is delivered upon\n"
             "               expiration.\n"
             "\n"
             "\n"
             "*** IMPORTANT NOTICE ***\n"
             "A signal handler function is called with two arguments:\n"
             "the first is the signal number, the second is the interrupted stack frame."
         }
     );
