"""Round-trip tests for the compact codegen IR (epic #8201, lane 2).

The generic encoder below plays the producer role: it walks a real CPython
ast and emits JCIR through the reference writer, so the round trip proves
the instruction vocabulary can carry everything the shim must rebuild. The
hand-emitted tests prove the writer contract is usable without ast on the
producer side, which is the seat the sealed native emitter sits in.
"""

import ast as pyast;
import __future__ as pyfuture;
import from builtins { exec as pyexec }
import from jaclang.compiler.backends.py.codegen_ir {
    CIR_FORMAT_VERSION,
    CirDiag,
    CodegenIrFormatError,
    CodegenIrVersionError,
    CodegenIrWriter,
    DIAG_WARNING,
    read_container
}
import from jaclang.compiler.backends.py.codegen_shim { compile_ir, transcribe }

glob FIXTURE_SRC: str = """'''Round trip fixture.'''
def greet(name, excited=False):
    msg = f"hello {name}"
    if excited:
        msg = msg + "!"
    return msg

class Counter:
    def __init__(self):
        self.total = 0

    def add(self, n):
        for i in range(n):
            self.total = self.total + 1
        return self.total

result = greet("world", True)
count = Counter().add(3)
""";

def encode_value(w: CodegenIrWriter, val: object) {
    if val is None {
        w.emit_none();
    } elif val is Ellipsis {
        w.emit_ellipsis();
    } elif isinstance(val, bool) {
        if val {
            w.emit_true();
        } else {
            w.emit_false();
        }
    } elif isinstance(val, int) {
        w.emit_int(val);
    } elif isinstance(val, float) {
        w.emit_float(val);
    } elif isinstance(val, str) {
        w.emit_str(val);
    } elif isinstance(val, bytes) {
        w.emit_bytes(val);
    } elif isinstance(val, list) {
        for item in val {
            encode_value(w, item);
        }
        w.emit_list(len(val));
    } elif isinstance(val, pyast.AST) {
        names: list = [];
        for (fname, fval) in pyast.iter_fields(val) {
            encode_value(w, fval);
            names.append(fname);
        }
        if "lineno" in val._attributes {
            # Location fields live on concrete nodes, not the `AST` base the
            # stub types here; the `_attributes` guard is the real check.
            located: any = val;
            end_line = located.end_lineno
                if located.end_lineno is not None
                else located.lineno;
            end_col = located.end_col_offset
                if located.end_col_offset is not None
                else located.col_offset;
            w.emit_loc(located.lineno, located.col_offset, end_line, end_col);
        }
        w.emit_node(type(val).__name__, names);
    } else {
        raise ValueError(
            f"fixture uses a value the encoder does not cover: {type(val).__name__}"
        );
    }
}

def fixture_blob -> bytes {
    tree = pyast.parse(FIXTURE_SRC);
    w = CodegenIrWriter();
    w.begin_module("rt_fixture.py");
    w.emit_loc(1, 0, 1, 0);
    encode_value(w, tree);
    w.end_module();
    return w.to_bytes();
}

test "codegen ir round trips a real program" {
    blob = fixture_blob();
    result = compile_ir(blob);
    assert len(result.diags) == 0;
    assert len(result.modules) == 1;
    assert result.modules[0].mod_path == "rt_fixture.py";
    assert len(result.modules[0].bytecode) > 0;
    ns: dict = {};
    pyexec(result.modules[0].code_obj, ns);
    assert ns["result"] == "hello world!";
    assert ns["count"] == 3;
    assert ns["__doc__"] == "Round trip fixture.";
    assert ns["greet"]("jac") == "hello jac";
    assert ns["greet"].__code__.co_firstlineno == 2;
}

test "compiled modules do not inherit future flags from the shim" {
    result = compile_ir(fixture_blob());
    assert len(result.diags) == 0;
    assert (result.modules[0].code_obj.co_flags & pyfuture.annotations.compiler_flag)
        == 0;
}

test "transcribed tree matches the source ast exactly" {
    tree = pyast.parse(FIXTURE_SRC);
    (mods, diags) = transcribe(fixture_blob());
    assert diags == [];
    assert len(mods) == 1;
    want = pyast.dump(tree, include_attributes=True);
    got = pyast.dump(mods[0][1], include_attributes=True);
    assert got == want;
}

