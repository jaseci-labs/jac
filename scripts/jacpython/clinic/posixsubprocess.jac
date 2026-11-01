"""The Argument Clinic signatures of _posixsubprocess.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/posixsubprocess.jac from them. Taken from
CPython 3.14.6 Modules/_posixsubprocess.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_posixsubprocess",
         version="3.14.6",
         sources=["Modules/_posixsubprocess.c"],
         functions=[
             Function(
                 name="fork_exec",
                 full_name="_posixsubprocess.fork_exec",
                 c_basename="subprocess_fork_exec",
                 docstring="fork_exec($module, args, executable_list, close_fds, pass_fds, cwd,\n"
                 "          env, p2cread, p2cwrite, c2pread, c2pwrite, errread, errwrite,\n"
                 "          errpipe_read, errpipe_write, restore_signals, call_setsid,\n"
                 "          pgid_to_set, gid, extra_groups, uid, child_umask, preexec_fn,\n"
                 "          /)\n"
                 "--\n"
                 "\n"
                 "Spawn a fresh new child process.\n"
                 "\n"
                 "Fork a child process, close parent file descriptors as appropriate in\n"
                 "the child and duplicate the few that are needed before calling exec() in\n"
                 "the child process.\n"
                 "\n"
                 "If close_fds is True, close file descriptors 3 and higher, except those\n"
                 "listed in the sorted tuple pass_fds.\n"
                 "\n"
                 "The preexec_fn, if supplied, will be called immediately before closing\n"
                 "file descriptors and exec.\n"
                 "\n"
                 "WARNING: preexec_fn is NOT SAFE if your application uses threads.\n"
                 "         It may trigger infrequent, difficult to debug deadlocks.\n"
                 "\n"
                 "If an error occurs in the child process before the exec, it is\n"
                 "serialized and written to the errpipe_write fd per subprocess.py.\n"
                 "\n"
                 "Returns: the child process's PID.\n"
                 "\n"
                 "Raises: Only on an error in the parent process.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="args", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="executable_list", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="close_fds",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="pass_fds",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     ),
                     Parameter(name="cwd", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="env", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="p2cread",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="p2cwrite",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="c2pread",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="c2pwrite",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="errread",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="errwrite",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="errpipe_read",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="errpipe_write",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="restore_signals",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="call_setsid",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="pgid_to_set",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(name="gid", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="extra_groups", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="uid", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="child_umask",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="preexec_fn", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=22,
                 max_pos=22,
                 pos_only=22
             )
         ],
         docs={"module_doc": "A POSIX helper for the subprocess module."}
     );
