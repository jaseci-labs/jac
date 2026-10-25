import from c {
    def _PyXIData_RegisterClass(
        tstate: ptr[PyThreadState], cls: ptr[PyTypeObject], getdata: _PyXIData_getdata_t
    ) -> i32;  def _PyXIData_UnregisterClass(
        tstate: ptr[PyThreadState], cls: ptr[PyTypeObject]
    ) -> i32;  def PyInterpreterState_GetID(interp: ptr[u8]) -> i64;
}

glob UNBOUND_REMOVE: Final[i32] = 1,
     UNBOUND_ERROR: Final[i32] = 2,
     UNBOUND_REPLACE: Final[i32] = 3,
     XIDATA_XIDATA_ONLY: Final[i32] = 0,
     XIDATA_FULL_FALLBACK: Final[i32] = 1;

def ensure_xid_class(cls: ptr[PyTypeObject], basic: ptr) -> i32;

def clear_xid_class(cls: ptr[PyTypeObject]) -> i32;

def get_interpid(data: ptr[_PyXIData_t]) -> i64;

def resolve_fallback(arg: i32, dflt: i32) -> tuple[i32, i32];

def resolve_unboundop(arg: i32, dflt: i32) -> tuple[i32, i32];

impl ensure_xid_class(cls: ptr[PyTypeObject], basic: ptr) -> i32 {
    tstate = PyThreadState_Get();
    getdata = _PyXIData_getdata_t();
    getdata.basic = int(basic);
    return _PyXIData_RegisterClass(tstate, cls, getdata);
}

impl clear_xid_class(cls: ptr[PyTypeObject]) -> i32 {
    tstate = PyThreadState_Get();
    return _PyXIData_UnregisterClass(tstate, cls);
}

impl get_interpid(data: ptr[_PyXIData_t]) -> i64 {
    if data {
        return data.view(1)[0].interpid;
    }
    return PyInterpreterState_GetID(ptr[u8](PyInterpreterState_Get()));
}

impl resolve_fallback(arg: i32, dflt: i32) -> tuple[i32, i32] {
    if arg < 0 {
        return (i32(0), dflt);
    }
    if arg == XIDATA_XIDATA_ONLY {
        return (i32(0), XIDATA_XIDATA_ONLY);
    }
    if arg == XIDATA_FULL_FALLBACK {
        return (i32(0), XIDATA_FULL_FALLBACK);
    }
    PyErr_Format(PyExc_ValueError, ptr[u8]("unsupported fallback %d"), arg);
    return (i32(-1), dflt);
}

impl resolve_unboundop(arg: i32, dflt: i32) -> tuple[i32, i32] {
    if arg < 0 {
        return (i32(0), dflt);
    }
    if arg == UNBOUND_REMOVE {
        return (i32(0), UNBOUND_REMOVE);
    }
    if arg == UNBOUND_ERROR {
        return (i32(0), UNBOUND_ERROR);
    }
    if arg == UNBOUND_REPLACE {
        return (i32(0), UNBOUND_REPLACE);
    }
    PyErr_Format(PyExc_ValueError, ptr[u8]("unsupported unboundop %d"), arg);
    return (i32(-1), dflt);
}
