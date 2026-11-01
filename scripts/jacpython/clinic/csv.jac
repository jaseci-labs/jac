"""The Argument Clinic signatures of _csv.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/csv.jac from them. Taken from
the C sources it replaces (Modules/_csv.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_csv",
         version="3.14.6",
         sources=["Modules/_csv.c"],
         functions=[
             Function(
                 name="list_dialects",
                 full_name="_csv.list_dialects",
                 c_basename="_csv_list_dialects",
                 docstring="list_dialects($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of all known dialect names.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="unregister_dialect",
                 full_name="_csv.unregister_dialect",
                 c_basename="_csv_unregister_dialect",
                 docstring="unregister_dialect($module, /, name)\n"
                 "--\n"
                 "\n"
                 "Delete the name/dialect mapping associated with a string name.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="name", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="get_dialect",
                 full_name="_csv.get_dialect",
                 c_basename="_csv_get_dialect",
                 docstring="get_dialect($module, /, name)\n"
                 "--\n"
                 "\n"
                 "Return the dialect instance associated with name.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="name", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="field_size_limit",
                 full_name="_csv.field_size_limit",
                 c_basename="_csv_field_size_limit",
                 docstring="field_size_limit($module, /, new_limit=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Sets an upper limit on parsed fields.\n"
                 "\n"
                 "Returns old limit. If limit is not given, no new limit is set and\n"
                 "the old limit is returned",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="new_limit",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             )
         ],
         docs={
             "dialect_reduce_doc": "raises an exception to avoid pickling",
             "Dialect_Type_doc": "CSV dialect\n"
             "\n"
             "The Dialect type records CSV parsing and generation options.\n",
             "Reader_Type_doc": "CSV reader\n"
             "\n"
             "Reader objects are responsible for reading and parsing tabular data\n"
             "in CSV format.\n",
             "csv_writerow_doc": "writerow($self, row, /)\n"
             "--\n"
             "\n"
             "Construct and write a CSV record from an iterable of fields.\n"
             "\n"
             "Non-string elements will be converted to string.",
             "csv_writerows_doc": "writerows($self, rows, /)\n"
             "--\n"
             "\n"
             "Construct and write a series of iterables to a csv file.\n"
             "\n"
             "Non-string elements will be converted to string.",
             "Writer_Type_doc": "CSV writer\n"
             "\n"
             "Writer objects are responsible for generating tabular data\n"
             "in CSV format from sequence input.\n",
             "csv_module_doc": "CSV parsing and writing.\n",
             "csv_reader_doc": "reader($module, iterable, /, dialect='excel', **fmtparams)\n"
             "--\n"
             "\n"
             "Return a reader object that will process lines from the given iterable.\n"
             "\n"
             "The \"iterable\" argument can be any object that returns a line\n"
             "of input for each iteration, such as a file object or a list.  The\n"
             "optional \"dialect\" argument defines a CSV dialect.  The function\n"
             "also accepts optional keyword arguments which override settings\n"
             "provided by the dialect.\n"
             "\n"
             "The returned object is an iterator.  Each iteration returns a row\n"
             "of the CSV file (which can span multiple input lines).\n",
             "csv_writer_doc": "writer($module, fileobj, /, dialect='excel', **fmtparams)\n"
             "--\n"
             "\n"
             "Return a writer object that will write user data on the given file object.\n"
             "\n"
             "The \"fileobj\" argument can be any object that supports the file API.\n"
             "The optional \"dialect\" argument defines a CSV dialect.  The function\n"
             "also accepts optional keyword arguments which override settings\n"
             "provided by the dialect.\n",
             "csv_register_dialect_doc": "register_dialect($module, name, /, dialect='excel', **fmtparams)\n"
             "--\n"
             "\n"
             "Create a mapping from a string name to a CVS dialect.\n"
             "\n"
             "The optional \"dialect\" argument specifies the base dialect instance\n"
             "or the name of the registered dialect.  The function also accepts\n"
             "optional keyword arguments which override settings provided by the\n"
             "dialect.\n"
         }
     );
