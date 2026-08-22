"""Differential oracles for P2 staged jac-py/Modules/ ports.

Each test compares system ``cc`` on the pinned ``.c`` source against ``jac run``
on the checked-in ``.jac`` lift. Int-line protocol from ``lift_oracle``.

Oracle regime by module (see ``_oracle`` / ``_staged_oracle`` / ``_staged_oracle_with_py_stubs``):
  - Fresh lift (``assert_lift_matches_c``): pystrcmp, getplatform, getcompiler,
    getcopyright, pyfpe
  - Fresh lift + TRAP check (``assert_lift_matches_c_or_traps``): mysnprintf
    (PyOS_snprintf quarantine only; PyOS_vsnprintf uses staged below)
  - Staged .jac (``assert_staged_jac_matches_c``): getbuildinfo, mysnprintf
    (PyOS_vsnprintf edge)
  - Staged .jac + py_runtime_stubs (``_staged_oracle_with_py_stubs``): bisect
    (_bisectmodule), heapq (_heapqmodule)

``rotatingtree`` is staged in ``test_rotatingtree_oracle.jac`` (same harness).
"""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle {
    assert_lift_matches_c,
    assert_lift_matches_c_or_traps,
    assert_staged_jac_matches_c
}

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules"),
     P1_INCLUDES: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p1_corpus", "includes"
     ),
     JACPORT: str = os.path.join(JAC_ROOT, "jaclang", "compiler", "cfront", "porting"),
     PY_STUBS: str = os.path.join(P1_INCLUDES, "py_runtime_stubs.c"),
     PY_ORACLE_INCLUDES: list[str] = [P1_INCLUDES, JACPORT],
     _MOCK_INT_LIST_C: str = (
         "typedef struct { PyObject ob_base; int val; } MockIntObject;\n"
         "static PyObject *mock_sq_item(PyObject *self, Py_ssize_t i) {\n"
         "    return ((PyListObject *)self)->ob_item[i];\n"
         "}\n"
         "static PySequenceMethods mock_list_seq = { .sq_item = mock_sq_item };\n"
         "static PyTypeObject mock_list_type = {\n"
         "    .tp_name = \"mocklist\",\n"
         "    .tp_as_sequence = &mock_list_seq,\n"
         "};\n"
         "static PyTypeObject mock_int_type = { .tp_name = \"mockint\" };\n"
     ),
     _MOCK_HEAP_C: str = (
         "    MockIntObject ints[4];\n"
         "    PyObject *items[4];\n"
         "    PyListObject list;\n"
         "    int vals[4] = {1, 3, 5, 7};\n"
         "    int i;\n"
         "    for (i = 0; i < 4; i++) {\n"
         "        ints[i].ob_base.ob_type = &mock_int_type;\n"
         "        ints[i].val = vals[i];\n"
         "        items[i] = (PyObject *)&ints[i];\n"
         "    }\n"
         "    list.ob_base.ob_type = &mock_list_type;\n"
         "    list.ob_size = 4;\n"
         "    list.ob_item = items;\n"
     ),
     _PY_MOCK_JAC: str = (
         "glob _mock_objs: list = [];\n"
         "glob _mock_vals: list = [];\n"
         "def PyObject_RichCompareBool(a: PyObj, b: PyObj, op: int) -> int {\n"
         "    av = 0; bv = 0;\n"
         "    for i in range(len(_mock_objs)) {\n"
         "        if _mock_objs[i] is a { av = _mock_vals[i]; }\n"
         "        if _mock_objs[i] is b { bv = _mock_vals[i]; }\n"
         "    }\n"
         "    if op == 0 and av < bv { return 1; }\n"
         "    return 0;\n"
         "}\n"
         "def PySequence_Size(seq: PyObj) -> int {\n"
         "    lst: PyListObject = seq;\n"
         "    return lst.ob_size;\n"
         "}\n"
         "def Py_EnterRecursiveCall(where: str) -> int { return 0; }\n"
         "def Py_LeaveRecursiveCall() -> None { }\n"
         "def PyErr_SetString(exc: PyObj, msg: str) -> None { }\n"
         "def Py_INCREF(o: PyObj) -> None { }\n"
         "def Py_DECREF(o: PyObj) -> None { }\n"
         "def mock_sq_item(s: PyObj, i: int) -> PyObj {\n"
         "    lst: PyListObject = s;\n"
         "    items: list = lst.ob_item;\n"
         "    return items[i];\n"
         "}\n"
         "def get_sq_item(s: PyObj) { return mock_sq_item; }\n"
         "def _make_int(v: int) -> PyObj {\n"
         "    o = PyObject();\n"
         "    _mock_objs.append(o);\n"
         "    _mock_vals.append(v);\n"
         "    return o;\n"
         "}\n"
         "def _mock_heap_list() -> PyListObject {\n"
         "    items = [_make_int(1), _make_int(3), _make_int(5), _make_int(7)];\n"
         "    lst = PyListObject();\n"
         "    lst.ob_size = 4;\n"
         "    lst.ob_item = items;\n"
         "    list_type = PyTypeObject();\n"
         "    list_seq = PySequenceMethods();\n"
         "    list_seq.sq_item = ssizeargfunc();\n"
         "    list_type.tp_as_sequence = list_seq;\n"
         "    lst.ob_base.ob_type = list_type;\n"
         "    return lst;\n"
         "}\n"
     );


