"""The select module: select(), poll, epoll (Linux), kqueue and kevent (macOS)."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    PyErr_Clear,
    PyExc_ImportError,
    PyExc_OSError,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyObject_DelAttrString,
    PyUnicode_InternFromString
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodDefinition,
    add_state_owned,
    jacpy_binding_module_native_set,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.clinic.select {
    epoll_methods,
    kqueue_doc,
    kqueue_methods,
    module_methods,
    poll_methods,
    select_epoll_new,
    select_kqueue_new
}
import from jaclang.runtime.python.modules.select {
    SelectState,
    epoll_closed_get,
    epoll_internal_close,
    epoll_of,
    epoll_token,
    have_broken_poll,
    kevent_member_get,
    kevent_member_set,
    kevent_token,
    kqueue_closed_get,
    kqueue_event_init,
    kqueue_event_new,
    kqueue_event_repr,
    kqueue_event_richcompare,
    kqueue_finalize,
    kqueue_token,
    module_definition,
    poll_token
}
import from jaclang.runtime.python.modules.select_constants { PLATFORM, CONSTANTS }
import from jaclang.runtime.python.modules.select_platform {
    HAS_EPOLL,
    HAS_KQUEUE,
    KEVENT_MEMBERS,
    PROBE_BROKEN_POLL
}

glob:priv POLL_TYPE: int = 0,
     EPOLL_TYPE: int = 1,
     KEVENT_TYPE: int = 2,
     KQUEUE_TYPE: int = 3,
     # Constants the module uses without publishing them.
     INTERNAL: list[str] = [
         "FD_SETSIZE",
         "EPOLL_CTL_ADD",
         "EPOLL_CTL_MOD",
         "EPOLL_CTL_DEL"
     ],
     MODULE_DOC: str = "This module supports asynchronous I/O on multiple file descriptors.\n\n*** IMPORTANT NOTICE ***\nOn Windows, only sockets are supported; on Unix, all file descriptors.",
     EPOLL_DOC: str = "select.epoll(sizehint=-1, flags=0)\n\nReturns an epolling object\n\nsizehint must be a positive integer or -1 for the default size. The\nsizehint is used to optimize internal data structures. It doesn't limit\nthe maximum number of monitored events.",
     KEVENT_DOC: str = "kevent(ident, filter=KQ_FILTER_READ, flags=KQ_EV_ADD, fflags=0, data=0, udata=0)\n\nThis object is the equivalent of the struct kevent for the C API.\n\nSee the kqueue manpage for more detailed information about the meaning\nof the arguments.\n\nOne minor note: while you might hope that udata could store a\nreference to a python object, it cannot, because it is impossible to\nkeep a proper reference count of the object once it's passed into the\nkernel. Therefore, I have restricted it to only storing an integer.  I\nrecommend ignoring it and simply using the 'ident' field to key off\nof. You could also set up a dictionary on the python side to store a\nudata->object mapping.";

def:priv poll_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, poll_token.handle);
}

def:priv epoll_dealloc(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, epoll_token.handle) != 0 {
        state = epoll_of(instance);
        if state is not None {
            epoll_internal_close(state);
        }
    }
    dispose_payload(instance, epoll_token.handle);
}

def:priv kevent_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, kevent_token.handle);
}

def:priv kqueue_dealloc(instance: ptr[PyObject]) {
    kqueue_finalize(instance);
    dispose_payload(instance, kqueue_token.handle);
}

def:priv kevent_properties -> list[PropertyDefinition] {
    properties: list[PropertyDefinition] = [];
    for index in range(len(KEVENT_MEMBERS)) {
        properties.append(
            PropertyDefinition(
                KEVENT_MEMBERS[index].name,
                PropertyCallbacks(read=kevent_member_get, write=kevent_member_set),
                u64(index),
                ""
            )
        );
    }
    return properties;
}

glob:priv poll_type = TypeDefinition(
         "select.poll",
         "",
         poll_methods,
         u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(dealloc=poll_dealloc)
     ),
     epoll_type = TypeDefinition(
         "select.epoll",
         EPOLL_DOC,
         epoll_methods,
         u64(TypeFlags.DEFAULT.value),
         TypeHooks(create=select_epoll_new, dealloc=epoll_dealloc),
         [
             PropertyDefinition(
                 "closed",
                 PropertyCallbacks(read=epoll_closed_get),
                 0,
                 "True if the epoll handler is closed"
             )
         ]
     ),
     kevent_type = TypeDefinition(
         "select.kevent",
         KEVENT_DOC,
         [],
         u64(TypeFlags.DEFAULT.value),
         TypeHooks(
             create=kqueue_event_new,
             initialize=kqueue_event_init,
             dealloc=kevent_dealloc,
             repr=kqueue_event_repr,
             compare=kqueue_event_richcompare
         ),
         kevent_properties(),
         unhashable=True
     ),
     kqueue_type = TypeDefinition(
         "select.kqueue",
         kqueue_doc,
         kqueue_methods,
         u64(TypeFlags.DEFAULT.value),
         TypeHooks(create=select_kqueue_new, dealloc=kqueue_dealloc),
         [
             PropertyDefinition(
                 "closed",
                 PropertyCallbacks(read=kqueue_closed_get),
                 0,
                 "True if the kqueue handler is closed"
             )
         ]
     );

def:priv add_constants(module: ptr[PyObject], prefix: str) -> bool {
    for (name, value) in CONSTANTS {
        if name.startswith(prefix)
            and name not in INTERNAL
            and PyModule_AddIntConstant(module, name, value) < 0 {
            return False;
        }
    }
    return True;
}

# Create a type into state slot `slot`, publishing it on the module when
# `public`.
def:priv add_type(
    module: ptr[PyObject],
    slot: int,
    name: str,
    definition: TypeDefinition,
    public: bool
) -> bool {
    created = definition.create(module);
    if not created {
        return False;
    }
    if public {
        return add_state_owned(module, slot, name, created);
    }
    jacpy_binding_state_set(module, i64(slot), created);
    jacpy_release(created);
    return True;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "select has no select_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    module_definition.handle = definition.handle;
    poll_token.handle = poll_type.handle;
    epoll_token.handle = epoll_type.handle;
    kevent_token.handle = kevent_type.handle;
    kqueue_token.handle = kqueue_type.handle;
    close = PyUnicode_InternFromString("close");
    if not close {
        return i32(-1);
    }
    jacpy_binding_module_native_set(module, SelectState(close=close));
    if PyModule_AddObjectRef(module, "error", PyExc_OSError) < 0
        or not add_constants(module, "PIPE_BUF") {
        return i32(-1);
    }
    if PROBE_BROKEN_POLL and have_broken_poll() {
        if PyObject_DelAttrString(module, "poll") == -1 {
            PyErr_Clear();
        }
    } elif not add_type(module, POLL_TYPE, "poll", poll_type, False)
        or not add_constants(module, "POLL") {
        return i32(-1);
    }
    if HAS_EPOLL
        and (
            not add_type(module, EPOLL_TYPE, "epoll", epoll_type, True)
            or not add_constants(module, "EPOLL")
        ) {
        return i32(-1);
    }
    if HAS_KQUEUE
        and (
            not add_type(module, KEVENT_TYPE, "kevent", kevent_type, True)
            or not add_type(module, KQUEUE_TYPE, "kqueue", kqueue_type, True)
            or not add_constants(module, "KQ_")
        ) {
        return i32(-1);
    }
    return i32(0);
}

# select_methods[]: select() and poll(); devpoll() exists only with
# <sys/devpoll.h>, which no supported target has.
def:priv methods -> list[MethodDefinition] {
    return [
        method
        for method in module_methods
        if method.name != "devpoll"
    ];
}

glob:priv definition = ModuleDefinition(
         "select", MODULE_DOC, methods(), ModuleHooks(execute=execute), 4
     );

def:pub PyInit_select -> ptr[PyObject] {
    return definition.initialize();
}
