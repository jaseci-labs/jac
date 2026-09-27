"""The pwd module: generated clinic tables plus the struct_passwd type."""

import from jaclang.runtime.python.cpython_api { PyObject, jacpy_struct_sequence_type }
import from jaclang.runtime.python.modules.user_records { PLATFORM }
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.clinic.pwd { module_methods }

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            "ImportError", "pwd has no user_records.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    record = jacpy_struct_sequence_type(
        "pwd.struct_passwd",
        "pwd.struct_passwd: Results from getpw*() routines.\n\nThis object may be accessed either as a tuple of\n  (pw_name,pw_passwd,pw_uid,pw_gid,pw_gecos,pw_dir,pw_shell)\nor via the object attributes as named in the above tuple.",
        "pw_name\tuser name\npw_passwd\tpassword\npw_uid\tuser id\npw_gid\tgroup id\npw_gecos\treal name\npw_dir\thome directory\npw_shell\tshell program",
        7
    );
    return i32(0) if add_state_owned(module, 0, "struct_passwd", record) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "pwd",
         "This module provides access to the Unix password database.\nIt is available on all Unix versions.\n\nPassword database entries are reported as 7-tuples containing the following\nitems from the password database (see `<pwd.h>'), in order:\npw_name, pw_passwd, pw_uid, pw_gid, pw_gecos, pw_dir, pw_shell.\nThe uid and gid items are integers, all others are strings. An\nexception is raised if the entry asked for cannot be found.",
         module_methods,
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit_pwd -> ptr[PyObject] {
    return definition.initialize();
}
