import from c {
    glob:priv mod_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("_get_proxy_settings"),
                 ml_meth=ptr(get_proxy_settings),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_get_proxies"),
                 ml_meth=ptr(get_proxies),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         _scproxy_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         _scproxy_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_scproxy"),
             m_doc=ptr[u8](),
             m_size=0,
             m_methods=addressof(mod_methods),
             m_slots=addressof(_scproxy_slots)
         );
}

def:pub PyInit__scproxy -> ptr[PyObject];

impl PyInit__scproxy -> ptr[PyObject] {
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(_scproxy_module)));
}
