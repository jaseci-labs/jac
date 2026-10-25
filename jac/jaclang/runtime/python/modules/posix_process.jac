import from c {
    obj load_averages {
        has one: f64 = 0.0,
            five: f64 = 0.0,
            fifteen: f64 = 0.0;
    }  def fork -> i32;  def forkpty(
        amaster: &mut i32, name: ptr[u8], termp: ptr, winp: ptr
    ) -> i32;  def getpid -> i32;  def _exit(status: i32);  def abort;  def system(
        command: ptr[u8]
    ) -> i32;  def nice(increment: i32) -> i32;  def getpriority(
        which: i32, who: u32
    ) -> i32;  def setpriority(which: i32, who: u32, priority: i32) -> i32;  def execv(
        path: ptr[u8], argv: ptr[ptr[u8]]
    ) -> i32;  def execve(
        path: ptr[u8], argv: ptr[ptr[u8]], envp: ptr[ptr[u8]]
    ) -> i32;  def posix_spawn(
        pid: &mut i32,
        path: ptr[u8],
        file_actions: ptr,
        attrp: ptr,
        argv: ptr[ptr[u8]],
        envp: ptr[ptr[u8]]
    ) -> i32;  def posix_spawnp(
        pid: &mut i32,
        file: ptr[u8],
        file_actions: ptr,
        attrp: ptr,
        argv: ptr[ptr[u8]],
        envp: ptr[ptr[u8]]
    ) -> i32;  def posix_spawnattr_init(attr: ptr) -> i32;  def posix_spawnattr_destroy(
        attr: ptr
    ) -> i32;  def posix_spawnattr_setpgroup(attr: ptr, pgroup: i32) -> i32;  def posix_spawnattr_setflags(
        attr: ptr, flags: i32
    ) -> i32;  def posix_spawnattr_setsigmask(attr: ptr, sigmask: ptr) -> i32;  def posix_spawnattr_setsigdefault(
        attr: ptr, sigdefault: ptr
    ) -> i32;  def posix_spawn_file_actions_init(file_actions: ptr) -> i32;  def posix_spawn_file_actions_destroy(
        file_actions: ptr
    ) -> i32;  def posix_spawn_file_actions_addopen(
        file_actions: ptr, fd: i32, path: ptr[u8], oflag: i32, mode: u32
    ) -> i32;  def posix_spawn_file_actions_addclose(
        file_actions: ptr, fd: i32
    ) -> i32;  def posix_spawn_file_actions_adddup2(
        file_actions: ptr, fd: i32, newfd: i32
    ) -> i32;  def kill(pid: i32, sig: i32) -> i32;  def killpg(
        pgrp: i32, sig: i32
    ) -> i32;  def `wait(status: &mut i32) -> i32;  def wait3(
        status: &mut i32, options: i32, usage: &mut rusage
    ) -> i32;  def wait4(
        pid: i32, status: &mut i32, options: i32, usage: &mut rusage
    ) -> i32;  def waitid(
        idtype: i32, id: u32, info: &mut siginfo_t, options: i32
    ) -> i32;  def waitpid(pid: i32, status: &mut i32, options: i32) -> i32;  def sched_get_priority_max(
        policy: i32
    ) -> i32;  def sched_get_priority_min(policy: i32) -> i32;  def sched_yield -> i32;  def getloadavg(
        loadavg: &mut load_averages, nelem: i32
    ) -> i32;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];
}

glob:priv Py_RTFLAGS_FORK: u64 = 32768,
     Py_RTFLAGS_EXEC: u64 = 65536,
     NCPUS_START: i32 = 64,
     WAITID_RESULT_DOC: str = "waitid_result: Result from waitid.\n\nThis object may be accessed either as a tuple of\n  (si_pid, si_uid, si_signo, si_status, si_code),\nor via the attributes si_pid, si_uid, and so on.\n\nSee os.waitid for more information.",
     TIMES_RESULT_DOC: str = "times_result: Result from os.times().\n\nThis object may be accessed either as a tuple of\n  (user, system, children_user, children_system, elapsed),\nor via the attributes user, system, children_user, children_system,\nand elapsed.\n\nSee os.times for more information.",
     SCHED_PARAM_DOC: str = "sched_param(sched_priority)\n--\n\nCurrently has only one field: sched_priority\n\n  sched_priority\n    A scheduling parameter.";

def os_nice_impl(module: ptr[PyObject], increment: i32) -> ptr[PyObject];

def os_getpriority_impl(module: ptr[PyObject], which: i32, who: i32) -> ptr[PyObject];

def os_setpriority_impl(
    module: ptr[PyObject], which: i32, who: i32, priority: i32
) -> ptr[PyObject];

def os_system_impl(module: ptr[PyObject], command: ptr[PyObject]) -> i64;

def os__exit_impl(module: ptr[PyObject], status: i32) -> ptr[PyObject];

def os_abort_impl(module: ptr[PyObject]) -> ptr[PyObject];

def free_string_array(array: ptr[ptr[u8]], count: i64);

def:priv string_array_new(count: i64) -> ptr[ptr[u8]];

def fsconvert_strdup(o: ptr[PyObject], out: ptr[ptr[u8]]) -> i32;

def parse_envlist(env: ptr[PyObject]) -> tuple[ptr[ptr[u8]], i64];

def parse_arglist(argv: ptr[PyObject], argc: i64) -> ptr[ptr[u8]];

def:priv first_argument_empty(argvlist: ptr[ptr[u8]]) -> bool;

def os_execv_impl(
    module: ptr[PyObject], path: path_t, argv: ptr[PyObject]
) -> ptr[PyObject];

def os_execve_impl(
    module: ptr[PyObject], path: path_t, argv: ptr[PyObject], env: ptr[PyObject]
) -> ptr[PyObject];

def convert_sched_param(module: ptr[PyObject], param: ptr[PyObject]) -> (i32 | None);

def parse_posix_spawn_flags(
    module: ptr[PyObject],
    func_name: str,
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject],
    attrp: ptr
) -> i32;

def:priv spawn_sigset(signals: ptr[PyObject], attrp: ptr, defaults: bool) -> bool;

def parse_file_actions(
    file_actions: ptr[PyObject], file_actionsp: ptr, temp_buffer: ptr[PyObject]
) -> i32;

def py_posix_spawn(
    use_posix_spawnp: bool,
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject];

def os_posix_spawn_impl(
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject];

def os_posix_spawnp_impl(
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject];

def:priv check_null_or_callable(value: ptr[PyObject], obj_name: str) -> i32;

def os_register_at_fork_impl(
    module: ptr[PyObject],
    before: ptr[PyObject],
    after_in_child: ptr[PyObject],
    after_in_parent: ptr[PyObject]
) -> ptr[PyObject];

def warn_about_fork_with_threads(name: str, num_os_threads: i64);

def:priv fork_forbidden(subinterpreters: bool) -> bool;

def os_fork1_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_fork_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_forkpty_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_sched_get_priority_max_impl(
    module: ptr[PyObject], policy: i32
) -> ptr[PyObject];

def os_sched_get_priority_min_impl(
    module: ptr[PyObject], policy: i32
) -> ptr[PyObject];

def os_sched_getscheduler_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject];

def os_sched_param_impl(
    cls: ptr[PyObject], sched_priority: ptr[PyObject]
) -> ptr[PyObject];

def sched_param_reduce(self: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def os_sched_setscheduler_impl(
    module: ptr[PyObject], pid: i32, policy: i32, param_obj: ptr[PyObject]
) -> ptr[PyObject];

def os_sched_getparam_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject];

def os_sched_setparam_impl(
    module: ptr[PyObject], pid: i32, param_obj: ptr[PyObject]
) -> ptr[PyObject];

def os_sched_rr_get_interval_impl(module: ptr[PyObject], pid: i32) -> f64;

def os_sched_yield_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_sched_setaffinity_impl(
    module: ptr[PyObject], pid: i32, mask: ptr[PyObject]
) -> ptr[PyObject];

def os_sched_getaffinity_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject];

def os_kill_impl(module: ptr[PyObject], pid: i32, signal: i64) -> ptr[PyObject];

def os_killpg_impl(module: ptr[PyObject], pgid: i32, signal: i32) -> ptr[PyObject];

def:priv doubletime(value: timeval) -> f64;

def:priv set_result(result: ptr[PyObject], pos: i64, item: ptr[PyObject]) -> bool;

def wait_helper(
    module: ptr[PyObject], pid: i32, status: i32, ru: rusage
) -> ptr[PyObject];

def os_wait3_impl(module: ptr[PyObject], options: i32) -> ptr[PyObject];

def os_wait4_impl(module: ptr[PyObject], pid: i32, options: i32) -> ptr[PyObject];

def os_waitid_impl(
    module: ptr[PyObject], idtype: i32, id: u32, options: i32
) -> ptr[PyObject];

def os_waitpid_impl(module: ptr[PyObject], pid: i32, options: i32) -> ptr[PyObject];

def os_wait_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_pidfd_open_impl(module: ptr[PyObject], pid: i32, flags: u32) -> ptr[PyObject];

def os_setns_impl(module: ptr[PyObject], fd: i32, nstype: i32) -> ptr[PyObject];

def os_unshare_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject];

def os_WCOREDUMP_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WIFCONTINUED_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WIFSTOPPED_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WIFSIGNALED_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WIFEXITED_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WEXITSTATUS_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WTERMSIG_impl(module: ptr[PyObject], status: i32) -> i32;

def os_WSTOPSIG_impl(module: ptr[PyObject], status: i32) -> i32;

def os_waitstatus_to_exitcode_impl(
    module: ptr[PyObject], status_obj: ptr[PyObject]
) -> ptr[PyObject];

def build_times_result(
    module: ptr[PyObject],
    user: f64,
    system_time: f64,
    children_user: f64,
    children_system: f64,
    elapsed: f64
) -> ptr[PyObject];

def os_times_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_getloadavg_impl(module: ptr[PyObject]) -> ptr[PyObject];

def posix_process_exec(module: ptr[PyObject]) -> bool;

impl os_nice_impl(module: ptr[PyObject], increment: i32) -> ptr[PyObject] {
    jacpy_set_errno(0);
    value = nice(increment);
    if HAVE_BROKEN_NICE and HAVE_GETPRIORITY {
        if value == 0 {
            value = getpriority(i32(PRIO_PROCESS), u32(0));
        }
    }
    if value == -1 and jacpy_errno() != 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(value));
}

impl os_getpriority_impl(module: ptr[PyObject], which: i32, who: i32) -> ptr[PyObject] {
    jacpy_set_errno(0);
    retval = getpriority(which, u32.wrap(who));
    if jacpy_errno() != 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(retval));
}

impl os_setpriority_impl(
    module: ptr[PyObject], which: i32, who: i32, priority: i32
) -> ptr[PyObject] {
    retval = setpriority(which, u32.wrap(who), priority);
    if retval == -1 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_system_impl(module: ptr[PyObject], command: ptr[PyObject]) -> i64 {
    bytes = PyBytes_AsString(command);
    if PySys_Audit("os.system", "(O)", command) < 0 {
        return -1;
    }
    thread = PyEval_SaveThread();
    result = system(bytes);
    PyEval_RestoreThread(thread);
    return i64(result);
}

impl os__exit_impl(module: ptr[PyObject], status: i32) -> ptr[PyObject] {
    _exit(status);
    return NULL;
}

impl os_abort_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    abort();
    return NULL;
}

impl free_string_array(array: ptr[ptr[u8]], count: i64) {
    for i in range(count) {
        PyMem_Free((array + i).view(1)[0]);
    }
    PyMem_Free(array);
}

impl string_array_new(count: i64) -> ptr[ptr[u8]] {
    if count < 0 or count > 0x7FFFFFFFFFFFFFFF // 8 {
        return ptr[ptr[u8]]();
    }
    return ptr[ptr[u8]](PyMem_Malloc(u64(count) * 8));
}

impl fsconvert_strdup(o: ptr[PyObject], out: ptr[ptr[u8]]) -> i32 {
    result = i32(0);
    ub = NULL;
    if PyUnicode_FSConverter(o, &mut ub) == 0 {
        return i32(0);
    }
    size = PyBytes_Size(ub);
    copy = ptr[u8](PyMem_Malloc(u64(size + 1)));
    out.view(1)[0] = copy;
    if copy {
        memcpy(copy, PyBytes_AsString(ub), u64(size + 1));
        result = i32(1);
    } else {
        PyErr_NoMemory();
    }
    jacpy_release(ub);
    return result;
}

impl parse_envlist(env: ptr[PyObject]) -> tuple[ptr[ptr[u8]], i64] {
    i = PyMapping_Size(env);
    if i < 0 {
        return (ptr[ptr[u8]](), i64(0));
    }
    envlist = string_array_new(i + 1);
    if not envlist {
        PyErr_NoMemory();
        return (ptr[ptr[u8]](), i64(0));
    }
    envc = i64(0);
    keys = NULL;
    vals = NULL;
    key = NULL;
    val = NULL;
    key2 = NULL;
    val2 = NULL;
    failed = True;
    while True {
        keys = PyMapping_Keys(env);
        if not keys {
            break;
        }
        vals = PyMapping_Values(env);
        if not vals {
            break;
        }
        if jacpy_is_list(keys) == 0 or jacpy_is_list(vals) == 0 {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("env.keys() or env.values() is not a list")
            );
            break;
        }
        pos = i64(0);
        entry_failed = False;
        while pos < i {
            key = PyList_GetItemRef(keys, pos);
            if not key {
                entry_failed = True;
                break;
            }
            val = PyList_GetItemRef(vals, pos);
            if not val {
                entry_failed = True;
                break;
            }
            if PyUnicode_FSConverter(key, &mut key2) == 0 {
                entry_failed = True;
                break;
            }
            if PyUnicode_FSConverter(val, &mut val2) == 0 {
                entry_failed = True;
                break;
            }
            if PyBytes_Size(key2) == 0 or strchr(PyBytes_AsString(key2) + 1, i32(61)) {
                PyErr_SetString(
                    PyExc_ValueError, ptr[u8]("illegal environment variable name")
                );
                entry_failed = True;
                break;
            }
            keyval = PyBytes_FromFormat(
                ptr[u8]("%s=%s"), PyBytes_AsString(key2), PyBytes_AsString(val2)
            );
            if not keyval {
                entry_failed = True;
                break;
            }
            slot = envlist + envc;
            envc += 1;
            if fsconvert_strdup(keyval, slot) == 0 {
                jacpy_release(keyval);
                entry_failed = True;
                break;
            }
            jacpy_release(key);
            key = NULL;
            jacpy_release(val);
            val = NULL;
            jacpy_release(key2);
            key2 = NULL;
            jacpy_release(val2);
            val2 = NULL;
            jacpy_release(keyval);
            pos += 1;
        }
        if entry_failed {
            break;
        }
        failed = False;
        break;
    }
    if failed {
        jacpy_release(key);
        jacpy_release(val);
        jacpy_release(key2);
        jacpy_release(val2);
        jacpy_release(keys);
        jacpy_release(vals);
        free_string_array(envlist, envc);
        return (ptr[ptr[u8]](), i64(0));
    }
    jacpy_release(vals);
    jacpy_release(keys);
    (envlist + envc).view(1)[0] = ptr[u8]();
    return (envlist, envc);
}

impl parse_arglist(argv: ptr[PyObject], argc: i64) -> ptr[ptr[u8]] {
    argvlist = string_array_new(argc + 1);
    if not argvlist {
        PyErr_NoMemory();
        return ptr[ptr[u8]]();
    }
    i = i64(0);
    while i < argc {
        item = PySequence_GetItem(argv, i);
        if not item {
            free_string_array(argvlist, i);
            return ptr[ptr[u8]]();
        }
        if fsconvert_strdup(item, argvlist + i) == 0 {
            jacpy_release(item);
            free_string_array(argvlist, i);
            return ptr[ptr[u8]]();
        }
        jacpy_release(item);
        i += 1;
    }
    (argvlist + argc).view(1)[0] = ptr[u8]();
    return argvlist;
}

impl first_argument_empty(argvlist: ptr[ptr[u8]]) -> bool {
    return argvlist.view(1)[0].view(1)[0] == 0;
}

impl os_execv_impl(
    module: ptr[PyObject], path: path_t, argv: ptr[PyObject]
) -> ptr[PyObject] {
    interp = PyInterpreterState_Get();
    if _PyInterpreterState_HasFeature(interp, Py_RTFLAGS_EXEC) == 0 {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("exec not supported for isolated subinterpreters")
        );
        return NULL;
    }
    if jacpy_is_list(argv) == 0 and jacpy_is_tuple(argv) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("execv() arg 2 must be a tuple or list")
        );
        return NULL;
    }
    argc = PySequence_Size(argv);
    if argc < 1 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("execv() arg 2 must not be empty"));
        return NULL;
    }
    argvlist = parse_arglist(argv, argc);
    if not argvlist {
        return NULL;
    }
    if first_argument_empty(argvlist) {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("execv() arg 2 first element cannot be empty")
        );
        free_string_array(argvlist, argc);
        return NULL;
    }
    if PySys_Audit("os.exec", "OOO", path.object, argv, Py_None) < 0 {
        free_string_array(argvlist, argc);
        return NULL;
    }
    execv(path.narrow, argvlist);

    posix_error();
    free_string_array(argvlist, argc);
    return NULL;
}

impl os_execve_impl(
    module: ptr[PyObject], path: path_t, argv: ptr[PyObject], env: ptr[PyObject]
) -> ptr[PyObject] {
    interp = PyInterpreterState_Get();
    if _PyInterpreterState_HasFeature(interp, Py_RTFLAGS_EXEC) == 0 {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("exec not supported for isolated subinterpreters")
        );
        return NULL;
    }
    if jacpy_is_list(argv) == 0 and jacpy_is_tuple(argv) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("execve: argv must be a tuple or list")
        );
        return NULL;
    }
    argc = PySequence_Size(argv);
    if argc < 1 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("execve: argv must not be empty"));
        return NULL;
    }
    if PyMapping_Check(env) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("execve: environment must be a mapping object")
        );
        return NULL;
    }
    argvlist = parse_arglist(argv, argc);
    if not argvlist {
        return NULL;
    }
    if first_argument_empty(argvlist) {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("execve: argv first element cannot be empty")
        );
        free_string_array(argvlist, argc);
        return NULL;
    }
    (envlist, envc) = parse_envlist(env);
    if not envlist {
        free_string_array(argvlist, argc);
        return NULL;
    }
    if PySys_Audit("os.exec", "OOO", path.object, argv, env) >= 0 {
        if HAVE_FEXECVE and path.fd > -1 {
            fexecve_call(path.fd, argvlist, envlist);
        } else {
            execve(path.narrow, argvlist, envlist);
        }

        posix_path_error(path);
    }
    free_string_array(envlist, envc);
    free_string_array(argvlist, argc);
    return NULL;
}

impl convert_sched_param(module: ptr[PyObject], param: ptr[PyObject]) -> (i32 | None) {
    if Py_TYPE(param) != state_object(module, STATE_SCHED_PARAM_TYPE) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("must have a sched_param object"));
        return None;
    }
    priority = PyLong_AsLong(PyStructSequence_GetItem(param, 0));
    if priority == -1 and PyErr_Occurred() {
        return None;
    }
    if priority > INT_MAX or priority < INT_MIN {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("sched_priority out of range"));
        return None;
    }
    return i32(priority);
}

impl parse_posix_spawn_flags(
    module: ptr[PyObject],
    func_name: str,
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject],
    attrp: ptr
) -> i32 {
    all_flags = i64(0);
    code = posix_spawnattr_init(attrp);
    if code != 0 {
        jacpy_set_errno(i64(code));
        posix_error();
        return i32(-1);
    }
    failed = True;
    while True {
        if setpgroup and setpgroup != Py_None {
            pgid = PyLong_AsInt(setpgroup);
            if pgid == -1 and PyErr_Occurred() {
                break;
            }
            code = posix_spawnattr_setpgroup(attrp, pgid);
            if code != 0 {
                jacpy_set_errno(i64(code));
                posix_error();
                break;
            }
            all_flags |= POSIX_SPAWN_SETPGROUP;
        }
        if resetids {
            all_flags |= POSIX_SPAWN_RESETIDS;
        }
        if setsid {
            if POSIX_SPAWN_SETSID != 0 {
                all_flags |= POSIX_SPAWN_SETSID;
            } elif POSIX_SPAWN_SETSID_NP != 0 {
                all_flags |= POSIX_SPAWN_SETSID_NP;
            } else {
                argument_unavailable_error(func_name, "setsid");
                return i32(-1);
            }
        }
        if setsigmask {
            if not spawn_sigset(setsigmask, attrp, False) {
                break;
            }
            all_flags |= POSIX_SPAWN_SETSIGMASK;
        }
        if setsigdef {
            if not spawn_sigset(setsigdef, attrp, True) {
                break;
            }
            all_flags |= POSIX_SPAWN_SETSIGDEF;
        }
        if scheduler and scheduler != Py_None {
            if POSIX_SPAWN_SETSCHEDULER == 0 {
                PyErr_SetString(
                    PyExc_NotImplementedError,
                    ptr[u8]("The scheduler option is not supported in this system.")
                );
                break;
            }
            py_schedpolicy = NULL;
            schedparam_obj = NULL;
            if PyArg_ParseTuple(
                scheduler,
                ptr[u8]("OO;A scheduler tuple must have two elements"),
                &mut py_schedpolicy,
                &mut schedparam_obj
            )
                == 0 {
                break;
            }
            schedparam = convert_sched_param(module, schedparam_obj);
            if schedparam is None {
                break;
            }
            if py_schedpolicy != Py_None {
                schedpolicy = PyLong_AsInt(py_schedpolicy);
                if schedpolicy == -1 and PyErr_Occurred() {
                    break;
                }
                code = spawnattr_setschedpolicy(attrp, schedpolicy);
                if code != 0 {
                    jacpy_set_errno(i64(code));
                    posix_error();
                    break;
                }
                all_flags |= POSIX_SPAWN_SETSCHEDULER;
            }
            code = spawnattr_setschedparam(attrp, schedparam);
            if code != 0 {
                jacpy_set_errno(i64(code));
                posix_error();
                break;
            }
            all_flags |= POSIX_SPAWN_SETSCHEDPARAM;
        }
        code = posix_spawnattr_setflags(attrp, i32(i16.wrap(all_flags)));
        if code != 0 {
            jacpy_set_errno(i64(code));
            posix_error();
            break;
        }
        failed = False;
        break;
    }
    if failed {
        posix_spawnattr_destroy(attrp);
        return i32(-1);
    }
    return i32(0);
}

impl spawn_sigset(signals: ptr[PyObject], attrp: ptr, defaults: bool) -> bool {
    signal_set = PyMem_RawMalloc(u64(SIGSET_SIZE));
    if not signal_set {
        PyErr_NoMemory();
        return False;
    }
    if _Py_Sigset_Converter(signals, signal_set) == 0 {
        PyMem_RawFree(signal_set);
        return False;
    }
    code = posix_spawnattr_setsigdefault(attrp, signal_set)
        if defaults
        else posix_spawnattr_setsigmask(attrp, signal_set);
    PyMem_RawFree(signal_set);
    if code != 0 {
        jacpy_set_errno(i64(code));
        posix_error();
        return False;
    }
    return True;
}

impl parse_file_actions(
    file_actions: ptr[PyObject], file_actionsp: ptr, temp_buffer: ptr[PyObject]
) -> i32 {
    seq = PySequence_Fast(
        file_actions, ptr[u8]("file_actions must be a sequence or None")
    );
    if not seq {
        return i32(-1);
    }
    code = posix_spawn_file_actions_init(file_actionsp);
    if code != 0 {
        jacpy_set_errno(i64(code));
        posix_error();
        jacpy_release(seq);
        return i32(-1);
    }
    file_action = NULL;
    failed = False;
    i = i64(0);
    while i < jacpy_fast_size(seq) {
        file_action = Py_NewRef(jacpy_fast_item(seq, i));
        if jacpy_is_tuple(file_action) == 0 or PyTuple_Size(file_action) == 0 {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("Each file_actions element must be a non-empty tuple")
            );
            failed = True;
            break;
        }
        tag = PyLong_AsLong(PyTuple_GetItem(file_action, 0));
        if tag == -1 and PyErr_Occurred() {
            failed = True;
            break;
        }
        tag_obj = NULL;
        if tag == POSIX_SPAWN_OPEN {
            fd = i32(0);
            oflag = i32(0);
            path = NULL;
            mode = u64(0);
            path_obj = NULL;
            oflag_obj = NULL;
            mode_obj = NULL;

            if PyArg_ParseTuple(
                file_action,
                ptr[u8]("OiOOO;A open file_action tuple must have 5 elements"),
                &mut tag_obj,
                &mut fd,
                &mut path_obj,
                &mut oflag_obj,
                &mut mode_obj
            )
                == 0 {
                failed = True;
                break;
            }
            if PyUnicode_FSConverter(path_obj, &mut path) == 0 {
                failed = True;
                break;
            }
            if PyArg_Parse(
                oflag_obj,
                ptr[u8]("i;A open file_action tuple must have 5 elements"),
                &mut oflag
            )
                == 0
                or PyArg_Parse(
                    mode_obj,
                    ptr[u8]("k;A open file_action tuple must have 5 elements"),
                    &mut mode
                )
                    == 0 {
                jacpy_release(path);
                failed = True;
                break;
            }
            if PyList_Append(temp_buffer, path) != 0 {
                jacpy_release(path);
                failed = True;
                break;
            }
            code = posix_spawn_file_actions_addopen(
                file_actionsp, fd, PyBytes_AsString(path), oflag, mode_bits(mode)
            );
            if code != 0 {
                jacpy_set_errno(i64(code));
                posix_error();
                jacpy_release(path);
                failed = True;
                break;
            }
            jacpy_release(path);
        } elif tag == POSIX_SPAWN_CLOSE {
            fd = i32(0);
            if PyArg_ParseTuple(
                file_action,
                ptr[u8]("Oi;A close file_action tuple must have 2 elements"),
                &mut tag_obj,
                &mut fd
            )
                == 0 {
                failed = True;
                break;
            }
            code = posix_spawn_file_actions_addclose(file_actionsp, fd);
            if code != 0 {
                jacpy_set_errno(i64(code));
                posix_error();
                failed = True;
                break;
            }
        } elif tag == POSIX_SPAWN_DUP2 {
            fd1 = i32(0);
            fd2 = i32(0);
            if PyArg_ParseTuple(
                file_action,
                ptr[u8]("Oii;A dup2 file_action tuple must have 3 elements"),
                &mut tag_obj,
                &mut fd1,
                &mut fd2
            )
                == 0 {
                failed = True;
                break;
            }
            code = posix_spawn_file_actions_adddup2(file_actionsp, fd1, fd2);
            if code != 0 {
                jacpy_set_errno(i64(code));
                posix_error();
                failed = True;
                break;
            }
        } else {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("Unknown file_actions identifier")
            );
            failed = True;
            break;
        }
        jacpy_release(file_action);
        i += 1;
    }
    jacpy_release(seq);
    if failed {
        jacpy_release(file_action);
        posix_spawn_file_actions_destroy(file_actionsp);
        return i32(-1);
    }
    return i32(0);
}

impl py_posix_spawn(
    use_posix_spawnp: bool,
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject] {
    func_name = "posix_spawnp" if use_posix_spawnp else "posix_spawn";
    argvlist = ptr[ptr[u8]]();
    envlist = ptr[ptr[u8]]();
    environ = ptr[ptr[u8]]();
    file_actions_buf = ptr();
    file_actionsp = ptr();
    attr = ptr();
    attrp = ptr();
    argc = i64(0);
    envc = i64(0);
    result = NULL;
    temp_buffer = NULL;
    while True {
        if jacpy_is_list(argv) == 0 and jacpy_is_tuple(argv) == 0 {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("%s: argv must be a tuple or list"), func_name
            );
            break;
        }
        argc = PySequence_Size(argv);
        if argc < 1 {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("%s: argv must not be empty"), func_name
            );
            break;
        }
        if PyMapping_Check(env) == 0 and env != Py_None {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("%s: environment must be a mapping object or None"),
                func_name
            );
            break;
        }
        if scheduler and jacpy_is_tuple(scheduler) == 0 and scheduler != Py_None {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("%s: scheduler must be a tuple or None"),
                func_name
            );
            break;
        }
        argvlist = parse_arglist(argv, argc);
        if not argvlist {
            break;
        }
        if first_argument_empty(argvlist) {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("%s: argv first element cannot be empty"),
                func_name
            );
            break;
        }
        if env == Py_None {
            environ = environment_table();
            envlist = environ;
        } else {
            (envlist, envc) = parse_envlist(env);
            if not envlist {
                break;
            }
        }
        if file_actions and file_actions != Py_None {
            temp_buffer = PyList_New(0);
            if not temp_buffer {
                break;
            }
            file_actions_buf = PyMem_RawMalloc(u64(FILE_ACTIONS_SIZE));
            if not file_actions_buf {
                PyErr_NoMemory();
                break;
            }
            if parse_file_actions(file_actions, file_actions_buf, temp_buffer) != 0 {
                break;
            }
            file_actionsp = file_actions_buf;
        }
        attr = PyMem_RawMalloc(u64(SPAWNATTR_SIZE));
        if not attr {
            PyErr_NoMemory();
            break;
        }
        if parse_posix_spawn_flags(
            module,
            func_name,
            setpgroup,
            resetids,
            setsid,
            setsigmask,
            setsigdef,
            scheduler,
            attr
        )
            != 0 {
            break;
        }
        attrp = attr;
        if PySys_Audit("os.posix_spawn", "OOO", path.object, argv, env) < 0 {
            break;
        }
        pid = i32(0);
        err_code = i32(0);
        if use_posix_spawnp {
            err_code = posix_spawnp(
                &mut pid, path.narrow, file_actionsp, attrp, argvlist, envlist
            );
        } else {
            err_code = posix_spawn(
                &mut pid, path.narrow, file_actionsp, attrp, argvlist, envlist
            );
        }
        if err_code != 0 {
            jacpy_set_errno(i64(err_code));
            path_object_error(path.object);
            break;
        }
        result = PyLong_FromLong(i64(pid));
        break;
    }
    if file_actionsp {
        posix_spawn_file_actions_destroy(file_actionsp);
    }
    if attrp {
        posix_spawnattr_destroy(attrp);
    }
    PyMem_RawFree(file_actions_buf);
    PyMem_RawFree(attr);
    if envlist and envlist != environ {
        free_string_array(envlist, envc);
    }
    if argvlist {
        free_string_array(argvlist, argc);
    }
    jacpy_release(temp_buffer);
    return result;
}

impl os_posix_spawn_impl(
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject] {
    return py_posix_spawn(
        False,
        module,
        path,
        argv,
        env,
        file_actions,
        setpgroup,
        resetids,
        setsid,
        setsigmask,
        setsigdef,
        scheduler
    );
}

impl os_posix_spawnp_impl(
    module: ptr[PyObject],
    path: path_t,
    argv: ptr[PyObject],
    env: ptr[PyObject],
    file_actions: ptr[PyObject],
    setpgroup: ptr[PyObject],
    resetids: bool,
    setsid: bool,
    setsigmask: ptr[PyObject],
    setsigdef: ptr[PyObject],
    scheduler: ptr[PyObject]
) -> ptr[PyObject] {
    return py_posix_spawn(
        True,
        module,
        path,
        argv,
        env,
        file_actions,
        setpgroup,
        resetids,
        setsid,
        setsigmask,
        setsigdef,
        scheduler
    );
}

impl check_null_or_callable(value: ptr[PyObject], obj_name: str) -> i32 {
    if value and PyCallable_Check(value) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("'%s' must be callable, not %s"),
            obj_name,
            _PyType_Name(Py_TYPE(value))
        );
        return i32(-1);
    }
    return i32(0);
}

impl os_register_at_fork_impl(
    module: ptr[PyObject],
    before: ptr[PyObject],
    after_in_child: ptr[PyObject],
    after_in_parent: ptr[PyObject]
) -> ptr[PyObject] {
    if not before and not after_in_child and not after_in_parent {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("At least one argument is required."));
        return NULL;
    }
    if check_null_or_callable(before, "before") != 0
        or check_null_or_callable(after_in_child, "after_in_child") != 0
        or check_null_or_callable(after_in_parent, "after_in_parent") != 0 {
        return NULL;
    }
    interp = PyInterpreterState_Get();
    if register_at_forker(interp, BEFORE_FORKERS, before) != 0 {
        return NULL;
    }
    if register_at_forker(interp, AFTER_FORKERS_CHILD, after_in_child) != 0 {
        return NULL;
    }
    if register_at_forker(interp, AFTER_FORKERS_PARENT, after_in_parent) != 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl warn_about_fork_with_threads(name: str, num_os_threads: i64) {
    num_python_threads = num_os_threads;
    if num_python_threads <= 0 {
        threading_name = interned("threading");
        if not threading_name {
            PyErr_Clear();
            return;
        }
        threading = PyImport_GetModule(threading_name);
        jacpy_release(threading_name);
        if not threading {
            PyErr_Clear();
            return;
        }
        active_name = interned("_active");
        threading_active = PyObject_GetAttr(threading, active_name)
            if active_name
            else NULL;
        jacpy_release(active_name);
        if not threading_active {
            PyErr_Clear();
            jacpy_release(threading);
            return;
        }
        limbo_name = interned("_limbo");
        threading_limbo = PyObject_GetAttr(threading, limbo_name)
            if limbo_name
            else NULL;
        jacpy_release(limbo_name);
        if not threading_limbo {
            PyErr_Clear();
            jacpy_release(threading);
            jacpy_release(threading_active);
            return;
        }
        jacpy_release(threading);

        num_python_threads = PyMapping_Length(threading_active)
            + PyMapping_Length(threading_limbo);
        PyErr_Clear();
        jacpy_release(threading_active);
        jacpy_release(threading_limbo);
    }
    if num_python_threads > 1 {
        PyErr_WarnFormat(
            PyExc_DeprecationWarning,
            1,
            ptr[u8](
                "This process (pid=%d) is multi-threaded, use of %s() may lead to deadlocks in the child."
            ),
            getpid(),
            name
        );
        PyErr_Clear();
    }
}

impl fork_forbidden(subinterpreters: bool) -> bool {
    interp = PyInterpreterState_Get();
    if jacpy_interpreter_finalizing() != 0 {
        PyErr_SetString(
            PyExc_PythonFinalizationError, ptr[u8]("can't fork at interpreter shutdown")
        );
        return True;
    }
    if subinterpreters {
        if interp != _PyInterpreterState_Main() {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("fork not supported for subinterpreters")
            );
            return True;
        }
    } elif _PyInterpreterState_HasFeature(interp, Py_RTFLAGS_FORK) == 0 {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("fork not supported for isolated subinterpreters")
        );
        return True;
    }
    return False;
}

impl os_fork1_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if fork_forbidden(True) {
        return NULL;
    }
    PyOS_BeforeFork();
    pid = fork_one();
    saved_errno = jacpy_errno();
    if pid == 0 {
        PyOS_AfterFork_Child();
    } else {
        num_os_threads = get_number_of_os_threads();
        PyOS_AfterFork_Parent();
        warn_about_fork_with_threads("fork1", num_os_threads);
    }
    if pid == -1 {
        jacpy_set_errno(i64(saved_errno));
        return posix_error();
    }
    return PyLong_FromLong(i64(pid));
}

impl os_fork_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if fork_forbidden(False) {
        return NULL;
    }
    if PySys_AuditTuple("os.fork", NULL) < 0 {
        return NULL;
    }
    PyOS_BeforeFork();
    pid = fork();
    saved_errno = jacpy_errno();
    if pid == 0 {
        PyOS_AfterFork_Child();
    } else {
        num_os_threads = get_number_of_os_threads();
        PyOS_AfterFork_Parent();
        warn_about_fork_with_threads("fork", num_os_threads);
    }
    if pid == -1 {
        jacpy_set_errno(i64(saved_errno));
        return posix_error();
    }
    return PyLong_FromLong(i64(pid));
}

impl os_forkpty_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    master_fd = i32(-1);
    if fork_forbidden(True) {
        return NULL;
    }
    if PySys_AuditTuple("os.forkpty", NULL) < 0 {
        return NULL;
    }
    PyOS_BeforeFork();
    pid = forkpty(&mut master_fd, ptr[u8](), ptr(), ptr());
    if pid == 0 {
        PyOS_AfterFork_Child();
    } else {
        num_os_threads = get_number_of_os_threads();
        PyOS_AfterFork_Parent();
        warn_about_fork_with_threads("forkpty", num_os_threads);
    }
    if pid == -1 {
        return posix_error();
    }
    return Py_BuildValue(ptr[u8]("(Ni)"), PyLong_FromLong(i64(pid)), master_fd);
}

impl os_sched_get_priority_max_impl(
    module: ptr[PyObject], policy: i32
) -> ptr[PyObject] {
    jacpy_set_errno(0);
    priority = sched_get_priority_max(policy);
    if priority == -1 and jacpy_errno() != 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(priority));
}

impl os_sched_get_priority_min_impl(
    module: ptr[PyObject], policy: i32
) -> ptr[PyObject] {
    jacpy_set_errno(0);
    priority = sched_get_priority_min(policy);
    if priority == -1 and jacpy_errno() != 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(priority));
}

impl os_sched_getscheduler_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject] {
    policy = sched_getscheduler_call(pid);
    if policy < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(policy));
}

impl os_sched_param_impl(
    cls: ptr[PyObject], sched_priority: ptr[PyObject]
) -> ptr[PyObject] {
    res = PyStructSequence_New(cls);
    if not res {
        return NULL;
    }
    PyStructSequence_SetItem(res, 0, Py_NewRef(sched_priority));
    return res;
}

impl sched_param_reduce(self: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue(
        ptr[u8]("(O(O))"), Py_TYPE(self), PyStructSequence_GetItem(self, 0)
    );
}

impl os_sched_setscheduler_impl(
    module: ptr[PyObject], pid: i32, policy: i32, param_obj: ptr[PyObject]
) -> ptr[PyObject] {
    param = convert_sched_param(module, param_obj);
    if param is None {
        return NULL;
    }

    if sched_setscheduler_call(pid, policy, param) == -1 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_sched_getparam_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject] {
    (status, sched_priority) = sched_getparam_call(pid);
    if status != 0 {
        return posix_error();
    }
    result = PyStructSequence_New(state_object(module, STATE_SCHED_PARAM_TYPE));
    if not result {
        return NULL;
    }
    priority = PyLong_FromLong(i64(sched_priority));
    if not priority {
        jacpy_release(result);
        return NULL;
    }
    PyStructSequence_SetItem(result, 0, priority);
    return result;
}

impl os_sched_setparam_impl(
    module: ptr[PyObject], pid: i32, param_obj: ptr[PyObject]
) -> ptr[PyObject] {
    param = convert_sched_param(module, param_obj);
    if param is None {
        return NULL;
    }
    if sched_setparam_call(pid, param) != 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_sched_rr_get_interval_impl(module: ptr[PyObject], pid: i32) -> f64 {
    (status, tv_sec, tv_nsec) = sched_rr_get_interval_call(pid);
    if status != 0 {
        posix_error();
        return -1.0;
    }
    return f64(tv_sec) + 1e-9 * f64(tv_nsec);
}

impl os_sched_yield_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    result = sched_yield();
    PyEval_RestoreThread(thread);
    if result < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_sched_setaffinity_impl(
    module: ptr[PyObject], pid: i32, mask: ptr[PyObject]
) -> ptr[PyObject] {
    iterator = PyObject_GetIter(mask);
    if not iterator {
        return NULL;
    }
    ncpus = NCPUS_START;
    setsize = cpu_alloc_size(ncpus);
    cpu_set = cpu_alloc(ncpus);
    failed = True;
    while True {
        if not cpu_set {
            PyErr_NoMemory();
            break;
        }
        cpu_zero_s(setsize, cpu_set);
        item_failed = False;
        while True {
            item = PyIter_Next(iterator);
            if not item {
                break;
            }
            if PyIndex_Check(item) == 0 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("expected an iterator of ints, but iterator yielded %R"),
                    Py_TYPE(item)
                );
                jacpy_release(item);
                item_failed = True;
                break;
            }
            cpu = PyLong_AsLong(item);
            jacpy_release(item);
            if cpu < 0 {
                if not PyErr_Occurred() {
                    PyErr_SetString(PyExc_ValueError, ptr[u8]("negative CPU number"));
                }
                item_failed = True;
                break;
            }
            if cpu > INT_MAX - 1 {
                PyErr_SetString(PyExc_OverflowError, ptr[u8]("CPU number too large"));
                item_failed = True;
                break;
            }
            if cpu >= i64(ncpus) {
                newncpus = ncpus;
                while i64(newncpus) <= cpu {
                    if i64(newncpus) > INT_MAX // 2 {
                        newncpus = i32(cpu + 1);
                    } else {
                        newncpus = newncpus * 2;
                    }
                }
                newmask = cpu_alloc(newncpus);
                if not newmask {
                    PyErr_NoMemory();
                    item_failed = True;
                    break;
                }
                newsetsize = cpu_alloc_size(newncpus);
                cpu_zero_s(newsetsize, newmask);
                memcpy(newmask, cpu_set, setsize);
                cpu_free(cpu_set);
                setsize = newsetsize;
                cpu_set = newmask;
                ncpus = newncpus;
            }
            cpu_set_s(cpu, setsize, cpu_set);
        }
        if item_failed or PyErr_Occurred() {
            break;
        }
        jacpy_release(iterator);
        iterator = NULL;
        if sched_setaffinity_call(pid, setsize, cpu_set) != 0 {
            posix_error();
            break;
        }
        failed = False;
        break;
    }
    if failed {
        if cpu_set {
            cpu_free(cpu_set);
        }
        jacpy_release(iterator);
        return NULL;
    }
    cpu_free(cpu_set);
    return Py_NewRef(Py_None);
}

impl os_sched_getaffinity_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject] {
    ncpus = NCPUS_START;
    setsize = u64(0);
    mask = ptr();
    while True {
        setsize = cpu_alloc_size(ncpus);
        mask = cpu_alloc(ncpus);
        if not mask {
            return PyErr_NoMemory();
        }
        if sched_getaffinity_call(pid, setsize, mask) == 0 {
            break;
        }
        cpu_free(mask);
        if jacpy_errno() != EINVAL {
            return posix_error();
        }
        if i64(ncpus) > INT_MAX // 2 {
            PyErr_SetString(
                PyExc_OverflowError,
                ptr[u8]("could not allocate a large enough CPU set")
            );
            return NULL;
        }
        ncpus *= 2;
    }
    res = PySet_New(NULL);
    failed = not res;
    if res {
        cpu = i64(0);
        count = cpu_count_s(setsize, mask);
        while count != 0 {
            if cpu_isset_s(cpu, setsize, mask) {
                cpu_num = PyLong_FromLong(cpu);
                count -= 1;
                if not cpu_num {
                    failed = True;
                    break;
                }
                if PySet_Add(res, cpu_num) != 0 {
                    jacpy_release(cpu_num);
                    failed = True;
                    break;
                }
                jacpy_release(cpu_num);
            }
            cpu += 1;
        }
    }
    if failed {
        if mask {
            cpu_free(mask);
        }
        jacpy_release(res);
        return NULL;
    }
    cpu_free(mask);
    return res;
}

impl os_kill_impl(module: ptr[PyObject], pid: i32, signal: i64) -> ptr[PyObject] {
    if PySys_Audit("os.kill", "in", pid, signal) < 0 {
        return NULL;
    }
    if kill(pid, i32.wrap(signal)) == -1 {
        return posix_error();
    }

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl os_killpg_impl(module: ptr[PyObject], pgid: i32, signal: i32) -> ptr[PyObject] {
    if PySys_Audit("os.killpg", "ii", pgid, signal) < 0 {
        return NULL;
    }
    if killpg(pgid, signal) == -1 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl doubletime(value: timeval) -> f64 {
    return f64(value.tv_sec) + f64(value.tv_usec) * 0.000001;
}

impl set_result(result: ptr[PyObject], pos: i64, item: ptr[PyObject]) -> bool {
    if not item {
        jacpy_release(result);
        return False;
    }
    PyStructSequence_SetItem(result, pos, item);
    return True;
}

impl wait_helper(
    module: ptr[PyObject], pid: i32, status: i32, ru: rusage
) -> ptr[PyObject] {
    if pid == -1 {
        return posix_error();
    }

    if pid == 0 {
        ru = rusage();
    }
    struct_rusage = PyImport_ImportModuleAttrString("resource", "struct_rusage");
    if not struct_rusage {
        return NULL;
    }
    result = PyStructSequence_New(struct_rusage);
    jacpy_release(struct_rusage);
    if not result {
        return NULL;
    }
    if not set_result(result, 0, PyFloat_FromDouble(doubletime(ru.ru_utime))) {
        return NULL;
    }
    if not set_result(result, 1, PyFloat_FromDouble(doubletime(ru.ru_stime))) {
        return NULL;
    }
    counters = [
        ru.ru_maxrss,
        ru.ru_ixrss,
        ru.ru_idrss,
        ru.ru_isrss,
        ru.ru_minflt,
        ru.ru_majflt,
        ru.ru_nswap,
        ru.ru_inblock,
        ru.ru_oublock,
        ru.ru_msgsnd,
        ru.ru_msgrcv,
        ru.ru_nsignals,
        ru.ru_nvcsw,
        ru.ru_nivcsw
    ];
    for index in range(len(counters)) {
        if not set_result(result, i64(index + 2), PyLong_FromLong(counters[index])) {
            return NULL;
        }
    }
    return Py_BuildValue(ptr[u8]("NiN"), PyLong_FromLong(i64(pid)), status, result);
}

impl os_wait3_impl(module: ptr[PyObject], options: i32) -> ptr[PyObject] {
    ru = rusage();
    async_err = i32(0);
    status = i32(0);
    pid = i32(0);
    while True {
        thread = PyEval_SaveThread();
        pid = wait3(&mut status, options, &mut ru);
        PyEval_RestoreThread(thread);
        if not (pid < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    if pid < 0 {
        return posix_error() if async_err == 0 else NULL;
    }
    return wait_helper(module, pid, status, ru);
}

impl os_wait4_impl(module: ptr[PyObject], pid: i32, options: i32) -> ptr[PyObject] {
    ru = rusage();
    async_err = i32(0);
    status = i32(0);
    res = i32(0);
    while True {
        thread = PyEval_SaveThread();
        res = wait4(pid, &mut status, options, &mut ru);
        PyEval_RestoreThread(thread);
        if not (res < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    if res < 0 {
        return posix_error() if async_err == 0 else NULL;
    }
    return wait_helper(module, res, status, ru);
}

impl os_waitid_impl(
    module: ptr[PyObject], idtype: i32, id: u32, options: i32
) -> ptr[PyObject] {
    si = siginfo_t();
    si.si_pid = 0;
    async_err = i32(0);
    res = i32(0);
    while True {
        thread = PyEval_SaveThread();
        res = waitid(idtype, id, &mut si, options);
        PyEval_RestoreThread(thread);
        if not (res < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    if res < 0 {
        return posix_error() if async_err == 0 else NULL;
    }
    if si.si_pid == 0 {
        return Py_NewRef(Py_None);
    }
    result = PyStructSequence_New(state_object(module, STATE_WAITID_RESULT_TYPE));
    if not result {
        return NULL;
    }
    if not set_result(result, 0, PyLong_FromLong(i64(si.si_pid))) {
        return NULL;
    }
    if not set_result(result, 1, _PyLong_FromUid(si.si_uid)) {
        return NULL;
    }
    if not set_result(result, 2, PyLong_FromLong(i64(si.si_signo))) {
        return NULL;
    }
    if not set_result(result, 3, PyLong_FromLong(i64(si.si_status))) {
        return NULL;
    }
    if not set_result(result, 4, PyLong_FromLong(i64(si.si_code))) {
        return NULL;
    }
    return result;
}

impl os_waitpid_impl(module: ptr[PyObject], pid: i32, options: i32) -> ptr[PyObject] {
    async_err = i32(0);
    status = i32(0);
    res = i32(0);
    while True {
        thread = PyEval_SaveThread();
        res = waitpid(pid, &mut status, options);
        PyEval_RestoreThread(thread);
        if not (res < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    if res < 0 {
        return posix_error() if async_err == 0 else NULL;
    }
    return Py_BuildValue(ptr[u8]("Ni"), PyLong_FromLong(i64(res)), status);
}

impl os_wait_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    async_err = i32(0);
    status = i32(0);
    pid = i32(0);
    while True {
        thread = PyEval_SaveThread();
        pid = `wait(&mut status);
        PyEval_RestoreThread(thread);
        if not (pid < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    if pid < 0 {
        return posix_error() if async_err == 0 else NULL;
    }
    return Py_BuildValue(ptr[u8]("Ni"), PyLong_FromLong(i64(pid)), status);
}

impl os_pidfd_open_impl(module: ptr[PyObject], pid: i32, flags: u32) -> ptr[PyObject] {
    fd = pidfd_open_call(pid, flags);
    if fd < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(fd));
}

