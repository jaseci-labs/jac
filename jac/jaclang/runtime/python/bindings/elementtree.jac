"""The _elementtree module: Element, SubElement, TreeBuilder, XMLParser,
ParseError and the element iterator."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_SyntaxError,
    PyImport_ImportModule,
    PyImport_ImportModuleAttrString,
    PyModule_AddObjectRef,
    PyObject,
    PyObject_GenericGetAttr,
    PyUnicode_InternFromString
}
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
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
import from jaclang.runtime.python.bindings.clinic.elementtree {
    Element_methods,
    TreeBuilder_methods,
    XMLParser_methods,
    _elementtree_TreeBuilder___init___init,
    _elementtree_XMLParser___init___init,
    module_methods
}
import from jaclang.runtime.python.modules.elementtree {
    ELEMENT_ITER_RECORD_SIZE,
    ELEMENT_RECORD_SIZE,
    ELEMENT_TYPE_NAME,
    ElementIter_token,
    ElementTreeState,
    Element_token,
    TREEBUILDER_RECORD_SIZE,
    TreeBuilder_token,
    XMLPARSER_MEMBERS,
    XMLPARSER_RECORD_SIZE,
    XMLParser_token,
    element_ass_subscr,
    element_attrib_getter,
    element_attrib_setter,
    element_bool,
    element_dealloc,
    element_gc_clear,
    element_gc_traverse,
    element_getitem,
    element_init,
    element_length,
    element_new,
    element_repr,
    element_setitem,
    element_subscr,
    element_tag_getter,
    element_tag_setter,
    element_tail_getter,
    element_tail_setter,
    element_text_getter,
    element_text_setter,
    elementiter_dealloc,
    elementiter_next,
    elementiter_self,
    elementiter_traverse,
    import_expat_capi,
    module_definition,
    subelement,
    treebuilder_dealloc,
    treebuilder_gc_clear,
    treebuilder_gc_traverse,
    treebuilder_new,
    xmlparser_dealloc,
    xmlparser_gc_clear,
    xmlparser_gc_traverse,
    xmlparser_new,
    xmlparser_version_getter
}

# element_methods, in _elementtree.c's order.
glob:priv ELEMENT_METHOD_ORDER: list[str] = [
         "clear",
         "get",
         "set",
         "find",
         "findtext",
         "findall",
         "append",
         "extend",
         "insert",
         "remove",
         "iter",
         "itertext",
         "iterfind",
         "items",
         "keys",
         "makeelement",
         "__copy__",
         "__deepcopy__",
         "__sizeof__",
         "__getstate__",
         "__setstate__"
     ],
     TREEBUILDER_METHOD_ORDER: list[str] = [
         "data",
         "start",
         "end",
         "comment",
         "pi",
         "close"
     ],
     XMLPARSER_METHOD_ORDER: list[str] = [
         "feed",
         "close",
         "flush",
         "_parse_whole",
         "_setevents"
     ];

def:priv ordered(
    methods: list[MethodDefinition], order: list[str]
) -> list[MethodDefinition] {
    result: list[MethodDefinition] = [];
    for name in order {
        for method in methods {
            if method.name == name {
                result.append(method);
            }
        }
    }
    return result;
}

glob:priv GC_IMMUTABLE: u64 = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     element_type = TypeDefinition(
         ELEMENT_TYPE_NAME,
         "",
         ordered(Element_methods, ELEMENT_METHOD_ORDER),
         GC_IMMUTABLE | u64(TypeFlags.BASETYPE.value | TypeFlags.MANAGED_WEAKREF.value),
         TypeHooks(
             create=element_new,
             initialize=element_init,
             dealloc=element_dealloc,
             traverse=element_gc_traverse,
             clear=element_gc_clear,
             repr=element_repr,
             get_attribute=PyObject_GenericGetAttr,
             length=element_length,
             item=element_getitem,
             assign=element_setitem,
             boolean=element_bool,
             mapping_length=element_length,
             subscript=element_subscr,
             assign_subscript=element_ass_subscr
         ),
         [
             PropertyDefinition(
                 "tag",
                 PropertyCallbacks(read=element_tag_getter, write=element_tag_setter),
                 doc="A string identifying what kind of data this element represents"
             ),
             PropertyDefinition(
                 "text",
                 PropertyCallbacks(read=element_text_getter, write=element_text_setter),
                 doc="A string of text directly after the start tag, or None"
             ),
             PropertyDefinition(
                 "tail",
                 PropertyCallbacks(read=element_tail_getter, write=element_tail_setter),
                 doc="A string of text directly after the end tag, or None"
             ),
             PropertyDefinition(
                 "attrib",
                 PropertyCallbacks(
                     read=element_attrib_getter, write=element_attrib_setter
                 ),
                 doc="A dictionary containing the element's attributes"
             )
         ],
         record_size=ELEMENT_RECORD_SIZE
     ),
     # The module's name, since the pure-Python implementation has no such
     # type.
     element_iter_type = TypeDefinition(
         "_elementtree._element_iterator",
         "",
         [],
         GC_IMMUTABLE | u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(
             dealloc=elementiter_dealloc,
             traverse=elementiter_traverse,
             iter=elementiter_self,
             next=elementiter_next
         ),
         record_size=ELEMENT_ITER_RECORD_SIZE
     ),
     treebuilder_type = TypeDefinition(
         "xml.etree.ElementTree.TreeBuilder",
         "",
         ordered(TreeBuilder_methods, TREEBUILDER_METHOD_ORDER),
         GC_IMMUTABLE | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=treebuilder_new,
             initialize=_elementtree_TreeBuilder___init___init,
             dealloc=treebuilder_dealloc,
             traverse=treebuilder_gc_traverse,
             clear=treebuilder_gc_clear
         ),
         record_size=TREEBUILDER_RECORD_SIZE
     ),
     xmlparser_type = TypeDefinition(
         "xml.etree.ElementTree.XMLParser",
         "",
         ordered(XMLParser_methods, XMLPARSER_METHOD_ORDER),
         GC_IMMUTABLE | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=xmlparser_new,
             initialize=_elementtree_XMLParser___init___init,
             dealloc=xmlparser_dealloc,
             traverse=xmlparser_gc_traverse,
             clear=xmlparser_gc_clear
         ),
         [
             PropertyDefinition(
                 "version", PropertyCallbacks(read=xmlparser_version_getter)
             )
         ],
         members=XMLPARSER_MEMBERS,
         record_size=XMLPARSER_RECORD_SIZE
     );

def:priv interned(name: str) -> ptr[PyObject] {
    return PyUnicode_InternFromString(name);
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    module_definition.handle = definition.handle;
    Element_token.handle = element_type.handle;
    ElementIter_token.handle = element_iter_type.handle;
    TreeBuilder_token.handle = treebuilder_type.handle;
    XMLParser_token.handle = xmlparser_type.handle;
    state = ElementTreeState();
    jacpy_binding_module_native_set(module, state);
    # The object types.
    state.ElementIter_Type = element_iter_type.create(module);
    if not state.ElementIter_Type {
        return i32(-1);
    }
    state.TreeBuilder_Type = treebuilder_type.create(module);
    if not state.TreeBuilder_Type {
        return i32(-1);
    }
    state.Element_Type = element_type.create(module);
    if not state.Element_Type {
        return i32(-1);
    }
    state.XMLParser_Type = xmlparser_type.create(module);
    if not state.XMLParser_Type {
        return i32(-1);
    }
    state.deepcopy_obj = PyImport_ImportModuleAttrString("copy", "deepcopy");
    if not state.deepcopy_obj {
        return i32(-1);
    }
    state.elementpath_obj = PyImport_ImportModule("xml.etree.ElementPath");
    if not state.elementpath_obj {
        return i32(-1);
    }
    # Link against pyexpat.
    if not import_expat_capi(state) {
        return i32(-1);
    }
    state.str_append = interned("append");
    state.str_find = interned("find");
    state.str_findall = interned("findall");
    state.str_findtext = interned("findtext");
    state.str_iterfind = interned("iterfind");
    state.str_tail = interned("tail");
    state.str_text = interned("text");
    state.str_doctype = interned("doctype");
    if not state.str_append
        or not state.str_find
        or not state.str_findall
        or not state.str_findtext
        or not state.str_iterfind
        or not state.str_tail
        or not state.str_text
        or not state.str_doctype {
        return i32(-1);
    }
    state.parseerror_obj = jacpy_binding_exception(
        "xml.etree.ElementTree.ParseError", PyExc_SyntaxError, ""
    );
    if PyModule_AddObjectRef(module, "ParseError", state.parseerror_obj) < 0 {
        return i32(-1);
    }
    for (name, type) in [
        ("Element", state.Element_Type),
        ("TreeBuilder", state.TreeBuilder_Type),
        ("XMLParser", state.XMLParser_Type)
    ] {
        if PyModule_AddObjectRef(module, name, type) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv methods: list[MethodDefinition] = [
         MethodDefinition("SubElement", MethodCallbacks(keywords=subelement), "", 3)
     ]
         + module_methods,
     definition = ModuleDefinition(
         "_elementtree", "", methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__elementtree -> ptr[PyObject] {
    return definition.initialize();
}
