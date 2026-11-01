def:priv ucd_dealloc(instance: ptr[PyObject]);

def:priv ucd_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

glob:priv ucd_type = TypeDefinition(
         "unicodedata.UCD",
         "",
         UCD_methods,
         u64(
             TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
         ),
         TypeHooks(dealloc=ucd_dealloc, traverse=ucd_traverse),
         members=[
             MemberField("unidata_version", MemberType.STRING.value, 0, readonly=True)
         ],
         record_size=8,
         generic_getattr=True
     );

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "unicodedata",
         "This module provides access to the Unicode Character Database which\n"
         "defines character properties for all Unicode characters. The data in\n"
         "this database is based on the UnicodeData.txt file version\n"
             + UNIDATA_VERSION
             + " which is publicly available from ftp://ftp.unicode.org/.\n"
             "\n"
             "The module uses the same names and symbols as defined by the\n"
             "UnicodeData File Format "
             + UNIDATA_VERSION
             + ".",
         UCD_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit_unicodedata -> ptr[PyObject];

impl ucd_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, UCD_token.handle);
}

impl ucd_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, UCD_token.handle, visitor, context);
}

impl execute(module: ptr[PyObject]) -> i32 {
    UCD_token.handle = ucd_type.handle;
    if jacpy_module_add_string_text(module, "unidata_version", UNIDATA_VERSION) < 0 {
        return i32(-1);
    }
    type_ = ucd_type.create(module);
    if not type_ {
        return i32(-1);
    }
    if PyModule_AddType(module, type_) < 0 {
        jacpy_release(type_);
        return i32(-1);
    }

    v = new_previous_version(type_, addressof(ucd_3_2_0_version));
    jacpy_release(type_);
    if PyModule_Add(module, ptr[u8]("ucd_3_2_0"), v) < 0 {
        return i32(-1);
    }

    if PyModule_Add(module, ptr[u8]("_ucnhash_CAPI"), unicodedata_create_capi()) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit_unicodedata -> ptr[PyObject] {
    return definition.initialize();
}