impl os_setns_impl(module: ptr[PyObject], fd: i32, nstype: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    res = setns_call(fd, nstype);
    PyEval_RestoreThread(thread);
    if res != 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_unshare_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    res = unshare_call(flags);
    PyEval_RestoreThread(thread);
    if res != 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_WCOREDUMP_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WCOREDUMP(status);
}

impl os_WIFCONTINUED_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WIFCONTINUED(status);
}

impl os_WIFSTOPPED_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WIFSTOPPED(status);
}

impl os_WIFSIGNALED_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WIFSIGNALED(status);
}

impl os_WIFEXITED_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WIFEXITED(status);
}

impl os_WEXITSTATUS_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WEXITSTATUS(status);
}

impl os_WTERMSIG_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WTERMSIG(status);
}

impl os_WSTOPSIG_impl(module: ptr[PyObject], status: i32) -> i32 {
    return WSTOPSIG(status);
}

impl os_waitstatus_to_exitcode_impl(
    module: ptr[PyObject], status_obj: ptr[PyObject]
) -> ptr[PyObject] {
    status = PyLong_AsInt(status_obj);
    if status == -1 and PyErr_Occurred() {
        return NULL;
    }
    exitcode = i32(0);
    if WIFEXITED(status) != 0 {
        exitcode = WEXITSTATUS(status);

        if exitcode < 0 {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("invalid WEXITSTATUS: %i"), exitcode
            );
            return NULL;
        }
    } elif WIFSIGNALED(status) != 0 {
        signum = WTERMSIG(status);
        if signum <= 0 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("invalid WTERMSIG: %i"), signum);
            return NULL;
        }
        exitcode = -signum;
    } elif WIFSTOPPED(status) != 0 {
        signum = WSTOPSIG(status);
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("process stopped by delivery of signal %i"),
            signum
        );
        return NULL;
    } else {
        PyErr_Format(PyExc_ValueError, ptr[u8]("invalid wait status: %i"), status);
        return NULL;
    }
    return PyLong_FromLong(i64(exitcode));
}

