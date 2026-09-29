"""The pyexpat module: the xmlparser type, ExpatError, the errors and model
submodules, and the expat_CAPI capsule."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddStringConstant,
    PyObject,
    PyUnicode_InternFromString
}
import from jaclang.runtime.python.bindings.module {
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_exception,
    jacpy_binding_module_native_set
}
import from jaclang.runtime.python.bindings.type {
    PropertyCallbacks,
    PropertyDefinition,
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.clinic.pyexpat {
    module_methods,
    xmlparser_methods
}
import from jaclang.runtime.python.modules.expat {
    XML_PARAM_ENTITY_PARSING_ALWAYS,
    XML_PARAM_ENTITY_PARSING_NEVER,
    XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE
}
import from jaclang.runtime.python.modules.pyexpat {
    HANDLER_NAMES,
    PyexpatState,
    XMLPARSER_MEMBERS,
    XMLPARSER_RECORD_SIZE,
    add_errors_module,
    add_features,
    add_model_module,
    add_version,
    module_definition,
    new_capsule,
    xmlparse_ErrorByteIndex_getter,
    xmlparse_ErrorCode_getter,
    xmlparse_ErrorColumnNumber_getter,
    xmlparse_ErrorLineNumber_getter,
    xmlparse_buffer_size_getter,
    xmlparse_buffer_size_setter,
    xmlparse_buffer_text_getter,
    xmlparse_buffer_text_setter,
    xmlparse_buffer_used_getter,
    xmlparse_clear,
    xmlparse_dealloc,
    xmlparse_handler_getter,
    xmlparse_handler_setter,
    xmlparse_namespace_prefixes_getter,
    xmlparse_namespace_prefixes_setter,
    xmlparse_ordered_attributes_getter,
    xmlparse_ordered_attributes_setter,
    xmlparse_specified_attributes_getter,
    xmlparse_specified_attributes_setter,
    xmlparse_traverse,
    xmlparser_token
}

# xmlparse_methods, in pyexpat.c's order.
glob:priv METHOD_ORDER: list[str] = [
         "Parse",
         "ParseFile",
         "SetBase",
         "GetBase",
         "GetInputContext",
         "ExternalEntityParserCreate",
         "SetParamEntityParsing",
         "UseForeignDTD",
         "SetBillionLaughsAttackProtectionActivationThreshold",
         "SetBillionLaughsAttackProtectionMaximumAmplification",
         "SetAllocTrackerActivationThreshold",
         "SetAllocTrackerMaximumAmplification",
         "SetReparseDeferralEnabled",
         "GetReparseDeferralEnabled"
     ];

def:priv ordered_methods -> list[MethodDefinition] {
    ordered: list[MethodDefinition] = [];
    for name in METHOD_ORDER {
        for method in xmlparser_methods {
            if method.name == name {
                ordered.append(method);
            }
        }
    }
    return ordered;
}

# xmlparse_getsetlist, then a descriptor per handler whose closure is its
# index in the handler table.
def:priv xmlparser_properties -> list[PropertyDefinition] {
    properties: list[PropertyDefinition] = [
        PropertyDefinition(
            "ErrorCode", PropertyCallbacks(read=xmlparse_ErrorCode_getter)
        ),
        PropertyDefinition(
            "ErrorLineNumber", PropertyCallbacks(read=xmlparse_ErrorLineNumber_getter)
        ),
        PropertyDefinition(
            "ErrorColumnNumber",
            PropertyCallbacks(read=xmlparse_ErrorColumnNumber_getter)
        ),
        PropertyDefinition(
            "ErrorByteIndex", PropertyCallbacks(read=xmlparse_ErrorByteIndex_getter)
        ),
        # XML_GetErrorLineNumber() and friends are the Current* functions.
        PropertyDefinition(
            "CurrentLineNumber", PropertyCallbacks(read=xmlparse_ErrorLineNumber_getter)
        ),
        PropertyDefinition(
            "CurrentColumnNumber",
            PropertyCallbacks(read=xmlparse_ErrorColumnNumber_getter)
        ),
        PropertyDefinition(
            "CurrentByteIndex", PropertyCallbacks(read=xmlparse_ErrorByteIndex_getter)
        ),
        PropertyDefinition(
            "buffer_size",
            PropertyCallbacks(
                read=xmlparse_buffer_size_getter, write=xmlparse_buffer_size_setter
            )
        ),
        PropertyDefinition(
            "buffer_text",
            PropertyCallbacks(
                read=xmlparse_buffer_text_getter, write=xmlparse_buffer_text_setter
            )
        ),
        PropertyDefinition(
            "buffer_used", PropertyCallbacks(read=xmlparse_buffer_used_getter)
        ),
        PropertyDefinition(
            "namespace_prefixes",
            PropertyCallbacks(
                read=xmlparse_namespace_prefixes_getter,
                write=xmlparse_namespace_prefixes_setter
            )
        ),
        PropertyDefinition(
            "ordered_attributes",
            PropertyCallbacks(
                read=xmlparse_ordered_attributes_getter,
                write=xmlparse_ordered_attributes_setter
            )
        ),
        PropertyDefinition(
            "specified_attributes",
            PropertyCallbacks(
                read=xmlparse_specified_attributes_getter,
                write=xmlparse_specified_attributes_setter
            )
        )
    ];
    for index in range(len(HANDLER_NAMES)) {
        properties.append(
            PropertyDefinition(
                HANDLER_NAMES[index],
                PropertyCallbacks(
                    read=xmlparse_handler_getter, write=xmlparse_handler_setter
                ),
                context=u64(index)
            )
        );
    }
    return properties;
}

glob:priv xmlparser_type = TypeDefinition(
         "pyexpat.xmlparser",
         "XML parser",
         ordered_methods(),
         u64(
             TypeFlags.GC.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
         ),
         TypeHooks(
             dealloc=xmlparse_dealloc, traverse=xmlparse_traverse, clear=xmlparse_clear
         ),
         xmlparser_properties(),
         members=XMLPARSER_MEMBERS,
         record_size=XMLPARSER_RECORD_SIZE
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    module_definition.handle = definition.handle;
    xmlparser_token.handle = xmlparser_type.handle;
    state = PyexpatState();
    jacpy_binding_module_native_set(module, state);
    state.str_read = PyUnicode_InternFromString("read");
    if not state.str_read {
        return i32(-1);
    }
    state.xml_parse_type = xmlparser_type.create(module);
    if not state.xml_parse_type {
        return i32(-1);
    }
    state.error = jacpy_binding_exception("xml.parsers.expat.ExpatError", NULL, "");
    if not state.error {
        return i32(-1);
    }
    if PyModule_AddObjectRef(module, "error", state.error) < 0
        or PyModule_AddObjectRef(module, "ExpatError", state.error) < 0
        or PyModule_AddObjectRef(module, "XMLParserType", state.xml_parse_type) < 0 {
        return i32(-1);
    }
    if add_version(module) < 0 {
        return i32(-1);
    }
    # Expat cannot report how it was compiled; its XML_Char is UTF-8 here.
    if PyModule_AddStringConstant(module, "native_encoding", "UTF-8") < 0 {
        return i32(-1);
    }
    if add_errors_module(module) < 0
        or add_model_module(module) < 0
        or add_features(module) < 0 {
        return i32(-1);
    }
    for (name, value) in [
        ("XML_PARAM_ENTITY_PARSING_NEVER", XML_PARAM_ENTITY_PARSING_NEVER),
        (
            "XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE",
            XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE
        ),
        ("XML_PARAM_ENTITY_PARSING_ALWAYS", XML_PARAM_ENTITY_PARSING_ALWAYS)
    ] {
        if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return i32(-1);
        }
    }
    capsule = new_capsule();
    if not capsule {
        return i32(-1);
    }
    if PyModule_Add(module, "expat_CAPI", capsule) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "pyexpat",
         "Python wrapper for Expat parser.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit_pyexpat -> ptr[PyObject] {
    return definition.initialize();
}