test "hand emitted ir proves the writer contract" {
    w = CodegenIrWriter();
    w.begin_module("hand.py");
    w.emit_loc(1, 0, 1, 14);
    w.emit_str("value");
    w.emit_node("Store", []);
    w.emit_node("Name", ["id", "ctx"]);
    w.emit_list(1);
    w.emit_int(40);
    w.emit_node("Constant", ["value"]);
    w.emit_node("Add", []);
    w.emit_int(2);
    w.emit_node("Constant", ["value"]);
    w.emit_node("BinOp", ["left", "op", "right"]);
    w.emit_node("Assign", ["targets", "value"]);
    w.emit_loc(2, 0, 2, 20);
    w.emit_str("big");
    w.emit_node("Store", []);
    w.emit_node("Name", ["id", "ctx"]);
    w.emit_list(1);
    w.emit_int(2 ** 70 + 5);
    w.emit_node("Constant", ["value"]);
    w.emit_node("Assign", ["targets", "value"]);
    w.emit_list(2);
    w.emit_list(0);
    w.emit_node("Module", ["body", "type_ignores"]);
    w.end_module();
    result = compile_ir(w.to_bytes());
    assert len(result.diags) == 0;
    ns: dict = {};
    pyexec(result.modules[0].code_obj, ns);
    assert ns["value"] == 42;
    assert ns["big"] == 2 ** 70 + 5;
}

test "python inline splice lands with offset line numbers" {
    w = CodegenIrWriter();
    w.begin_module("splice.py");
    w.emit_loc(1, 0, 1, 1);
    w.emit_parse_splice("X = 40\nY = X + 2", 10);
    w.emit_list(1);
    w.emit_list(0);
    w.emit_node("Module", ["body", "type_ignores"]);
    w.end_module();
    blob = w.to_bytes();
    (mods, splice_diags) = transcribe(blob);
    assert splice_diags == [];
    body = mods[0][1].body;
    assert len(body) == 2;
    assert body[0].lineno == 11;
    assert body[1].lineno == 12;
    result = compile_ir(blob);
    ns: dict = {};
    pyexec(result.modules[0].code_obj, ns);
    assert ns["X"] == 40;
    assert ns["Y"] == 42;
}

test "version mismatch is refused" {
    blob = bytearray(fixture_blob());
    blob[4] = (CIR_FORMAT_VERSION + 1) & 255;
    caught = False;
    try {
        read_container(bytes(blob));
    } except CodegenIrVersionError {
        caught = True;
    }
    assert caught;
}

test "unknown opcode is a hard error" {
    w = CodegenIrWriter();
    w.begin_module("bad.py");
    w.emit_loc(1, 0, 1, 1);
    w.emit_list(0);
    w._code.append(123);
    w.end_module();
    blob = w.to_bytes();
    caught = "";
    try {
        compile_ir(blob);
    } except CodegenIrFormatError as e {
        caught = str(e);
    }
    assert "unknown opcode 123" in caught;
    assert "refusing to guess" in caught;
}

test "diagnostics cross the container" {
    w = CodegenIrWriter();
    w.add_diag(
        CirDiag(
            message="native lane demoted method walk",
            code_str="E9001",
            mod_path="m.jac",
            severity=DIAG_WARNING,
            help="declare the field",
            first_line=3,
            col_start=1,
            last_line=3,
            col_end=9
        )
    );
    blob = w.to_bytes();
    container = read_container(blob);
    assert len(container.diags) == 1;
    d = container.diags[0];
    assert d.message == "native lane demoted method walk";
    assert d.code_str == "E9001";
    assert d.mod_path == "m.jac";
    assert d.severity == DIAG_WARNING;
    assert d.help == "declare the field";
    assert (d.first_line, d.col_start, d.last_line, d.col_end, ) == (3, 1, 3, 9, );
    result = compile_ir(blob);
    assert result.modules == [];
    assert len(result.diags) == 1;
    assert result.diags[0].code_str == "E9001";
}

test "writer refuses an unbalanced module stream" {
    w = CodegenIrWriter();
    w.begin_module("unbalanced.py");
    w.emit_loc(1, 0, 1, 1);
    w.emit_int(1);
    w.emit_int(2);
    caught = False;
    try {
        w.end_module();
    } except CodegenIrFormatError {
        caught = True;
    }
    assert caught;
}