impl build_times_result(
    module: ptr[PyObject],
    user: f64,
    system_time: f64,
    children_user: f64,
    children_system: f64,
    elapsed: f64
) -> ptr[PyObject] {
    value = PyStructSequence_New(state_object(module, STATE_TIMES_RESULT_TYPE));
    if not value {
        return NULL;
    }
    fields = [user, system_time, children_user, children_system, elapsed];
    for i in range(5) {
        o = PyFloat_FromDouble(fields[i]);
        if not o {
            jacpy_release(value);
            return NULL;
        }
        PyStructSequence_SetItem(value, i64(i), o);
    }
    return value;
}

impl os_times_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    ticks_per_second = f64(posix_state(module).ticks_per_second);
    jacpy_set_errno(0);
    (ok, user, system_time, children_user, children_system, elapsed) = process_times();
    if not ok {
        return posix_error();
    }
    return build_times_result(
        module,
        user / ticks_per_second,
        system_time / ticks_per_second,
        children_user / ticks_per_second,
        children_system / ticks_per_second,
        elapsed / ticks_per_second
    );
}

impl os_getloadavg_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    loadavg = load_averages();
    if getloadavg(&mut loadavg, i32(3)) != 3 {
        PyErr_SetString(PyExc_OSError, ptr[u8]("Load averages are unobtainable"));
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("ddd"), loadavg.one, loadavg.five, loadavg.fifteen);
}

