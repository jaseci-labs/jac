"""The pyexpat module: Python's wrapper for the Expat XML parser.

Derived from CPython 3.14.6 Modules/pyexpat.c; see ../LICENSE.cpython. Expat
runs with the GIL held and calls back into the handlers below with the parser
object as its user data; the object's fields are a C record so those callbacks
reach them as pyexpat.c does. A failing handler adds a traceback entry for the
pyexpat.c line CPython reports, stops the parser and clears every handler.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    PyByteArray_AsString,
    PyCapsule_GetPointer,
    PyCapsule_New,
    PyBytes_AsString,
    PyDict_GetItemRef,
    PyDict_New,
    PyDict_SetItem,
    PyErr_FormatUnraisable,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetObject,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyList_Append,
    PyList_New,
    PyList_SetItem,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddStringConstant,
    PyModule_New,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallOneArg,
    PyObject_GetOptionalAttr,
    PyObject_IsTrue,
    PyObject_SetAttrString,
    PyTuple_New,
    PyType_GetModule,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_Decode,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FromFormat,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    Py_LeaveRecursiveCall,
    _PyImport_SetModule,
    _PyTraceback_Add,
    _Py_HashSecret,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_is_bytearray,
    jacpy_is_bytes,
    jacpy_is_dict,
    jacpy_is_long,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_recursion_enter,
    jacpy_release,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.capi {
    StaticText,
    c_string_text,
    object_error,
    text_object,
    text_value,
    type_name
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_free,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload { jacpy_binding_untrack }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.members { MemberField }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.expat {
    PYEXPAT_CAPI_MAGIC,
    PYEXPAT_CAPI_SIZE,
    PYEXPAT_CAPSULE_NAME,
    PyExpat_CAPI,
    XML_Content,
    XML_FEATURE_END,
    XML_Memory_Handling_Suite,
    XML_ERROR_INVALID_ARGUMENT,
    XML_ERROR_NONE,
    XML_ErrorString,
    XML_ExpatVersion,
    XML_ExternalEntityParserCreate,
    XML_FALSE,
    XML_FreeContentModel,
    XML_GetBase,
    XML_GetBuffer,
    XML_GetCurrentByteIndex,
    XML_GetCurrentColumnNumber,
    XML_GetCurrentLineNumber,
    XML_GetErrorCode,
    XML_GetFeatureList,
    XML_GetInputContext,
    XML_GetSpecifiedAttributeCount,
    XML_Parse,
    XML_ParseBuffer,
    XML_ParserCreate_MM,
    XML_ParserFree,
    XML_STATUS_ERROR,
    XML_STATUS_OK,
    XML_SetAllocTrackerActivationThreshold,
    XML_SetAllocTrackerMaximumAmplification,
    XML_SetAttlistDeclHandler,
    XML_SetBase,
    XML_SetBillionLaughsAttackProtectionActivationThreshold,
    XML_SetBillionLaughsAttackProtectionMaximumAmplification,
    XML_SetCharacterDataHandler,
    XML_SetCommentHandler,
    XML_SetDefaultHandler,
    XML_SetDefaultHandlerExpand,
    XML_SetElementDeclHandler,
    XML_SetElementHandler,
    XML_SetEncoding,
    XML_SetEndCdataSectionHandler,
    XML_SetEndDoctypeDeclHandler,
    XML_SetEndElementHandler,
    XML_SetEndNamespaceDeclHandler,
    XML_SetEntityDeclHandler,
    XML_SetExternalEntityRefHandler,
    XML_SetHashSalt,
    XML_SetNamespaceDeclHandler,
    XML_SetNotStandaloneHandler,
    XML_SetNotationDeclHandler,
    XML_SetParamEntityParsing,
    XML_SetProcessingInstructionHandler,
    XML_SetReparseDeferralEnabled,
    XML_SetReturnNSTriplet,
    XML_SetSkippedEntityHandler,
    XML_SetStartCdataSectionHandler,
    XML_SetStartDoctypeDeclHandler,
    XML_SetStartElementHandler,
    XML_SetStartNamespaceDeclHandler,
    XML_SetUnknownEncodingHandler,
    XML_SetUnparsedEntityDeclHandler,
    XML_SetUserData,
    XML_SetXmlDeclHandler,
    XML_StopParser,
    XML_TRUE,
    XML_UseForeignDTD,
    expat_memory_suite,
    expat_version
}

import from c {
    # xmlparseobject after its header; `intern` comes first so the member
    # descriptor reads it at offset 0.
    obj xmlparser_record {
        has intern: ptr[PyObject],
            itself: ptr,
            parent: ptr[PyObject],
            ordered_attributes: i32,
            specified_attributes: i32,
            in_callback: i32,
            ns_prefixes: i32,
            buffer: ptr[u8],
            buffer_size: i32,
            buffer_used: i32,
            reparse_deferral_enabled: i32,
            handlers: ptr[ptr[PyObject]];
    }  def strlen(text: ptr[u8]) -> u64;
}

glob XMLPARSER_RECORD_SIZE: int = 72,
     XMLPARSER_MEMBERS: list[MemberField] = [
         MemberField(name="intern", kind=6, offset=0, readonly=True)
     ];

# enum HandlerTypes, with each handler's attribute name, the name its
# traceback entry carries, and the pyexpat.c line CPython reports for it.
glob StartElement: int = 0,
     EndElement: int = 1,
     ProcessingInstruction: int = 2,
     CharacterData: int = 3,
     UnparsedEntityDecl: int = 4,
     NotationDecl: int = 5,
     StartNamespaceDecl: int = 6,
     EndNamespaceDecl: int = 7,
     Comment: int = 8,
     StartCdataSection: int = 9,
     EndCdataSection: int = 10,
     Default: int = 11,
     DefaultHandlerExpand: int = 12,
     NotStandalone: int = 13,
     ExternalEntityRef: int = 14,
     StartDoctypeDecl: int = 15,
     EndDoctypeDecl: int = 16,
     EntityDecl: int = 17,
     XmlDecl: int = 18,
     ElementDecl: int = 19,
     AttlistDecl: int = 20,
     SkippedEntity: int = 21,
     HANDLER_COUNT: int = 22,
     HANDLER_NAMES: list[str] = [
         "StartElementHandler",
         "EndElementHandler",
         "ProcessingInstructionHandler",
         "CharacterDataHandler",
         "UnparsedEntityDeclHandler",
         "NotationDeclHandler",
         "StartNamespaceDeclHandler",
         "EndNamespaceDeclHandler",
         "CommentHandler",
         "StartCdataSectionHandler",
         "EndCdataSectionHandler",
         "DefaultHandler",
         "DefaultHandlerExpand",
         "NotStandaloneHandler",
         "ExternalEntityRefHandler",
         "StartDoctypeDeclHandler",
         "EndDoctypeDeclHandler",
         "EntityDeclHandler",
         "XmlDeclHandler",
         "ElementDeclHandler",
         "AttlistDeclHandler",
         "SkippedEntityHandler"
     ],
     FRAME_NAMES: list[str] = [
         "StartElement",
         "EndElement",
         "ProcessingInstruction",
         "CharacterData",
         "UnparsedEntityDecl",
         "NotationDecl",
         "StartNamespaceDecl",
         "EndNamespaceDecl",
         "Comment",
         "StartCdataSection",
         "EndCdataSection",
         "Default",
         "DefaultHandlerExpand",
         "NotStandalone",
         "ExternalEntityRef",
         "StartDoctypeDecl",
         "EndDoctypeDecl",
         "EntityDecl",
         "XmlDecl",
         "ElementDecl",
         "AttlistDecl",
         "SkippedEntity"
     ],
     FRAME_LINES: list[int] = [
         490,
         556,
         562,
         355,
         574,
         714,
         721,
         726,
         730,
         734,
         738,
         742,
         746,
         751,
         765,
         775,
         777,
         591,
         601,
         669,
         695,
         703
     ],
     FRAME_FILE: str = "./Modules/pyexpat.c",
     CHARACTER_DATA_BUFFER_SIZE: int = 8192,
     MAX_CHUNK_SIZE: int = 1 << 20,
     BUF_SIZE: int = 2048,
     INT_MAX: int = 2147483647,
     # Installing a handler: none, the dispatching one, or the no-op character
     # data handler used while a character data callback is active.
     HANDLER_OFF: int = 0,
     HANDLER_ON: int = 1,
     HANDLER_NOOP: int = 2;

# The handle of the module definition, which the binding fills in, so a type
# finds its module as PyType_GetModuleByDef() does.
obj DefinitionHandle {
    has handle: ptr = ptr();
}

glob module_definition = DefinitionHandle(),
     xmlparser_token = ClassToken();

# pyexpat_state.
obj PyexpatState(NativeState) {
    has xml_parse_type: ptr[PyObject] = NULL,
        error: ptr[PyObject] = NULL,
        str_read: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        for value in [self.xml_parse_type, self.error, self.str_read] {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    def clear {
        references = [self.xml_parse_type, self.error, self.str_read];
        self.xml_parse_type = NULL;
        self.error = NULL;
        self.str_read = NULL;
        for value in references {
            jacpy_release(value);
        }
    }

    def drop {
        self.clear();
    }
}

def module_state(module: ptr[PyObject]) -> PyexpatState {
    state = jacpy_binding_module_native_get(module);
    if isinstance(state, PyexpatState) {
        return state;
    }
    return PyexpatState();
}

# PyType_GetModuleState(cls).
def:priv state_of_class(cls: ptr[PyObject]) -> PyexpatState {
    return module_state(PyType_GetModule(cls));
}

def:priv fields(instance: ptr[PyObject]) -> ptr[xmlparser_record] {
    return ptr[xmlparser_record](
        jacpy_binding_record(instance, xmlparser_token.handle)
    );
}

# ------------------------------------------------------------------ errors

# set_xml_error(): an ExpatError with code, lineno and offset attributes;
# `message` replaces Expat's text for the code when given.
def:priv set_xml_error(
    error: ptr[PyObject], code: i32, lineno: u64, column: u64, message: str = ""
) -> ptr[PyObject] {
    arg: ptr[PyObject] = NULL;
    if message {
        arg = text_object(message);
    } else {
        arg = PyUnicode_FromFormat(
            "%s: line %zu, column %zu", XML_ErrorString(code), lineno, column
        );
    }
    if not arg {
        return NULL;
    }
    result = PyObject_CallOneArg(error, arg);
    jacpy_release(arg);
    if result
        and set_error_attribute(result, "code", PyLong_FromLong(i64(code)))
        and set_error_attribute(result, "lineno", PyLong_FromSize_t(lineno))
        and set_error_attribute(result, "offset", PyLong_FromSize_t(column)) {
        PyErr_SetObject(error, result);
    }
    jacpy_release(result);
    return NULL;
}

# Set an attribute to an owned value; False with the exception set.
def:priv set_error_attribute(
    error: ptr[PyObject], name: str, value: ptr[PyObject]
) -> bool {
    ok = value != NULL and PyObject_SetAttrString(error, name, value) != -1;
    jacpy_release(value);
    return ok;
}

# set_error(): the error `code` at the parser's current position.
def:priv set_error(
    state: PyexpatState, instance: ptr[PyObject], code: i32, message: str = ""
) -> ptr[PyObject] {
    parser = fields(instance).view(1)[0].itself;
    lineno = XML_GetCurrentLineNumber(parser);
    column = XML_GetCurrentColumnNumber(parser);
    return set_xml_error(state.error, code, lineno, column, message);
}

def:priv set_invalid_arg(
    state: PyexpatState, instance: ptr[PyObject], message: str
) -> ptr[PyObject] {
    return set_error(state, instance, XML_ERROR_INVALID_ARGUMENT, message);
}

# ------------------------------------------------------------- conversions

# conv_string_to_unicode(): None for a NULL string, else strict UTF-8.
def conv_string_to_unicode(text: ptr[u8]) -> ptr[PyObject] {
    if not text {
        return Py_NewRef(Py_None);
    }
    return PyUnicode_DecodeUTF8Stateful(ptr(text), i64(strlen(text)), ptr[u8](), None);
}

def:priv conv_string_len_to_unicode(text: ptr[u8], size: i32) -> ptr[PyObject] {
    if not text {
        return Py_NewRef(Py_None);
    }
    return PyUnicode_DecodeUTF8Stateful(ptr(text), i64(size), ptr[u8](), None);
}

# string_intern(): the text, shared through the parser's intern dict.
def:priv string_intern(instance: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject] {
    result = conv_string_to_unicode(text);
    if not result {
        return result;
    }
    intern = fields(instance).view(1)[0].intern;
    if not intern {
        return result;
    }
    value: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(intern, result, &mut value) == 0
        and PyDict_SetItem(intern, result, result) == 0 {
        return result;
    }
    jacpy_release(result);
    return value;
}

# A tuple owning `items`; NULL (releasing the others) when any is missing, as
# Py_BuildValue() does with its N and O& conversions.
def:priv owned_tuple(items: list[ptr[PyObject]]) -> ptr[PyObject] {
    complete = True;
    for item in items {
        if not item {
            complete = False;
        }
    }
    result: ptr[PyObject] = NULL;
    if complete {
        result = PyTuple_New(i64(len(items)));
    }
    if not result {
        for item in items {
            jacpy_release(item);
        }
        return NULL;
    }
    for index in range(len(items)) {
        jacpy_tuple_set_owned(result, i64(index), items[index]);
    }
    return result;
}

# ----------------------------------------------------------------- handlers

def:priv have_handler(instance: ptr[PyObject], index: int) -> bool {
    handlers = fields(instance).view(1)[0].handlers;
    return bool((handlers + index).view(1)[0]);
}

# error_external_entity_ref_handler(): installed after a failure so parsing
# stops at the next external entity reference.
def:priv error_external_entity_ref_handler(
    parser: ptr, context: ptr[u8], base: ptr[u8], system_id: ptr[u8], public_id: ptr[u8]
) -> i32 {
    return i32(0);
}

def:priv noop_character_data_handler(user_data: ptr, data: ptr[u8], size: i32) {}

def:priv flag_error(instance: ptr[PyObject]) {
    clear_handlers(instance, False);
    XML_SetExternalEntityRefHandler(
        fields(instance).view(1)[0].itself, error_external_entity_ref_handler
    );
}

def:priv call_with_frame(
    index: int, func: ptr[PyObject], args: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject] {
    result = PyObject_Call(func, args, NULL);
    if not result {
        _PyTraceback_Add(FRAME_NAMES[index], FRAME_FILE, i32(FRAME_LINES[index]));
        XML_StopParser(fields(instance).view(1)[0].itself, XML_FALSE);
    }
    return result;
}

# call_character_handler(): 0, or -1 once the error is flagged.
def:priv call_character_handler(
    instance: ptr[PyObject], text: ptr[u8], size: i32
) -> i32 {
    if not have_handler(instance, CharacterData) {
        return i32(-1);
    }
    args = PyTuple_New(1);
    if not args {
        return i32(-1);
    }
    temp = conv_string_len_to_unicode(text, size);
    if not temp {
        jacpy_release(args);
        flag_error(instance);
        XML_SetCharacterDataHandler(
            fields(instance).view(1)[0].itself, noop_character_data_handler
        );
        return i32(-1);
    }
    jacpy_tuple_set_owned(args, 0, temp);
    record = fields(instance).view(1);
    record[0].in_callback = 1;
    handler = (record[0].handlers + CharacterData).view(1)[0];
    result = call_with_frame(CharacterData, handler, args, instance);
    fields(instance).view(1)[0].in_callback = 0;
    jacpy_release(args);
    if not result {
        flag_error(instance);
        XML_SetCharacterDataHandler(
            fields(instance).view(1)[0].itself, noop_character_data_handler
        );
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

def:priv flush_character_buffer(instance: ptr[PyObject]) -> i32 {
    record = fields(instance).view(1);
    if not record[0].buffer or record[0].buffer_used == 0 {
        return i32(0);
    }
    status = call_character_handler(instance, record[0].buffer, record[0].buffer_used);
    fields(instance).view(1)[0].buffer_used = 0;
    return status;
}

def:priv my_CharacterDataHandler(user_data: ptr, data: ptr[u8], size: i32) {
    instance = ptr[PyObject](user_data);
    if PyErr_Occurred() {
        return;
    }
    record = fields(instance).view(1);
    if not record[0].buffer {
        call_character_handler(instance, data, size);
        return;
    }
    if size > record[0].buffer_size - record[0].buffer_used {
        if flush_character_buffer(instance) < 0 {
            return;
        }
        # The handler may have gone; the rest is dropped then.
        if not have_handler(instance, CharacterData) {
            return;
        }
    }
    record = fields(instance).view(1);
    if size > record[0].buffer_size {
        call_character_handler(instance, data, size);
        fields(instance).view(1)[0].buffer_used = 0;
    } else {
        jacpy_memory_copy(
            ptr(record[0].buffer + record[0].buffer_used), ptr(data), i64(size)
        );
        record[0].buffer_used = record[0].buffer_used + size;
    }
}

# The start of each RC_HANDLER: a handler is set, no error is pending and
# the buffered character data went out.
def:priv ready(instance: ptr[PyObject], index: int) -> bool {
    if not have_handler(instance, index) {
        return False;
    }
    if PyErr_Occurred() {
        return False;
    }
    return flush_character_buffer(instance) >= 0;
}

# The rest of an RC_HANDLER: call the handler with `args` (owned); its
# result, or NULL once the error is flagged.
def:priv dispatch(
    instance: ptr[PyObject], index: int, args: ptr[PyObject]
) -> ptr[PyObject] {
    if not args {
        flag_error(instance);
        return NULL;
    }
    record = fields(instance).view(1);
    record[0].in_callback = 1;
    handler = (record[0].handlers + index).view(1)[0];
    result = call_with_frame(index, handler, args, instance);
    fields(instance).view(1)[0].in_callback = 0;
    jacpy_release(args);
    if not result {
        flag_error(instance);
    }
    return result;
}

def:priv void_handler(instance: ptr[PyObject], index: int, args: ptr[PyObject]) {
    jacpy_release(dispatch(instance, index, args));
}

def:priv my_StartElementHandler(user_data: ptr, name: ptr[u8], atts: ptr[ptr[u8]]) {
    instance = ptr[PyObject](user_data);
    if not have_handler(instance, StartElement) {
        return;
    }
    if PyErr_Occurred() {
        return;
    }
    if flush_character_buffer(instance) < 0 {
        return;
    }
    record = fields(instance).view(1);
    # max: the number of atts slots filled; max / 2 attributes.
    count = 0;
    if record[0].specified_attributes {
        count = int(XML_GetSpecifiedAttributeCount(record[0].itself));
    } else {
        while (atts + count).view(1)[0] {
            count += 2;
        }
    }
    ordered = bool(record[0].ordered_attributes);
    container = PyList_New(i64(count)) if ordered else PyDict_New();
    if not container {
        flag_error(instance);
        return;
    }
    index = 0;
    while index < count {
        key = string_intern(instance, (atts + index).view(1)[0]);
        if not key {
            flag_error(instance);
            jacpy_release(container);
            return;
        }
        value = conv_string_to_unicode((atts + index + 1).view(1)[0]);
        if not value {
            flag_error(instance);
            jacpy_release(container);
            jacpy_release(key);
            return;
        }
        if ordered {
            PyList_SetItem(container, i64(index), key);
            PyList_SetItem(container, i64(index + 1), value);
        } elif PyDict_SetItem(container, key, value) != 0 {
            flag_error(instance);
            jacpy_release(key);
            jacpy_release(value);
            jacpy_release(container);
            return;
        } else {
            jacpy_release(key);
            jacpy_release(value);
        }
        index += 2;
    }
    tag = string_intern(instance, name);
    if not tag {
        jacpy_release(container);
        return;
    }
    args = owned_tuple([tag, container]);
    if not args {
        return;
    }
    record = fields(instance).view(1);
    record[0].in_callback = 1;
    handler = (record[0].handlers + StartElement).view(1)[0];
    result = call_with_frame(StartElement, handler, args, instance);
    fields(instance).view(1)[0].in_callback = 0;
    jacpy_release(args);
    if not result {
        flag_error(instance);
        return;
    }
    jacpy_release(result);
}

def:priv my_EndElementHandler(user_data: ptr, name: ptr[u8]) {
    instance = ptr[PyObject](user_data);
    if ready(instance, EndElement) {
        void_handler(
            instance, EndElement, owned_tuple([string_intern(instance, name)])
        );
    }
}

def:priv my_ProcessingInstructionHandler(
    user_data: ptr, target: ptr[u8], data: ptr[u8]
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, ProcessingInstruction) {
        void_handler(
            instance,
            ProcessingInstruction,
            owned_tuple([string_intern(instance, target), conv_string_to_unicode(data)])
        );
    }
}

def:priv my_UnparsedEntityDeclHandler(
    user_data: ptr,
    entity_name: ptr[u8],
    base: ptr[u8],
    system_id: ptr[u8],
    public_id: ptr[u8],
    notation_name: ptr[u8]
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, UnparsedEntityDecl) {
        void_handler(
            instance,
            UnparsedEntityDecl,
            owned_tuple(
                [
                    string_intern(instance, entity_name),
                    string_intern(instance, base),
                    string_intern(instance, system_id),
                    string_intern(instance, public_id),
                    string_intern(instance, notation_name)
                ]
            )
        );
    }
}

def:priv my_EntityDeclHandler(
    user_data: ptr,
    entity_name: ptr[u8],
    is_parameter_entity: i32,
    value: ptr[u8],
    value_length: i32,
    base: ptr[u8],
    system_id: ptr[u8],
    public_id: ptr[u8],
    notation_name: ptr[u8]
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, EntityDecl) {
        void_handler(
            instance,
            EntityDecl,
            owned_tuple(
                [
                    string_intern(instance, entity_name),
                    PyLong_FromLong(i64(is_parameter_entity)),
                    conv_string_len_to_unicode(value, value_length),
                    string_intern(instance, base),
                    string_intern(instance, system_id),
                    string_intern(instance, public_id),
                    string_intern(instance, notation_name)
                ]
            )
        );
    }
}

def:priv my_XmlDeclHandler(
    user_data: ptr, version: ptr[u8], encoding: ptr[u8], standalone: i32
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, XmlDecl) {
        void_handler(
            instance,
            XmlDecl,
            owned_tuple(
                [
                    conv_string_to_unicode(version),
                    conv_string_to_unicode(encoding),
                    PyLong_FromLong(i64(standalone))
                ]
            )
        );
    }
}

# conv_content_model(): (type, quant, name, children) for a content model.
def:priv conv_content_model(model: ptr[XML_Content]) -> ptr[PyObject] {
    if jacpy_recursion_enter(" in conv_content_model") != 0 {
        return NULL;
    }
    content = model.view(1);
    result: ptr[PyObject] = NULL;
    children = PyTuple_New(i64(content[0].numchildren));
    if children {
        complete = True;
        for index in range(int(content[0].numchildren)) {
            child = conv_content_model(content[0].children + index);
            if not child {
                jacpy_release(children);
                complete = False;
                break;
            }
            jacpy_tuple_set_owned(children, i64(index), child);
        }
        if complete {
            result = owned_tuple(
                [
                    PyLong_FromLong(i64(content[0].content_type)),
                    PyLong_FromLong(i64(content[0].quant)),
                    conv_string_to_unicode(content[0].name),
                    children
                ]
            );
        }
    }
    Py_LeaveRecursiveCall();
    return result;
}

def:priv my_ElementDeclHandler(user_data: ptr, name: ptr[u8], model: ptr[XML_Content]) {
    instance = ptr[PyObject](user_data);
    args: ptr[PyObject] = NULL;
    if have_handler(instance, ElementDecl) {
        if not PyErr_Occurred() and flush_character_buffer(instance) >= 0 {
            modelobj = conv_content_model(model);
            if not modelobj {
                flag_error(instance);
            } else {
                nameobj = string_intern(instance, name);
                if not nameobj {
                    jacpy_release(modelobj);
                    flag_error(instance);
                } else {
                    args = owned_tuple([nameobj, modelobj]);
                    if not args {
                        flag_error(instance);
                    } else {
                        record = fields(instance).view(1);
                        record[0].in_callback = 1;
                        handler = (record[0].handlers + ElementDecl).view(1)[0];
                        result = call_with_frame(ElementDecl, handler, args, instance);
                        fields(instance).view(1)[0].in_callback = 0;
                        if not result {
                            flag_error(instance);
                        } else {
                            jacpy_release(result);
                        }
                    }
                }
            }
        }
    }
    jacpy_release(args);
    XML_FreeContentModel(fields(instance).view(1)[0].itself, model);
}

def:priv my_AttlistDeclHandler(
    user_data: ptr,
    elname: ptr[u8],
    attname: ptr[u8],
    att_type: ptr[u8],
    dflt: ptr[u8],
    isrequired: i32
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, AttlistDecl) {
        void_handler(
            instance,
            AttlistDecl,
            owned_tuple(
                [
                    string_intern(instance, elname),
                    string_intern(instance, attname),
                    conv_string_to_unicode(att_type),
                    conv_string_to_unicode(dflt),
                    PyLong_FromLong(i64(isrequired))
                ]
            )
        );
    }
}

def:priv my_SkippedEntityHandler(
    user_data: ptr, entity_name: ptr[u8], is_parameter_entity: i32
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, SkippedEntity) {
        void_handler(
            instance,
            SkippedEntity,
            owned_tuple(
                [
                    string_intern(instance, entity_name),
                    PyLong_FromLong(i64(is_parameter_entity))
                ]
            )
        );
    }
}

def:priv my_NotationDeclHandler(
    user_data: ptr,
    notation_name: ptr[u8],
    base: ptr[u8],
    system_id: ptr[u8],
    public_id: ptr[u8]
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, NotationDecl) {
        void_handler(
            instance,
            NotationDecl,
            owned_tuple(
                [
                    string_intern(instance, notation_name),
                    string_intern(instance, base),
                    string_intern(instance, system_id),
                    string_intern(instance, public_id)
                ]
            )
        );
    }
}

def:priv my_StartNamespaceDeclHandler(user_data: ptr, prefix: ptr[u8], uri: ptr[u8]) {
    instance = ptr[PyObject](user_data);
    if ready(instance, StartNamespaceDecl) {
        void_handler(
            instance,
            StartNamespaceDecl,
            owned_tuple([string_intern(instance, prefix), string_intern(instance, uri)])
        );
    }
}

def:priv my_EndNamespaceDeclHandler(user_data: ptr, prefix: ptr[u8]) {
    instance = ptr[PyObject](user_data);
    if ready(instance, EndNamespaceDecl) {
        void_handler(
            instance, EndNamespaceDecl, owned_tuple([string_intern(instance, prefix)])
        );
    }
}

def:priv my_CommentHandler(user_data: ptr, data: ptr[u8]) {
    instance = ptr[PyObject](user_data);
    if ready(instance, Comment) {
        void_handler(instance, Comment, owned_tuple([conv_string_to_unicode(data)]));
    }
}

def:priv my_StartCdataSectionHandler(user_data: ptr) {
    instance = ptr[PyObject](user_data);
    if ready(instance, StartCdataSection) {
        void_handler(instance, StartCdataSection, PyTuple_New(0));
    }
}

def:priv my_EndCdataSectionHandler(user_data: ptr) {
    instance = ptr[PyObject](user_data);
    if ready(instance, EndCdataSection) {
        void_handler(instance, EndCdataSection, PyTuple_New(0));
    }
}

def:priv my_DefaultHandler(user_data: ptr, text: ptr[u8], size: i32) {
    instance = ptr[PyObject](user_data);
    if ready(instance, Default) {
        void_handler(
            instance, Default, owned_tuple([conv_string_len_to_unicode(text, size)])
        );
    }
}

def:priv my_DefaultHandlerExpandHandler(user_data: ptr, text: ptr[u8], size: i32) {
    instance = ptr[PyObject](user_data);
    if ready(instance, DefaultHandlerExpand) {
        void_handler(
            instance,
            DefaultHandlerExpand,
            owned_tuple([conv_string_len_to_unicode(text, size)])
        );
    }
}

# INT_HANDLER: the handler's result as a C long, truncated to int.
def:priv int_result(result: ptr[PyObject]) -> i32 {
    if not result {
        return i32(0);
    }
    code = i32.wrap(PyLong_AsLong(result));
    jacpy_release(result);
    return code;
}

def:priv my_NotStandaloneHandler(user_data: ptr) -> i32 {
    instance = ptr[PyObject](user_data);
    if not ready(instance, NotStandalone) {
        return i32(0);
    }
    return int_result(dispatch(instance, NotStandalone, PyTuple_New(0)));
}

def:priv my_ExternalEntityRefHandler(
    parser: ptr, context: ptr[u8], base: ptr[u8], system_id: ptr[u8], public_id: ptr[u8]
) -> i32 {
    # XML_GetUserData(): the first field of the parser.
    instance = ptr[PyObject](ptr[ptr](parser).view(1)[0]);
    if not ready(instance, ExternalEntityRef) {
        return i32(0);
    }
    return int_result(
        dispatch(
            instance,
            ExternalEntityRef,
            owned_tuple(
                [
                    conv_string_to_unicode(context),
                    string_intern(instance, base),
                    string_intern(instance, system_id),
                    string_intern(instance, public_id)
                ]
            )
        )
    );
}

def:priv my_StartDoctypeDeclHandler(
    user_data: ptr,
    doctype_name: ptr[u8],
    sysid: ptr[u8],
    pubid: ptr[u8],
    has_internal_subset: i32
) {
    instance = ptr[PyObject](user_data);
    if ready(instance, StartDoctypeDecl) {
        void_handler(
            instance,
            StartDoctypeDecl,
            owned_tuple(
                [
                    string_intern(instance, doctype_name),
                    string_intern(instance, sysid),
                    string_intern(instance, pubid),
                    PyLong_FromLong(i64(has_internal_subset))
                ]
            )
        );
    }
}

def:priv my_EndDoctypeDeclHandler(user_data: ptr) {
    instance = ptr[PyObject](user_data);
    if ready(instance, EndDoctypeDecl) {
        void_handler(instance, EndDoctypeDecl, PyTuple_New(0));
    }
}

# CALL_XML_HANDLER_SETTER(): install the handler `index` dispatches to, or
# none, or (character data only) the no-op one.
def:priv install_handler(parser: ptr, index: int, mode: int) {
    on = mode == HANDLER_ON;
    if index == StartElement {
        if on {
            XML_SetStartElementHandler(parser, my_StartElementHandler);
        } else {
            XML_SetStartElementHandler(parser, 0);
        }
    } elif index == EndElement {
        if on {
            XML_SetEndElementHandler(parser, my_EndElementHandler);
        } else {
            XML_SetEndElementHandler(parser, 0);
        }
    } elif index == ProcessingInstruction {
        if on {
            XML_SetProcessingInstructionHandler(
                parser, my_ProcessingInstructionHandler
            );
        } else {
            XML_SetProcessingInstructionHandler(parser, 0);
        }
    } elif index == CharacterData {
        if on {
            XML_SetCharacterDataHandler(parser, my_CharacterDataHandler);
        } elif mode == HANDLER_NOOP {
            XML_SetCharacterDataHandler(parser, noop_character_data_handler);
        } else {
            XML_SetCharacterDataHandler(parser, 0);
        }
    } elif index == UnparsedEntityDecl {
        if on {
            XML_SetUnparsedEntityDeclHandler(parser, my_UnparsedEntityDeclHandler);
        } else {
            XML_SetUnparsedEntityDeclHandler(parser, 0);
        }
    } elif index == NotationDecl {
        if on {
            XML_SetNotationDeclHandler(parser, my_NotationDeclHandler);
        } else {
            XML_SetNotationDeclHandler(parser, 0);
        }
    } elif index == StartNamespaceDecl {
        if on {
            XML_SetStartNamespaceDeclHandler(parser, my_StartNamespaceDeclHandler);
        } else {
            XML_SetStartNamespaceDeclHandler(parser, 0);
        }
    } elif index == EndNamespaceDecl {
        if on {
            XML_SetEndNamespaceDeclHandler(parser, my_EndNamespaceDeclHandler);
        } else {
            XML_SetEndNamespaceDeclHandler(parser, 0);
        }
    } elif index == Comment {
        if on {
            XML_SetCommentHandler(parser, my_CommentHandler);
        } else {
            XML_SetCommentHandler(parser, 0);
        }
    } elif index == StartCdataSection {
        if on {
            XML_SetStartCdataSectionHandler(parser, my_StartCdataSectionHandler);
        } else {
            XML_SetStartCdataSectionHandler(parser, 0);
        }
    } elif index == EndCdataSection {
        if on {
            XML_SetEndCdataSectionHandler(parser, my_EndCdataSectionHandler);
        } else {
            XML_SetEndCdataSectionHandler(parser, 0);
        }
    } elif index == Default {
        if on {
            XML_SetDefaultHandler(parser, my_DefaultHandler);
        } else {
            XML_SetDefaultHandler(parser, 0);
        }
    } elif index == DefaultHandlerExpand {
        if on {
            XML_SetDefaultHandlerExpand(parser, my_DefaultHandlerExpandHandler);
        } else {
            XML_SetDefaultHandlerExpand(parser, 0);
        }
    } elif index == NotStandalone {
        if on {
            XML_SetNotStandaloneHandler(parser, my_NotStandaloneHandler);
        } else {
            XML_SetNotStandaloneHandler(parser, 0);
        }
    } elif index == ExternalEntityRef {
        if on {
            XML_SetExternalEntityRefHandler(parser, my_ExternalEntityRefHandler);
        } else {
            XML_SetExternalEntityRefHandler(parser, 0);
        }
    } elif index == StartDoctypeDecl {
        if on {
            XML_SetStartDoctypeDeclHandler(parser, my_StartDoctypeDeclHandler);
        } else {
            XML_SetStartDoctypeDeclHandler(parser, 0);
        }
    } elif index == EndDoctypeDecl {
        if on {
            XML_SetEndDoctypeDeclHandler(parser, my_EndDoctypeDeclHandler);
        } else {
            XML_SetEndDoctypeDeclHandler(parser, 0);
        }
    } elif index == EntityDecl {
        if on {
            XML_SetEntityDeclHandler(parser, my_EntityDeclHandler);
        } else {
            XML_SetEntityDeclHandler(parser, 0);
        }
    } elif index == XmlDecl {
        if on {
            XML_SetXmlDeclHandler(parser, my_XmlDeclHandler);
        } else {
            XML_SetXmlDeclHandler(parser, 0);
        }
    } elif index == ElementDecl {
        if on {
            XML_SetElementDeclHandler(parser, my_ElementDeclHandler);
        } else {
            XML_SetElementDeclHandler(parser, 0);
        }
    } elif index == AttlistDecl {
        if on {
            XML_SetAttlistDeclHandler(parser, my_AttlistDeclHandler);
        } else {
            XML_SetAttlistDeclHandler(parser, 0);
        }
    } elif index == SkippedEntity {
        if on {
            XML_SetSkippedEntityHandler(parser, my_SkippedEntityHandler);
        } else {
            XML_SetSkippedEntityHandler(parser, 0);
        }
    }
}

# clear_handlers(): `initial` only empties a fresh table.
def:priv clear_handlers(instance: ptr[PyObject], initial: bool) {
    record = fields(instance).view(1);
    handlers = record[0].handlers;
    if not handlers {
        return;
    }
    for index in range(HANDLER_COUNT) {
        slot = (handlers + index).view(1);
        if initial {
            slot[0] = NULL;
        } else {
            old = slot[0];
            slot[0] = NULL;
            jacpy_release(old);
            install_handler(fields(instance).view(1)[0].itself, index, HANDLER_OFF);
        }
    }
}

# --------------------------------------------------------- xmlparser methods

def:priv get_parse_result(
    state: PyexpatState, instance: ptr[PyObject], status: i32
) -> ptr[PyObject] {
    if PyErr_Occurred() {
        return NULL;
    }
    if status == 0 {
        return set_error(
            state, instance, XML_GetErrorCode(fields(instance).view(1)[0].itself)
        );
    }
    if flush_character_buffer(instance) < 0 {
        return NULL;
    }
    return PyLong_FromLong(i64(status));
}

def pyexpat_xmlparser_SetReparseDeferralEnabled_impl(
    receiver: ptr[PyObject], enabled: bool
) -> ptr[PyObject] {
    record = fields(receiver).view(1);
    XML_SetReparseDeferralEnabled(record[0].itself, XML_TRUE if enabled else XML_FALSE);
    fields(receiver).view(1)[0].reparse_deferral_enabled = i32(1)
        if enabled
        else i32(0);
    return Py_NewRef(Py_None);
}

def pyexpat_xmlparser_GetReparseDeferralEnabled_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(fields(receiver).view(1)[0].reparse_deferral_enabled));
}

def pyexpat_xmlparser_Parse_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], data: ptr[PyObject], isfinal: bool
) -> ptr[PyObject] {
    state = state_of_class(cls);
    view = BufferArgument();
    exported = False;
    text = ptr[u8]();
    size = i64(0);
    if jacpy_is_unicode(data) {
        text = PyUnicode_AsUTF8AndSize(data, &mut size);
        if not text {
            return NULL;
        }
        # Explicitly set UTF-8 encoding; the result is ignored.
        XML_SetEncoding(fields(receiver).view(1)[0].itself, utf8_name.get());
    } else {
        if not view.export(data, 0) {
            return NULL;
        }
        exported = True;
        text = ptr[u8](view.address());
        size = view.size();
    }
    status = i32(0);
    stopped = False;
    while size > MAX_CHUNK_SIZE {
        status = XML_Parse(
            fields(receiver).view(1)[0].itself, text, i32(MAX_CHUNK_SIZE), i32(0)
        );
        if not status {
            stopped = True;
            break;
        }
        text = text + MAX_CHUNK_SIZE;
        size -= MAX_CHUNK_SIZE;
    }
    if not stopped {
        status = XML_Parse(
            fields(receiver).view(1)[0].itself, text, i32(size), i32(isfinal)
        );
    }
    if exported {
        view.close();
    }
    return get_parse_result(state, receiver, status);
}

# readinst(): read up to `size` bytes into `buffer`; the count, or -1.
def:priv readinst(buffer: ptr, size: i32, method: ptr[PyObject]) -> i32 {
    data = PyObject_CallFunction(method, "i", size);
    if not data {
        return i32(-1);
    }
    source = ptr[u8]();
    if jacpy_is_bytes(data) {
        source = PyBytes_AsString(data);
    } elif jacpy_is_bytearray(data) {
        source = PyByteArray_AsString(data);
    } else {
        object_error(
            PyExc_TypeError,
            "read() did not return a bytes object (type=" + type_name(data)[:400] + ")"
        );
        jacpy_release(data);
        return i32(-1);
    }
    length = jacpy_bytes_length(data);
    if length > i64(size) {
        object_error(
            PyExc_ValueError,
            f"read() returned too much data: {size} bytes requested, {length} returned"
        );
        jacpy_release(data);
        return i32(-1);
    }
    jacpy_memory_copy(buffer, ptr(source), length);
    jacpy_release(data);
    return i32(length);
}

def pyexpat_xmlparser_ParseFile_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_of_class(cls);
    method: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(file, state.str_read, &mut method) < 0 {
        return NULL;
    }
    if not method {
        object_error(PyExc_TypeError, "argument must have 'read' attribute");
        return NULL;
    }
    status = i32(1);
    while True {
        buffer = XML_GetBuffer(fields(receiver).view(1)[0].itself, i32(BUF_SIZE));
        if not buffer {
            jacpy_release(method);
            return get_parse_result(state, receiver, i32(0));
        }
        count = readinst(buffer, i32(BUF_SIZE), method);
        if count < 0 {
            jacpy_release(method);
            return NULL;
        }
        status = XML_ParseBuffer(
            fields(receiver).view(1)[0].itself, count, i32(count == 0)
        );
        if PyErr_Occurred() {
            jacpy_release(method);
            return NULL;
        }
        if not status or count == 0 {
            break;
        }
    }
    jacpy_release(method);
    return get_parse_result(state, receiver, status);
}

def pyexpat_xmlparser_SetBase_impl(
    receiver: ptr[PyObject], base: str
) -> ptr[PyObject] {
    if not XML_SetBase(fields(receiver).view(1)[0].itself, base) {
        return PyErr_NoMemory();
    }
    return Py_NewRef(Py_None);
}

def pyexpat_xmlparser_GetBase_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return conv_string_to_unicode(XML_GetBase(fields(receiver).view(1)[0].itself));
}

def pyexpat_xmlparser_GetInputContext_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    record = fields(receiver).view(1);
    if record[0].in_callback {
        offset = i32(0);
        size = i32(0);
        buffer = XML_GetInputContext(record[0].itself, &mut offset, &mut size);
        if buffer {
            return jacpy_bytes_from_memory(ptr(buffer + offset), i64(size - offset));
        }
    }
    return Py_NewRef(Py_None);
}

def pyexpat_xmlparser_ExternalEntityParserCreate_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], context: ptr[u8], encoding: ptr[u8]
) -> ptr[PyObject] {
    state = state_of_class(cls);
    created = jacpy_binding_allocate(state.xml_parse_type);
    if not created {
        return NULL;
    }
    source = fields(receiver).view(1);
    record = fields(created).view(1);
    record[0].buffer_size = source[0].buffer_size;
    record[0].buffer_used = 0;
    record[0].buffer = ptr[u8]();
    record[0].ordered_attributes = source[0].ordered_attributes;
    record[0].specified_attributes = source[0].specified_attributes;
    record[0].in_callback = 0;
    record[0].ns_prefixes = source[0].ns_prefixes;
    record[0].itself = XML_ExternalEntityParserCreate(
        source[0].itself, context, encoding
    );
    # The subparser uses the parent's XML_Parser inside Expat, so it keeps
    # the parent object alive.
    record[0].parent = Py_NewRef(receiver);
    record[0].handlers = ptr[ptr[PyObject]]();
    record[0].intern = Py_NewRef(source[0].intern) if source[0].intern else NULL;
    if source[0].buffer {
        record[0].buffer = ptr[u8](PyMem_Malloc(u64(record[0].buffer_size)));
        if not record[0].buffer {
            jacpy_release(created);
            return PyErr_NoMemory();
        }
    }
    if not record[0].itself {
        jacpy_release(created);
        return PyErr_NoMemory();
    }
    XML_SetUserData(record[0].itself, ptr(created));
    handlers = ptr[ptr[PyObject]](PyMem_Malloc(u64(HANDLER_COUNT * 8)));
    if not handlers {
        jacpy_release(created);
        return PyErr_NoMemory();
    }
    fields(created).view(1)[0].handlers = handlers;
    clear_handlers(created, True);
    parent_handlers = fields(receiver).view(1)[0].handlers;
    for index in range(HANDLER_COUNT) {
        handler = (parent_handlers + index).view(1)[0];
        if handler {
            (handlers + index).view(1)[0] = Py_NewRef(handler);
            install_handler(fields(created).view(1)[0].itself, index, HANDLER_ON);
        }
    }
    return created;
}

def pyexpat_xmlparser_SetParamEntityParsing_impl(
    receiver: ptr[PyObject], flag: i32
) -> ptr[PyObject] {
    result = XML_SetParamEntityParsing(fields(receiver).view(1)[0].itself, flag);
    return PyLong_FromLong(i64(result));
}

def pyexpat_xmlparser_UseForeignDTD_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], flag: bool
) -> ptr[PyObject] {
    state = state_of_class(cls);
    code = XML_UseForeignDTD(
        fields(receiver).view(1)[0].itself, XML_TRUE if flag else XML_FALSE
    );
    if code != XML_ERROR_NONE {
        return set_error(state, receiver, code);
    }
    return Py_NewRef(Py_None);
}

# set_activation_threshold(): the setter fails only for a non-root parser.
def:priv activation_threshold_result(
    receiver: ptr[PyObject], cls: ptr[PyObject], accepted: u8
) -> ptr[PyObject] {
    if accepted == XML_TRUE {
        return Py_NewRef(Py_None);
    }
    return set_invalid_arg(
        state_of_class(cls), receiver, "parser must be a root parser"
    );
}

# set_maximum_amplification(): Expat does not say which check failed, so an
# out-of-range factor is named before the parser kind.
def:priv maximum_amplification_result(
    receiver: ptr[PyObject], cls: ptr[PyObject], max_factor: f32, accepted: u8
) -> ptr[PyObject] {
    if accepted == XML_TRUE {
        return Py_NewRef(Py_None);
    }
    message = "'max_factor' must be at least 1.0"
        if max_factor != max_factor or max_factor < f32(1.0)
        else "parser must be a root parser";
    return set_invalid_arg(state_of_class(cls), receiver, message);
}

def pyexpat_xmlparser_SetBillionLaughsAttackProtectionActivationThreshold_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], threshold: u64
) -> ptr[PyObject] {
    return activation_threshold_result(
        receiver,
        cls,
        XML_SetBillionLaughsAttackProtectionActivationThreshold(
            fields(receiver).view(1)[0].itself, threshold
        )
    );
}

def pyexpat_xmlparser_SetBillionLaughsAttackProtectionMaximumAmplification_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], max_factor: f32
) -> ptr[PyObject] {
    return maximum_amplification_result(
        receiver,
        cls,
        max_factor,
        XML_SetBillionLaughsAttackProtectionMaximumAmplification(
            fields(receiver).view(1)[0].itself, max_factor
        )
    );
}

def pyexpat_xmlparser_SetAllocTrackerActivationThreshold_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], threshold: u64
) -> ptr[PyObject] {
    return activation_threshold_result(
        receiver,
        cls,
        XML_SetAllocTrackerActivationThreshold(
            fields(receiver).view(1)[0].itself, threshold
        )
    );
}

def pyexpat_xmlparser_SetAllocTrackerMaximumAmplification_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], max_factor: f32
) -> ptr[PyObject] {
    return maximum_amplification_result(
        receiver,
        cls,
        max_factor,
        XML_SetAllocTrackerMaximumAmplification(
            fields(receiver).view(1)[0].itself, max_factor
        )
    );
}

# ------------------------------------------------------- unknown encodings

# template_buffer: the bytes 0 to 255.
glob:priv TEMPLATE_BUFFER: bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
         + b"\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f"
         + b"\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f"
         + b"\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f"
         + b"\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f"
         + b"\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f"
         + b"\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f"
         + b"\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f"
         + b"\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f"
         + b"\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f"
         + b"\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf"
         + b"\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf"
         + b"\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf"
         + b"\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf"
         + b"\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef"
         + b"\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";

# PyUnknownEncodingHandler(): a single-byte codec's map, -1 for bytes it
# decodes to U+FFFD. `info` is the XML_Encoding record.
def PyUnknownEncodingHandler(data: ptr, name: ptr[u8], info: ptr[i32]) -> i32 {
    if PyErr_Occurred() {
        return XML_STATUS_ERROR;
    }
    encoding = c_string_text(name);
    if not encoding {
        return XML_STATUS_ERROR;
    }
    decoded = PyUnicode_Decode(TEMPLATE_BUFFER, 256, text_value(encoding), "replace");
    jacpy_release(encoding);
    if not decoded {
        return XML_STATUS_ERROR;
    }
    if PyUnicode_GetLength(decoded) != 256 {
        jacpy_release(decoded);
        object_error(PyExc_ValueError, "multi-byte encodings are not supported");
        return XML_STATUS_ERROR;
    }
    for index in range(256) {
        character = PyUnicode_ReadChar(decoded, i64(index));
        (info + index).view(1)[0] = i32(-1)
            if character == u32(0xFFFD)
            else i32(character);
    }
    # data, convert and release follow the map.
    tail = ptr[ptr](info + 256);
    for index in range(3) {
        (tail + index).view(1)[0] = ptr();
    }
    jacpy_release(decoded);
    return XML_STATUS_OK;
}

# ---------------------------------------------------------- object lifetime

# newxmlparseobject().
def:priv new_xmlparser(
    state: PyexpatState,
    encoding: ptr[u8],
    namespace_separator: ptr[u8],
    intern: ptr[PyObject]
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(state.xml_parse_type);
    if not created {
        return NULL;
    }
    record = fields(created).view(1);
    record[0].buffer = ptr[u8]();
    record[0].buffer_size = i32(CHARACTER_DATA_BUFFER_SIZE);
    record[0].buffer_used = 0;
    record[0].ordered_attributes = 0;
    record[0].specified_attributes = 0;
    record[0].in_callback = 0;
    record[0].ns_prefixes = 0;
    record[0].handlers = ptr[ptr[PyObject]]();
    record[0].intern = Py_NewRef(intern) if intern else NULL;
    record[0].reparse_deferral_enabled = 1;
    # namespace_separator is either NULL or one character.
    record[0].itself = XML_ParserCreate_MM(
        encoding, addressof(expat_memory_suite), namespace_separator
    );
    record[0].parent = NULL;
    if not record[0].itself {
        object_error(PyExc_RuntimeError, "XML_ParserCreate failed");
        jacpy_release(created);
        return NULL;
    }
    XML_SetHashSalt(
        record[0].itself, u64.wrap(addressof(_Py_HashSecret).view(1)[0].expat_hashsalt)
    );
    XML_SetUserData(record[0].itself, ptr(created));
    XML_SetUnknownEncodingHandler(record[0].itself, PyUnknownEncodingHandler, ptr());
    handlers = ptr[ptr[PyObject]](PyMem_Malloc(u64(HANDLER_COUNT * 8)));
    if not handlers {
        jacpy_release(created);
        return PyErr_NoMemory();
    }
    fields(created).view(1)[0].handlers = handlers;
    clear_handlers(created, True);
    return created;
}

def xmlparse_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    record = fields(instance).view(1);
    handlers = record[0].handlers;
    if handlers {
        for index in range(HANDLER_COUNT) {
            status = visit_reference((handlers + index).view(1)[0], visitor, context);
            if status != 0 {
                return status;
            }
        }
    }
    status = visit_reference(record[0].parent, visitor, context);
    if status != 0 {
        return status;
    }
    return visit_reference(Py_TYPE(instance), visitor, context);
}

# xmlparse_clear(): the parent stays until XML_ParserFree() has run, since a
# subparser still uses its parent's XML_Parser.
def xmlparse_clear(instance: ptr[PyObject]) -> i32 {
    clear_handlers(instance, False);
    record = fields(instance).view(1);
    intern = record[0].intern;
    record[0].intern = NULL;
    jacpy_release(intern);
    return i32(0);
}

def xmlparse_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    xmlparse_clear(instance);
    record = fields(instance).view(1);
    if record[0].itself {
        XML_ParserFree(record[0].itself);
    }
    record[0].itself = ptr();
    parent = record[0].parent;
    record[0].parent = NULL;
    jacpy_release(parent);
    record = fields(instance).view(1);
    if record[0].handlers {
        PyMem_Free(ptr(record[0].handlers));
        record[0].handlers = ptr[ptr[PyObject]]();
    }
    if record[0].buffer {
        PyMem_Free(ptr(record[0].buffer));
        record[0].buffer = ptr[u8]();
    }
    jacpy_binding_free(instance);
}

# ---------------------------------------------------------------- getsets

def xmlparse_handler_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    handler = (fields(instance).view(1)[0].handlers + int(context)).view(1)[0];
    return Py_NewRef(handler if handler else Py_None);
}

def xmlparse_handler_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    index = int(context);
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    if index == CharacterData {
        # The cached data goes out with the old handler.
        if flush_character_buffer(instance) < 0 {
            return i32(-1);
        }
    }
    mode = HANDLER_ON;
    stored: ptr[PyObject] = NULL;
    if value == Py_None {
        # With a character data callback active the C handler cannot be
        # removed safely; a no-op replaces it.
        mode = HANDLER_OFF;
        if index == CharacterData and fields(instance).view(1)[0].in_callback {
            mode = HANDLER_NOOP;
        }
    } else {
        stored = Py_NewRef(value);
    }
    slot = (fields(instance).view(1)[0].handlers + index).view(1);
    old = slot[0];
    slot[0] = stored;
    jacpy_release(old);
    install_handler(fields(instance).view(1)[0].itself, index, mode);
    return i32(0);
}

def xmlparse_ErrorCode_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(i64(XML_GetErrorCode(fields(instance).view(1)[0].itself)));
}

def xmlparse_ErrorLineNumber_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(
        i64.wrap(XML_GetCurrentLineNumber(fields(instance).view(1)[0].itself))
    );
}

def xmlparse_ErrorColumnNumber_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(
        i64.wrap(XML_GetCurrentColumnNumber(fields(instance).view(1)[0].itself))
    );
}

def xmlparse_ErrorByteIndex_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(XML_GetCurrentByteIndex(fields(instance).view(1)[0].itself));
}

def xmlparse_buffer_text_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(bool(fields(instance).view(1)[0].buffer)));
}

def xmlparse_buffer_text_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    flag = PyObject_IsTrue(value);
    if flag < 0 {
        return i32(-1);
    }
    record = fields(instance).view(1);
    if flag {
        if not record[0].buffer {
            record[0].buffer = ptr[u8](PyMem_Malloc(u64(record[0].buffer_size)));
            if not record[0].buffer {
                PyErr_NoMemory();
                return i32(-1);
            }
            record[0].buffer_used = 0;
        }
    } elif record[0].buffer {
        if flush_character_buffer(instance) < 0 {
            return i32(-1);
        }
        record = fields(instance).view(1);
        PyMem_Free(ptr(record[0].buffer));
        record[0].buffer = ptr[u8]();
    }
    return i32(0);
}

def xmlparse_buffer_size_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(i64(fields(instance).view(1)[0].buffer_size));
}

def xmlparse_buffer_size_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    if not jacpy_is_long(value) {
        object_error(PyExc_TypeError, "buffer_size must be an integer");
        return i32(-1);
    }
    new_size = PyLong_AsLong(value);
    if new_size <= 0 {
        if not PyErr_Occurred() {
            object_error(PyExc_ValueError, "buffer_size must be greater than zero");
        }
        return i32(-1);
    }
    record = fields(instance).view(1);
    # Trivial case: no change.
    if new_size == i64(record[0].buffer_size) {
        return i32(0);
    }
    if new_size > INT_MAX {
        object_error(
            PyExc_ValueError, f"buffer_size must not be greater than {INT_MAX}"
        );
        return i32(-1);
    }
    if record[0].buffer {
        if record[0].buffer_used != 0 {
            if flush_character_buffer(instance) < 0 {
                return i32(-1);
            }
        }
        PyMem_Free(ptr(fields(instance).view(1)[0].buffer));
    }
    record = fields(instance).view(1);
    record[0].buffer = ptr[u8](PyMem_Malloc(u64(new_size)));
    if not record[0].buffer {
        PyErr_NoMemory();
        return i32(-1);
    }
    record[0].buffer_size = i32(new_size);
    return i32(0);
}

def xmlparse_buffer_used_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(i64(fields(instance).view(1)[0].buffer_used));
}

def xmlparse_namespace_prefixes_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(fields(instance).view(1)[0].ns_prefixes));
}

def xmlparse_namespace_prefixes_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    flag = PyObject_IsTrue(value);
    if flag < 0 {
        return i32(-1);
    }
    record = fields(instance).view(1);
    record[0].ns_prefixes = flag;
    XML_SetReturnNSTriplet(record[0].itself, flag);
    return i32(0);
}

def xmlparse_ordered_attributes_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(fields(instance).view(1)[0].ordered_attributes));
}

def xmlparse_ordered_attributes_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    flag = PyObject_IsTrue(value);
    if flag < 0 {
        return i32(-1);
    }
    fields(instance).view(1)[0].ordered_attributes = flag;
    return i32(0);
}

def xmlparse_specified_attributes_getter(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(fields(instance).view(1)[0].specified_attributes));
}

def xmlparse_specified_attributes_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_RuntimeError, "Cannot delete attribute");
        return i32(-1);
    }
    flag = PyObject_IsTrue(value);
    if flag < 0 {
        return i32(-1);
    }
    fields(instance).view(1)[0].specified_attributes = flag;
    return i32(0);
}

# ------------------------------------------------------- module functions

def pyexpat_ParserCreate_impl(
    module: ptr[PyObject],
    encoding: ptr[u8],
    namespace_separator: ptr[u8],
    intern: ptr[PyObject]
) -> ptr[PyObject] {
    if namespace_separator and strlen(namespace_separator) > 1 {
        object_error(
            PyExc_ValueError,
            "namespace_separator must be at most one character, omitted, or None"
        );
        return NULL;
    }
    # Explicitly passing None means no interning; omitting it, a new dict.
    owned = False;
    if intern == Py_None {
        intern = NULL;
    } elif not intern {
        intern = PyDict_New();
        if not intern {
            return NULL;
        }
        owned = True;
    } elif not jacpy_is_dict(intern) {
        object_error(PyExc_TypeError, "intern must be a dictionary");
        return NULL;
    }
    result = new_xmlparser(module_state(module), encoding, namespace_separator, intern);
    if owned {
        jacpy_release(intern);
    }
    return result;
}

def pyexpat_ErrorString_impl(module: ptr[PyObject], code: i64) -> ptr[PyObject] {
    return conv_string_to_unicode(XML_ErrorString(i32.wrap(code)));
}

# pyexpat_capsule_destructor().
def capsule_destructor(capsule: ptr[PyObject]) {
    address = PyCapsule_GetPointer(capsule, "pyexpat.expat_CAPI");
    if not address {
        PyErr_FormatUnraisable("Exception ignored while destroying pyexact capsule");
        return;
    }
    PyMem_Free(address);
}

# ------------------------------------------------------------ the C API

# The capsule's name and magic outlive every capsule.
glob:priv capsule_name = StaticText(text=PYEXPAT_CAPSULE_NAME),
     utf8_name = StaticText(text="utf-8"),
     capsule_magic = StaticText(text=PYEXPAT_CAPI_MAGIC);

# The pyexpat.expat_CAPI capsule over a PyMem copy of the dispatch table.
# The linked Expat (2.7) predates XML_SetHashSalt16Bytes, so that entry is
# NULL, as in a CPython build against it.
def new_capsule -> ptr[PyObject] {
    name = capsule_name.get();
    magic = capsule_magic.get();
    if not name or not magic {
        return PyErr_NoMemory();
    }
    capi = ptr[PyExpat_CAPI](PyMem_Malloc(u64(PYEXPAT_CAPI_SIZE)));
    if not capi {
        return PyErr_NoMemory();
    }
    (major, minor, micro) = expat_version();
    table = capi.view(1);
    table[0].size = PYEXPAT_CAPI_SIZE;
    table[0].magic = magic;
    table[0].MAJOR_VERSION = i32(major);
    table[0].MINOR_VERSION = i32(minor);
    table[0].MICRO_VERSION = i32(micro);
    table[0].ErrorString = XML_ErrorString;
    table[0].GetErrorCode = XML_GetErrorCode;
    table[0].GetErrorColumnNumber = XML_GetCurrentColumnNumber;
    table[0].GetErrorLineNumber = XML_GetCurrentLineNumber;
    table[0].Parse = XML_Parse;
    table[0].ParserCreate_MM = XML_ParserCreate_MM;
    table[0].ParserFree = XML_ParserFree;
    table[0].SetCharacterDataHandler = XML_SetCharacterDataHandler;
    table[0].SetCommentHandler = XML_SetCommentHandler;
    table[0].SetDefaultHandlerExpand = XML_SetDefaultHandlerExpand;
    table[0].SetElementHandler = XML_SetElementHandler;
    table[0].SetNamespaceDeclHandler = XML_SetNamespaceDeclHandler;
    table[0].SetProcessingInstructionHandler = XML_SetProcessingInstructionHandler;
    table[0].SetUnknownEncodingHandler = XML_SetUnknownEncodingHandler;
    table[0].SetUserData = XML_SetUserData;
    table[0].SetStartDoctypeDeclHandler = XML_SetStartDoctypeDeclHandler;
    table[0].SetEncoding = XML_SetEncoding;
    table[0].DefaultUnknownEncodingHandler = PyUnknownEncodingHandler;
    table[0].SetHashSalt = XML_SetHashSalt;
    table[0].SetHashSalt16Bytes = 0;
    table[0].SetReparseDeferralEnabled = XML_SetReparseDeferralEnabled;
    table[0].SetAllocTrackerActivationThreshold = XML_SetAllocTrackerActivationThreshold;
    table[0].SetAllocTrackerMaximumAmplification = XML_SetAllocTrackerMaximumAmplification;
    table[0].SetBillionLaughsAttackProtectionActivationThreshold = XML_SetBillionLaughsAttackProtectionActivationThreshold;
    table[0].SetBillionLaughsAttackProtectionMaximumAmplification = XML_SetBillionLaughsAttackProtectionMaximumAmplification;
    capsule = PyCapsule_New(ptr(capi), name, capsule_destructor);
    if not capsule {
        PyMem_Free(ptr(capi));
    }
    return capsule;
}

# --------------------------------------------------------- the submodules

# error_info_of: each XML_Error by code (XML_ERROR_NONE is not exposed), with
# the message used when the linked Expat has none for it.
glob ERROR_INFO: list[tuple[str, str]] = [
         ("", ""),
         ("XML_ERROR_NO_MEMORY", "out of memory"),
         ("XML_ERROR_SYNTAX", "syntax error"),
         ("XML_ERROR_NO_ELEMENTS", "no element found"),
         ("XML_ERROR_INVALID_TOKEN", "not well-formed (invalid token)"),
         ("XML_ERROR_UNCLOSED_TOKEN", "unclosed token"),
         ("XML_ERROR_PARTIAL_CHAR", "partial character"),
         ("XML_ERROR_TAG_MISMATCH", "mismatched tag"),
         ("XML_ERROR_DUPLICATE_ATTRIBUTE", "duplicate attribute"),
         ("XML_ERROR_JUNK_AFTER_DOC_ELEMENT", "junk after document element"),
         ("XML_ERROR_PARAM_ENTITY_REF", "illegal parameter entity reference"),
         ("XML_ERROR_UNDEFINED_ENTITY", "undefined entity"),
         ("XML_ERROR_RECURSIVE_ENTITY_REF", "recursive entity reference"),
         ("XML_ERROR_ASYNC_ENTITY", "asynchronous entity"),
         ("XML_ERROR_BAD_CHAR_REF", "reference to invalid character number"),
         ("XML_ERROR_BINARY_ENTITY_REF", "reference to binary entity"),
         (
             "XML_ERROR_ATTRIBUTE_EXTERNAL_ENTITY_REF",
             "reference to external entity in attribute"
         ),
         (
             "XML_ERROR_MISPLACED_XML_PI",
             "XML or text declaration not at start of entity"
         ),
         ("XML_ERROR_UNKNOWN_ENCODING", "unknown encoding"),
         (
             "XML_ERROR_INCORRECT_ENCODING",
             "encoding specified in XML declaration is incorrect"
         ),
         ("XML_ERROR_UNCLOSED_CDATA_SECTION", "unclosed CDATA section"),
         (
             "XML_ERROR_EXTERNAL_ENTITY_HANDLING",
             "error in processing external entity reference"
         ),
         ("XML_ERROR_NOT_STANDALONE", "document is not standalone"),
         (
             "XML_ERROR_UNEXPECTED_STATE",
             "unexpected parser state - please send a bug report"
         ),
         ("XML_ERROR_ENTITY_DECLARED_IN_PE", "entity declared in parameter entity"),
         (
             "XML_ERROR_FEATURE_REQUIRES_XML_DTD",
             "requested feature requires XML_DTD support in Expat"
         ),
         (
             "XML_ERROR_CANT_CHANGE_FEATURE_ONCE_PARSING",
             "cannot change setting once parsing has begun"
         ),
         ("XML_ERROR_UNBOUND_PREFIX", "unbound prefix"),
         ("XML_ERROR_UNDECLARING_PREFIX", "must not undeclare prefix"),
         ("XML_ERROR_INCOMPLETE_PE", "incomplete markup in parameter entity"),
         ("XML_ERROR_XML_DECL", "XML declaration not well-formed"),
         ("XML_ERROR_TEXT_DECL", "text declaration not well-formed"),
         ("XML_ERROR_PUBLICID", "illegal character(s) in public id"),
         ("XML_ERROR_SUSPENDED", "parser suspended"),
         ("XML_ERROR_NOT_SUSPENDED", "parser not suspended"),
         ("XML_ERROR_ABORTED", "parsing aborted"),
         ("XML_ERROR_FINISHED", "parsing finished"),
         ("XML_ERROR_SUSPEND_PE", "cannot suspend in external parameter entity"),
         (
             "XML_ERROR_RESERVED_PREFIX_XML",
             "reserved prefix (xml) must not be undeclared or bound to another namespace name"
         ),
         (
             "XML_ERROR_RESERVED_PREFIX_XMLNS",
             "reserved prefix (xmlns) must not be declared or undeclared"
         ),
         (
             "XML_ERROR_RESERVED_NAMESPACE_URI",
             "prefix must not be bound to one of the reserved namespace names"
         ),
         ("XML_ERROR_INVALID_ARGUMENT", "invalid argument"),
         (
             "XML_ERROR_NO_BUFFER",
             "a successful prior call to function XML_GetBuffer is required"
         ),
         (
             "XML_ERROR_AMPLIFICATION_LIMIT_BREACH",
             "limit on input amplification factor (from DTD and entities) breached"
         ),
         ("XML_ERROR_NOT_STARTED", "parser not started")
     ],
     MODEL_CONSTANTS: list[tuple[str, int]] = [
         ("XML_CTYPE_EMPTY", 1),
         ("XML_CTYPE_ANY", 2),
         ("XML_CTYPE_MIXED", 3),
         ("XML_CTYPE_NAME", 4),
         ("XML_CTYPE_CHOICE", 5),
         ("XML_CTYPE_SEQ", 6),
         ("XML_CQUANT_NONE", 0),
         ("XML_CQUANT_OPT", 1),
         ("XML_CQUANT_REP", 2),
         ("XML_CQUANT_PLUS", 3)
     ];

# add_submodule(): a new module registered in sys.modules and added to
# `module`; it is returned borrowed.
def:priv add_submodule(module: ptr[PyObject], fullname: str) -> ptr[PyObject] {
    name = fullname.split(".")[-1];
    submodule = PyModule_New(fullname);
    if not submodule {
        return NULL;
    }
    key = text_object(fullname);
    if _PyImport_SetModule(key, submodule) < 0 {
        jacpy_release(submodule);
        jacpy_release(key);
        return NULL;
    }
    jacpy_release(key);
    if PyModule_Add(module, name, submodule) < 0 {
        return NULL;
    }
    return submodule;
}

# add_errors_module().
def add_errors_module(module: ptr[PyObject]) -> i32 {
    errors = add_submodule(module, "pyexpat.errors");
    if not errors {
        return i32(-1);
    }
    codes = PyDict_New();
    if not codes {
        return i32(-1);
    }
    messages = PyDict_New();
    if not messages {
        jacpy_release(codes);
        return i32(-1);
    }
    for code in range(1, len(ERROR_INFO)) {
        (name, description) = ERROR_INFO[code];
        # Expat's own text is the source of truth; the copy is a fallback.
        found = XML_ErrorString(i32(code));
        message = c_string_text(found) if found else text_object(description);
        number = PyLong_FromLong(i64(code)) if message else NULL;
        if not message
            or not number
            or PyModule_AddObjectRef(errors, name, message) < 0
            or PyDict_SetItem(codes, message, number) < 0
            or PyDict_SetItem(messages, number, message) < 0 {
            jacpy_release(message);
            jacpy_release(number);
            jacpy_release(codes);
            jacpy_release(messages);
            return i32(-1);
        }
        jacpy_release(message);
        jacpy_release(number);
    }
    if PyModule_AddStringConstant(
        errors, "__doc__", "Constants used to describe error conditions."
    )
        < 0 {
        jacpy_release(codes);
        jacpy_release(messages);
        return i32(-1);
    }
    if PyModule_Add(errors, "codes", codes) < 0 {
        jacpy_release(messages);
        return i32(-1);
    }
    if PyModule_Add(errors, "messages", messages) < 0 {
        return i32(-1);
    }
    return i32(0);
}

# add_model_module().
def add_model_module(module: ptr[PyObject]) -> i32 {
    model = add_submodule(module, "pyexpat.model");
    if not model {
        return i32(-1);
    }
    if PyModule_AddStringConstant(
        model, "__doc__", "Constants used to interpret content model information."
    )
        < 0 {
        return i32(-1);
    }
    for (name, value) in MODEL_CONSTANTS {
        if PyModule_AddIntConstant(model, name, i64(value)) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

# add_features(): (name, value) for each compiled-in Expat feature.
def add_features(module: ptr[PyObject]) -> i32 {
    features = PyList_New(0);
    if not features {
        return i32(-1);
    }
    entry_ptr = XML_GetFeatureList();
    index = 0;
    while (entry_ptr + index).view(1)[0].feature != XML_FEATURE_END {
        feature = (entry_ptr + index).view(1)[0];
        item = owned_tuple(
            [c_string_text(feature.name), PyLong_FromLong(i64(i32.wrap(feature.value)))]
        );
        if not item {
            jacpy_release(features);
            return i32(-1);
        }
        status = PyList_Append(features, item);
        jacpy_release(item);
        if status < 0 {
            jacpy_release(features);
            return i32(-1);
        }
        index += 1;
    }
    return PyModule_Add(module, "features", features);
}

# EXPAT_VERSION and version_info.
def add_version(module: ptr[PyObject]) -> i32 {
    text = c_string_text(XML_ExpatVersion());
    if not text or PyModule_Add(module, "EXPAT_VERSION", text) < 0 {
        return i32(-1);
    }
    (major, minor, micro) = expat_version();
    info = owned_tuple(
        [
            PyLong_FromLong(i64(major)),
            PyLong_FromLong(i64(minor)),
            PyLong_FromLong(i64(micro))
        ]
    );
    return PyModule_Add(module, "version_info", info);
}
