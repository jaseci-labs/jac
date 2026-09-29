"""The unicodedata module: the UCD type, ucd_3_2_0 and the name capsule."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    PyModule_Add,
    PyModule_AddStringConstant,
    PyModule_AddType,
    PyObject
}
import from jaclang.runtime.python.bindings.module { ModuleDefinition, ModuleHooks }
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.unicodedata { UCD_methods }
import from jaclang.runtime.python.modules.unicodedata {
    UCD_token,
    new_previous_version,
    ucd_3_2_0_version,
    ucd_unidata_version,
    unicodedata_create_capi
}
import from jaclang.runtime.python.modules.unicodedata_db { UNIDATA_VERSION }

def:priv ucd_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, UCD_token.handle);
}

def:priv ucd_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, UCD_token.handle, visitor, context);
}

def:priv unidata_version(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return ucd_unidata_version(instance);
}

# The functions are both the module's and the UCD type's methods: for a
# module function self is the module, for a method a UCD object.
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
         [
             PropertyDefinition(
                 "unidata_version", PropertyCallbacks(read=unidata_version)
             )
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    UCD_token.handle = ucd_type.handle;
    if PyModule_AddStringConstant(module, "unidata_version", UNIDATA_VERSION) < 0 {
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
    # Unicode database version 3.2.0 used by the IDNA encoding
    v = new_previous_version(type_, addressof(ucd_3_2_0_version));
    jacpy_release(type_);
    if PyModule_Add(module, "ucd_3_2_0", v) < 0 {
        return i32(-1);
    }
    # Export C API
    if PyModule_Add(module, "_ucnhash_CAPI", unicodedata_create_capi()) < 0 {
        return i32(-1);
    }
    return i32(0);
}

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

def:pub PyInit_unicodedata -> ptr[PyObject] {
    return definition.initialize();
}