impl posix_process_exec(module: ptr[PyObject]) -> bool {
    if HAVE_WAITID {
        waitid_result = struct_sequence_type(
            "posix.waitid_result",
            WAITID_RESULT_DOC,
            [
                ("si_pid", ""),
                ("si_uid", ""),
                ("si_signo", ""),
                ("si_status", ""),
                ("si_code", "")
            ],
            5
        );
        if not add_state_owned(
            module, STATE_WAITID_RESULT_TYPE, "waitid_result", waitid_result
        ) {
            return False;
        }
    }
    if HAVE_SCHED_SETPARAM
        or HAVE_SCHED_SETSCHEDULER
        or POSIX_SPAWN_SETSCHEDULER != 0
        or POSIX_SPAWN_SETSCHEDPARAM != 0 {
        sched_param = struct_sequence_type(
            "posix.sched_param",
            SCHED_PARAM_DOC,
            [("sched_priority", "the scheduling priority")],
            1
        );
        if not add_state_owned(
            module, STATE_SCHED_PARAM_TYPE, "sched_param", sched_param
        ) {
            return False;
        }
    }
    times_result = struct_sequence_type(
        "posix.times_result",
        TIMES_RESULT_DOC,
        [
            ("user", "user time"),
            ("system", "system time"),
            ("children_user", "user time of children"),
            ("children_system", "system time of children"),
            ("elapsed", "elapsed time since an arbitrary point in the past")
        ],
        5
    );
    if not add_state_owned(
        module, STATE_TIMES_RESULT_TYPE, "times_result", times_result
    ) {
        return False;
    }
    if HAVE_WAIT3 or HAVE_WAIT4 {
        struct_rusage = interned("struct_rusage");
        if not struct_rusage {
            return False;
        }
        jacpy_binding_state_set(module, i64(STATE_STRUCT_RUSAGE), struct_rusage);
        jacpy_release(struct_rusage);
    }
    ticks_per_second = i64(0);
    if _Py_GetTicksPerSecond(&mut ticks_per_second) < 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot read ticks_per_second"));
        return False;
    }
    posix_state(module).ticks_per_second = ticks_per_second;
    return True;
}
