def export_runtime_objects(
    module: ptr[PyObject], objects: list[tuple[str, ptr[PyObject]]]
) -> i32;

impl export_runtime_objects(
    module: ptr[PyObject], objects: list[tuple[str, ptr[PyObject]]]
) -> i32 {
    for (public, value) in objects {
        if jacpy_module_add_object_ref_text(module, public, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}
