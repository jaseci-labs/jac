def:pub PyInit__interpqueues -> ptr[PyObject];

impl PyInit__interpqueues -> ptr[PyObject] {
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(moduledef)));
}
