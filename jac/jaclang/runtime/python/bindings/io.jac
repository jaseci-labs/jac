import from c { glob:priv io_tables_ready: i32 = 0; }

def:priv install_io_tables -> bool;

def:pub PyInit__io -> ptr[PyObject];

impl install_io_tables -> bool {
    if io_tables_ready != 0 {
        return True;
    }
    table = method_table(module_methods);
    if not table {
        return False;
    }
    if not install_iobase_tables()
        or not install_fileio_tables()
        or not install_bytesio_tables()
        or not install_stringio_tables()
        or not install_buffered_tables()
        or not install_textio_tables() {
        return False;
    }
    definition = addressof(_PyIO_Module).view(1);
    definition[0].m_methods = table;
    definition[0].m_traverse = int(ptr(iomodule_traverse));
    definition[0].m_clear = int(ptr(iomodule_clear));
    definition[0].m_free = int(ptr(iomodule_free));
    io_tables_ready = 1;
    return True;
}

impl PyInit__io -> ptr[PyObject] {
    if not install_io_tables() {
        return NULL;
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(_PyIO_Module)));
}
