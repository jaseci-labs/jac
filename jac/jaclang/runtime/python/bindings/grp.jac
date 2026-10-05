"""The grp module: generated clinic tables plus the struct_group type."""

import from jaclang.runtime.python.cpython_api { PyObject, jacpy_struct_sequence_type }
import from jaclang.runtime.python.modules.user_records { PLATFORM }
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.clinic.grp { module_methods }

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            "ImportError", "grp has no user_records.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    record = jacpy_struct_sequence_type(
        "grp.struct_group",
        "grp.struct_group: Results from getgr*() routines.\n\nThis object may be accessed either as a tuple of\n  (gr_name,gr_passwd,gr_gid,gr_mem)\nor via the object attributes as named in the above tuple.\n",
        "gr_name\tgroup name\ngr_passwd\tpassword\ngr_gid\tgroup id\ngr_mem\tgroup members",
        4
    );
    return i32(0) if add_state_owned(module, 0, "struct_group", record) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "grp",
         "Access to the Unix group database.\n\nGroup entries are reported as 4-tuples containing the following fields\nfrom the group database, in order:\n\n  gr_name   - name of the group\n  gr_passwd - group password (encrypted); often empty\n  gr_gid    - numeric ID of the group\n  gr_mem    - list of members\n\nThe gid is an integer, name and password are strings.  (Note that most\nusers are not explicitly listed as members of the groups they are in\naccording to the password database.  Check both databases to get\ncomplete membership information.)",
         module_methods,
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit_grp -> ptr[PyObject] {
    return definition.initialize();
}
