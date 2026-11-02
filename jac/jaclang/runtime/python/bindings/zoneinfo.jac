def:pub PyInit__zoneinfo -> ptr[PyObject];

impl PyInit__zoneinfo -> ptr[PyObject] {
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(zoneinfomodule)));
}
