def:pub PyInit__interpchannels -> ptr[PyObject];

impl PyInit__interpchannels -> ptr[PyObject] {
    definition = addressof(interpchannels_moduledef).view(1);
    if int(definition[0].m_free) == 0 {
        definition[0].m_traverse = int(ptr(module_traverse));
        definition[0].m_clear = int(ptr(module_clear));
        definition[0].m_free = int(ptr(module_free));
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(interpchannels_moduledef)));
}