def _oracle(c_name: str, driver: str, jac_entry: str) {
    c_path = os.path.join(MODULES, c_name);
    assert_lift_matches_c(c_path, driver, jac_entry, include_dirs=[MODULES]);
}


def _staged_oracle(c_name: str, driver: str, jac_entry: str) {
    base = os.path.splitext(c_name)[0];
    c_path = os.path.join(MODULES, c_name);
    jac_path = os.path.join(MODULES, f"{base}.jac");
    assert_staged_jac_matches_c(
        c_path, jac_path, driver, jac_entry, include_dirs=[MODULES]
    );
}


def _staged_oracle_with_py_stubs(c_name: str, driver: str, jac_entry: str) {
    base = os.path.splitext(c_name)[0];
    c_path = os.path.join(MODULES, c_name);
    jac_path = os.path.join(MODULES, f"{base}.jac");
    assert_staged_jac_matches_c(
        c_path,
        jac_path,
        driver,
        jac_entry,
        include_dirs=PY_ORACLE_INCLUDES,
        extra_sources=[PY_STUBS]
    );
}


test "jac-py pystrcmp: cc vs lifted jac agree on PyOS_mystricmp" {
    _oracle(
        "pystrcmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"Ab\", \"aB\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"Ab\", \"aB\"));\n" "}\n"
    );
}

test "jac-py getplatform: cc vs lifted jac agree on Py_GetPlatform length" {
    _oracle(
        "getplatform.c",
        "#include <stdio.h>\n"
        "#include <string.h>\n"
        "const char *Py_GetPlatform(void);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)strlen(Py_GetPlatform()));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(len(Py_GetPlatform()));\n" "}\n"
    );
}

test "jac-py getcompiler: cc vs lifted jac agree on Py_GetCompiler first byte" {
    _oracle(
        "getcompiler.c",
        "#include <stdio.h>\n"
        "const char *Py_GetCompiler(void);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)Py_GetCompiler()[0]);\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(ord(Py_GetCompiler()[0]));\n" "}\n"
    );
}

test "jac-py getcopyright: cc vs lifted jac agree on Py_GetCopyright length" {
    _oracle(
        "getcopyright.c",
        "#include <stdio.h>\n"
        "#include <string.h>\n"
        "const char *Py_GetCopyright(void);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)strlen(Py_GetCopyright()));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(len(Py_GetCopyright()));\n" "}\n"
    );
}

test "jac-py getbuildinfo: cc vs staged jac agree on Py_GetBuildInfo length" {
    _staged_oracle(
        "getbuildinfo.c",
        "#include <stdio.h>\n"
        "#include <string.h>\n"
        "const char *Py_GetBuildInfo(void);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)strlen(Py_GetBuildInfo()));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(len(Py_GetBuildInfo()));\n" "}\n"
    );
}

