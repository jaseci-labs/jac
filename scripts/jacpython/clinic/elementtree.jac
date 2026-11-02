"""The Argument Clinic signatures of _elementtree.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/elementtree.jac from them. Taken from
CPython 3.14.6 Modules/_elementtree.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_elementtree",
         version="3.14.6",
         sources=["Modules/_elementtree.c"],
         classes={
             "Element": "ElementObject *",
             "TreeBuilder": "TreeBuilderObject *",
             "XMLParser": "XMLParserObject *"
         },
         functions=[
             Function(
                 name="_set_factories",
                 full_name="_elementtree._set_factories",
                 c_basename="_elementtree__set_factories",
                 docstring="_set_factories($module, comment_factory, pi_factory, /)\n"
                 "--\n"
                 "\n"
                 "Change the factories used to create comments and processing instructions.\n"
                 "\n"
                 "For internal use only.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="comment_factory", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="pi_factory", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="append",
                 full_name="_elementtree.Element.append",
                 c_basename="_elementtree_Element_append",
                 cls="Element",
                 docstring="append($self, subelement, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="subelement",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state()->Element_Type"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="clear",
                 full_name="_elementtree.Element.clear",
                 c_basename="_elementtree_Element_clear",
                 cls="Element",
                 docstring="clear($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__copy__",
                 full_name="_elementtree.Element.__copy__",
                 c_basename="_elementtree_Element___copy__",
                 cls="Element",
                 docstring="__copy__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="__deepcopy__",
                 full_name="_elementtree.Element.__deepcopy__",
                 c_basename="_elementtree_Element___deepcopy__",
                 cls="Element",
                 docstring="__deepcopy__($self, memo, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="memo",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyDict_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__sizeof__",
                 full_name="_elementtree.Element.__sizeof__",
                 c_basename="_elementtree_Element___sizeof__",
                 cls="Element",
                 docstring="__sizeof__($self, /)\n" "--",
                 returns="size_t",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__getstate__",
                 full_name="_elementtree.Element.__getstate__",
                 c_basename="_elementtree_Element___getstate__",
                 cls="Element",
                 docstring="__getstate__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__setstate__",
                 full_name="_elementtree.Element.__setstate__",
                 c_basename="_elementtree_Element___setstate__",
                 cls="Element",
                 docstring="__setstate__($self, state, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="state", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="extend",
                 full_name="_elementtree.Element.extend",
                 c_basename="_elementtree_Element_extend",
                 cls="Element",
                 docstring="extend($self, elements, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="elements", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="find",
                 full_name="_elementtree.Element.find",
                 c_basename="_elementtree_Element_find",
                 cls="Element",
                 docstring="find($self, /, path, namespaces=None)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="path", format_unit="O"),
                     Parameter(
                         name="namespaces",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="findtext",
                 full_name="_elementtree.Element.findtext",
                 c_basename="_elementtree_Element_findtext",
                 cls="Element",
                 docstring="findtext($self, /, path, default=None, namespaces=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="path", format_unit="O"),
                     Parameter(
                         name="default",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="namespaces",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="findall",
                 full_name="_elementtree.Element.findall",
                 c_basename="_elementtree_Element_findall",
                 cls="Element",
                 docstring="findall($self, /, path, namespaces=None)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="path", format_unit="O"),
                     Parameter(
                         name="namespaces",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="iterfind",
                 full_name="_elementtree.Element.iterfind",
                 c_basename="_elementtree_Element_iterfind",
                 cls="Element",
                 docstring="iterfind($self, /, path, namespaces=None)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="path", format_unit="O"),
                     Parameter(
                         name="namespaces",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="get",
                 full_name="_elementtree.Element.get",
                 c_basename="_elementtree_Element_get",
                 cls="Element",
                 docstring="get($self, /, key, default=None)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="key", format_unit="O"),
                     Parameter(
                         name="default",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="iter",
                 full_name="_elementtree.Element.iter",
                 c_basename="_elementtree_Element_iter",
                 cls="Element",
                 docstring="iter($self, /, tag=None)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="tag",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="itertext",
                 full_name="_elementtree.Element.itertext",
                 c_basename="_elementtree_Element_itertext",
                 cls="Element",
                 docstring="itertext($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="insert",
                 full_name="_elementtree.Element.insert",
                 c_basename="_elementtree_Element_insert",
                 cls="Element",
                 docstring="insert($self, index, subelement, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="index",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="subelement",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state()->Element_Type"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="items",
                 full_name="_elementtree.Element.items",
                 c_basename="_elementtree_Element_items",
                 cls="Element",
                 docstring="items($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="keys",
                 full_name="_elementtree.Element.keys",
                 c_basename="_elementtree_Element_keys",
                 cls="Element",
                 docstring="keys($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="makeelement",
                 full_name="_elementtree.Element.makeelement",
                 c_basename="_elementtree_Element_makeelement",
                 cls="Element",
                 docstring="makeelement($self, tag, attrib, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="tag", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="attrib",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyDict_Type"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="remove",
                 full_name="_elementtree.Element.remove",
                 c_basename="_elementtree_Element_remove",
                 cls="Element",
                 docstring="remove($self, subelement, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="subelement",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state()->Element_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set",
                 full_name="_elementtree.Element.set",
                 c_basename="_elementtree_Element_set",
                 cls="Element",
                 docstring="set($self, key, value, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__init__",
                 full_name="_elementtree.TreeBuilder.__init__",
                 c_basename="_elementtree_TreeBuilder___init__",
                 kind="METHOD_INIT",
                 cls="TreeBuilder",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="element_factory",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="comment_factory",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="pi_factory",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="insert_comments",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="insert_pis",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="data",
                 full_name="_elementtree.TreeBuilder.data",
                 c_basename="_elementtree_TreeBuilder_data",
                 cls="TreeBuilder",
                 docstring="data($self, data, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="data", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="end",
                 full_name="_elementtree.TreeBuilder.end",
                 c_basename="_elementtree_TreeBuilder_end",
                 cls="TreeBuilder",
                 docstring="end($self, tag, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="tag", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="comment",
                 full_name="_elementtree.TreeBuilder.comment",
                 c_basename="_elementtree_TreeBuilder_comment",
                 cls="TreeBuilder",
                 docstring="comment($self, text, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="text", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pi",
                 full_name="_elementtree.TreeBuilder.pi",
                 c_basename="_elementtree_TreeBuilder_pi",
                 cls="TreeBuilder",
                 docstring="pi($self, target, text=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="target", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="text",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="close",
                 full_name="_elementtree.TreeBuilder.close",
                 c_basename="_elementtree_TreeBuilder_close",
                 cls="TreeBuilder",
                 docstring="close($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="start",
                 full_name="_elementtree.TreeBuilder.start",
                 c_basename="_elementtree_TreeBuilder_start",
                 cls="TreeBuilder",
                 docstring="start($self, tag, attrs, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="tag", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="attrs",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyDict_Type"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__init__",
                 full_name="_elementtree.XMLParser.__init__",
                 c_basename="_elementtree_XMLParser___init__",
                 kind="METHOD_INIT",
                 cls="XMLParser",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="target",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="encoding",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="close",
                 full_name="_elementtree.XMLParser.close",
                 c_basename="_elementtree_XMLParser_close",
                 cls="XMLParser",
                 docstring="close($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="flush",
                 full_name="_elementtree.XMLParser.flush",
                 c_basename="_elementtree_XMLParser_flush",
                 cls="XMLParser",
                 docstring="flush($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="feed",
                 full_name="_elementtree.XMLParser.feed",
                 c_basename="_elementtree_XMLParser_feed",
                 cls="XMLParser",
                 docstring="feed($self, data, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="data", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_parse_whole",
                 full_name="_elementtree.XMLParser._parse_whole",
                 c_basename="_elementtree_XMLParser__parse_whole",
                 cls="XMLParser",
                 docstring="_parse_whole($self, file, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="file", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_setevents",
                 full_name="_elementtree.XMLParser._setevents",
                 c_basename="_elementtree_XMLParser__setevents",
                 cls="XMLParser",
                 docstring="_setevents($self, events_queue, events_to_report=None, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="events_queue", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="events_to_report",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             )
         ],
         docs={
             "element_getsetlist_tag_doc": "A string identifying what kind of data this element represents",
             "element_getsetlist_text_doc": "A string of text directly after the start tag, or None",
             "element_getsetlist_tail_doc": "A string of text directly after the end tag, or None",
             "element_getsetlist_attrib_doc": "A dictionary containing the element's attributes"
         }
     );
