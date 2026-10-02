"""The _elementtree module: the C accelerator for xml.etree.ElementTree.

Derived from CPython 3.14.6 Modules/_elementtree.c; see ../LICENSE.cpython.
Element, the element iterator, TreeBuilder and XMLParser keep their fields in
C records laid out as the C structs are. An element's text and tail are tagged
pointers: the low bit marks a list of fragments the tree builder collected,
joined when read. XMLParser reaches Expat only through the pyexpat.expat_CAPI
capsule, whose handlers call back here with the parser object as user data.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_GetConstant,
    Py_NewRef,
    Py_None,
    Py_ReprEnter,
    Py_ReprLeave,
    Py_TYPE,
    PyBytes_AsString,
    PyBytes_Concat,
    PyBytes_Size,
    PyBytes_Type,
    PyCallable_Check,
    PyDict_Copy,
    PyDict_GetItemStringRef,
    PyDict_GetItemWithError,
    PyDict_Items,
    PyDict_Keys,
    PyDict_New,
    PyDict_Next,
    PyDict_PopString,
    PyDict_SetItem,
    PyDict_Size,
    PyDict_Type,
    PyDict_Update,
    PyErr_ExceptionMatches,
    PyErr_Clear,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetNone,
    PyErr_SetObject,
    PyErr_WarnEx,
    PyExc_AttributeError,
    PyExc_DeprecationWarning,
    PyExc_ImportError,
    PyExc_IndexError,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_RuntimeWarning,
    PyExc_StopIteration,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_SetItem,
    PyList_SetSlice,
    PyList_Size,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    PyNumber_Add,
    PyNumber_AsSsize_t,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallFunctionObjArgs,
    PyObject_CallMethodObjArgs,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_GetAttr,
    PyObject_GetAttrString,
    PyObject_HasAttrWithError,
    PyObject_IsTrue,
    PyObject_RichCompareBool,
    PyObject_SetAttr,
    PyObject_SetAttrString,
    PyObject_Vectorcall,
    PySequence_Fast,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Pack,
    PyTuple_Size,
    PyType_GetModule,
    PyUnicode_AsEncodedString,
    PyUnicode_AsUTF8,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_GetLength,
    PyUnicode_Join,
    PyUnicode_ReadChar,
    PyUnstable_Object_IsUniquelyReferenced,
    Py_LeaveRecursiveCall,
    _Py_HashSecret,
    jacpy_bytes_from_memory,
    jacpy_is_bytes,
    jacpy_is_dict,
    jacpy_is_exact_dict,
    jacpy_is_exact_list,
    jacpy_is_exact_unicode,
    jacpy_is_list,
    jacpy_is_slice,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_recursion_enter,
    jacpy_release,
    jacpy_tuple_set_owned,
    jacpy_type_check,
    jacpy_type_name
}
import from jaclang.runtime.python.object_model.capsule { PyCapsule_GetPointer }
import from jaclang.runtime.python.object_model.slice {
    PySlice_AdjustIndices,
    PySlice_Unpack
}
import from jaclang.runtime.python.capi { StaticText, object_error, text_value }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_basicsize,
    jacpy_binding_free,
    jacpy_binding_owner,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_clear_weakrefs,
    jacpy_binding_untrack
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.members { MemberField }
import from jaclang.runtime.python.bindings.converters { ClassToken, bad_argument }
import from jaclang.runtime.python.modules.expat {
    PyExpat_CAPI,
    XML_ERROR_UNDEFINED_ENTITY,
    XML_FALSE,
    XML_TRUE,
    expat_memory_suite,
    expat_version
}

import from c {
    # ElementObject after its header.
    obj element_record {
        has tag: ptr[PyObject],
            text: ptr[PyObject],
            tail: ptr[PyObject],
            extra: ptr[element_extra];
    }
    # ElementObjectExtra: children points at the four static slots or at a
    # PyMem block.
    obj element_extra {
        has attrib: ptr[PyObject],
            length: i64,
            allocated: i64,
            children: ptr[ptr[PyObject]],
            static0: ptr[PyObject],
            static1: ptr[PyObject],
            static2: ptr[PyObject],
            static3: ptr[PyObject];
    }  obj parent_locator {
        has parent: ptr[PyObject],
            child_index: i64;
    }
    # ElementIterObject after its header.
    obj element_iter_record {
        has parent_stack: ptr[parent_locator],
            parent_stack_used: i64,
            parent_stack_size: i64,
            root_element: ptr[PyObject],
            sought_tag: ptr[PyObject],
            gettext: i32;
    }
    # TreeBuilderObject after its header; `module` (borrowed) stands for its
    # state pointer.
    obj treebuilder_record {
        has root_node: ptr[PyObject],
            current: ptr[PyObject],
            last: ptr[PyObject],
            last_for_tail: ptr[PyObject],
            data: ptr[PyObject],
            stack: ptr[PyObject],
            index: i64,
            element_factory: ptr[PyObject],
            comment_factory: ptr[PyObject],
            pi_factory: ptr[PyObject],
            events_append: ptr[PyObject],
            start_event_obj: ptr[PyObject],
            end_event_obj: ptr[PyObject],
            start_ns_event_obj: ptr[PyObject],
            end_ns_event_obj: ptr[PyObject],
            comment_event_obj: ptr[PyObject],
            pi_event_obj: ptr[PyObject],
            module: ptr[PyObject],
            insert_comments: i32,
            insert_pis: i32;
    }
    # XMLParserObject after its header; target and entity lead for the
    # member descriptors, and the module reference stands for its state.
    obj xmlparser_record {
        has target: ptr[PyObject],
            entity: ptr[PyObject],
            parser: ptr,
            names: ptr[PyObject],
            handle_start_ns: ptr[PyObject],
            handle_end_ns: ptr[PyObject],
            handle_start: ptr[PyObject],
            handle_data: ptr[PyObject],
            handle_end: ptr[PyObject],
            handle_comment: ptr[PyObject],
            handle_pi: ptr[PyObject],
            handle_doctype: ptr[PyObject],
            handle_close: ptr[PyObject],
            elementtree_module: ptr[PyObject];
    }  def strlen(text: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: str
    ) -> i32;  def memmove(target: ptr, source: ptr, size: u64) -> ptr;
}

glob ELEMENT_RECORD_SIZE: int = 32,
     ELEMENT_ITER_RECORD_SIZE: int = 48,
     TREEBUILDER_RECORD_SIZE: int = 152,
     XMLPARSER_RECORD_SIZE: int = 112,
     XMLPARSER_MEMBERS: list[MemberField] = [
         MemberField(name="entity", kind=6, offset=8, readonly=True),
         MemberField(name="target", kind=6, offset=0, readonly=True)
     ];

glob ELEMENT_TYPE_NAME: str = "xml.etree.ElementTree.Element";

glob:priv STATIC_CHILDREN: int = 4,
     # sizeof(ElementObjectExtra), and the offset of its static slots.
     EXTRA_SIZE: int = 64,
     STATIC_OFFSET: int = 32,
     # sizeof(ElementObject) of CPython: the header and five pointers.
     ELEMENT_OBJECT_SIZE: int = 56,
     INIT_PARENT_STACK_SIZE: int = 8,
     INT_MAX: int = 2147483647,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     PY_EQ: i32 = 2,
     PY_CONSTANT_EMPTY_STR: u32 = 7;

# The handle of the module definition, which the binding fills in, so a type
# finds its module as PyType_GetModuleByDef() does.
obj DefinitionHandle {
    has handle: ptr = ptr();
}

glob module_definition = DefinitionHandle(),
     Element_token = ClassToken(),
     ElementIter_token = ClassToken(),
     TreeBuilder_token = ClassToken(),
     XMLParser_token = ClassToken();

glob:priv empty_text = StaticText(text=""),
     utf8_name = StaticText(text="utf-8"),
     namespace_separator = StaticText(text="}");

# elementtreestate.
obj ElementTreeState(NativeState) {
    has parseerror_obj: ptr[PyObject] = NULL,
        deepcopy_obj: ptr[PyObject] = NULL,
        elementpath_obj: ptr[PyObject] = NULL,
        comment_factory: ptr[PyObject] = NULL,
        pi_factory: ptr[PyObject] = NULL,
        str_text: ptr[PyObject] = NULL,
        str_tail: ptr[PyObject] = NULL,
        str_append: ptr[PyObject] = NULL,
        str_find: ptr[PyObject] = NULL,
        str_findtext: ptr[PyObject] = NULL,
        str_findall: ptr[PyObject] = NULL,
        str_iterfind: ptr[PyObject] = NULL,
        str_doctype: ptr[PyObject] = NULL,
        Element_Type: ptr[PyObject] = NULL,
        ElementIter_Type: ptr[PyObject] = NULL,
        TreeBuilder_Type: ptr[PyObject] = NULL,
        XMLParser_Type: ptr[PyObject] = NULL,
        expat_capsule: ptr[PyObject] = NULL,
        expat_capi: ptr[PyExpat_CAPI] = ptr[PyExpat_CAPI]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        for value in [
            self.parseerror_obj,
            self.deepcopy_obj,
            self.elementpath_obj,
            self.comment_factory,
            self.pi_factory,
            self.Element_Type,
            self.ElementIter_Type,
            self.TreeBuilder_Type,
            self.XMLParser_Type,
            self.expat_capsule
        ] {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    def clear {
        references = [
            self.parseerror_obj,
            self.deepcopy_obj,
            self.elementpath_obj,
            self.comment_factory,
            self.pi_factory,
            self.str_append,
            self.str_find,
            self.str_findall,
            self.str_findtext,
            self.str_iterfind,
            self.str_tail,
            self.str_text,
            self.str_doctype,
            self.Element_Type,
            self.ElementIter_Type,
            self.TreeBuilder_Type,
            self.XMLParser_Type,
            self.expat_capsule
        ];
        self.parseerror_obj = NULL;
        self.deepcopy_obj = NULL;
        self.elementpath_obj = NULL;
        self.comment_factory = NULL;
        self.pi_factory = NULL;
        self.str_append = NULL;
        self.str_find = NULL;
        self.str_findall = NULL;
        self.str_findtext = NULL;
        self.str_iterfind = NULL;
        self.str_tail = NULL;
        self.str_text = NULL;
        self.str_doctype = NULL;
        self.Element_Type = NULL;
        self.ElementIter_Type = NULL;
        self.TreeBuilder_Type = NULL;
        self.XMLParser_Type = NULL;
        self.expat_capsule = NULL;
        self.expat_capi = ptr[PyExpat_CAPI]();
        for value in references {
            jacpy_release(value);
        }
    }

    def drop {
        self.clear();
    }
}

def module_state(module: ptr[PyObject]) -> ElementTreeState {
    state = jacpy_binding_module_native_get(module);
    if isinstance(state, ElementTreeState) {
        return state;
    }
    return ElementTreeState();
}

# get_elementtree_state_by_cls(): PyType_GetModuleState(cls).
def:priv state_by_cls(cls: ptr[PyObject]) -> ElementTreeState {
    return module_state(PyType_GetModule(cls));
}

# get_elementtree_state_by_type(): the state of the module defining `type`.
def:priv state_by_type(type: ptr[PyObject]) -> ElementTreeState {
    return module_state(jacpy_binding_owner(type, module_definition.handle));
}

def:priv element(instance: ptr[PyObject]) -> ptr[element_record] {
    return ptr[element_record](jacpy_binding_record(instance, Element_token.handle));
}

def:priv element_iter(instance: ptr[PyObject]) -> ptr[element_iter_record] {
    return ptr[element_iter_record](
        jacpy_binding_record(instance, ElementIter_token.handle)
    );
}

def:priv treebuilder(instance: ptr[PyObject]) -> ptr[treebuilder_record] {
    return ptr[treebuilder_record](
        jacpy_binding_record(instance, TreeBuilder_token.handle)
    );
}

def:priv xmlparser(instance: ptr[PyObject]) -> ptr[xmlparser_record] {
    return ptr[xmlparser_record](
        jacpy_binding_record(instance, XMLParser_token.handle)
    );
}

def:priv is_element(state: ElementTreeState, value: ptr[PyObject]) -> bool {
    return jacpy_type_check(value, state.Element_Type) != 0;
}

# ----------------------------------------------------------------- helpers

# JOIN_GET(), JOIN_OBJ() and JOIN_SET() over a tagged text or tail pointer.
def:priv join_get(value: ptr[PyObject]) -> int {
    return int(value) & 1;
}

def:priv join_obj(value: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](int(value) & ~1);
}

def:priv join_set(value: ptr[PyObject], flag: int) -> ptr[PyObject] {
    return ptr[PyObject](int(join_obj(value)) | flag);
}

# _set_joined_ptr() on an element's text (or tail): store the tagged `value`
# and release the object it replaces.
def:priv set_joined_text(instance: ptr[PyObject], value: ptr[PyObject], tail: bool) {
    record = element(instance).view(1);
    previous = record[0].tail if tail else record[0].text;
    if tail {
        record[0].tail = value;
    } else {
        record[0].text = value;
    }
    jacpy_release(join_obj(previous));
}

# The type's tp_name, cut to `limit` bytes as C's %.<limit>s does.
def:priv type_name_clipped(value: ptr[PyObject], limit: int) -> str {
    name = jacpy_type_name(value);
    if not name {
        PyErr_Clear();
        return "?";
    }
    text = text_value(name);
    jacpy_release(name);
    encoded = text.encode("utf-8", "surrogatepass");
    if len(encoded) <= limit {
        return text;
    }
    return encoded[:limit].decode("utf-8", "replace");
}

def:priv list_join(items: ptr[PyObject]) -> ptr[PyObject] {
    joiner = Py_GetConstant(PY_CONSTANT_EMPTY_STR);
    if not joiner {
        return NULL;
    }
    result = PyUnicode_Join(joiner, items);
    jacpy_release(joiner);
    return result;
}

def:priv is_empty_dict(value: ptr[PyObject]) -> bool {
    return jacpy_is_exact_dict(value) != 0 and PyDict_Size(value) == 0;
}

# PySequence_Fast_GET_SIZE() and PySequence_Fast_GET_ITEM() (borrowed).
def:priv fast_size(sequence: ptr[PyObject]) -> i64 {
    if jacpy_is_list(sequence) != 0 {
        return PyList_Size(sequence);
    }
    return PyTuple_Size(sequence);
}

def:priv fast_item(sequence: ptr[PyObject], index: i64) -> ptr[PyObject] {
    if jacpy_is_list(sequence) != 0 {
        return PyList_GetItem(sequence, index);
    }
    return PyTuple_GetItem(sequence, index);
}

def:priv raise_type_error(value: ptr[PyObject]) {
    object_error(
        PyExc_TypeError,
        "expected an Element, not \"" + type_name_clipped(value, 200) + "\""
    );
}

# The "... takes at least/at most N argument(s) (M given)" of getargs.
def:priv arity_error(fname: str, low: int, high: int, given: int) {
    expected = low if given < low else high;
    bound = "exactly" if low == high else ("at least" if given < low else "at most");
    plural = "" if expected == 1 else "s";
    object_error(
        PyExc_TypeError,
        f"{fname}() takes {bound} {expected} argument{plural} ({given} given)"
    );
}

# ----------------------------------------------------- element extra block

def:priv static_children(extra: ptr[element_extra]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](int(extra) + STATIC_OFFSET);
}

# create_extra(): attrib (may be NULL) is borrowed.
def:priv create_extra(instance: ptr[PyObject], attrib: ptr[PyObject]) -> i32 {
    extra = ptr[element_extra](PyMem_Malloc(u64(EXTRA_SIZE)));
    if not extra {
        PyErr_NoMemory();
        return i32(-1);
    }
    block = extra.view(1);
    block[0].attrib = Py_NewRef(attrib) if attrib else NULL;
    block[0].length = 0;
    block[0].allocated = i64(STATIC_CHILDREN);
    block[0].children = static_children(extra);
    element(instance).view(1)[0].extra = extra;
    return i32(0);
}

def:priv dealloc_extra(extra: ptr[element_extra]) {
    if not extra {
        return;
    }
    block = extra.view(1);
    jacpy_release(block[0].attrib);
    for index in range(int(block[0].length)) {
        jacpy_release((block[0].children + index).view(1)[0]);
    }
    if block[0].children != static_children(extra) {
        PyMem_Free(ptr(block[0].children));
    }
    PyMem_Free(ptr(extra));
}

# clear_extra(): detach first so releases cannot reach it again.
def:priv clear_extra(instance: ptr[PyObject]) {
    record = element(instance).view(1);
    extra = record[0].extra;
    if not extra {
        return;
    }
    record[0].extra = ptr[element_extra]();
    dealloc_extra(extra);
}

def:priv extra_of(instance: ptr[PyObject]) -> ptr[element_extra] {
    return element(instance).view(1)[0].extra;
}

def:priv child_count(instance: ptr[PyObject]) -> i64 {
    extra = extra_of(instance);
    return extra.view(1)[0].length if extra else i64(0);
}

def:priv child_at(instance: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return (extra_of(instance).view(1)[0].children + index).view(1)[0];
}

def:priv set_child(instance: ptr[PyObject], index: i64, value: ptr[PyObject]) {
    (extra_of(instance).view(1)[0].children + index).view(1)[0] = value;
}

# element_resize(): room for `extra` more children, growing as Python 2.4's
# lists did.
def:priv element_resize(instance: ptr[PyObject], more: i64) -> i32 {
    if not extra_of(instance) {
        if create_extra(instance, NULL) < 0 {
            return i32(-1);
        }
    }
    extra = extra_of(instance);
    block = extra.view(1);
    size = block[0].length + more;
    if size > block[0].allocated {
        size = (size >> 3) + (3 if size < 9 else 6) + size;
        # Always room for at least one child.
        size = size or i64(1);
        if size > PY_SSIZE_T_MAX // 8 {
            PyErr_NoMemory();
            return i32(-1);
        }
        children = ptr[ptr[PyObject]]();
        if block[0].children != static_children(extra) {
            children = ptr[ptr[PyObject]](
                PyMem_Realloc(ptr(block[0].children), u64(size * 8))
            );
            if not children {
                PyErr_NoMemory();
                return i32(-1);
            }
        } else {
            children = ptr[ptr[PyObject]](PyMem_Malloc(u64(size * 8)));
            if not children {
                PyErr_NoMemory();
                return i32(-1);
            }
            # Move the children out of the static area.
            jacpy_memory_copy(
                ptr(children), ptr(block[0].children), block[0].length * 8
            );
        }
        block[0].children = children;
        block[0].allocated = size;
    }
    return i32(0);
}

def:priv element_add_subelement(
    state: ElementTreeState, instance: ptr[PyObject], child: ptr[PyObject]
) -> i32 {
    if not is_element(state, child) {
        raise_type_error(child);
        return i32(-1);
    }
    if element_resize(instance, 1) < 0 {
        return i32(-1);
    }
    block = extra_of(instance).view(1);
    (block[0].children + block[0].length).view(1)[0] = Py_NewRef(child);
    block[0].length = block[0].length + 1;
    return i32(0);
}

# element_get_attrib(): the attrib dict (borrowed), made when missing; the
# extra block must exist.
def:priv element_get_attrib(instance: ptr[PyObject]) -> ptr[PyObject] {
    block = extra_of(instance).view(1);
    result = block[0].attrib;
    if not result {
        result = PyDict_New();
        block[0].attrib = result;
    }
    return result;
}

# element_get_text() / element_get_tail(): a new reference, joining a list
# the tree builder collected.
def:priv element_get_text(
    instance: ptr[PyObject], tail: bool = False
) -> ptr[PyObject] {
    record = element(instance).view(1);
    result = record[0].tail if tail else record[0].text;
    if join_get(result) {
        result = join_obj(result);
        if jacpy_is_exact_list(result) != 0 {
            joined = list_join(result);
            if not joined {
                return NULL;
            }
            record = element(instance).view(1);
            if tail {
                record[0].tail = joined;
            } else {
                record[0].text = joined;
            }
            jacpy_release(result);
            result = joined;
        }
    }
    return Py_NewRef(result);
}

# create_new_element(): attrib (may be NULL) is borrowed.
def:priv create_new_element(
    state: ElementTreeState, tag: ptr[PyObject], attrib: ptr[PyObject]
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(state.Element_Type);
    if not created {
        return NULL;
    }
    record = element(created).view(1);
    record[0].extra = ptr[element_extra]();
    record[0].tag = Py_NewRef(tag);
    record[0].text = Py_NewRef(Py_None);
    record[0].tail = Py_NewRef(Py_None);
    if attrib and not is_empty_dict(attrib) {
        if create_extra(created, attrib) < 0 {
            jacpy_release(created);
            return NULL;
        }
    }
    return created;
}

# get_attrib_from_keywords(): kwds merged over its "attrib" entry, which is
# removed from kwds.
def:priv get_attrib_from_keywords(kwds: ptr[PyObject]) -> ptr[PyObject] {
    attrib: ptr[PyObject] = NULL;
    if PyDict_PopString(kwds, "attrib", &mut attrib) < 0 {
        return NULL;
    }
    if attrib {
        if jacpy_is_dict(attrib) == 0 {
            object_error(
                PyExc_TypeError,
                "attrib must be dict, not " + type_name_clipped(attrib, 100)
            );
            jacpy_release(attrib);
            return NULL;
        }
        copied = PyDict_Copy(attrib);
        jacpy_release(attrib);
        attrib = copied;
    } else {
        attrib = PyDict_New();
    }
    if attrib and PyDict_Update(attrib, kwds) < 0 {
        jacpy_release(attrib);
        return NULL;
    }
    return attrib;
}

# The attrib of Element() and SubElement(): a positional dict copied and
# updated from kwds, else the keywords; NULL with no error set means none.
def:priv merged_attrib(attrib: ptr[PyObject], kwds: ptr[PyObject]) -> ptr[PyObject] {
    if attrib {
        copied = PyDict_Copy(attrib);
        if not copied {
            return NULL;
        }
        if kwds and PyDict_Update(copied, kwds) < 0 {
            jacpy_release(copied);
            return NULL;
        }
        return copied;
    }
    if kwds {
        return get_attrib_from_keywords(kwds);
    }
    return NULL;
}

# ------------------------------------------------------------ Element type

def element_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(type);
    if created {
        record = element(created).view(1);
        record[0].tag = Py_NewRef(Py_None);
        record[0].text = Py_NewRef(Py_None);
        record[0].tail = Py_NewRef(Py_None);
        record[0].extra = ptr[element_extra]();
    }
    return created;
}

# element_init(): PyArg_ParseTuple(args, "O|O!:Element", ...).
def element_init(
    instance: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    given = int(PyTuple_Size(args));
    if given < 1 or given > 2 {
        arity_error("Element", 1, 2, given);
        return i32(-1);
    }
    tag = PyTuple_GetItem(args, 0);
    attrib: ptr[PyObject] = NULL;
    if given == 2 {
        attrib = PyTuple_GetItem(args, 1);
        if jacpy_is_dict(attrib) == 0 {
            bad_argument_value("Element", 2, "dict", attrib);
            return i32(-1);
        }
    }
    attrib = merged_attrib(attrib, kwds);
    if not attrib and PyErr_Occurred() {
        return i32(-1);
    }
    if attrib and not is_empty_dict(attrib) {
        if create_extra(instance, attrib) < 0 {
            jacpy_release(attrib);
            return i32(-1);
        }
    }
    # The reference to attrib is no longer needed.
    jacpy_release(attrib);
    # Replace the objects tag, text and tail pointed to.
    record = element(instance).view(1);
    previous = record[0].tag;
    record[0].tag = Py_NewRef(tag);
    jacpy_release(previous);
    set_joined_text(instance, Py_NewRef(Py_None), False);
    set_joined_text(instance, Py_NewRef(Py_None), True);
    return i32(0);
}

# getargs' converterr() message for an O! unit.
def:priv bad_argument_value(
    fname: str, position: int, expected: str, value: ptr[PyObject]
) {
    shown = "None" if value == Py_None else type_name_clipped(value, 50);
    object_error(
        PyExc_TypeError,
        f"{fname}() argument {position} must be {expected}, not {shown}"
    );
}

# SubElement(parent, tag, attrib={}, **extra).
def subelement(
    module: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    given = int(PyTuple_Size(args));
    if given < 2 or given > 3 {
        arity_error("SubElement", 2, 3, given);
        return NULL;
    }
    parent = PyTuple_GetItem(args, 0);
    if not is_element(state, parent) {
        bad_argument_value("SubElement", 1, ELEMENT_TYPE_NAME, parent);
        return NULL;
    }
    tag = PyTuple_GetItem(args, 1);
    attrib: ptr[PyObject] = NULL;
    if given == 3 {
        attrib = PyTuple_GetItem(args, 2);
        if jacpy_is_dict(attrib) == 0 {
            bad_argument_value("SubElement", 3, "dict", attrib);
            return NULL;
        }
    }
    attrib = merged_attrib(attrib, kwds);
    if not attrib and PyErr_Occurred() {
        return NULL;
    }
    created = create_new_element(state, tag, attrib);
    jacpy_release(attrib);
    if not created {
        return NULL;
    }
    if element_add_subelement(state, parent, created) < 0 {
        jacpy_release(created);
        return NULL;
    }
    return created;
}

def element_gc_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    status = visit_reference(Py_TYPE(instance), visitor, context);
    if status != 0 {
        return status;
    }
    record = element(instance).view(1);
    for value in [record[0].tag, join_obj(record[0].text), join_obj(record[0].tail)] {
        status = visit_reference(value, visitor, context);
        if status != 0 {
            return status;
        }
    }
    extra = record[0].extra;
    if extra {
        block = extra.view(1);
        status = visit_reference(block[0].attrib, visitor, context);
        if status != 0 {
            return status;
        }
        for index in range(int(block[0].length)) {
            status = visit_reference(
                (block[0].children + index).view(1)[0], visitor, context
            );
            if status != 0 {
                return status;
            }
        }
    }
    return i32(0);
}

def element_gc_clear(instance: ptr[PyObject]) -> i32 {
    record = element(instance).view(1);
    tag = record[0].tag;
    record[0].tag = NULL;
    jacpy_release(tag);
    record = element(instance).view(1);
    if record[0].text {
        set_joined_text(instance, NULL, False);
    }
    record = element(instance).view(1);
    if record[0].tail {
        set_joined_text(instance, NULL, True);
    }
    # With every reference dropped the extra block goes too.
    clear_extra(instance);
    return i32(0);
}

def element_dealloc(instance: ptr[PyObject]) {
    # bpo-31095: untrack before any callback can run.
    jacpy_binding_untrack(instance);
    jacpy_binding_clear_weakrefs(instance);
    element_gc_clear(instance);
    jacpy_binding_free(instance);
}

def _elementtree_Element_append_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], subelement: ptr[PyObject]
) -> ptr[PyObject] {
    if element_add_subelement(state_by_cls(cls), receiver, subelement) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _elementtree_Element_clear_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    clear_extra(receiver);
    set_joined_text(receiver, Py_NewRef(Py_None), False);
    set_joined_text(receiver, Py_NewRef(Py_None), True);
    return Py_NewRef(Py_None);
}

def _elementtree_Element___copy___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_cls(cls);
    source = element(receiver).view(1);
    attrib = source[0].extra.view(1)[0].attrib if source[0].extra else NULL;
    copied = create_new_element(state, source[0].tag, attrib);
    if not copied {
        return NULL;
    }
    text = element(receiver).view(1)[0].text;
    Py_NewRef(join_obj(text));
    set_joined_text(copied, text, False);
    tail = element(receiver).view(1)[0].tail;
    Py_NewRef(join_obj(tail));
    set_joined_text(copied, tail, True);
    if extra_of(receiver) {
        length = child_count(receiver);
        if element_resize(copied, length) < 0 {
            jacpy_release(copied);
            return NULL;
        }
        for index in range(int(length)) {
            set_child(copied, i64(index), Py_NewRef(child_at(receiver, i64(index))));
        }
        extra_of(copied).view(1)[0].length = length;
    }
    return copied;
}

def _elementtree_Element___deepcopy___impl(
    receiver: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_recursion_enter(" in Element.__deepcopy__") != 0 {
        return NULL;
    }
    result = element_deepcopy(receiver, memo);
    Py_LeaveRecursiveCall();
    return result;
}

def:priv element_deepcopy(
    receiver: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_type(Py_TYPE(receiver));
    # deepcopy() holds a reference to what it copies.
    tag = deepcopy(state, element(receiver).view(1)[0].tag, memo);
    if not tag {
        return NULL;
    }
    attrib: ptr[PyObject] = NULL;
    extra = extra_of(receiver);
    if extra and extra.view(1)[0].attrib {
        attrib = deepcopy(state, extra.view(1)[0].attrib, memo);
        if not attrib {
            jacpy_release(tag);
            return NULL;
        }
    }
    copied = create_new_element(state, tag, attrib);
    jacpy_release(tag);
    jacpy_release(attrib);
    if not copied {
        return NULL;
    }
    source_text = element(receiver).view(1)[0].text;
    text = deepcopy(state, join_obj(source_text), memo);
    if not text {
        jacpy_release(copied);
        return NULL;
    }
    set_joined_text(copied, join_set(text, join_get(source_text)), False);
    source_tail = element(receiver).view(1)[0].tail;
    tail = deepcopy(state, join_obj(source_tail), memo);
    if not tail {
        jacpy_release(copied);
        return NULL;
    }
    set_joined_text(copied, join_set(tail, join_get(source_tail)), True);
    if extra_of(receiver) {
        expected_count = child_count(receiver);
        if element_resize(copied, expected_count) < 0 {
            jacpy_release(copied);
            return NULL;
        }
        index = i64(0);
        while extra_of(receiver) and index < child_count(receiver) {
            child = deepcopy(state, child_at(receiver, index), memo);
            if not child or not is_element(state, child) {
                if child {
                    raise_type_error(child);
                    jacpy_release(child);
                }
                extra_of(copied).view(1)[0].length = index;
                jacpy_release(copied);
                return NULL;
            }
            if extra_of(receiver) and expected_count != child_count(receiver) {
                # The source changed; make room for what is left of it.
                expected_count = child_count(receiver);
                if element_resize(copied, expected_count) < 0 {
                    jacpy_release(child);
                    extra_of(copied).view(1)[0].length = index;
                    jacpy_release(copied);
                    return NULL;
                }
            }
            set_child(copied, index, child);
            index += 1;
        }
        # The source's extra may be gone by now; `index` children were copied.
        extra_of(copied).view(1)[0].length = index;
    }
    # The memo records the copy so deepcopy does not visit it again.
    key = PyLong_FromSsize_t(i64(int(receiver)));
    if not key {
        jacpy_release(copied);
        return NULL;
    }
    status = PyDict_SetItem(memo, key, copied);
    jacpy_release(key);
    if status < 0 {
        jacpy_release(copied);
        return NULL;
    }
    return copied;
}

# deepcopy(): fast paths for None, str, uniquely referenced plain dicts and
# exact elements, else copy.deepcopy().
def:priv deepcopy(
    state: ElementTreeState, value: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    if value == Py_None or jacpy_is_exact_unicode(value) != 0 {
        return Py_NewRef(value);
    }
    if PyUnstable_Object_IsUniquelyReferenced(value) != 0 {
        if jacpy_is_exact_dict(value) != 0 {
            position = i64(0);
            key: ptr[PyObject] = NULL;
            item: ptr[PyObject] = NULL;
            simple = True;
            while PyDict_Next(value, &mut position, &mut key, &mut item) != 0 {
                if jacpy_is_exact_unicode(key) == 0
                    or jacpy_is_exact_unicode(item) == 0 {
                    simple = False;
                    break;
                }
            }
            if simple {
                return PyDict_Copy(value);
            }
        } elif Py_TYPE(value) == state.Element_Type {
            # Its __deepcopy__() can run arbitrary code, so hold it.
            Py_NewRef(value);
            result = _elementtree_Element___deepcopy___impl(value, memo);
            jacpy_release(value);
            return result;
        }
    }
    if not state.deepcopy_obj {
        object_error(PyExc_RuntimeError, "deepcopy helper not found");
        return NULL;
    }
    Py_NewRef(value);
    result = PyObject_CallFunctionObjArgs(state.deepcopy_obj, value, memo, NULL);
    jacpy_release(value);
    return result;
}

def _elementtree_Element___sizeof___impl(receiver: ptr[PyObject]) -> u64 {
    result = u64(jacpy_binding_basicsize(receiver));
    extra = extra_of(receiver);
    if extra {
        result += u64(EXTRA_SIZE);
        block = extra.view(1);
        if block[0].children != static_children(extra) {
            result += u64(block[0].allocated * 8);
        }
    }
    return result;
}

# __getstate__(): the instance dict of the pure-Python Element, so pickles
# are interchangeable between the implementations.
def _elementtree_Element___getstate___impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    count = child_count(receiver);
    children = PyList_New(count);
    if not children {
        return NULL;
    }
    for index in range(int(count)) {
        PyList_SetItem(children, i64(index), Py_NewRef(child_at(receiver, i64(index))));
    }
    attrib: ptr[PyObject] = NULL;
    extra = extra_of(receiver);
    if extra and extra.view(1)[0].attrib {
        attrib = Py_NewRef(extra.view(1)[0].attrib);
    } else {
        attrib = PyDict_New();
        if not attrib {
            jacpy_release(children);
            return NULL;
        }
    }
    record = element(receiver).view(1);
    result = PyDict_New();
    if result {
        entries = [
            ("tag", record[0].tag),
            ("_children", children),
            ("attrib", attrib),
            ("text", join_obj(record[0].text)),
            ("tail", join_obj(record[0].tail))
        ];
        for (name, value) in entries {
            key = PyUnicode_FromString(name);
            if not key or PyDict_SetItem(result, key, value) < 0 {
                jacpy_release(key);
                jacpy_release(result);
                result = NULL;
                break;
            }
            jacpy_release(key);
        }
    }
    jacpy_release(children);
    jacpy_release(attrib);
    return result;
}

def:priv element_setstate_from_attributes(
    state: ElementTreeState,
    instance: ptr[PyObject],
    tag: ptr[PyObject],
    attrib: ptr[PyObject],
    text: ptr[PyObject],
    tail: ptr[PyObject],
    children: ptr[PyObject]
) -> ptr[PyObject] {
    if not tag {
        object_error(PyExc_TypeError, "tag may not be NULL");
        return NULL;
    }
    record = element(instance).view(1);
    previous = record[0].tag;
    record[0].tag = Py_NewRef(tag);
    jacpy_release(previous);
    text = join_set(text, jacpy_is_exact_list(text)) if text else Py_None;
    Py_NewRef(join_obj(text));
    set_joined_text(instance, text, False);
    tail = join_set(tail, jacpy_is_exact_list(tail)) if tail else Py_None;
    Py_NewRef(join_obj(tail));
    set_joined_text(instance, tail, True);
    if not children and not attrib {
        return Py_NewRef(Py_None);
    }
    oldextra = ptr[element_extra]();
    if children {
        if jacpy_is_list(children) == 0 {
            object_error(PyExc_TypeError, "'_children' is not a list");
            return NULL;
        }
        count = PyList_Size(children);
        # (Re-)allocate the extra block, detached so releases cannot reach it.
        oldextra = extra_of(instance);
        element(instance).view(1)[0].extra = ptr[element_extra]();
        if element_resize(instance, count) != 0 {
            clear_extra(instance);
            element(instance).view(1)[0].extra = oldextra;
            return NULL;
        }
        if oldextra {
            extra_of(instance).view(1)[0].attrib = oldextra.view(1)[0].attrib;
            oldextra.view(1)[0].attrib = NULL;
        }
        for index in range(int(count)) {
            child = PyList_GetItem(children, i64(index));
            if not is_element(state, child) {
                raise_type_error(child);
                extra_of(instance).view(1)[0].length = i64(index);
                dealloc_extra(oldextra);
                return NULL;
            }
            set_child(instance, i64(index), Py_NewRef(child));
        }
        extra_of(instance).view(1)[0].length = count;
    } elif element_resize(instance, 0) != 0 {
        return NULL;
    }
    # Stash attrib.
    block = extra_of(instance).view(1);
    previous_attrib = block[0].attrib;
    block[0].attrib = Py_NewRef(attrib) if attrib else NULL;
    jacpy_release(previous_attrib);
    dealloc_extra(oldextra);
    return Py_NewRef(Py_None);
}

# element_setstate_from_Python(): the state dict read as the keyword-only
# arguments tag, attrib, text, tail and _children.
def:priv element_setstate_from_Python(
    state: ElementTreeState, instance: ptr[PyObject], dictionary: ptr[PyObject]
) -> ptr[PyObject] {
    names = ["tag", "attrib", "text", "tail", "_children"];
    values: list[ptr[PyObject]] = [NULL, NULL, NULL, NULL, NULL];
    found = 0;
    failed = False;
    for index in range(len(names)) {
        value: ptr[PyObject] = NULL;
        if PyDict_GetItemStringRef(dictionary, names[index], &mut value) < 0 {
            failed = True;
            break;
        }
        if value {
            values[index] = value;
            found += 1;
        }
    }
    if not failed and found < int(PyDict_Size(dictionary)) {
        # An extraneous keyword argument.
        position = i64(0);
        key: ptr[PyObject] = NULL;
        item: ptr[PyObject] = NULL;
        while PyDict_Next(dictionary, &mut position, &mut key, &mut item) != 0 {
            if jacpy_is_unicode(key) == 0 {
                object_error(PyExc_TypeError, "keywords must be strings");
                failed = True;
                break;
            }
            text = text_value(key);
            if text not in names {
                PyErr_Format(
                    PyExc_TypeError,
                    "this function got an unexpected keyword argument '%S'",
                    key
                );
                failed = True;
                break;
            }
        }
    }
    result: ptr[PyObject] = NULL;
    if not failed {
        result = element_setstate_from_attributes(
            state, instance, values[0], values[1], values[2], values[3], values[4]
        );
    }
    for value in values {
        jacpy_release(value);
    }
    return result;
}

def _elementtree_Element___setstate___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_exact_dict(state) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "Don't know how to unpickle \"%.200R\" as an Element",
            state
        );
        return NULL;
    }
    return element_setstate_from_Python(state_by_cls(cls), receiver, state);
}

def:priv path_char(character: int) -> bool {
    # '/', '*', '[', '@', '.'
    return character in [47, 42, 91, 64, 46];
}

# checkpath(): whether a tag holds an xpath character.
def:priv checkpath(tag: ptr[PyObject]) -> bool {
    if jacpy_is_unicode(tag) != 0 {
        length = int(PyUnicode_GetLength(tag));
        if length >= 3
            and int(PyUnicode_ReadChar(tag, 0)) == 123
            and (
                int(PyUnicode_ReadChar(tag, 1)) == 125
                or (
                    int(PyUnicode_ReadChar(tag, 1)) == 42
                    and int(PyUnicode_ReadChar(tag, 2)) == 125
                )
            ) {
            # A wildcard: '{}tag' or '{*}tag'.
            return True;
        }
        check = True;
        for index in range(length) {
            character = int(PyUnicode_ReadChar(tag, i64(index)));
            if character == 123 {
                check = False;
            } elif character == 125 {
                check = True;
            } elif check and path_char(character) {
                return True;
            }
        }
        return False;
    }
    if jacpy_is_bytes(tag) != 0 {
        data = PyBytes_AsString(tag);
        length = int(PyBytes_Size(tag));
        if length >= 3
            and int(data.view(1)[0]) == 123
            and (
                int((data + 1).view(1)[0]) == 125
                or (
                    int((data + 1).view(1)[0]) == 42
                    and int((data + 2).view(1)[0]) == 125
                )
            ) {
            return True;
        }
        check = True;
        for index in range(length) {
            character = int((data + index).view(1)[0]);
            if character == 123 {
                check = False;
            } elif character == 125 {
                check = True;
            } elif check and path_char(character) {
                return True;
            }
        }
        return False;
    }
    # An unknown type might be a path expression.
    return True;
}

def _elementtree_Element_extend_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], elements: ptr[PyObject]
) -> ptr[PyObject] {
    sequence = PySequence_Fast(elements, "'elements' must be an iterable");
    if not sequence {
        return NULL;
    }
    state = state_by_cls(cls);
    index = i64(0);
    while index < fast_size(sequence) {
        item = Py_NewRef(fast_item(sequence, index));
        if element_add_subelement(state, receiver, item) < 0 {
            jacpy_release(sequence);
            jacpy_release(item);
            return NULL;
        }
        jacpy_release(item);
        index += 1;
    }
    jacpy_release(sequence);
    return Py_NewRef(Py_None);
}

# The first child whose tag equals `path`, with a new reference; NULL when
# there is none, or with the error set when a comparison fails.
def:priv find_child(receiver: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    index = i64(0);
    while extra_of(receiver) and index < child_count(receiver) {
        item = Py_NewRef(child_at(receiver, index));
        tag = Py_NewRef(element(item).view(1)[0].tag);
        status = PyObject_RichCompareBool(tag, path, PY_EQ);
        jacpy_release(tag);
        if status > 0 {
            return item;
        }
        jacpy_release(item);
        if status < 0 {
            return NULL;
        }
        index += 1;
    }
    return NULL;
}

def _elementtree_Element_find_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    path: ptr[PyObject],
    namespaces: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_cls(cls);
    if checkpath(path) or namespaces != Py_None {
        return PyObject_CallMethodObjArgs(
            state.elementpath_obj, state.str_find, receiver, path, namespaces, NULL
        );
    }
    found = find_child(receiver, path);
    if found or PyErr_Occurred() {
        return found;
    }
    return Py_NewRef(Py_None);
}

def _elementtree_Element_findtext_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    path: ptr[PyObject],
    default_: ptr[PyObject],
    namespaces: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_cls(cls);
    if checkpath(path) or namespaces != Py_None {
        return PyObject_CallMethodObjArgs(
            state.elementpath_obj,
            state.str_findtext,
            receiver,
            path,
            default_,
            namespaces,
            NULL
        );
    }
    found = find_child(receiver, path);
    if not found and PyErr_Occurred() {
        return NULL;
    }
    if found {
        text = element_get_text(found);
        jacpy_release(found);
        if text == Py_None {
            jacpy_release(text);
            return Py_GetConstant(PY_CONSTANT_EMPTY_STR);
        }
        return text;
    }
    return Py_NewRef(default_);
}

def _elementtree_Element_findall_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    path: ptr[PyObject],
    namespaces: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_cls(cls);
    if checkpath(path) or namespaces != Py_None {
        return PyObject_CallMethodObjArgs(
            state.elementpath_obj, state.str_findall, receiver, path, namespaces, NULL
        );
    }
    out = PyList_New(0);
    if not out {
        return NULL;
    }
    index = i64(0);
    while extra_of(receiver) and index < child_count(receiver) {
        item = Py_NewRef(child_at(receiver, index));
        tag = Py_NewRef(element(item).view(1)[0].tag);
        status = PyObject_RichCompareBool(tag, path, PY_EQ);
        jacpy_release(tag);
        if status != 0 and (status < 0 or PyList_Append(out, item) < 0) {
            jacpy_release(item);
            jacpy_release(out);
            return NULL;
        }
        jacpy_release(item);
        index += 1;
    }
    return out;
}

def _elementtree_Element_iterfind_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    path: ptr[PyObject],
    namespaces: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_cls(cls);
    return PyObject_CallMethodObjArgs(
        state.elementpath_obj, state.str_iterfind, receiver, path, namespaces, NULL
    );
}

def _elementtree_Element_get_impl(
    receiver: ptr[PyObject], key: ptr[PyObject], default_: ptr[PyObject]
) -> ptr[PyObject] {
    extra = extra_of(receiver);
    if extra and extra.view(1)[0].attrib {
        attrib = Py_NewRef(extra.view(1)[0].attrib);
        found = PyDict_GetItemWithError(attrib, key);
        value = Py_NewRef(found) if found else NULL;
        jacpy_release(attrib);
        if value or PyErr_Occurred() {
            return value;
        }
    }
    return Py_NewRef(default_);
}

def _elementtree_Element_iter_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], tag: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_unicode(tag) != 0 {
        if PyUnicode_GetLength(tag) == 1 and int(PyUnicode_ReadChar(tag, 0)) == 42 {
            tag = Py_None;
        }
    } elif jacpy_is_bytes(tag) != 0 {
        if PyBytes_Size(tag) == 1 and int(PyBytes_AsString(tag).view(1)[0]) == 42 {
            tag = Py_None;
        }
    }
    return create_elementiter(state_by_cls(cls), receiver, tag, False);
}

def _elementtree_Element_itertext_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return create_elementiter(state_by_cls(cls), receiver, Py_None, True);
}

def element_getitem(instance: ptr[PyObject], index: i64) -> ptr[PyObject] {
    if not extra_of(instance) or index < 0 or index >= child_count(instance) {
        object_error(PyExc_IndexError, "child index out of range");
        return NULL;
    }
    return Py_NewRef(child_at(instance, index));
}

def element_bool(instance: ptr[PyObject]) -> i32 {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        "Testing an element's truth value will always return True in future versions.  Use specific 'len(elem)' or 'elem is not None' test instead.",
        1
    )
        < 0 {
        return i32(-1);
    }
    return i32(1) if child_count(instance) else i32(0);
}

def _elementtree_Element_insert_impl(
    receiver: ptr[PyObject], index: i64, subelement: ptr[PyObject]
) -> ptr[PyObject] {
    if not extra_of(receiver) {
        if create_extra(receiver, NULL) < 0 {
            return NULL;
        }
    }
    length = child_count(receiver);
    if index < 0 {
        index += length;
        if index < 0 {
            index = 0;
        }
    }
    if index > length {
        index = length;
    }
    if element_resize(receiver, 1) < 0 {
        return NULL;
    }
    position = child_count(receiver);
    while position > index {
        set_child(receiver, position, child_at(receiver, position - 1));
        position -= 1;
    }
    set_child(receiver, index, Py_NewRef(subelement));
    block = extra_of(receiver).view(1);
    block[0].length = block[0].length + 1;
    return Py_NewRef(Py_None);
}

def _elementtree_Element_items_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    extra = extra_of(receiver);
    if not extra or not extra.view(1)[0].attrib {
        return PyList_New(0);
    }
    return PyDict_Items(extra.view(1)[0].attrib);
}

def _elementtree_Element_keys_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    extra = extra_of(receiver);
    if not extra or not extra.view(1)[0].attrib {
        return PyList_New(0);
    }
    return PyDict_Keys(extra.view(1)[0].attrib);
}

def element_length(instance: ptr[PyObject]) -> i64 {
    return child_count(instance);
}

def _elementtree_Element_makeelement_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    tag: ptr[PyObject],
    attrib: ptr[PyObject]
) -> ptr[PyObject] {
    copied = PyDict_Copy(attrib);
    if not copied {
        return NULL;
    }
    created = create_new_element(state_by_cls(cls), tag, copied);
    jacpy_release(copied);
    return created;
}

def _elementtree_Element_remove_impl(
    receiver: ptr[PyObject], subelement: ptr[PyObject]
) -> ptr[PyObject] {
    # The children may be cleared or shrink while comparing, so the bounds
    # are checked on every step; faster growth is not guarded, as in lists.
    status = 0;
    index = i64(0);
    while extra_of(receiver) and index < child_count(receiver) {
        if child_at(receiver, index) == subelement {
            status = 1;
            break;
        }
        child = Py_NewRef(child_at(receiver, index));
        status = int(PyObject_RichCompareBool(child, subelement, PY_EQ));
        jacpy_release(child);
        if status < 0 {
            return NULL;
        } elif status > 0 {
            break;
        }
        index += 1;
    }
    if status == 0 {
        object_error(PyExc_ValueError, "Element.remove(x): element not found");
        return NULL;
    }
    # A mutation on the last step may have removed or cleared the children.
    if not extra_of(receiver) or index >= child_count(receiver) {
        return Py_NewRef(Py_None);
    }
    found = child_at(receiver, index);
    block = extra_of(receiver).view(1);
    block[0].length = block[0].length - 1;
    while index < block[0].length {
        set_child(receiver, index, child_at(receiver, index + 1));
        index += 1;
    }
    jacpy_release(found);
    return Py_NewRef(Py_None);
}

def element_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    tag = element(instance).view(1)[0].tag;
    if not tag {
        return PyUnicode_FromFormat("<Element at %p>", instance);
    }
    status = Py_ReprEnter(instance);
    if status == 0 {
        result = PyUnicode_FromFormat(
            "<Element %R at %p>", element(instance).view(1)[0].tag, instance
        );
        Py_ReprLeave(instance);
        return result;
    }
    if status > 0 {
        object_error(
            PyExc_RuntimeError,
            "reentrant call inside " + type_name_clipped(instance, 1024) + ".__repr__"
        );
    }
    return NULL;
}

def _elementtree_Element_set_impl(
    receiver: ptr[PyObject], key: ptr[PyObject], value_: ptr[PyObject]
) -> ptr[PyObject] {
    if not extra_of(receiver) {
        if create_extra(receiver, NULL) < 0 {
            return NULL;
        }
    }
    attrib = element_get_attrib(receiver);
    if not attrib {
        return NULL;
    }
    if PyDict_SetItem(attrib, key, value_) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def element_setitem(instance: ptr[PyObject], index: i64, item: ptr[PyObject]) -> i32 {
    if not extra_of(instance) or index < 0 or index >= child_count(instance) {
        object_error(PyExc_IndexError, "child assignment index out of range");
        return i32(-1);
    }
    old = child_at(instance, index);
    if item {
        state = state_by_type(Py_TYPE(instance));
        if not is_element(state, item) {
            raise_type_error(item);
            return i32(-1);
        }
        set_child(instance, index, Py_NewRef(item));
    } else {
        block = extra_of(instance).view(1);
        block[0].length = block[0].length - 1;
        position = index;
        while position < block[0].length {
            set_child(instance, position, child_at(instance, position + 1));
            position += 1;
        }
    }
    jacpy_release(old);
    return i32(0);
}

def element_subscr(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != 0 {
        index = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return NULL;
        }
        if index < 0 and extra_of(instance) {
            index += child_count(instance);
        }
        return element_getitem(instance, index);
    }
    if jacpy_is_slice(item) != 0 {
        # The slice length is computed once user code can no longer change
        # the children (gh-143200).
        start = i64(0);
        stop = i64(0);
        step = i64(0);
        if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
            return NULL;
        }
        if not extra_of(instance) {
            return PyList_New(0);
        }
        count = PySlice_AdjustIndices(
            child_count(instance), &mut start, &mut stop, step
        );
        if count <= 0 {
            return PyList_New(0);
        }
        result = PyList_New(count);
        if not result {
            return NULL;
        }
        # Each index is computed, never stepped past the end, where a huge
        # step would overflow.
        for index in range(int(count)) {
            PyList_SetItem(
                result,
                i64(index),
                Py_NewRef(child_at(instance, start + i64(index) * step))
            );
        }
        return result;
    }
    object_error(PyExc_TypeError, "element indices must be integers");
    return NULL;
}

def element_ass_subscr(
    instance: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if PyIndex_Check(item) != 0 {
        index = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        if index < 0 and extra_of(instance) {
            index += child_count(instance);
        }
        return element_setitem(instance, index, value);
    }
    if jacpy_is_slice(item) == 0 {
        object_error(PyExc_TypeError, "element indices must be integers");
        return i32(-1);
    }
    start = i64(0);
    stop = i64(0);
    step = i64(0);
    if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
        return i32(-1);
    }
    if not value {
        return delete_slice(instance, start, stop, step);
    }
    # A new slice is assigned.
    sequence = PySequence_Fast(value, "assignment expects an iterable");
    if not sequence {
        return i32(-1);
    }
    newlen = fast_size(sequence);
    if not extra_of(instance) {
        if create_extra(instance, NULL) < 0 {
            jacpy_release(sequence);
            return i32(-1);
        }
    }
    slicelen = PySlice_AdjustIndices(
        child_count(instance), &mut start, &mut stop, step
    );
    if step != 1 and newlen != slicelen {
        jacpy_release(sequence);
        object_error(
            PyExc_ValueError,
            f"attempt to assign sequence of size {newlen} to extended slice of size {slicelen}"
        );
        return i32(-1);
    }
    # Resize before the recycle bin exists, so nothing leaks.
    if newlen > slicelen {
        if element_resize(instance, newlen - slicelen) < 0 {
            jacpy_release(sequence);
            return i32(-1);
        }
    }
    state = state_by_type(Py_TYPE(instance));
    for index in range(int(newlen)) {
        candidate = fast_item(sequence, i64(index));
        if not is_element(state, candidate) {
            raise_type_error(candidate);
            jacpy_release(sequence);
            return i32(-1);
        }
    }
    recycle: ptr[PyObject] = NULL;
    if slicelen > 0 {
        # The old items wait in a recycle list until the element is
        # consistent again, so their release cannot re-enter here.
        recycle = PyList_New(slicelen);
        if not recycle {
            jacpy_release(sequence);
            return i32(-1);
        }
        for index in range(int(slicelen)) {
            PyList_SetItem(
                recycle, i64(index), child_at(instance, start + i64(index) * step)
            );
        }
    }
    length = child_count(instance);
    if newlen < slicelen {
        # Delete slice.
        position = stop;
        while position < length {
            set_child(
                instance, position + newlen - slicelen, child_at(instance, position)
            );
            position += 1;
        }
    } elif newlen > slicelen {
        # Insert slice.
        position = length - 1;
        while position >= stop {
            set_child(
                instance, position + newlen - slicelen, child_at(instance, position)
            );
            position -= 1;
        }
    }
    # Replace the slice.
    for index in range(int(newlen)) {
        set_child(
            instance,
            start + i64(index) * step,
            Py_NewRef(fast_item(sequence, i64(index)))
        );
    }
    block = extra_of(instance).view(1);
    block[0].length = block[0].length + newlen - slicelen;
    jacpy_release(sequence);
    # Empty the recycle bin.
    jacpy_release(recycle);
    return i32(0);
}

def:priv delete_slice(
    instance: ptr[PyObject], start: i64, stop: i64, step: i64
) -> i32 {
    if not extra_of(instance) {
        return i32(0);
    }
    slicelen = PySlice_AdjustIndices(
        child_count(instance), &mut start, &mut stop, step
    );
    if slicelen <= 0 {
        return i32(0);
    }
    # Deleting does not care about direction, so make the range ascending.
    if step < 0 {
        stop = start + 1;
        start = stop + step * (slicelen - 1) - 1;
        step = -step;
    }
    # Every removed child waits in `recycle`.
    recycle = PyList_New(slicelen);
    if not recycle {
        return i32(-1);
    }
    children = extra_of(instance).view(1)[0].children;
    # Walk the children to delete; before the next one, num_moved children
    # shift down by the i + 1 places already freed.
    # Positions are compared without forming one past a huge step, which
    # would overflow.
    length = child_count(instance);
    for position in range(int(slicelen)) {
        index = i64(position);
        current = start + index * step;
        num_moved = step - 1;
        if step >= length - current {
            num_moved = length - current - 1;
        }
        PyList_SetItem(recycle, index, (children + current).view(1)[0]);
        memmove(
            ptr(children + (current - index)),
            ptr(children + (current + 1)),
            u64(num_moved * 8)
        );
    }
    # The tail left after the last removed child.
    last = start + (slicelen - 1) * step;
    if step < length - last {
        current = last + step;
        memmove(
            ptr(children + (current - slicelen)),
            ptr(children + current),
            u64((length - current) * 8)
        );
    }
    block = extra_of(instance).view(1);
    block[0].length = block[0].length - slicelen;
    # Discard the recycle list with the deleted children.
    jacpy_release(recycle);
    return i32(0);
}

def element_tag_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return Py_NewRef(element(instance).view(1)[0].tag);
}

def element_text_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return element_get_text(instance);
}

def element_tail_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return element_get_text(instance, True);
}

def element_attrib_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    if not extra_of(instance) {
        if create_extra(instance, NULL) < 0 {
            return NULL;
        }
    }
    result = element_get_attrib(instance);
    return Py_NewRef(result) if result else NULL;
}

def:priv refuse_delete(value: ptr[PyObject]) -> bool {
    if not value {
        object_error(PyExc_AttributeError, "can't delete element attribute");
        return True;
    }
    return False;
}

def element_tag_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if refuse_delete(value) {
        return i32(-1);
    }
    record = element(instance).view(1);
    previous = record[0].tag;
    record[0].tag = Py_NewRef(value);
    jacpy_release(previous);
    return i32(0);
}

def element_text_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if refuse_delete(value) {
        return i32(-1);
    }
    set_joined_text(instance, Py_NewRef(value), False);
    return i32(0);
}

def element_tail_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if refuse_delete(value) {
        return i32(-1);
    }
    set_joined_text(instance, Py_NewRef(value), True);
    return i32(0);
}

def element_attrib_setter(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if refuse_delete(value) {
        return i32(-1);
    }
    if jacpy_is_dict(value) == 0 {
        object_error(
            PyExc_TypeError, "attrib must be dict, not " + type_name_clipped(value, 200)
        );
        return i32(-1);
    }
    if not extra_of(instance) {
        if create_extra(instance, NULL) < 0 {
            return i32(-1);
        }
    }
    block = extra_of(instance).view(1);
    previous = block[0].attrib;
    block[0].attrib = Py_NewRef(value);
    jacpy_release(previous);
    return i32(0);
}

# ------------------------------------------------------- element iterator

# The iterator walks the tree in pre-order with a stack of (parent, next
# child index) pairs.

def elementiter_dealloc(instance: ptr[PyObject]) {
    record = element_iter(instance).view(1);
    used = record[0].parent_stack_used;
    record[0].parent_stack_used = 0;
    # bpo-31095: untrack before any callback can run.
    jacpy_binding_untrack(instance);
    stack = element_iter(instance).view(1)[0].parent_stack;
    while used > 0 {
        used -= 1;
        jacpy_release((stack + used).view(1)[0].parent);
    }
    PyMem_Free(ptr(stack));
    record = element_iter(instance).view(1);
    jacpy_release(record[0].sought_tag);
    jacpy_release(element_iter(instance).view(1)[0].root_element);
    jacpy_binding_free(instance);
}

def elementiter_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    record = element_iter(instance).view(1);
    used = record[0].parent_stack_used;
    while used > 0 {
        used -= 1;
        status = visit_reference(
            (record[0].parent_stack + used).view(1)[0].parent, visitor, context
        );
        if status != 0 {
            return status;
        }
    }
    for value in [record[0].root_element, record[0].sought_tag, Py_TYPE(instance)] {
        status = visit_reference(value, visitor, context);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

def elementiter_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv parent_stack_push_new(instance: ptr[PyObject], parent: ptr[PyObject]) -> i32 {
    record = element_iter(instance).view(1);
    if record[0].parent_stack_used >= record[0].parent_stack_size {
        new_size = record[0].parent_stack_size * 2;
        stack = ptr[parent_locator](
            PyMem_Realloc(ptr(record[0].parent_stack), u64(new_size * 16))
        );
        if not stack {
            return i32(-1);
        }
        record[0].parent_stack = stack;
        record[0].parent_stack_size = new_size;
    }
    item = (record[0].parent_stack + record[0].parent_stack_used).view(1);
    record[0].parent_stack_used = record[0].parent_stack_used + 1;
    item[0].parent = Py_NewRef(parent);
    item[0].child_index = 0;
    return i32(0);
}

# elementiter_next(): iter() and itertext() share it; itertext() yields only
# non-empty text, and the tails of the elements below the one it started at.
def elementiter_next(instance: ptr[PyObject]) -> ptr[PyObject] {
    while True {
        record = element_iter(instance).view(1);
        elem: ptr[PyObject] = NULL;
        text: ptr[PyObject] = NULL;
        take_text = False;
        if not record[0].parent_stack_used {
            # The start or the end of the iteration.
            if not record[0].root_element {
                PyErr_SetNone(PyExc_StopIteration);
                return NULL;
            }
            # The root's reference moves to elem.
            elem = record[0].root_element;
            record[0].root_element = NULL;
        } else {
            # Visit the current parent's next child, or pop the parent.
            item = (record[0].parent_stack + (record[0].parent_stack_used - 1)).view(1);
            child_index = item[0].child_index;
            elem = item[0].parent;
            if not extra_of(elem) or child_index >= child_count(elem) {
                record[0].parent_stack_used = record[0].parent_stack_used - 1;
                # itertext() returns only inner text, not the text after the
                # element it began with.
                if record[0].gettext and record[0].parent_stack_used {
                    text = element_get_text(elem, True);
                    take_text = True;
                } else {
                    jacpy_release(elem);
                    continue;
                }
            } else {
                elem = Py_NewRef(child_at(elem, child_index));
                item[0].child_index = child_index + 1;
            }
        }
        if not take_text {
            if parent_stack_push_new(instance, elem) < 0 {
                jacpy_release(elem);
                PyErr_NoMemory();
                return NULL;
            }
            record = element_iter(instance).view(1);
            if record[0].gettext {
                tag = element(elem).view(1)[0].tag;
                if tag != Py_None and jacpy_is_unicode(tag) == 0 {
                    jacpy_release(elem);
                    continue;
                }
                text = element_get_text(elem);
                take_text = True;
            } else {
                sought = record[0].sought_tag;
                if sought == Py_None {
                    return elem;
                }
                status = PyObject_RichCompareBool(
                    element(elem).view(1)[0].tag, sought, PY_EQ
                );
                if status > 0 {
                    return elem;
                }
                jacpy_release(elem);
                if status < 0 {
                    return NULL;
                }
                continue;
            }
        }
        # gettext:
        jacpy_release(elem);
        if not text {
            return NULL;
        }
        if text == Py_None {
            jacpy_release(text);
        } else {
            status = PyObject_IsTrue(text);
            if status > 0 {
                return text;
            }
            jacpy_release(text);
            if status < 0 {
                return NULL;
            }
        }
    }
    return NULL;
}

def:priv create_elementiter(
    state: ElementTreeState, receiver: ptr[PyObject], tag: ptr[PyObject], gettext: bool
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(state.ElementIter_Type);
    if not created {
        return NULL;
    }
    record = element_iter(created).view(1);
    record[0].sought_tag = Py_NewRef(tag);
    record[0].gettext = i32(1) if gettext else i32(0);
    record[0].root_element = Py_NewRef(receiver);
    stack = ptr[parent_locator](PyMem_Malloc(u64(INIT_PARENT_STACK_SIZE * 16)));
    if not stack {
        jacpy_release(created);
        PyErr_NoMemory();
        return NULL;
    }
    record = element_iter(created).view(1);
    record[0].parent_stack = stack;
    record[0].parent_stack_used = 0;
    record[0].parent_stack_size = i64(INIT_PARENT_STACK_SIZE);
    return created;
}

# ------------------------------------------------------------ TreeBuilder

def:priv builder_state(instance: ptr[PyObject]) -> ElementTreeState {
    return module_state(treebuilder(instance).view(1)[0].module);
}

def treebuilder_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(type);
    if not created {
        return NULL;
    }
    record = treebuilder(created).view(1);
    record[0].root_node = NULL;
    record[0].current = Py_NewRef(Py_None);
    record[0].last = Py_NewRef(Py_None);
    record[0].data = NULL;
    record[0].element_factory = NULL;
    record[0].comment_factory = NULL;
    record[0].pi_factory = NULL;
    stack = PyList_New(20);
    record = treebuilder(created).view(1);
    record[0].stack = stack;
    if not stack {
        jacpy_release(created);
        return NULL;
    }
    record[0].index = 0;
    record[0].events_append = NULL;
    record[0].start_event_obj = NULL;
    record[0].end_event_obj = NULL;
    record[0].start_ns_event_obj = NULL;
    record[0].end_ns_event_obj = NULL;
    record[0].comment_event_obj = NULL;
    record[0].pi_event_obj = NULL;
    record[0].insert_comments = 0;
    record[0].insert_pis = 0;
    record[0].module = jacpy_binding_owner(type, module_definition.handle);
    return created;
}

# Store an owned value (or NULL) in a TreeBuilder field, releasing the old.
def:priv replace_field(slot: ptr[ptr[PyObject]], value: ptr[PyObject]) {
    previous = slot.view(1)[0];
    slot.view(1)[0] = value;
    jacpy_release(previous);
}

def:priv builder_field(instance: ptr[PyObject], offset: int) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](int(treebuilder(instance)) + offset);
}

# Field offsets of treebuilder_record.
glob:priv TB_ROOT: int = 0,
     TB_THIS: int = 8,
     TB_LAST: int = 16,
     TB_LAST_FOR_TAIL: int = 24,
     TB_DATA: int = 32,
     TB_STACK: int = 40,
     TB_ELEMENT_FACTORY: int = 56,
     TB_COMMENT_FACTORY: int = 64,
     TB_PI_FACTORY: int = 72,
     TB_EVENTS_APPEND: int = 80,
     TB_START_EVENT: int = 88,
     TB_END_EVENT: int = 96,
     TB_START_NS_EVENT: int = 104,
     TB_END_NS_EVENT: int = 112,
     TB_COMMENT_EVENT: int = 120,
     TB_PI_EVENT: int = 128,
     # The fields tp_traverse visits and tp_clear drops, in C's orders.
     TB_VISITED: list[int] = [
         TB_PI_EVENT,
         TB_COMMENT_EVENT,
         TB_END_NS_EVENT,
         TB_START_NS_EVENT,
         TB_END_EVENT,
         TB_START_EVENT,
         TB_EVENTS_APPEND,
         TB_ROOT,
         TB_THIS,
         TB_LAST,
         TB_LAST_FOR_TAIL,
         TB_DATA,
         TB_STACK,
         TB_PI_FACTORY,
         TB_COMMENT_FACTORY,
         TB_ELEMENT_FACTORY
     ],
     TB_CLEARED: list[int] = [
         TB_PI_EVENT,
         TB_COMMENT_EVENT,
         TB_END_NS_EVENT,
         TB_START_NS_EVENT,
         TB_END_EVENT,
         TB_START_EVENT,
         TB_EVENTS_APPEND,
         TB_STACK,
         TB_DATA,
         TB_LAST,
         TB_LAST_FOR_TAIL,
         TB_THIS,
         TB_PI_FACTORY,
         TB_COMMENT_FACTORY,
         TB_ELEMENT_FACTORY,
         TB_ROOT
     ];

def _elementtree_TreeBuilder___init___impl(
    receiver: ptr[PyObject],
    element_factory: ptr[PyObject],
    comment_factory: ptr[PyObject],
    pi_factory: ptr[PyObject],
    insert_comments: bool,
    insert_pis: bool
) -> i32 {
    if element_factory != Py_None {
        replace_field(
            builder_field(receiver, TB_ELEMENT_FACTORY), Py_NewRef(element_factory)
        );
    } else {
        replace_field(builder_field(receiver, TB_ELEMENT_FACTORY), NULL);
    }
    if comment_factory == Py_None {
        comment_factory = builder_state(receiver).comment_factory;
    }
    if comment_factory {
        replace_field(
            builder_field(receiver, TB_COMMENT_FACTORY), Py_NewRef(comment_factory)
        );
        treebuilder(receiver).view(1)[0].insert_comments = i32(insert_comments);
    } else {
        replace_field(builder_field(receiver, TB_COMMENT_FACTORY), NULL);
        treebuilder(receiver).view(1)[0].insert_comments = 0;
    }
    if pi_factory == Py_None {
        pi_factory = builder_state(receiver).pi_factory;
    }
    if pi_factory {
        replace_field(builder_field(receiver, TB_PI_FACTORY), Py_NewRef(pi_factory));
        treebuilder(receiver).view(1)[0].insert_pis = i32(insert_pis);
    } else {
        replace_field(builder_field(receiver, TB_PI_FACTORY), NULL);
        treebuilder(receiver).view(1)[0].insert_pis = 0;
    }
    return i32(0);
}

def treebuilder_gc_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    status = visit_reference(Py_TYPE(instance), visitor, context);
    if status != 0 {
        return status;
    }
    for offset in TB_VISITED {
        status = visit_reference(
            builder_field(instance, offset).view(1)[0], visitor, context
        );
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

def treebuilder_gc_clear(instance: ptr[PyObject]) -> i32 {
    for offset in TB_CLEARED {
        replace_field(builder_field(instance, offset), NULL);
    }
    return i32(0);
}

def treebuilder_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    treebuilder_gc_clear(instance);
    jacpy_binding_free(instance);
}

# _set_factories(): the old (comment_factory, pi_factory).
def _elementtree__set_factories_impl(
    module: ptr[PyObject], comment_factory: ptr[PyObject], pi_factory: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    if PyCallable_Check(comment_factory) == 0 and comment_factory != Py_None {
        object_error(
            PyExc_TypeError,
            "Comment factory must be callable, not "
                + type_name_clipped(comment_factory, 100)
        );
        return NULL;
    }
    if PyCallable_Check(pi_factory) == 0 and pi_factory != Py_None {
        object_error(
            PyExc_TypeError,
            "PI factory must be callable, not " + type_name_clipped(pi_factory, 100)
        );
        return NULL;
    }
    old = PyTuple_Pack(
        2, state.comment_factory or Py_None, state.pi_factory or Py_None
    );
    previous = state.comment_factory;
    state.comment_factory = NULL
        if comment_factory == Py_None
        else Py_NewRef(comment_factory);
    jacpy_release(previous);
    previous = state.pi_factory;
    state.pi_factory = NULL if pi_factory == Py_None else Py_NewRef(pi_factory);
    jacpy_release(previous);
    return old;
}

# treebuilder_extend_element_text_or_tail(): append the collected data to
# the element's text (or tail).
def:priv extend_text_or_tail(
    state: ElementTreeState, builder: ptr[PyObject], target: ptr[PyObject], tail: bool
) -> i32 {
    data_slot = builder_field(builder, TB_DATA);
    # The fast paths, almost always taken.
    if Py_TYPE(target) == state.Element_Type {
        record = element(target).view(1);
        dest = record[0].tail if tail else record[0].text;
        dest_obj = join_obj(dest);
        data = data_slot.view(1)[0];
        if dest_obj == Py_None {
            joined = join_set(data, jacpy_is_exact_list(data));
            if tail {
                record[0].tail = joined;
            } else {
                record[0].text = joined;
            }
            data_slot.view(1)[0] = NULL;
            jacpy_release(dest_obj);
            return i32(0);
        } elif join_get(dest) {
            if PyList_SetSlice(dest_obj, PY_SSIZE_T_MAX, PY_SSIZE_T_MAX, data) < 0 {
                return i32(-1);
            }
            replace_field(data_slot, NULL);
            return i32(0);
        }
    }
    # The fallback for other elements and the non-trivial cases.
    name = state.str_tail if tail else state.str_text;
    previous = PyObject_GetAttr(target, name);
    if not previous {
        return i32(-1);
    }
    joined = list_join(builder_field(builder, TB_DATA).view(1)[0]);
    if not joined {
        jacpy_release(previous);
        return i32(-1);
    }
    if previous != Py_None {
        added = PyNumber_Add(previous, joined);
        jacpy_release(joined);
        jacpy_release(previous);
        if not added {
            return i32(-1);
        }
        joined = added;
    } else {
        jacpy_release(previous);
    }
    status = PyObject_SetAttr(target, name, joined);
    jacpy_release(joined);
    if status < 0 {
        return i32(-1);
    }
    replace_field(builder_field(builder, TB_DATA), NULL);
    return i32(0);
}

def:priv treebuilder_flush_data(builder: ptr[PyObject]) -> i32 {
    record = treebuilder(builder).view(1);
    if not record[0].data {
        return i32(0);
    }
    state = builder_state(builder);
    if not record[0].last_for_tail {
        return extend_text_or_tail(state, builder, record[0].last, False);
    }
    return extend_text_or_tail(state, builder, record[0].last_for_tail, True);
}

def:priv treebuilder_add_subelement(
    state: ElementTreeState, parent: ptr[PyObject], child: ptr[PyObject]
) -> i32 {
    if Py_TYPE(parent) == state.Element_Type {
        return element_add_subelement(state, parent, child);
    }
    result = PyObject_CallMethodObjArgs(parent, state.str_append, child, NULL);
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

def:priv treebuilder_append_event(
    builder: ptr[PyObject], action: ptr[PyObject], item: ptr[PyObject]
) -> i32 {
    if action {
        event = PyTuple_Pack(2, action, item);
        if not event {
            return i32(-1);
        }
        result = PyObject_CallOneArg(
            treebuilder(builder).view(1)[0].events_append, event
        );
        jacpy_release(event);
        if not result {
            return i32(-1);
        }
        jacpy_release(result);
    }
    return i32(0);
}

def:priv treebuilder_handle_start(
    builder: ptr[PyObject], tag: ptr[PyObject], attrib: ptr[PyObject]
) -> ptr[PyObject] {
    state = builder_state(builder);
    if treebuilder_flush_data(builder) < 0 {
        return NULL;
    }
    factory = treebuilder(builder).view(1)[0].element_factory;
    created: ptr[PyObject] = NULL;
    if not factory {
        created = create_new_element(state, tag, attrib);
    } elif not attrib {
        attrib = PyDict_New();
        if not attrib {
            return NULL;
        }
        created = PyObject_CallFunctionObjArgs(factory, tag, attrib, NULL);
        jacpy_release(attrib);
    } else {
        created = PyObject_CallFunctionObjArgs(factory, tag, attrib, NULL);
    }
    if not created {
        return NULL;
    }
    current = treebuilder(builder).view(1)[0].current;
    replace_field(builder_field(builder, TB_LAST_FOR_TAIL), NULL);
    if current != Py_None {
        if treebuilder_add_subelement(state, current, created) < 0 {
            jacpy_release(created);
            return NULL;
        }
    } else {
        if treebuilder(builder).view(1)[0].root_node {
            object_error(state.parseerror_obj, "multiple elements on top level");
            jacpy_release(created);
            return NULL;
        }
        treebuilder(builder).view(1)[0].root_node = Py_NewRef(created);
    }
    record = treebuilder(builder).view(1);
    if record[0].index < PyList_Size(record[0].stack) {
        if PyList_SetItem(record[0].stack, record[0].index, Py_NewRef(current)) < 0 {
            jacpy_release(created);
            return NULL;
        }
    } elif PyList_Append(record[0].stack, current) < 0 {
        jacpy_release(created);
        return NULL;
    }
    record = treebuilder(builder).view(1);
    record[0].index = record[0].index + 1;
    replace_field(builder_field(builder, TB_THIS), Py_NewRef(created));
    replace_field(builder_field(builder, TB_LAST), Py_NewRef(created));
    if treebuilder_append_event(
        builder, treebuilder(builder).view(1)[0].start_event_obj, created
    )
        < 0 {
        jacpy_release(created);
        return NULL;
    }
    return created;
}

def:priv treebuilder_handle_data(
    builder: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    record = treebuilder(builder).view(1);
    if not record[0].data {
        if record[0].last == Py_None {
            # Data before the first start() is ignored.
            return Py_NewRef(Py_None);
        }
        # The first item is stored as is.
        record[0].data = Py_NewRef(data);
    } elif Py_TYPE(record[0].data) == addressof(PyBytes_Type)
        and PyUnstable_Object_IsUniquelyReferenced(record[0].data) != 0
        and Py_TYPE(data) == addressof(PyBytes_Type)
        and PyBytes_Size(data) == 1 {
        # Single character data sections grow the bytes in place, as
        # _PyBytes_Resize() does.
        grown = record[0].data;
        record[0].data = NULL;
        PyBytes_Concat(&mut grown, data);
        treebuilder(builder).view(1)[0].data = grown;
        if not grown {
            return NULL;
        }
    } elif jacpy_is_exact_list(record[0].data) != 0 {
        # Later items go to a list.
        if PyList_Append(record[0].data, data) < 0 {
            return NULL;
        }
    } else {
        items = PyList_New(2);
        if not items {
            return NULL;
        }
        record = treebuilder(builder).view(1);
        PyList_SetItem(items, 0, Py_NewRef(record[0].data));
        PyList_SetItem(items, 1, Py_NewRef(data));
        replace_field(builder_field(builder, TB_DATA), items);
    }
    return Py_NewRef(Py_None);
}

def:priv treebuilder_handle_end(
    builder: ptr[PyObject], tag: ptr[PyObject]
) -> ptr[PyObject] {
    if treebuilder_flush_data(builder) < 0 {
        return NULL;
    }
    record = treebuilder(builder).view(1);
    if record[0].index == 0 {
        object_error(PyExc_IndexError, "pop from empty stack");
        return NULL;
    }
    item = record[0].last;
    record[0].last = Py_NewRef(record[0].current);
    replace_field(builder_field(builder, TB_LAST_FOR_TAIL), record[0].last);
    record = treebuilder(builder).view(1);
    record[0].index = record[0].index - 1;
    record[0].current = Py_NewRef(PyList_GetItem(record[0].stack, record[0].index));
    jacpy_release(item);
    record = treebuilder(builder).view(1);
    if treebuilder_append_event(builder, record[0].end_event_obj, record[0].last) < 0 {
        return NULL;
    }
    return Py_NewRef(treebuilder(builder).view(1)[0].last);
}

def:priv treebuilder_handle_comment(
    builder: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject] {
    if treebuilder_flush_data(builder) < 0 {
        return NULL;
    }
    record = treebuilder(builder).view(1);
    comment: ptr[PyObject] = NULL;
    if record[0].comment_factory {
        comment = PyObject_CallOneArg(record[0].comment_factory, text);
        if not comment {
            return NULL;
        }
        record = treebuilder(builder).view(1);
        current = record[0].current;
        if record[0].insert_comments and current != Py_None {
            if treebuilder_add_subelement(builder_state(builder), current, comment)
                < 0 {
                jacpy_release(comment);
                return NULL;
            }
            replace_field(builder_field(builder, TB_LAST_FOR_TAIL), Py_NewRef(comment));
        }
    } else {
        comment = Py_NewRef(text);
    }
    record = treebuilder(builder).view(1);
    if record[0].events_append and record[0].comment_event_obj {
        if treebuilder_append_event(builder, record[0].comment_event_obj, comment)
            < 0 {
            jacpy_release(comment);
            return NULL;
        }
    }
    return comment;
}

def:priv treebuilder_handle_pi(
    builder: ptr[PyObject], target: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject] {
    if treebuilder_flush_data(builder) < 0 {
        return NULL;
    }
    record = treebuilder(builder).view(1);
    pi: ptr[PyObject] = NULL;
    if record[0].pi_factory {
        pi = PyObject_CallFunctionObjArgs(record[0].pi_factory, target, text, NULL);
        if not pi {
            return NULL;
        }
        record = treebuilder(builder).view(1);
        current = record[0].current;
        if record[0].insert_pis and current != Py_None {
            if treebuilder_add_subelement(builder_state(builder), current, pi) < 0 {
                jacpy_release(pi);
                return NULL;
            }
            replace_field(builder_field(builder, TB_LAST_FOR_TAIL), Py_NewRef(pi));
        }
    } else {
        pi = PyTuple_Pack(2, target, text);
        if not pi {
            return NULL;
        }
    }
    record = treebuilder(builder).view(1);
    if record[0].events_append and record[0].pi_event_obj {
        if treebuilder_append_event(builder, record[0].pi_event_obj, pi) < 0 {
            jacpy_release(pi);
            return NULL;
        }
    }
    return pi;
}

def:priv treebuilder_handle_start_ns(
    builder: ptr[PyObject], prefix: ptr[PyObject], uri: ptr[PyObject]
) -> ptr[PyObject] {
    record = treebuilder(builder).view(1);
    if record[0].events_append and record[0].start_ns_event_obj {
        parcel = PyTuple_Pack(2, prefix, uri);
        if not parcel {
            return NULL;
        }
        if treebuilder_append_event(builder, record[0].start_ns_event_obj, parcel)
            < 0 {
            jacpy_release(parcel);
            return NULL;
        }
        jacpy_release(parcel);
    }
    return Py_NewRef(Py_None);
}

def:priv treebuilder_handle_end_ns(
    builder: ptr[PyObject], prefix: ptr[PyObject]
) -> ptr[PyObject] {
    record = treebuilder(builder).view(1);
    if record[0].events_append and record[0].end_ns_event_obj {
        if treebuilder_append_event(builder, record[0].end_ns_event_obj, prefix) < 0 {
            return NULL;
        }
    }
    return Py_NewRef(Py_None);
}

def _elementtree_TreeBuilder_data_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    return treebuilder_handle_data(receiver, data);
}

def _elementtree_TreeBuilder_end_impl(
    receiver: ptr[PyObject], tag: ptr[PyObject]
) -> ptr[PyObject] {
    return treebuilder_handle_end(receiver, tag);
}

def _elementtree_TreeBuilder_comment_impl(
    receiver: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject] {
    return treebuilder_handle_comment(receiver, text);
}

def _elementtree_TreeBuilder_pi_impl(
    receiver: ptr[PyObject], target: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject] {
    return treebuilder_handle_pi(receiver, target, text);
}

def:priv treebuilder_done(builder: ptr[PyObject]) -> ptr[PyObject] {
    top = treebuilder(builder).view(1)[0].root_node;
    return Py_NewRef(top or Py_None);
}

def _elementtree_TreeBuilder_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return treebuilder_done(receiver);
}

def _elementtree_TreeBuilder_start_impl(
    receiver: ptr[PyObject], tag: ptr[PyObject], attrs: ptr[PyObject]
) -> ptr[PyObject] {
    return treebuilder_handle_start(receiver, tag, attrs);
}

# ------------------------------------------------------ the expat interface

def:priv parser_state(instance: ptr[PyObject]) -> ElementTreeState {
    return module_state(xmlparser(instance).view(1)[0].elementtree_module);
}

def:priv capi_of(state: ElementTreeState) -> ptr[PyExpat_CAPI] {
    return state.expat_capi;
}

# Whether the capsule's entry at `slot` (its index counting 8-byte words from
# the start of the record) is set; entries past the Expat version are NULL.
def:priv capi_has(capi: ptr[PyExpat_CAPI], slot: int) -> bool {
    return bool((ptr[ptr](capi) + slot).view(1)[0]);
}

glob:priv CAPI_SET_HASH_SALT: int = 21,
     CAPI_SET_REPARSE_DEFERRAL_ENABLED: int = 22,
     CAPI_SET_HASH_SALT_16_BYTES: int = 27;

def:priv decode_utf8(text: ptr[u8], size: i64) -> ptr[PyObject] {
    return PyUnicode_DecodeUTF8Stateful(ptr(text), size, ptr[u8](), None);
}

# makeuniversal(): a UTF-8 tag or attribute name from Expat as a universal
# name, "{uri}local" for a namespaced one, cached in the names dict.
def:priv makeuniversal(instance: ptr[PyObject], text: ptr[u8]) -> ptr[PyObject] {
    size = i64(strlen(text));
    key = jacpy_bytes_from_memory(ptr(text), size);
    if not key {
        return NULL;
    }
    names = xmlparser(instance).view(1)[0].names;
    found = PyDict_GetItemWithError(names, key);
    value = Py_NewRef(found) if found else NULL;
    if not value and not PyErr_Occurred() {
        # A new name: convert it to a universal name and decode it.
        separator = size;
        for index in range(int(size)) {
            if int((text + index).view(1)[0]) == 125 {
                separator = i64(index);
                break;
            }
        }
        if separator != size {
            # "{" + name, decoded as one run so errors keep their positions.
            buffer = ptr[u8](PyMem_Malloc(u64(size + 1)));
            if not buffer {
                jacpy_release(key);
                return PyErr_NoMemory();
            }
            buffer.view(1)[0] = u8(123);
            jacpy_memory_copy(ptr(buffer + 1), ptr(text), size);
            value = decode_utf8(buffer, size + 1);
            PyMem_Free(ptr(buffer));
        } else {
            value = decode_utf8(text, size);
        }
        if not value {
            jacpy_release(key);
            return NULL;
        }
        if PyDict_SetItem(names, key, value) < 0 {
            jacpy_release(key);
            jacpy_release(value);
            return NULL;
        }
    }
    jacpy_release(key);
    return value;
}

# expat_set_error(): a ParseError with code and position attributes;
# `message` (a C string, or NULL for Expat's) leads the text.
def:priv expat_set_error(
    state: ElementTreeState, code: i32, line: i64, column: i64, message: ptr[u8]
) {
    shown: ptr[u8] = message;
    if not shown {
        shown = state.expat_capi.view(1)[0].ErrorString(code);
    }
    errmsg = PyUnicode_FromFormat("%s: line %zd, column %zd", shown, line, column);
    if not errmsg {
        return;
    }
    error = PyObject_CallOneArg(state.parseerror_obj, errmsg);
    jacpy_release(errmsg);
    if not error {
        return;
    }
    number = PyLong_FromLong(i64(code));
    if not number {
        jacpy_release(error);
        return;
    }
    if PyObject_SetAttrString(error, "code", number) == -1 {
        jacpy_release(error);
        jacpy_release(number);
        return;
    }
    jacpy_release(number);
    position = PyTuple_New(2);
    if position {
        first = PyLong_FromSsize_t(line);
        second = PyLong_FromSsize_t(column) if first else NULL;
        if not first or not second {
            jacpy_release(first);
            jacpy_release(position);
            position = NULL;
        } else {
            jacpy_tuple_set_owned(position, 0, first);
            jacpy_tuple_set_owned(position, 1, second);
        }
    }
    if not position {
        jacpy_release(error);
        return;
    }
    if PyObject_SetAttrString(error, "position", position) == -1 {
        jacpy_release(error);
        jacpy_release(position);
        return;
    }
    jacpy_release(position);
    PyErr_SetObject(state.parseerror_obj, error);
    jacpy_release(error);
}

def:priv is_treebuilder(state: ElementTreeState, value: ptr[PyObject]) -> bool {
    return Py_TYPE(value) == state.TreeBuilder_Type;
}

# expat_default_handler(): entity references Expat could not expand.
def expat_default_handler(op: ptr, data_in: ptr[u8], data_len: i32) {
    instance = ptr[PyObject](op);
    if data_len < 2 or int(data_in.view(1)[0]) != 38 {
        return;
    }
    if PyErr_Occurred() {
        return;
    }
    key = decode_utf8(data_in + 1, i64(data_len - 2));
    if not key {
        return;
    }
    value = PyDict_GetItemWithError(xmlparser(instance).view(1)[0].entity, key);
    state = parser_state(instance);
    if value {
        record = xmlparser(instance).view(1);
        result: ptr[PyObject] = NULL;
        if is_treebuilder(state, record[0].target) {
            result = treebuilder_handle_data(record[0].target, value);
        } elif record[0].handle_data {
            result = PyObject_CallOneArg(record[0].handle_data, value);
        }
        jacpy_release(result);
    } elif not PyErr_Occurred() {
        # Report the first error, not the last: "undefined entity " and up to
        # 100 bytes of the reference, as strncat() into a char[128] does.
        message = ptr[u8](PyMem_Malloc(128));
        if not message {
            PyErr_NoMemory();
        } else {
            prefix = "undefined entity ".encode("utf-8");
            for index in range(len(prefix)) {
                (message + index).view(1)[0] = u8(prefix[index]);
            }
            limit = int(data_len) if data_len < 100 else 100;
            count = 0;
            while count < limit and int((data_in + count).view(1)[0]) != 0 {
                (message + (len(prefix) + count)).view(1)[0] = (data_in + count).view(1)[
                    0
                ];
                count += 1;
            }
            (message + (len(prefix) + count)).view(1)[0] = u8(0);
            capi = state.expat_capi.view(1);
            parser = xmlparser(instance).view(1)[0].parser;
            expat_set_error(
                state,
                XML_ERROR_UNDEFINED_ENTITY,
                i64.wrap(capi[0].GetErrorLineNumber(parser)),
                i64.wrap(capi[0].GetErrorColumnNumber(parser)),
                message
            );
            PyMem_Free(ptr(message));
        }
    }
    jacpy_release(key);
}

def expat_start_handler(op: ptr, tag_in: ptr[u8], attrib_in: ptr[ptr[u8]]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    tag = makeuniversal(instance, tag_in);
    if not tag {
        # The parser looks for errors.
        return;
    }
    attrib: ptr[PyObject] = NULL;
    if attrib_in.view(1)[0] {
        attrib = PyDict_New();
        if not attrib {
            jacpy_release(tag);
            return;
        }
        pair = attrib_in;
        while pair.view(1)[0] and (pair + 1).view(1)[0] {
            key = makeuniversal(instance, pair.view(1)[0]);
            if not key {
                jacpy_release(attrib);
                jacpy_release(tag);
                return;
            }
            raw = (pair + 1).view(1)[0];
            value = decode_utf8(raw, i64(strlen(raw)));
            if not value {
                jacpy_release(key);
                jacpy_release(attrib);
                jacpy_release(tag);
                return;
            }
            status = PyDict_SetItem(attrib, key, value);
            jacpy_release(value);
            jacpy_release(key);
            if status < 0 {
                jacpy_release(attrib);
                jacpy_release(tag);
                return;
            }
            pair = pair + 2;
        }
    }
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    result: ptr[PyObject] = NULL;
    if is_treebuilder(state, record[0].target) {
        # The shortcut.
        result = treebuilder_handle_start(record[0].target, tag, attrib);
    } elif record[0].handle_start {
        if not attrib {
            attrib = PyDict_New();
            if not attrib {
                jacpy_release(tag);
                return;
            }
        }
        result = PyObject_CallFunctionObjArgs(
            xmlparser(instance).view(1)[0].handle_start, tag, attrib, NULL
        );
    }
    jacpy_release(tag);
    jacpy_release(attrib);
    jacpy_release(result);
}

def expat_data_handler(op: ptr, data_in: ptr[u8], data_len: i32) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    data = decode_utf8(data_in, i64(data_len));
    if not data {
        return;
    }
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    result: ptr[PyObject] = NULL;
    if is_treebuilder(state, record[0].target) {
        result = treebuilder_handle_data(record[0].target, data);
    } elif record[0].handle_data {
        result = PyObject_CallOneArg(record[0].handle_data, data);
    }
    jacpy_release(data);
    jacpy_release(result);
}

def expat_end_handler(op: ptr, tag_in: ptr[u8]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    result: ptr[PyObject] = NULL;
    if is_treebuilder(state, record[0].target) {
        # The standard tree builder does not look at the end tag.
        result = treebuilder_handle_end(record[0].target, Py_None);
    } elif record[0].handle_end {
        tag = makeuniversal(instance, tag_in);
        if tag {
            result = PyObject_CallOneArg(
                xmlparser(instance).view(1)[0].handle_end, tag
            );
            jacpy_release(tag);
        }
    }
    jacpy_release(result);
}

def expat_start_ns_handler(op: ptr, prefix_in: ptr[u8], uri_in: ptr[u8]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    uri_text = uri_in or empty_text.get();
    prefix_text = prefix_in or empty_text.get();
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    result: ptr[PyObject] = NULL;
    if is_treebuilder(state, record[0].target) {
        # TreeBuilder does not implement start_ns(); report the event.
        target = record[0].target;
        builder = treebuilder(target).view(1);
        if builder[0].events_append and builder[0].start_ns_event_obj {
            prefix = decode_utf8(prefix_text, i64(strlen(prefix_text)));
            if not prefix {
                return;
            }
            uri = decode_utf8(uri_text, i64(strlen(uri_text)));
            if not uri {
                jacpy_release(prefix);
                return;
            }
            result = treebuilder_handle_start_ns(target, prefix, uri);
            jacpy_release(uri);
            jacpy_release(prefix);
        }
    } elif record[0].handle_start_ns {
        prefix = decode_utf8(prefix_text, i64(strlen(prefix_text)));
        if not prefix {
            return;
        }
        uri = decode_utf8(uri_text, i64(strlen(uri_text)));
        if not uri {
            jacpy_release(prefix);
            return;
        }
        result = PyObject_CallFunctionObjArgs(
            xmlparser(instance).view(1)[0].handle_start_ns, prefix, uri, NULL
        );
        jacpy_release(uri);
        jacpy_release(prefix);
    }
    jacpy_release(result);
}

def expat_end_ns_handler(op: ptr, prefix_in: ptr[u8]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    prefix_text = prefix_in or empty_text.get();
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    result: ptr[PyObject] = NULL;
    if is_treebuilder(state, record[0].target) {
        # TreeBuilder does not implement end_ns(); report the event.
        target = record[0].target;
        builder = treebuilder(target).view(1);
        if builder[0].events_append and builder[0].end_ns_event_obj {
            result = treebuilder_handle_end_ns(target, Py_None);
        }
    } elif record[0].handle_end_ns {
        prefix = decode_utf8(prefix_text, i64(strlen(prefix_text)));
        if not prefix {
            return;
        }
        result = PyObject_CallOneArg(
            xmlparser(instance).view(1)[0].handle_end_ns, prefix
        );
        jacpy_release(prefix);
    }
    jacpy_release(result);
}

def expat_comment_handler(op: ptr, comment_in: ptr[u8]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    if is_treebuilder(state, record[0].target) {
        target = record[0].target;
        comment = decode_utf8(comment_in, i64(strlen(comment_in)));
        if not comment {
            return;
        }
        result = treebuilder_handle_comment(target, comment);
        jacpy_release(result);
        jacpy_release(comment);
    } elif record[0].handle_comment {
        comment = decode_utf8(comment_in, i64(strlen(comment_in)));
        if not comment {
            return;
        }
        result = PyObject_CallOneArg(
            xmlparser(instance).view(1)[0].handle_comment, comment
        );
        jacpy_release(result);
        jacpy_release(comment);
    }
}

def expat_start_doctype_handler(
    op: ptr,
    doctype_name: ptr[u8],
    sysid: ptr[u8],
    pubid: ptr[u8],
    has_internal_subset: i32
) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    doctype_name_obj = makeuniversal(instance, doctype_name);
    if not doctype_name_obj {
        return;
    }
    sysid_obj: ptr[PyObject] = NULL;
    if sysid {
        sysid_obj = makeuniversal(instance, sysid);
        if not sysid_obj {
            jacpy_release(doctype_name_obj);
            return;
        }
    } else {
        sysid_obj = Py_NewRef(Py_None);
    }
    pubid_obj: ptr[PyObject] = NULL;
    if pubid {
        pubid_obj = makeuniversal(instance, pubid);
        if not pubid_obj {
            jacpy_release(doctype_name_obj);
            jacpy_release(sysid_obj);
            return;
        }
    } else {
        pubid_obj = Py_NewRef(Py_None);
    }
    state = parser_state(instance);
    handler = xmlparser(instance).view(1)[0].handle_doctype;
    if handler {
        # The target's doctype handler.
        result = PyObject_CallFunctionObjArgs(
            handler, doctype_name_obj, pubid_obj, sysid_obj, NULL
        );
        jacpy_release(result);
    } elif PyObject_HasAttrWithError(instance, state.str_doctype) > 0 {
        PyErr_WarnEx(
            PyExc_RuntimeWarning,
            "The doctype() method of XMLParser is ignored.  Define doctype() method on the TreeBuilder target.",
            1
        );
    }
    jacpy_release(doctype_name_obj);
    jacpy_release(pubid_obj);
    jacpy_release(sysid_obj);
}

def expat_pi_handler(op: ptr, target_in: ptr[u8], data_in: ptr[u8]) {
    instance = ptr[PyObject](op);
    if PyErr_Occurred() {
        return;
    }
    state = parser_state(instance);
    record = xmlparser(instance).view(1);
    if is_treebuilder(state, record[0].target) {
        target = record[0].target;
        builder = treebuilder(target).view(1);
        if (builder[0].events_append and builder[0].pi_event_obj)
            or builder[0].insert_pis {
            pi_target = decode_utf8(target_in, i64(strlen(target_in)));
            if not pi_target {
                return;
            }
            data = decode_utf8(data_in, i64(strlen(data_in)));
            if not data {
                jacpy_release(pi_target);
                return;
            }
            result = treebuilder_handle_pi(target, pi_target, data);
            jacpy_release(result);
            jacpy_release(data);
            jacpy_release(pi_target);
        }
    } elif record[0].handle_pi {
        pi_target = decode_utf8(target_in, i64(strlen(target_in)));
        if not pi_target {
            return;
        }
        data = decode_utf8(data_in, i64(strlen(data_in)));
        if not data {
            jacpy_release(pi_target);
            return;
        }
        result = PyObject_CallFunctionObjArgs(
            xmlparser(instance).view(1)[0].handle_pi, pi_target, data, NULL
        );
        jacpy_release(result);
        jacpy_release(data);
        jacpy_release(pi_target);
    }
}

# ---------------------------------------------------------------- XMLParser

def xmlparser_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    created = jacpy_binding_allocate(type);
    if created {
        # gh-111784: the parser keeps its module alive.
        module = jacpy_binding_owner(type, module_definition.handle);
        xmlparser(created).view(1)[0].elementtree_module = Py_NewRef(module);
    }
    return created;
}

# ignore_attribute_error(): 0 when the lookup succeeded or found nothing.
def:priv ignore_attribute_error(value: ptr[PyObject]) -> i32 {
    if not value {
        if PyErr_ExceptionMatches(PyExc_AttributeError) == 0 {
            return i32(-1);
        }
        PyErr_Clear();
    }
    return i32(0);
}

def:priv parser_field(instance: ptr[PyObject], offset: int) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](int(xmlparser(instance)) + offset);
}

# Offsets of xmlparser_record's handler fields, with the target attribute
# each is looked up by.
glob:priv XP_TARGET: int = 0,
     XP_ENTITY: int = 8,
     XP_NAMES: int = 24,
     XP_MODULE: int = 104,
     XP_HANDLERS: list[tuple[int, str]] = [
         (32, "start_ns"),
         (40, "end_ns"),
         (48, "start"),
         (56, "data"),
         (64, "end"),
         (72, "comment"),
         (80, "pi"),
         (96, "close"),
         (88, "doctype")
     ];

def _elementtree_XMLParser___init___impl(
    receiver: ptr[PyObject], target: ptr[PyObject], encoding: ptr[u8]
) -> i32 {
    entity = PyDict_New();
    if not entity {
        return i32(-1);
    }
    replace_field(parser_field(receiver, XP_ENTITY), entity);
    names = PyDict_New();
    if not names {
        replace_field(parser_field(receiver, XP_ENTITY), NULL);
        return i32(-1);
    }
    replace_field(parser_field(receiver, XP_NAMES), names);
    state = parser_state(receiver);
    capi = state.expat_capi;
    table = capi.view(1);
    parser = table[0].ParserCreate_MM(
        encoding, addressof(expat_memory_suite), namespace_separator.get()
    );
    xmlparser(receiver).view(1)[0].parser = parser;
    if not parser {
        replace_field(parser_field(receiver, XP_ENTITY), NULL);
        replace_field(parser_field(receiver, XP_NAMES), NULL);
        PyErr_NoMemory();
        return i32(-1);
    }
    # 16 bytes of entropy when Expat (2.8.0 and later) takes them (gh-149018).
    if capi_has(capi, CAPI_SET_HASH_SALT_16_BYTES) {
        table[0].SetHashSalt16Bytes(parser, ptr[u8](addressof(_Py_HashSecret)));
    } elif capi_has(capi, CAPI_SET_HASH_SALT) {
        table[0].SetHashSalt(
            parser, u64.wrap(addressof(_Py_HashSecret).view(1)[0].expat_hashsalt)
        );
    }
    if target != Py_None {
        target = Py_NewRef(target);
    } else {
        target = treebuilder_new(state.TreeBuilder_Type, NULL, NULL);
        if not target {
            replace_field(parser_field(receiver, XP_ENTITY), NULL);
            replace_field(parser_field(receiver, XP_NAMES), NULL);
            return i32(-1);
        }
    }
    replace_field(parser_field(receiver, XP_TARGET), target);
    for (offset, name) in XP_HANDLERS {
        handler = PyObject_GetAttrString(target, name);
        replace_field(parser_field(receiver, offset), handler);
        if ignore_attribute_error(handler) {
            return i32(-1);
        }
    }
    # Configure the parser.
    record = xmlparser(receiver).view(1);
    table[0].SetUserData(parser, ptr(receiver));
    if record[0].handle_start_ns or record[0].handle_end_ns {
        table[0].SetNamespaceDeclHandler(
            parser, expat_start_ns_handler, expat_end_ns_handler
        );
    }
    table[0].SetElementHandler(parser, expat_start_handler, expat_end_handler);
    table[0].SetDefaultHandlerExpand(parser, expat_default_handler);
    table[0].SetCharacterDataHandler(parser, expat_data_handler);
    if record[0].handle_comment {
        table[0].SetCommentHandler(parser, expat_comment_handler);
    }
    if record[0].handle_pi {
        table[0].SetProcessingInstructionHandler(parser, expat_pi_handler);
    }
    table[0].SetStartDoctypeDeclHandler(parser, expat_start_doctype_handler);
    table[0].SetUnknownEncodingHandler(
        parser, table[0].DefaultUnknownEncodingHandler, ptr()
    );
    return i32(0);
}

def xmlparser_gc_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    status = visit_reference(Py_TYPE(instance), visitor, context);
    if status != 0 {
        return status;
    }
    for offset in [
        96,
        80,
        72,
        64,
        56,
        48,
        32,
        40,
        88,
        XP_TARGET,
        XP_ENTITY,
        XP_NAMES
    ] {
        status = visit_reference(
            parser_field(instance, offset).view(1)[0], visitor, context
        );
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

def xmlparser_gc_clear(instance: ptr[PyObject]) -> i32 {
    record = xmlparser(instance).view(1);
    if record[0].parser {
        parser = record[0].parser;
        record[0].parser = ptr();
        capi = parser_state(instance).expat_capi;
        if capi {
            capi.view(1)[0].ParserFree(parser);
        }
    }
    for offset in [
        XP_MODULE,
        96,
        80,
        72,
        64,
        56,
        48,
        32,
        40,
        88,
        XP_TARGET,
        XP_ENTITY,
        XP_NAMES
    ] {
        replace_field(parser_field(instance, offset), NULL);
    }
    return i32(0);
}

def xmlparser_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    xmlparser_gc_clear(instance);
    jacpy_binding_free(instance);
}

def:priv check_xmlparser(instance: ptr[PyObject]) -> bool {
    if not xmlparser(instance).view(1)[0].target {
        object_error(PyExc_ValueError, "XMLParser.__init__() wasn't called");
        return False;
    }
    return True;
}

def:priv expat_parse(
    state: ElementTreeState,
    instance: ptr[PyObject],
    data: ptr[u8],
    data_len: i32,
    final: i32
) -> ptr[PyObject] {
    capi = state.expat_capi.view(1);
    parser = xmlparser(instance).view(1)[0].parser;
    ok = capi[0].Parse(parser, data, data_len, final);
    if PyErr_Occurred() {
        return NULL;
    }
    if not ok {
        parser = xmlparser(instance).view(1)[0].parser;
        expat_set_error(
            state,
            capi[0].GetErrorCode(parser),
            i64.wrap(capi[0].GetErrorLineNumber(parser)),
            i64.wrap(capi[0].GetErrorColumnNumber(parser)),
            ptr[u8]()
        );
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _elementtree_XMLParser_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    # No more data for the parser.
    if not check_xmlparser(receiver) {
        return NULL;
    }
    state = parser_state(receiver);
    result = expat_parse(state, receiver, empty_text.get(), 0, 1);
    if not result {
        return NULL;
    }
    record = xmlparser(receiver).view(1);
    if is_treebuilder(state, record[0].target) {
        jacpy_release(result);
        return treebuilder_done(record[0].target);
    }
    if record[0].handle_close {
        jacpy_release(result);
        return PyObject_CallNoArgs(xmlparser(receiver).view(1)[0].handle_close);
    }
    return result;
}

def _elementtree_XMLParser_flush_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not check_xmlparser(receiver) {
        return NULL;
    }
    state = parser_state(receiver);
    capi = state.expat_capi;
    if not capi_has(capi, CAPI_SET_REPARSE_DEFERRAL_ENABLED) {
        return Py_NewRef(Py_None);
    }
    # The parser is private to this object, so reparse deferral is known to be
    # enabled here.
    table = capi.view(1);
    table[0].SetReparseDeferralEnabled(
        xmlparser(receiver).view(1)[0].parser, XML_FALSE
    );
    result = expat_parse(state, receiver, empty_text.get(), 0, 0);
    table[0].SetReparseDeferralEnabled(xmlparser(receiver).view(1)[0].parser, XML_TRUE);
    return result;
}

def _elementtree_XMLParser_feed_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    # Feed data to the parser.
    if not check_xmlparser(receiver) {
        return NULL;
    }
    state = parser_state(receiver);
    if jacpy_is_unicode(data) != 0 {
        size = i64(0);
        text = PyUnicode_AsUTF8AndSize(data, &mut size);
        if not text {
            return NULL;
        }
        if size > INT_MAX {
            object_error(PyExc_OverflowError, "size does not fit in an int");
            return NULL;
        }
        # Explicitly UTF-8; the result is ignored.
        state.expat_capi.view(1)[0].SetEncoding(
            xmlparser(receiver).view(1)[0].parser, utf8_name.get()
        );
        return expat_parse(state, receiver, text, i32(size), 0);
    }
    view = BufferArgument();
    if not view.export(data, 0) {
        return NULL;
    }
    if view.size() > INT_MAX {
        view.close();
        object_error(PyExc_OverflowError, "size does not fit in an int");
        return NULL;
    }
    result = expat_parse(state, receiver, ptr[u8](view.address()), i32(view.size()), 0);
    view.close();
    return result;
}

def _elementtree_XMLParser__parse_whole_impl(
    receiver: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject] {
    # (internal) parse the whole input, until the end of the stream.
    if not check_xmlparser(receiver) {
        return NULL;
    }
    reader = PyObject_GetAttrString(file, "read");
    if not reader {
        return NULL;
    }
    state = parser_state(receiver);
    while True {
        buffer = PyObject_CallFunction(reader, "i", i32(64 * 1024));
        if not buffer {
            # read() failed (a KeyboardInterrupt, say).
            jacpy_release(reader);
            return NULL;
        }
        if jacpy_is_exact_unicode(buffer) != 0 {
            # A str is encoded to UTF-8.
            if PyUnicode_GetLength(buffer) == 0 {
                jacpy_release(buffer);
                break;
            }
            encoded = PyUnicode_AsEncodedString(buffer, "utf-8", "surrogatepass");
            jacpy_release(buffer);
            if not encoded {
                jacpy_release(reader);
                return NULL;
            }
            buffer = encoded;
        } elif Py_TYPE(buffer) != addressof(PyBytes_Type)
            or PyBytes_Size(buffer) == 0 {
            jacpy_release(buffer);
            break;
        }
        if PyBytes_Size(buffer) > INT_MAX {
            jacpy_release(buffer);
            jacpy_release(reader);
            object_error(PyExc_OverflowError, "size does not fit in an int");
            return NULL;
        }
        result = expat_parse(
            state, receiver, PyBytes_AsString(buffer), i32(PyBytes_Size(buffer)), 0
        );
        jacpy_release(buffer);
        if not result {
            jacpy_release(reader);
            return NULL;
        }
        jacpy_release(result);
    }
    jacpy_release(reader);
    result = expat_parse(state, receiver, empty_text.get(), 0, 1);
    if result and is_treebuilder(state, xmlparser(receiver).view(1)[0].target) {
        jacpy_release(result);
        return treebuilder_done(xmlparser(receiver).view(1)[0].target);
    }
    return result;
}

# The C string of an event name (UTF-8 of a str, or a bytes payload); NULL
# for anything else.
def:priv event_name_of(value: ptr[PyObject]) -> ptr[u8] {
    if jacpy_is_unicode(value) != 0 {
        return PyUnicode_AsUTF8(value);
    }
    if jacpy_is_bytes(value) != 0 {
        return PyBytes_AsString(value);
    }
    return ptr[u8]();
}

def _elementtree_XMLParser__setevents_impl(
    receiver: ptr[PyObject],
    events_queue: ptr[PyObject],
    events_to_report: ptr[PyObject]
) -> ptr[PyObject] {
    # Activate element event reporting.
    if not check_xmlparser(receiver) {
        return NULL;
    }
    state = parser_state(receiver);
    target = xmlparser(receiver).view(1)[0].target;
    if not is_treebuilder(state, target) {
        object_error(
            PyExc_TypeError,
            "event handling only supported for ElementTree.TreeBuilder targets"
        );
        return NULL;
    }
    events_append = PyObject_GetAttrString(events_queue, "append");
    if not events_append {
        return NULL;
    }
    replace_field(builder_field(target, TB_EVENTS_APPEND), events_append);
    # Clear out the existing events.
    for offset in [
        TB_START_EVENT,
        TB_END_EVENT,
        TB_START_NS_EVENT,
        TB_END_NS_EVENT,
        TB_COMMENT_EVENT,
        TB_PI_EVENT
    ] {
        replace_field(builder_field(target, offset), NULL);
    }
    if events_to_report == Py_None {
        # The default is "end" only.
        treebuilder(target).view(1)[0].end_event_obj = PyUnicode_FromString("end");
        return Py_NewRef(Py_None);
    }
    sequence = PySequence_Fast(events_to_report, "events must be a sequence");
    if not sequence {
        return NULL;
    }
    capi = state.expat_capi.view(1);
    index = i64(0);
    while index < fast_size(sequence) {
        name_obj = fast_item(sequence, index);
        name = event_name_of(name_obj);
        if not name {
            jacpy_release(sequence);
            PyErr_Format(PyExc_ValueError, "invalid events sequence");
            return NULL;
        }
        parser = xmlparser(receiver).view(1)[0].parser;
        if strcmp(name, "start") == 0 {
            replace_field(builder_field(target, TB_START_EVENT), Py_NewRef(name_obj));
        } elif strcmp(name, "end") == 0 {
            replace_field(builder_field(target, TB_END_EVENT), Py_NewRef(name_obj));
        } elif strcmp(name, "start-ns") == 0 {
            replace_field(
                builder_field(target, TB_START_NS_EVENT), Py_NewRef(name_obj)
            );
            capi[0].SetNamespaceDeclHandler(
                parser, expat_start_ns_handler, expat_end_ns_handler
            );
        } elif strcmp(name, "end-ns") == 0 {
            replace_field(builder_field(target, TB_END_NS_EVENT), Py_NewRef(name_obj));
            capi[0].SetNamespaceDeclHandler(
                parser, expat_start_ns_handler, expat_end_ns_handler
            );
        } elif strcmp(name, "comment") == 0 {
            replace_field(builder_field(target, TB_COMMENT_EVENT), Py_NewRef(name_obj));
            capi[0].SetCommentHandler(parser, expat_comment_handler);
        } elif strcmp(name, "pi") == 0 {
            replace_field(builder_field(target, TB_PI_EVENT), Py_NewRef(name_obj));
            capi[0].SetProcessingInstructionHandler(parser, expat_pi_handler);
        } else {
            PyErr_Format(PyExc_ValueError, "unknown event '%s'", name);
            jacpy_release(sequence);
            return NULL;
        }
        index += 1;
    }
    jacpy_release(sequence);
    return Py_NewRef(Py_None);
}

def xmlparser_version_getter(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    (major, minor, micro) = expat_version();
    return PyUnicode_FromFormat("Expat %d.%d.%d", i32(major), i32(minor), i32(micro));
}

# object(subclass_of='clinic_state()->Element_Type'), with clinic_state() the
# state of the receiver's module.
def subclass_clinic_state_Element_Type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) {
    state = state_by_type(Py_TYPE(receiver));
    if not is_element(state, value) {
        bad_argument(fname, label, ELEMENT_TYPE_NAME, value);
    }
}

# pyexpat's capsule, checked as _elementtree's module_exec() does; the error
# is set and NULL returned when it is not usable.
def import_expat_capi(state: ElementTreeState) -> bool {
    capsule = PyImport_ImportModuleAttrString("pyexpat", "expat_CAPI");
    if not capsule {
        return False;
    }
    state.expat_capsule = capsule;
    capi = ptr[PyExpat_CAPI](
        PyCapsule_GetPointer(capsule, ptr[u8]("pyexpat.expat_CAPI"))
    );
    if not capi {
        return False;
    }
    state.expat_capi = capi;
    table = capi.view(1);
    (major, minor, micro) = expat_version();
    if strcmp(table[0].magic, "pyexpat.expat_CAPI 1.1") != 0
        or table[0].size < 224
        or int(table[0].MAJOR_VERSION) != major
        or int(table[0].MINOR_VERSION) != minor
        or int(table[0].MICRO_VERSION) != micro {
        object_error(PyExc_ImportError, "pyexpat version is incompatible");
        return False;
    }
    return True;
}