test "jac-py pyfpe: cc vs lifted jac agree on PyFPE_dummy" {
    _oracle(
        "pyfpe.c",
        "#include <stdio.h>\n"
        "double PyFPE_dummy(void *dummy);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)PyFPE_dummy(0));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(int(PyFPE_dummy(None)));\n" "}\n"
    );
}

test "jac-py mysnprintf: PyOS_snprintf is quarantined (TRAP)" {
    (status, detail) = assert_lift_matches_c_or_traps(
        os.path.join(MODULES, "mysnprintf.c"),
        "#include <stdio.h>\n"
        "int PyOS_snprintf(char *str, unsigned long size, const char *format, ...);\n"
        "int main(void) {\n"
        "    char buf[8];\n"
        "    printf(\"%d\\n\", PyOS_snprintf(buf, 8, \"x\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    buf = \"\\0\\0\\0\\0\\0\\0\\0\\0\";\n"
        "    print(PyOS_snprintf(buf, 8, \"x\"));\n"
        "}\n",
        "PyOS_snprintf",
        include_dirs=[MODULES]
    );
    assert status == "ok" , detail;
    assert detail == "trap" , detail;
}

test "jac-py mysnprintf: cc vs staged jac agree on PyOS_vsnprintf size edge" {
    _staged_oracle(
        "mysnprintf.c",
        "#include <stdio.h>\n"
        "typedef char *va_list;\n"
        "int PyOS_vsnprintf(char *str, unsigned long size, const char *format, va_list va);\n"
        "int main(void) {\n"
        "    char buf[8];\n"
        "    printf(\"%d\\n\", PyOS_vsnprintf(buf, 2147483647UL, \"x\", 0));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    buf = \"\\0\\0\\0\\0\\0\\0\\0\\0\";\n"
        "    print(PyOS_vsnprintf(buf, 2147483647, \"x\", \"\"));\n"
        "}\n"
    );
}

test "jac-py bisect: cc vs staged jac agree on bisect_right mock list" {
    _staged_oracle_with_py_stubs(
        "_bisectmodule.c",
        "#include <stdio.h>\n" "#include \"Python.h\"\n"
            + _MOCK_INT_LIST_C
            + "Py_ssize_t bisect_right(PyObject *list, PyObject *item, Py_ssize_t lo,\n"
            + "                        Py_ssize_t hi, PyObject *key);\n"
            + "int main(void) {\n"
            + _MOCK_HEAP_C
            + "    MockIntObject item4;\n"
            + "    item4.ob_base.ob_type = &mock_int_type;\n"
            + "    item4.val = 4;\n"
            + "    printf(\"%ld\\n\", (long)bisect_right((PyObject *)&list,\n"
            + "                                          (PyObject *)&item4, 0, -1, Py_None));\n"
            + "    return 0;\n"
            + "}\n",
        _PY_MOCK_JAC
            + "with entry {\n"
            + "    lst = _mock_heap_list();\n"
            + "    item4 = _make_int(4);\n"
            + "    print(bisect_right(lst, item4, 0, -1, Py_None));\n"
            + "}\n"
    );
}

test "jac-py heapq: cc vs staged jac agree on heap_siftdown mock heap" {
    _staged_oracle_with_py_stubs(
        "_heapqmodule.c",
        "#include <stdio.h>\n" "#include \"Python.h\"\n"
            + _MOCK_INT_LIST_C
            + "int heap_siftdown(PyObject *heap, Py_ssize_t startpos, Py_ssize_t pos);\n"
            + "int main(void) {\n"
            + _MOCK_HEAP_C
            + "    printf(\"%d\\n\", heap_siftdown((PyObject *)&list, 0, 3));\n"
            + "    return 0;\n"
            + "}\n",
        _PY_MOCK_JAC
            + "with entry {\n"
            + "    lst = _mock_heap_list();\n"
            + "    print(heap_siftdown(lst, 0, 3));\n"
            + "}\n"
    );
}
