"""The Argument Clinic signatures of _multiprocessing.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/multiprocessing.jac from them. Taken from
the C sources it replaces (Modules/_multiprocessing/multiprocessing.c, Modules/_multiprocessing/semaphore.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_multiprocessing",
         version="3.14.6",
         sources=[
             "Modules/_multiprocessing/multiprocessing.c",
             "Modules/_multiprocessing/semaphore.c"
         ],
         classes={"SemLock": "SemLockObject *"},
         functions=[
             Function(
                 name="closesocket",
                 full_name="_multiprocessing.closesocket",
                 c_basename="_multiprocessing_closesocket",
                 docstring="closesocket($module, handle, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="HANDLE",
                         type="HANDLE",
                         format_unit="\"F_HANDLE\""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="recv",
                 full_name="_multiprocessing.recv",
                 c_basename="_multiprocessing_recv",
                 docstring="recv($module, handle, size, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="HANDLE",
                         type="HANDLE",
                         format_unit="\"F_HANDLE\""
                     ),
                     Parameter(
                         name="size",
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
                 name="send",
                 full_name="_multiprocessing.send",
                 c_basename="_multiprocessing_send",
                 docstring="send($module, handle, buf, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="HANDLE",
                         type="HANDLE",
                         format_unit="\"F_HANDLE\""
                     ),
                     Parameter(
                         name="buf",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sem_unlink",
                 full_name="_multiprocessing.sem_unlink",
                 c_basename="_multiprocessing_sem_unlink",
                 docstring="sem_unlink($module, name, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
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
                 name="acquire",
                 full_name="_multiprocessing.SemLock.acquire",
                 c_basename="_multiprocessing_SemLock_acquire",
                 cls="SemLock",
                 docstring="acquire($self, /, block=True, timeout=None)\n"
                 "--\n"
                 "\n"
                 "Acquire the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE) && defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="block",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="timeout",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="release",
                 full_name="_multiprocessing.SemLock.release",
                 c_basename="_multiprocessing_SemLock_release",
                 cls="SemLock",
                 docstring="release($self, /)\n"
                 "--\n"
                 "\n"
                 "Release the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE) && defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="acquire",
                 full_name="_multiprocessing.SemLock.acquire",
                 c_basename="_multiprocessing_SemLock_acquire",
                 cls="SemLock",
                 docstring="acquire($self, /, block=True, timeout=None)\n"
                 "--\n"
                 "\n"
                 "Acquire the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE) && !defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="block",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="timeout",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="release",
                 full_name="_multiprocessing.SemLock.release",
                 c_basename="_multiprocessing_SemLock_release",
                 cls="SemLock",
                 docstring="release($self, /)\n"
                 "--\n"
                 "\n"
                 "Release the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE) && !defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__new__",
                 full_name="_multiprocessing.SemLock.__new__",
                 c_basename="_multiprocessing_SemLock",
                 kind="METHOD_NEW",
                 cls="SemLock",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="kind", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="value", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="maxvalue", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="name",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="unlink", converter="bool", type="int", format_unit="p"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=5,
                 max_pos=5
             ),
             Function(
                 name="_rebuild",
                 full_name="_multiprocessing.SemLock._rebuild",
                 c_basename="_multiprocessing_SemLock__rebuild",
                 kind="CLASS_METHOD",
                 cls="SemLock",
                 docstring="_rebuild($type, handle, kind, maxvalue, name, /)\n" "--",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="SEM_HANDLE",
                         type="SEM_HANDLE",
                         format_unit="\"F_SEM_HANDLE\""
                     ),
                     Parameter(
                         name="kind",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="maxvalue",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     )
                 ],
                 flags="METH_FASTCALL|METH_CLASS",
                 parser="PARSE_FORMAT",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="_count",
                 full_name="_multiprocessing.SemLock._count",
                 c_basename="_multiprocessing_SemLock__count",
                 cls="SemLock",
                 docstring="_count($self, /)\n"
                 "--\n"
                 "\n"
                 "Num of `acquire()`s minus num of `release()`s for this process.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_is_mine",
                 full_name="_multiprocessing.SemLock._is_mine",
                 c_basename="_multiprocessing_SemLock__is_mine",
                 cls="SemLock",
                 docstring="_is_mine($self, /)\n"
                 "--\n"
                 "\n"
                 "Whether the lock is owned by this thread.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_get_value",
                 full_name="_multiprocessing.SemLock._get_value",
                 c_basename="_multiprocessing_SemLock__get_value",
                 cls="SemLock",
                 docstring="_get_value($self, /)\n"
                 "--\n"
                 "\n"
                 "Get the value of the semaphore.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_is_zero",
                 full_name="_multiprocessing.SemLock._is_zero",
                 c_basename="_multiprocessing_SemLock__is_zero",
                 cls="SemLock",
                 docstring="_is_zero($self, /)\n"
                 "--\n"
                 "\n"
                 "Return whether semaphore has value zero.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_after_fork",
                 full_name="_multiprocessing.SemLock._after_fork",
                 c_basename="_multiprocessing_SemLock__after_fork",
                 cls="SemLock",
                 docstring="_after_fork($self, /)\n"
                 "--\n"
                 "\n"
                 "Rezero the net acquisition count after fork().",
                 condition="defined(HAVE_MP_SEMAPHORE)",
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
                 full_name="_multiprocessing.SemLock.__enter__",
                 c_basename="_multiprocessing_SemLock___enter__",
                 cls="SemLock",
                 docstring="__enter__($self, /)\n"
                 "--\n"
                 "\n"
                 "Enter the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
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
                 full_name="_multiprocessing.SemLock.__exit__",
                 c_basename="_multiprocessing_SemLock___exit__",
                 cls="SemLock",
                 docstring="__exit__($self, exc_type=None, exc_value=None, exc_tb=None, /)\n"
                 "--\n"
                 "\n"
                 "Exit the semaphore/lock.",
                 condition="defined(HAVE_MP_SEMAPHORE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="exc_type",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="exc_value",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="exc_tb",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=3,
                 pos_only=3
             )
         ],
         docs={
             "semlock_members_handle_doc": "",
             "semlock_members_kind_doc": "",
             "semlock_members_maxvalue_doc": "",
             "semlock_members_name_doc": ""
         }
     );
