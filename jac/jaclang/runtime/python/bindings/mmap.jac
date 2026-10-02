"""The mmap module: the mmap type with its buffer, sequence and mapping protocols."""

import from jaclang.runtime.python.cpython_api {
    PyExc_ImportError,
    PyExc_OSError,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodDefinition,
    add_owned
}
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
import from jaclang.runtime.python.bindings.clinic.mmap { mmap_methods }
import from jaclang.runtime.python.modules.mmap {
    mmap_ass_item,
    mmap_ass_subscript,
    mmap_closed_get,
    mmap_getbuffer,
    mmap_item,
    mmap_length,
    mmap_new,
    mmap_release,
    mmap_releasebuffer,
    mmap_repr,
    mmap_subscript,
    mmap_token,
    page_size
}
import from jaclang.runtime.python.modules.mmap_constants { PLATFORM, CONSTANTS }

glob:priv INTERNAL: list[str] = [
         "_SC_PAGESIZE",
         "MS_SYNC",
         "F_FULLFSYNC",
         "MREMAP_MAYMOVE"
     ],
     ACCESS_MODES: list[tuple[str, i64]] = [
         ("ACCESS_DEFAULT", 0),
         ("ACCESS_READ", 1),
         ("ACCESS_WRITE", 2),
         ("ACCESS_COPY", 3)
     ],
     # mmap_object_methods[]: __sizeof__ and _protect are Windows-only.
     WINDOWS_ONLY: list[str] = ["__sizeof__", "_protect"],
     MMAP_DOC: str = "Windows: mmap(fileno, length[, tagname[, access[, offset]]])\n\nMaps length bytes from the file specified by the file handle fileno,\nand returns a mmap object.  If length is larger than the current size\nof the file, the file is extended to contain length bytes.  If length\nis 0, the maximum length of the map is the current size of the file,\nexcept that if the file is empty Windows raises an exception (you cannot\ncreate an empty mapping on Windows).\n\nUnix: mmap(fileno, length[, flags[, prot[, access[, offset[, trackfd]]]]])\n\nMaps length bytes from the file specified by the file descriptor fileno,\nand returns a mmap object.  If length is 0, the maximum length of the map\nwill be the current size of the file when mmap is called.\nflags specifies the nature of the mapping. MAP_PRIVATE creates a\nprivate copy-on-write mapping, so changes to the contents of the mmap\nobject will be private to this process, and MAP_SHARED creates a mapping\nthat's shared with all other processes mapping the same areas of the file.\nThe default value is MAP_SHARED.\n\nTo map anonymous memory, pass -1 as the fileno (both versions).";

def:priv mmap_dealloc(instance: ptr[PyObject]) {
    mmap_release(instance);
    dispose_payload(instance, mmap_token.handle);
}

def:priv mmap_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, mmap_token.handle, visitor, context);
}

def:priv methods -> list[MethodDefinition] {
    return [
        method
        for method in mmap_methods
        if method.name not in WINDOWS_ONLY
    ];
}

glob:priv mmap_type = TypeDefinition(
         "mmap.mmap",
         MMAP_DOC,
         methods(),
         u64(TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=mmap_new,
             dealloc=mmap_dealloc,
             traverse=mmap_traverse,
             repr=mmap_repr,
             length=mmap_length,
             item=mmap_item,
             assign=mmap_ass_item,
             mapping_length=mmap_length,
             subscript=mmap_subscript,
             assign_subscript=mmap_ass_subscript,
             buffer=mmap_getbuffer,
             release_buffer=mmap_releasebuffer
         ),
         [PropertyDefinition("closed", PropertyCallbacks(read=mmap_closed_get), 0, "")],
         weaklist=True,
         generic_getattr=True
     );

# The MADV_* constants, or all the others.
def:priv add_constants(module: ptr[PyObject], advice: bool) -> bool {
    for (name, value) in CONSTANTS {
        if name in INTERNAL or name.startswith("MADV_") != advice {
            continue;
        }
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return False;
        }
    }
    return True;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError, "mmap has no mmap_constants for this target platform"
        );
        return i32(-1);
    }
    mmap_token.handle = mmap_type.handle;
    if PyModule_AddObjectRef(module, "error", PyExc_OSError) < 0 {
        return i32(-1);
    }
    if not add_owned(module, "mmap", mmap_type.create(module)) {
        return i32(-1);
    }
    # PROT_* and MAP_*, the page size, the access modes, then MADV_*.
    if not add_constants(module, False) {
        return i32(-1);
    }
    granularity = page_size();
    if PyModule_AddIntConstant(module, "PAGESIZE", granularity) < 0
        or PyModule_AddIntConstant(module, "ALLOCATIONGRANULARITY", granularity) < 0 {
        return i32(-1);
    }
    for (name, value) in ACCESS_MODES {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0) if add_constants(module, True) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "mmap", "", [], ModuleHooks(execute=execute)
     );

def:pub PyInit_mmap -> ptr[PyObject] {
    return definition.initialize();
}
