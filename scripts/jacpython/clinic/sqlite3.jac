"""The Argument Clinic signatures of _sqlite3.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/sqlite3.jac from them. Taken from
the C sources it replaces (Modules/_sqlite/blob.c, Modules/_sqlite/connection.c, Modules/_sqlite/cursor.c, Modules/_sqlite/microprotocols.c, Modules/_sqlite/module.c, Modules/_sqlite/prepare_protocol.c, Modules/_sqlite/row.c, Modules/_sqlite/statement.c, Modules/_sqlite/util.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_sqlite3",
         version="3.14.6",
         sources=[
             "Modules/_sqlite/blob.c",
             "Modules/_sqlite/connection.c",
             "Modules/_sqlite/cursor.c",
             "Modules/_sqlite/microprotocols.c",
             "Modules/_sqlite/module.c",
             "Modules/_sqlite/prepare_protocol.c",
             "Modules/_sqlite/row.c",
             "Modules/_sqlite/statement.c",
             "Modules/_sqlite/util.c"
         ],
         classes={
             "Blob": "pysqlite_Blob *",
             "Connection": "pysqlite_Connection *",
             "Cursor": "pysqlite_Cursor *",
             "Row": "pysqlite_Row *"
         },
         functions=[
             Function(
                 name="close",
                 full_name="_sqlite3.Blob.close",
                 c_basename="blob_close",
                 cls="Blob",
                 docstring="close($self, /)\n" "--\n" "\n" "Close the blob.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read",
                 full_name="_sqlite3.Blob.read",
                 c_basename="blob_read",
                 cls="Blob",
                 docstring="read($self, length=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read data at the current offset position.\n"
                 "\n"
                 "  length\n"
                 "    Read length in bytes.\n"
                 "\n"
                 "If the end of the blob is reached, the data up to end of file will\n"
                 "be returned.  When length is not specified, or is negative,\n"
                 "Blob.read() will read until the end of the blob.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="write",
                 full_name="_sqlite3.Blob.write",
                 c_basename="blob_write",
                 cls="Blob",
                 docstring="write($self, data, /)\n"
                 "--\n"
                 "\n"
                 "Write data at the current offset.\n"
                 "\n"
                 "This function cannot change the blob length.  Writing beyond the end\n"
                 "of the blob will result in an exception being raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="seek",
                 full_name="_sqlite3.Blob.seek",
                 c_basename="blob_seek",
                 cls="Blob",
                 docstring="seek($self, offset, origin=0, /)\n"
                 "--\n"
                 "\n"
                 "Set the current access position to offset.\n"
                 "\n"
                 "The origin argument defaults to os.SEEK_SET (absolute blob\n"
                 "positioning).  Other values for origin are os.SEEK_CUR (seek\n"
                 "relative to the current position) and os.SEEK_END (seek relative to\n"
                 "the blob's end).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="origin",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tell",
                 full_name="_sqlite3.Blob.tell",
                 c_basename="blob_tell",
                 cls="Blob",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the current access position for the blob.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__enter__",
                 full_name="_sqlite3.Blob.__enter__",
                 c_basename="blob_enter",
                 cls="Blob",
                 docstring="__enter__($self, /)\n"
                 "--\n"
                 "\n"
                 "Blob context manager enter.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__exit__",
                 full_name="_sqlite3.Blob.__exit__",
                 c_basename="blob_exit",
                 cls="Blob",
                 docstring="__exit__($self, type, val, tb, /)\n"
                 "--\n"
                 "\n"
                 "Blob context manager exit.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="type", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="val", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="tb", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="connect",
                 full_name="_sqlite3.connect",
                 c_basename="pysqlite_connect",
                 docstring="connect($module, /, database, timeout=5.0, detect_types=0,\n"
                 "        isolation_level='', check_same_thread=True,\n"
                 "        factory=ConnectionType, cached_statements=128, uri=False, *,\n"
                 "        autocommit=sqlite3.LEGACY_TRANSACTION_CONTROL)\n"
                 "--\n"
                 "\n"
                 "Open a connection to the SQLite database file 'database'.\n"
                 "\n"
                 "You can use \":memory:\" to open a database connection to a database that\n"
                 "resides in RAM instead of on disk.\n"
                 "\n"
                 "Note: Passing more than 1 positional argument to _sqlite3.connect() is\n"
                 "deprecated. Parameters 'timeout', 'detect_types', 'isolation_level',\n"
                 "'check_same_thread', 'factory', 'cached_statements' and 'uri' will\n"
                 "become keyword-only parameters in Python 3.15.\n",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="database", format_unit="O"),
                     Parameter(
                         name="timeout",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=5.0,
                         c_default="5.0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="detect_types",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="isolation_level",
                         converter="IsolationLevel",
                         type="const char *",
                         format_unit="O&",
                         default_kind="value",
                         py_default="",
                         c_default="\"\"",
                         convert_with="isolation_level_converter",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="check_same_thread",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="factory",
                         format_unit="O",
                         default_kind="unknown",
                         c_default="(PyObject*)clinic_state()->ConnectionType",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="cached_statements",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=128,
                         c_default="128",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="uri",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="autocommit",
                         kind="KEYWORD_ONLY",
                         converter="Autocommit",
                         type="enum autocommit_mode",
                         format_unit="O&",
                         default_kind="unknown",
                         c_default="LEGACY_TRANSACTION_CONTROL",
                         convert_with="autocommit_converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=8,
                 positional_warning="Passing more than 1 positional argument to _sqlite3.connect() is deprecated. Parameters 'timeout', 'detect_types', 'isolation_level', 'check_same_thread', 'factory', 'cached_statements' and 'uri' will become keyword-only parameters in Python 3.15.",
                 bound_by_hand=True
             ),
             Function(
                 name="__init__",
                 full_name="_sqlite3.Connection.__init__",
                 c_basename="pysqlite_connection_init",
                 kind="METHOD_INIT",
                 cls="Connection",
                 docstring="\n"
                 "\n"
                 "Note: Passing more than 1 positional argument to _sqlite3.Connection()\n"
                 "is deprecated. Parameters 'timeout', 'detect_types',\n"
                 "'isolation_level', 'check_same_thread', 'factory', 'cached_statements'\n"
                 "and 'uri' will become keyword-only parameters in Python 3.15.\n",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="database", format_unit="O"),
                     Parameter(
                         name="timeout",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=5.0,
                         c_default="5.0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="detect_types",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="isolation_level",
                         converter="IsolationLevel",
                         type="const char *",
                         format_unit="O&",
                         default_kind="value",
                         py_default="",
                         c_default="\"\"",
                         convert_with="isolation_level_converter",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="check_same_thread",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="factory",
                         format_unit="O",
                         default_kind="unknown",
                         c_default="(PyObject*)clinic_state()->ConnectionType",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="cached_statements",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=128,
                         c_default="128",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="uri",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0",
                         deprecated_positional="3.15"
                     ),
                     Parameter(
                         name="autocommit",
                         kind="KEYWORD_ONLY",
                         converter="Autocommit",
                         type="enum autocommit_mode",
                         format_unit="O&",
                         default_kind="unknown",
                         c_default="LEGACY_TRANSACTION_CONTROL",
                         convert_with="autocommit_converter"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=8,
                 positional_warning="Passing more than 1 positional argument to _sqlite3.Connection() is deprecated. Parameters 'timeout', 'detect_types', 'isolation_level', 'check_same_thread', 'factory', 'cached_statements' and 'uri' will become keyword-only parameters in Python 3.15."
             ),
             Function(
                 name="cursor",
                 full_name="_sqlite3.Connection.cursor",
                 c_basename="pysqlite_connection_cursor",
                 cls="Connection",
                 docstring="cursor($self, /, factory=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Return a cursor for the connection.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="factory",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="blobopen",
                 full_name="_sqlite3.Connection.blobopen",
                 c_basename="blobopen",
                 cls="Connection",
                 docstring="blobopen($self, table, column, rowid, /, *, readonly=False, name='main')\n"
                 "--\n"
                 "\n"
                 "Open and return a BLOB object.\n"
                 "\n"
                 "  table\n"
                 "    Table name.\n"
                 "  column\n"
                 "    Column name.\n"
                 "  rowid\n"
                 "    Row id.\n"
                 "  readonly\n"
                 "    Open the BLOB without write permissions.\n"
                 "  name\n"
                 "    Database name.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="table",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="column",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="rowid",
                         kind="POSITIONAL_ONLY",
                         converter="sqlite3_int64",
                         type="sqlite3_int64",
                         format_unit="O&",
                         convert_with="sqlite3_int64_converter"
                     ),
                     Parameter(
                         name="readonly",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="main",
                         c_default="\"main\""
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="close",
                 full_name="_sqlite3.Connection.close",
                 c_basename="pysqlite_connection_close",
                 cls="Connection",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the database connection.\n"
                 "\n"
                 "Any pending transaction is not committed implicitly.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="commit",
                 full_name="_sqlite3.Connection.commit",
                 c_basename="pysqlite_connection_commit",
                 cls="Connection",
                 docstring="commit($self, /)\n"
                 "--\n"
                 "\n"
                 "Commit any pending transaction to the database.\n"
                 "\n"
                 "If there is no open transaction, this method is a no-op.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="rollback",
                 full_name="_sqlite3.Connection.rollback",
                 c_basename="pysqlite_connection_rollback",
                 cls="Connection",
                 docstring="rollback($self, /)\n"
                 "--\n"
                 "\n"
                 "Roll back to the start of any pending transaction.\n"
                 "\n"
                 "If there is no open transaction, this method is a no-op.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="create_function",
                 full_name="_sqlite3.Connection.create_function",
                 c_basename="pysqlite_connection_create_function",
                 cls="Connection",
                 docstring="create_function($self, /, name, narg, func, *, deterministic=False)\n"
                 "--\n"
                 "\n"
                 "Creates a new function.\n"
                 "\n"
                 "Note: Passing keyword arguments 'name', 'narg' and 'func' to\n"
                 "_sqlite3.Connection.create_function() is deprecated. Parameters\n"
                 "'name', 'narg' and 'func' will become positional-only in Python 3.15.\n",
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
                         name="name",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         deprecated_keyword="3.15"
                     ),
                     Parameter(
                         name="narg",
                         converter="int",
                         type="int",
                         format_unit="i",
                         deprecated_keyword="3.15"
                     ),
                     Parameter(name="func", format_unit="O", deprecated_keyword="3.15"),
                     Parameter(
                         name="deterministic",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 keyword_warning="Passing keyword arguments 'name', 'narg' and 'func' to _sqlite3.Connection.create_function() is deprecated. Parameters 'name', 'narg' and 'func' will become positional-only in Python 3.15."
             ),
             Function(
                 name="create_window_function",
                 full_name="_sqlite3.Connection.create_window_function",
                 c_basename="create_window_function",
                 cls="Connection",
                 docstring="create_window_function($self, name, num_params, aggregate_class, /)\n"
                 "--\n"
                 "\n"
                 "Creates or redefines an aggregate window function. Non-standard.\n"
                 "\n"
                 "  name\n"
                 "    The name of the SQL aggregate window function to be created or\n"
                 "    redefined.\n"
                 "  num_params\n"
                 "    The number of arguments the step and inverse methods takes.\n"
                 "  aggregate_class\n"
                 "    A class with step(), finalize(), value(), and inverse() methods.\n"
                 "    Set to None to clear the window function.",
                 condition="defined(HAVE_WINDOW_FUNCTIONS)",
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
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="num_params",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="aggregate_class", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="create_aggregate",
                 full_name="_sqlite3.Connection.create_aggregate",
                 c_basename="pysqlite_connection_create_aggregate",
                 cls="Connection",
                 docstring="create_aggregate($self, /, name, n_arg, aggregate_class)\n"
                 "--\n"
                 "\n"
                 "Creates a new aggregate.\n"
                 "\n"
                 "Note: Passing keyword arguments 'name', 'n_arg' and 'aggregate_class'\n"
                 "to _sqlite3.Connection.create_aggregate() is deprecated. Parameters\n"
                 "'name', 'n_arg' and 'aggregate_class' will become positional-only in\n"
                 "Python 3.15.\n",
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
                         name="name",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         deprecated_keyword="3.15"
                     ),
                     Parameter(
                         name="n_arg",
                         converter="int",
                         type="int",
                         format_unit="i",
                         deprecated_keyword="3.15"
                     ),
                     Parameter(
                         name="aggregate_class",
                         format_unit="O",
                         deprecated_keyword="3.15"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 keyword_warning="Passing keyword arguments 'name', 'n_arg' and 'aggregate_class' to _sqlite3.Connection.create_aggregate() is deprecated. Parameters 'name', 'n_arg' and 'aggregate_class' will become positional-only in Python 3.15."
             ),
             Function(
                 name="set_authorizer",
                 full_name="_sqlite3.Connection.set_authorizer",
                 c_basename="pysqlite_connection_set_authorizer",
                 cls="Connection",
                 docstring="set_authorizer($self, /, authorizer_callback)\n"
                 "--\n"
                 "\n"
                 "Set authorizer callback.\n"
                 "\n"
                 "Note: Passing keyword argument 'authorizer_callback' to\n"
                 "_sqlite3.Connection.set_authorizer() is deprecated. Parameter\n"
                 "'authorizer_callback' will become positional-only in Python 3.15.\n",
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
                         name="authorizer_callback",
                         format_unit="O",
                         deprecated_keyword="3.15"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 keyword_warning="Passing keyword argument 'authorizer_callback' to _sqlite3.Connection.set_authorizer() is deprecated. Parameter 'authorizer_callback' will become positional-only in Python 3.15."
             ),
             Function(
                 name="set_progress_handler",
                 full_name="_sqlite3.Connection.set_progress_handler",
                 c_basename="pysqlite_connection_set_progress_handler",
                 cls="Connection",
                 docstring="set_progress_handler($self, /, progress_handler, n)\n"
                 "--\n"
                 "\n"
                 "Set progress handler callback.\n"
                 "\n"
                 "  progress_handler\n"
                 "    A callable that takes no arguments.\n"
                 "    If the callable returns non-zero, the current query is\n"
                 "    terminated, and an exception is raised.\n"
                 "  n\n"
                 "    The number of SQLite virtual machine instructions that are\n"
                 "    executed between invocations of 'progress_handler'.\n"
                 "\n"
                 "If 'progress_handler' is None or 'n' is 0, the progress handler is\n"
                 "disabled.\n"
                 "\n"
                 "Note: Passing keyword argument 'progress_handler' to\n"
                 "_sqlite3.Connection.set_progress_handler() is deprecated. Parameter\n"
                 "'progress_handler' will become positional-only in Python 3.15.\n",
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
                         name="progress_handler",
                         format_unit="O",
                         deprecated_keyword="3.15"
                     ),
                     Parameter(name="n", converter="int", type="int", format_unit="i")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 keyword_warning="Passing keyword argument 'progress_handler' to _sqlite3.Connection.set_progress_handler() is deprecated. Parameter 'progress_handler' will become positional-only in Python 3.15."
             ),
             Function(
                 name="set_trace_callback",
                 full_name="_sqlite3.Connection.set_trace_callback",
                 c_basename="pysqlite_connection_set_trace_callback",
                 cls="Connection",
                 docstring="set_trace_callback($self, /, trace_callback)\n"
                 "--\n"
                 "\n"
                 "Set a trace callback called for each SQL statement (passed as unicode).\n"
                 "\n"
                 "Note: Passing keyword argument 'trace_callback' to\n"
                 "_sqlite3.Connection.set_trace_callback() is deprecated. Parameter\n"
                 "'trace_callback' will become positional-only in Python 3.15.\n",
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
                         name="trace_callback",
                         format_unit="O",
                         deprecated_keyword="3.15"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 keyword_warning="Passing keyword argument 'trace_callback' to _sqlite3.Connection.set_trace_callback() is deprecated. Parameter 'trace_callback' will become positional-only in Python 3.15."
             ),
             Function(
                 name="enable_load_extension",
                 full_name="_sqlite3.Connection.enable_load_extension",
                 c_basename="pysqlite_connection_enable_load_extension",
                 cls="Connection",
                 docstring="enable_load_extension($self, enable, /)\n"
                 "--\n"
                 "\n"
                 "Enable dynamic loading of SQLite extension modules.",
                 condition="defined(PY_SQLITE_ENABLE_LOAD_EXTENSION)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="enable",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="load_extension",
                 full_name="_sqlite3.Connection.load_extension",
                 c_basename="pysqlite_connection_load_extension",
                 cls="Connection",
                 docstring="load_extension($self, name, /, *, entrypoint=None)\n"
                 "--\n"
                 "\n"
                 "Load SQLite extension module.",
                 condition="defined(PY_SQLITE_ENABLE_LOAD_EXTENSION)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="entrypoint",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="execute",
                 full_name="_sqlite3.Connection.execute",
                 c_basename="pysqlite_connection_execute",
                 cls="Connection",
                 docstring="execute($self, sql, parameters=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Executes an SQL statement.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="parameters",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="executemany",
                 full_name="_sqlite3.Connection.executemany",
                 c_basename="pysqlite_connection_executemany",
                 cls="Connection",
                 docstring="executemany($self, sql, parameters, /)\n"
                 "--\n"
                 "\n"
                 "Repeatedly executes an SQL statement.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="parameters", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="executescript",
                 full_name="_sqlite3.Connection.executescript",
                 c_basename="pysqlite_connection_executescript",
                 cls="Connection",
                 docstring="executescript($self, sql_script, /)\n"
                 "--\n"
                 "\n"
                 "Executes multiple SQL statements at once.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql_script", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="interrupt",
                 full_name="_sqlite3.Connection.interrupt",
                 c_basename="pysqlite_connection_interrupt",
                 cls="Connection",
                 docstring="interrupt($self, /)\n"
                 "--\n"
                 "\n"
                 "Abort any pending database operation.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="iterdump",
                 full_name="_sqlite3.Connection.iterdump",
                 c_basename="pysqlite_connection_iterdump",
                 cls="Connection",
                 docstring="iterdump($self, /, *, filter=None)\n"
                 "--\n"
                 "\n"
                 "Returns iterator to the dump of the database in an SQL text format.\n"
                 "\n"
                 "  filter\n"
                 "    An optional LIKE pattern for database objects to dump",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="filter",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="backup",
                 full_name="_sqlite3.Connection.backup",
                 c_basename="pysqlite_connection_backup",
                 cls="Connection",
                 docstring="backup($self, /, target, *, pages=-1, progress=None, name='main',\n"
                 "       sleep=0.25)\n"
                 "--\n"
                 "\n"
                 "Makes a backup of the database.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="target",
                         type="pysqlite_Connection *",
                         format_unit="O!",
                         subclass_of="clinic_state()->ConnectionType"
                     ),
                     Parameter(
                         name="pages",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     ),
                     Parameter(
                         name="progress",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="main",
                         c_default="\"main\""
                     ),
                     Parameter(
                         name="sleep",
                         kind="KEYWORD_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=0.25,
                         c_default="0.25"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="create_collation",
                 full_name="_sqlite3.Connection.create_collation",
                 c_basename="pysqlite_connection_create_collation",
                 cls="Connection",
                 docstring="create_collation($self, name, callback, /)\n"
                 "--\n"
                 "\n"
                 "Creates a collation function.",
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
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(name="callback", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="serialize",
                 full_name="_sqlite3.Connection.serialize",
                 c_basename="serialize",
                 cls="Connection",
                 docstring="serialize($self, /, *, name='main')\n"
                 "--\n"
                 "\n"
                 "Serialize a database into a byte string.\n"
                 "\n"
                 "  name\n"
                 "    Which database to serialize.\n"
                 "\n"
                 "For an ordinary on-disk database file, the serialization is just\n"
                 "a copy of the disk file.  For an in-memory database or a \"temp\"\n"
                 "database, the serialization is the same sequence of bytes which\n"
                 "would be written to disk if that database were backed up to disk.",
                 condition="defined(PY_SQLITE_HAVE_SERIALIZE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="main",
                         c_default="\"main\""
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="deserialize",
                 full_name="_sqlite3.Connection.deserialize",
                 c_basename="deserialize",
                 cls="Connection",
                 docstring="deserialize($self, data, /, *, name='main')\n"
                 "--\n"
                 "\n"
                 "Load a serialized database.\n"
                 "\n"
                 "  data\n"
                 "    The serialized database content.\n"
                 "  name\n"
                 "    Which database to reopen with the deserialization.\n"
                 "\n"
                 "The deserialize interface causes the database connection to\n"
                 "disconnect from the target database, and then reopen it as\n"
                 "an in-memory database based on the given serialized data.\n"
                 "\n"
                 "The deserialize interface will fail with SQLITE_BUSY if the database\n"
                 "is currently in a read transaction or is involved in a backup\n"
                 "operation.",
                 condition="defined(PY_SQLITE_HAVE_SERIALIZE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="s*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="main",
                         c_default="\"main\""
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__enter__",
                 full_name="_sqlite3.Connection.__enter__",
                 c_basename="pysqlite_connection_enter",
                 cls="Connection",
                 docstring="__enter__($self, /)\n"
                 "--\n"
                 "\n"
                 "Called when the connection is used as a context manager.\n"
                 "\n"
                 "Returns itself as a convenience to the caller.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__exit__",
                 full_name="_sqlite3.Connection.__exit__",
                 c_basename="pysqlite_connection_exit",
                 cls="Connection",
                 docstring="__exit__($self, type, value, traceback, /)\n"
                 "--\n"
                 "\n"
                 "Called when the connection is used as a context manager.\n"
                 "\n"
                 "If there was any exception, a rollback takes place; otherwise we\n"
                 "commit.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="type", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="traceback", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="setlimit",
                 full_name="_sqlite3.Connection.setlimit",
                 c_basename="setlimit",
                 cls="Connection",
                 docstring="setlimit($self, category, limit, /)\n"
                 "--\n"
                 "\n"
                 "Set connection run-time limits.\n"
                 "\n"
                 "  category\n"
                 "    The limit category to be set.\n"
                 "  limit\n"
                 "    The new limit. If the new limit is a negative number, the limit\n"
                 "    is unchanged.\n"
                 "\n"
                 "Attempts to increase a limit above its hard upper bound are silently\n"
                 "truncated to the hard upper bound. Regardless of whether or not the\n"
                 "limit was changed, the prior value of the limit is returned.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="category",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="limit",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getlimit",
                 full_name="_sqlite3.Connection.getlimit",
                 c_basename="getlimit",
                 cls="Connection",
                 docstring="getlimit($self, category, /)\n"
                 "--\n"
                 "\n"
                 "Get connection run-time limits.\n"
                 "\n"
                 "  category\n"
                 "    The limit category to be queried.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="category",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setconfig",
                 full_name="_sqlite3.Connection.setconfig",
                 c_basename="setconfig",
                 cls="Connection",
                 docstring="setconfig($self, op, enable=True, /)\n"
                 "--\n"
                 "\n"
                 "Set a boolean connection configuration option.\n"
                 "\n"
                 "  op\n"
                 "    The configuration verb; one of the sqlite3.SQLITE_DBCONFIG codes.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="op",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="enable",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getconfig",
                 full_name="_sqlite3.Connection.getconfig",
                 c_basename="getconfig",
                 cls="Connection",
                 docstring="getconfig($self, op, /)\n"
                 "--\n"
                 "\n"
                 "Query a boolean connection configuration option.\n"
                 "\n"
                 "  op\n"
                 "    The configuration verb; one of the sqlite3.SQLITE_DBCONFIG codes.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="op",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__init__",
                 full_name="_sqlite3.Cursor.__init__",
                 c_basename="pysqlite_cursor_init",
                 kind="METHOD_INIT",
                 cls="Cursor",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="connection",
                         kind="POSITIONAL_ONLY",
                         type="pysqlite_Connection *",
                         format_unit="O!",
                         subclass_of="clinic_state()->ConnectionType"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             ),
             Function(
                 name="execute",
                 full_name="_sqlite3.Cursor.execute",
                 c_basename="pysqlite_cursor_execute",
                 cls="Cursor",
                 docstring="execute($self, sql, parameters=(), /)\n"
                 "--\n"
                 "\n"
                 "Executes an SQL statement.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="parameters",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="executemany",
                 full_name="_sqlite3.Cursor.executemany",
                 c_basename="pysqlite_cursor_executemany",
                 cls="Cursor",
                 docstring="executemany($self, sql, seq_of_parameters, /)\n"
                 "--\n"
                 "\n"
                 "Repeatedly executes an SQL statement.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="seq_of_parameters",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="executescript",
                 full_name="_sqlite3.Cursor.executescript",
                 c_basename="pysqlite_cursor_executescript",
                 cls="Cursor",
                 docstring="executescript($self, sql_script, /)\n"
                 "--\n"
                 "\n"
                 "Executes multiple SQL statements at once.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sql_script",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="fetchone",
                 full_name="_sqlite3.Cursor.fetchone",
                 c_basename="pysqlite_cursor_fetchone",
                 cls="Cursor",
                 docstring="fetchone($self, /)\n"
                 "--\n"
                 "\n"
                 "Fetches one row from the resultset.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fetchmany",
                 full_name="_sqlite3.Cursor.fetchmany",
                 c_basename="pysqlite_cursor_fetchmany",
                 cls="Cursor",
                 docstring="fetchmany($self, /, size=1)\n"
                 "--\n"
                 "\n"
                 "Fetches several rows from the resultset.\n"
                 "\n"
                 "  size\n"
                 "    The default value is set by the Cursor.arraysize attribute.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         converter="uint32",
                         type="uint32_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=1,
                         c_default="((pysqlite_Cursor *)self)->arraysize",
                         convert_with="_PyLong_UInt32_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="fetchall",
                 full_name="_sqlite3.Cursor.fetchall",
                 c_basename="pysqlite_cursor_fetchall",
                 cls="Cursor",
                 docstring="fetchall($self, /)\n"
                 "--\n"
                 "\n"
                 "Fetches all rows from the resultset.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setinputsizes",
                 full_name="_sqlite3.Cursor.setinputsizes",
                 c_basename="pysqlite_cursor_setinputsizes",
                 cls="Cursor",
                 docstring="setinputsizes($self, sizes, /)\n"
                 "--\n"
                 "\n"
                 "Required by DB-API. Does nothing in sqlite3.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="sizes", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setoutputsize",
                 full_name="_sqlite3.Cursor.setoutputsize",
                 c_basename="pysqlite_cursor_setoutputsize",
                 cls="Cursor",
                 docstring="setoutputsize($self, size, column=None, /)\n"
                 "--\n"
                 "\n"
                 "Required by DB-API. Does nothing in sqlite3.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="size", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="column",
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
                 full_name="_sqlite3.Cursor.close",
                 c_basename="pysqlite_cursor_close",
                 cls="Cursor",
                 docstring="close($self, /)\n" "--\n" "\n" "Closes the cursor.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="arraysize",
                 full_name="_sqlite3.Cursor.arraysize",
                 c_basename="_sqlite3_Cursor_arraysize",
                 kind="GETTER",
                 cls="Cursor",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="arraysize",
                 full_name="_sqlite3.Cursor.arraysize",
                 c_basename="_sqlite3_Cursor_arraysize",
                 kind="SETTER",
                 cls="Cursor",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="complete_statement",
                 full_name="_sqlite3.complete_statement",
                 c_basename="pysqlite_complete_statement",
                 docstring="complete_statement($module, /, statement)\n"
                 "--\n"
                 "\n"
                 "Checks if a string contains a complete SQL statement.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="statement",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="register_adapter",
                 full_name="_sqlite3.register_adapter",
                 c_basename="pysqlite_register_adapter",
                 docstring="register_adapter($module, type, adapter, /)\n"
                 "--\n"
                 "\n"
                 "Register a function to adapt Python objects to SQLite values.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="type",
                         kind="POSITIONAL_ONLY",
                         type="PyTypeObject *",
                         format_unit="O"
                     ),
                     Parameter(name="adapter", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="register_converter",
                 full_name="_sqlite3.register_converter",
                 c_basename="pysqlite_register_converter",
                 docstring="register_converter($module, typename, converter, /)\n"
                 "--\n"
                 "\n"
                 "Register a function to convert SQLite values to Python objects.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="typename",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="converter", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="enable_callback_tracebacks",
                 full_name="_sqlite3.enable_callback_tracebacks",
                 c_basename="pysqlite_enable_callback_trace",
                 docstring="enable_callback_tracebacks($module, enable, /)\n"
                 "--\n"
                 "\n"
                 "Enable or disable callback functions throwing errors to stderr.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="enable",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="adapt",
                 full_name="_sqlite3.adapt",
                 c_basename="pysqlite_adapt",
                 docstring="adapt($module, obj, proto=PrepareProtocolType, alt=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Adapt given object to given protocol.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="proto",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="unknown",
                         c_default="(PyObject *)clinic_state()->PrepareProtocolType"
                     ),
                     Parameter(
                         name="alt",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="__new__",
                 full_name="_sqlite3.Row.__new__",
                 c_basename="pysqlite_row_new",
                 kind="METHOD_NEW",
                 cls="Row",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cursor",
                         kind="POSITIONAL_ONLY",
                         type="pysqlite_Cursor *",
                         format_unit="O!",
                         subclass_of="clinic_state()->CursorType"
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="keys",
                 full_name="_sqlite3.Row.keys",
                 c_basename="pysqlite_row_keys",
                 cls="Row",
                 docstring="keys($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns the keys of the row.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             )
         ],
         docs={"doc": "PEP 246 style object adaption protocol type."}
     );
