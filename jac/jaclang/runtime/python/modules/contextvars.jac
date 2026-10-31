def _contextvars_copy_context_impl(module: ptr[PyObject]) -> ptr[PyObject];

impl _contextvars_copy_context_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyContext_CopyCurrent();
}
